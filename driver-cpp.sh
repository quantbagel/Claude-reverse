#!/bin/bash
# driver-cpp.sh - Orchestration loop for C++ decompilation (e.g., Dwarf Fortress)
# Usage: driver-cpp.sh [--single <func>] [--continuous] [--class <classname>]
#
# Like driver.sh but optimized for C++ binaries:
# - Uses decompiler hints (Ghidra/r2)
# - Handles C++ name mangling
# - Groups functions by class
# - More lenient matching (semantic equivalence)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "config.sh" ]]; then
    echo "ERROR: config.sh not found. Run init.sh first."
    exit 1
fi
source config.sh

# Parse arguments
MODE="single"
SINGLE_FUNC=""
TARGET_CLASS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --single)
            MODE="single"
            SINGLE_FUNC="$2"
            shift 2
            ;;
        --class)
            MODE="class"
            TARGET_CLASS="$2"
            shift 2
            ;;
        --continuous)
            MODE="continuous"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: driver-cpp.sh [options]"
            echo ""
            echo "Options:"
            echo "  --single <func>    Attempt a single function"
            echo "  --class <name>     Attempt all methods of a class"
            echo "  --continuous       Keep running until done"
            echo "  --dry-run          Show prompt without running"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            exit 1
            ;;
    esac
done

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
SESSION_LOG="$LOG_DIR/cpp_session_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$SESSION_LOG"
}

# C++ specific prompt - focuses on decompiler output and semantic matching
invoke_claude_cpp() {
    local func_name="$1"
    local demangled=$(echo "$func_name" | c++filt)

    log "=== Attempting: $func_name ==="
    log "Demangled: $demangled"

    # Get decompiler output first
    local decomp_hint=""
    decomp_hint=$(./tools/decompile "$func_name" 2>/dev/null | head -100)

    local prompt="You are reverse engineering a C++ binary to recreate its source code.

TARGET FUNCTION: $func_name
DEMANGLED NAME: $demangled

## Available Tools
- tools/disasm <func>     - Get assembly
- tools/decompile <func>  - Get decompiler pseudocode
- tools/context <func>    - See called functions, callers
- tools/classes <name>    - Analyze C++ class structure
- tools/demangle <name>   - Demangle C++ names
- tools/build <file.cpp>  - Compile your code
- tools/compare <func> <file.cpp> - Compare output

## Decompiler Hint
Here's what the decompiler suggests for this function:
\`\`\`
$decomp_hint
\`\`\`

## Your Task
1. Analyze the decompiler output and assembly
2. Write clean C++ code that implements the same logic
3. Place your code in src/ (e.g., src/ClassName.cpp)
4. Create necessary headers in include/
5. Build and compare - iterate until it matches or you determine it's not achievable

## C++ Considerations
- This is C++ - use classes, methods, proper headers
- Watch for: virtual functions, vtables, RTTI
- STL containers may be used (std::vector, std::string, etc.)
- Name mangling affects symbol lookup

## Matching Strategy
For C++, exact byte-matching is often impossible. Aim for:
1. Same control flow (branches, loops)
2. Same function calls in same order
3. Equivalent register usage
4. If semantically equivalent but not byte-identical, document the difference

START NOW. First examine the assembly and decompiler output."

    if $DRY_RUN; then
        log "=== DRY RUN - Prompt ==="
        echo "$prompt"
        return 0
    fi

    local attempt_log="$LOG_DIR/${func_name//\//_}_$(date +%Y%m%d_%H%M%S).log"

    # Run Claude
    claude -p "$prompt" \
        --allowedTools "Bash(tools/*),Bash(src/*),Edit,Write,Read" \
        --max-turns ${CLAUDE_MAX_TURNS:-100} \
        2>&1 | tee "$attempt_log"
}

# Main
main() {
    log "=== C++ Decompilation Driver ==="
    log "Binary: $BINARY_PATH"
    log "Mode: $MODE"

    case $MODE in
        single)
            if [[ -z "$SINGLE_FUNC" ]]; then
                # Get next function from scorer
                SINGLE_FUNC=$(python3 scorer.py 2>/dev/null) || {
                    log "No functions available"
                    exit 0
                }
            fi
            invoke_claude_cpp "$SINGLE_FUNC"
            ;;

        class)
            log "Targeting class: $TARGET_CLASS"
            # Get all methods of the class
            methods=$(nm "$BINARY_PATH" 2>/dev/null | c++filt | grep "$TARGET_CLASS::" | awk '{print $3}' | head -20)
            for method in $methods; do
                log "--- Method: $method ---"
                invoke_claude_cpp "$method"
                sleep 2
            done
            ;;

        continuous)
            log "Continuous mode - Ctrl+C to stop"
            while true; do
                func=$(python3 scorer.py 2>/dev/null) || {
                    log "No more functions!"
                    break
                }
                invoke_claude_cpp "$func"
                sleep 5
            done
            ;;
    esac

    log "=== Session complete ==="
}

main
