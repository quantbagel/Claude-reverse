#!/bin/bash
# Auto-generated configuration for decompilation project
# Generated: Tue  9 Dec 2025 20:48:29 EST

# Target binary
BINARY_PATH="/Users/bagel/Desktop/everything/projects/Claude-reverse/targets/df/df_linux/libs/Dwarf_Fortress"

# Architecture
ARCH="x86_64"

# Compiler settings
CC="gcc"

# Compiler flags - adjust these to match the original binary
# Common flags to try: -O0, -O1, -O2, -O3, -Os
# For exact matches, you may need to experiment with:
#   - Optimization level
#   - Debug info (-g)
#   - Position independent code (-fPIC, -fPIE)
#   - Stack protection (-fno-stack-protector)
CFLAGS="-O2 -fno-pic -fno-pie"

# Architecture-specific flags
case "$ARCH" in
    x86_64)
        CFLAGS="$CFLAGS -m64"
        ;;
    i386)
        CFLAGS="$CFLAGS -m32"
        ;;
    arm64)
        CFLAGS="$CFLAGS -arch arm64"
        ;;
esac

# Include paths
INCLUDE_DIRS="-I$(dirname "${BASH_SOURCE[0]}")/include"

# Maximum attempts per function before giving up
MAX_ATTEMPTS=10

# Claude settings
CLAUDE_MAX_TURNS=50
