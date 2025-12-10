#!/bin/bash
# driver-df.sh - Dwarf Fortress decompilation driver
# Usage: driver-df.sh [--single <func>] [--continuous] [--dry-run]
#
# Uses Docker for Linux x86_64 compilation and comparison.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source config.sh 2>/dev/null || true

MODE="single"
SINGLE_FUNC=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --single) MODE="single"; SINGLE_FUNC="$2"; shift 2 ;;
        --continuous) MODE="continuous"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: driver-df.sh [--single <func>] [--continuous] [--dry-run]"
            exit 0
            ;;
        *) shift ;;
    esac
done

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

run_claude() {
    local func="$1"

    log "=== Decompiling: $func ==="

    local prompt="You are decompiling Dwarf Fortress, a C++ game.

TARGET: $func

## Tools Available (run via Bash)
- tools/disasm $func          # Get x86_64 assembly
- tools/decompile $func       # Get pseudocode hints
- tools/context $func         # See function relationships
- tools/classes <name>        # Analyze C++ classes
- tools/demangle <name>       # Decode C++ names
- tools/docker-build <file.cpp>           # Compile (Linux x86_64)
- tools/docker-compare $func <file.cpp>   # Verify match

## Workflow
1. Run tools/disasm to see the assembly
2. Run tools/decompile for pseudocode hints
3. Write C++ code in src/<name>.cpp
4. Run tools/docker-build to compile
5. Run tools/docker-compare to check match
6. Iterate until MATCH or give up

## Notes
- This is C++ - use classes, proper types
- Target is Linux x86_64, compiled with g++
- Binary is stripped, work from assembly
- Put headers in include/

START: Run tools/disasm $func"

    if $DRY_RUN; then
        echo "=== DRY RUN ==="
        echo "$prompt"
        return
    fi

    local attempt_log="$LOG_DIR/${func}_$(date +%Y%m%d_%H%M%S).log"

    # Use permission-mode bypassPermissions for automated runs
    # The tools are sandboxed to tools/* directory
    claude -p "$prompt" \
        --allowedTools "Bash(tools/*),Bash(src/*),Edit,Write,Read" \
        --max-turns 100 \
        --permission-mode bypassPermissions \
        2>&1 | tee "$attempt_log"

    # Check if it was a match and update state
    if grep -q "MATCH" "$attempt_log"; then
        log "SUCCESS: $func matched!"
        # Update state to mark as matched
        local tmp=$(mktemp)
        jq ".[\"$func\"].status = \"matched\"" state/functions.json > "$tmp" && mv "$tmp" state/functions.json
        echo "$func" >> state/matched.txt
    else
        # Increment attempts
        local attempts=$(jq -r ".[\"$func\"].attempts // 0" state/functions.json)
        local tmp=$(mktemp)
        jq ".[\"$func\"].attempts = $((attempts + 1))" state/functions.json > "$tmp" && mv "$tmp" state/functions.json
        log "No match for $func (attempt $((attempts + 1)))"
    fi
}

# Main
log "=== Dwarf Fortress Decompilation ==="
log "Mode: $MODE"

case $MODE in
    single)
        func="${SINGLE_FUNC:-$(python3 scorer.py 2>/dev/null | head -1)}"
        if [[ -z "$func" ]]; then
            log "No function specified and scorer returned nothing"
            exit 1
        fi
        run_claude "$func"
        ;;
    continuous)
        log "Continuous mode - Ctrl+C to stop"
        while true; do
            func=$(python3 scorer.py 2>/dev/null | head -1)
            [[ -z "$func" ]] && { log "Done!"; break; }
            run_claude "$func"
            sleep 5
        done
        ;;
esac

log "=== Complete ==="
