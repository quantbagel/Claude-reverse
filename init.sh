#!/bin/bash
# init.sh - Initialize a decompilation project from a binary
# Usage: init.sh <binary_path> [--compiler clang|gcc] [--arch x86_64|arm64]
#
# This script:
# 1. Analyzes the binary with radare2 to identify functions
# 2. Creates the state/functions.json with function metadata
# 3. Generates config.sh with appropriate compiler settings
# 4. Sets up the directory structure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
BINARY_PATH=""
COMPILER="clang"
ARCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --compiler)
            COMPILER="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: init.sh <binary_path> [--compiler clang|gcc] [--arch x86_64|arm64]"
            echo ""
            echo "Options:"
            echo "  --compiler    Compiler to use (default: clang)"
            echo "  --arch        Target architecture (auto-detected if not specified)"
            exit 0
            ;;
        *)
            if [[ -z "$BINARY_PATH" ]]; then
                BINARY_PATH="$1"
            else
                echo "ERROR: Unknown argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$BINARY_PATH" ]]; then
    echo "ERROR: No binary path specified."
    echo "Usage: init.sh <binary_path> [--compiler clang|gcc] [--arch x86_64|arm64]"
    exit 1
fi

# Convert to absolute path
if [[ "$BINARY_PATH" != /* ]]; then
    BINARY_PATH="$(cd "$(dirname "$BINARY_PATH")" && pwd)/$(basename "$BINARY_PATH")"
fi

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "ERROR: Binary not found: $BINARY_PATH"
    exit 1
fi

echo "=== Initializing Decompilation Project ==="
echo "Binary: $BINARY_PATH"
echo ""

# Check for radare2
if ! command -v r2 &> /dev/null; then
    echo "ERROR: radare2 (r2) not found. Please install it:"
    echo "  macOS: brew install radare2"
    echo "  Linux: apt install radare2"
    exit 1
fi

# Detect architecture if not specified
if [[ -z "$ARCH" ]]; then
    echo "Detecting architecture..."
    FILE_INFO=$(file "$BINARY_PATH")

    if echo "$FILE_INFO" | grep -qi "x86_64\|x86-64\|AMD64"; then
        ARCH="x86_64"
    elif echo "$FILE_INFO" | grep -qi "arm64\|aarch64"; then
        ARCH="arm64"
    elif echo "$FILE_INFO" | grep -qi "i386\|i686\|x86"; then
        ARCH="i386"
    else
        echo "WARNING: Could not detect architecture, defaulting to x86_64"
        ARCH="x86_64"
    fi
fi

echo "Architecture: $ARCH"
echo "Compiler: $COMPILER"
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p src include state logs .build

# Generate config.sh
echo "Generating config.sh..."
cat > config.sh << EOF
#!/bin/bash
# Auto-generated configuration for decompilation project
# Generated: $(date)

# Target binary
BINARY_PATH="$BINARY_PATH"

# Architecture
ARCH="$ARCH"

# Compiler settings
CC="$COMPILER"

# Compiler flags - adjust these to match the original binary
# Common flags to try: -O0, -O1, -O2, -O3, -Os
# For exact matches, you may need to experiment with:
#   - Optimization level
#   - Debug info (-g)
#   - Position independent code (-fPIC, -fPIE)
#   - Stack protection (-fno-stack-protector)
CFLAGS="-O2"

# Architecture-specific flags
case "\$ARCH" in
    x86_64)
        CFLAGS="\$CFLAGS -m64"
        ;;
    i386)
        CFLAGS="\$CFLAGS -m32"
        ;;
    arm64)
        CFLAGS="\$CFLAGS -arch arm64"
        ;;
esac

# Include paths
INCLUDE_DIRS="-I\$(dirname "\${BASH_SOURCE[0]}")/include"

# Maximum attempts per function before giving up
MAX_ATTEMPTS=10

# Claude settings
CLAUDE_MAX_TURNS=50
EOF

echo "Created config.sh"
echo ""

# Analyze binary with radare2
echo "Analyzing binary with radare2 (this may take a moment)..."

# Create a temporary file for r2 output
R2_OUTPUT=$(mktemp)

# Run r2 analysis and export function information
r2 -q -e scr.color=0 -c "aaa; aflj" "$BINARY_PATH" > "$R2_OUTPUT" 2>/dev/null || {
    echo "WARNING: Full analysis failed, trying basic analysis..."
    r2 -q -e scr.color=0 -c "aa; aflj" "$BINARY_PATH" > "$R2_OUTPUT" 2>/dev/null
}

# Check if we got valid JSON
if ! jq empty "$R2_OUTPUT" 2>/dev/null; then
    echo "ERROR: Failed to get function list from radare2"
    rm -f "$R2_OUTPUT"
    exit 1
fi

# Convert r2 output to our state format
echo "Processing function list..."

python3 << PYTHON_SCRIPT
import json
import sys

with open("$R2_OUTPUT") as f:
    r2_funcs = json.load(f)

state = {}

for func in r2_funcs:
    name = func.get("name", "")

    # Skip invalid or unnamed functions
    if not name or name.startswith("fcn.") and len(name) < 10:
        continue

    # Clean up function name (remove sym. prefix for cleaner names)
    clean_name = name
    if clean_name.startswith("sym."):
        clean_name = clean_name[4:]
    elif clean_name.startswith("sym.imp."):
        # Skip imported functions (we can't decompile those)
        continue

    # Skip very tiny functions (likely thunks or stubs)
    size = func.get("size", 0)
    if size < 4:
        continue

    # Calculate instruction count estimate (rough: size / avg_instruction_size)
    # x86_64 avg instruction is about 4 bytes, ARM64 is exactly 4
    avg_instr_size = 4
    instructions = max(1, size // avg_instr_size)

    # Get additional metadata
    nargs = func.get("nargs", 0)
    nbbs = func.get("nbbs", 1)  # number of basic blocks (complexity indicator)
    cc = func.get("cc", 0)  # cyclomatic complexity if available

    # Calculate complexity score
    complexity = round(
        instructions * 0.1 +
        nbbs * 0.3 +
        cc * 0.2 +
        (size / 100) * 0.1,
        3
    )

    state[clean_name] = {
        "address": hex(func.get("offset", 0)),
        "size": size,
        "instructions": instructions,
        "basic_blocks": nbbs,
        "nargs": nargs,
        "complexity": complexity,
        "status": "unmatched",
        "attempts": 0,
        "source_file": None
    }

# Save state
with open("state/functions.json", "w") as f:
    json.dump(state, f, indent=2)

print(f"Found {len(state)} functions")
PYTHON_SCRIPT

rm -f "$R2_OUTPUT"

# Create initial header file with common types
echo "Creating include/types.h..."
cat > include/types.h << 'EOF'
#ifndef TYPES_H
#define TYPES_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Common type aliases (adjust as needed for your binary)
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef float f32;
typedef double f64;

// Pointer-sized types
typedef intptr_t sptr;
typedef uintptr_t uptr;

#endif // TYPES_H
EOF

# Initialize matched.txt
touch state/matched.txt

echo ""
echo "=== Initialization Complete ==="
echo ""
echo "Project structure:"
echo "  config.sh       - Configuration (edit compiler flags as needed)"
echo "  state/          - Function metadata and progress tracking"
echo "  src/            - Place decompiled C source files here"
echo "  include/        - Headers and type definitions"
echo "  tools/          - CLI tools for Claude"
echo "  logs/           - Session logs"
echo ""

# Show summary
TOTAL=$(jq 'length' state/functions.json)
echo "Found $TOTAL functions to decompile."
echo ""
echo "Next steps:"
echo "  1. Review and adjust config.sh (especially CFLAGS)"
echo "  2. Run: ./driver.sh to start automated decompilation"
echo "  3. Or manually: ./tools/list next"
echo ""
echo "Tips:"
echo "  - Use 'tools/list unmatched' to see remaining functions"
echo "  - Use 'tools/disasm <func>' to view a function's assembly"
echo "  - Use 'tools/context <func>' to understand dependencies"
