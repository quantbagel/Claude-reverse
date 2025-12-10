#!/bin/bash
# driver-parallel.sh - Run multiple decompilation workers in parallel
# Usage: driver-parallel.sh [--workers N] [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source config.sh 2>/dev/null || true

WORKERS=4  # Default parallel workers
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --workers|-w) WORKERS="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: driver-parallel.sh [--workers N] [--dry-run]"
            echo "  --workers N   Number of parallel workers (default: 4)"
            exit 0
            ;;
        *) shift ;;
    esac
done

LOG_DIR="$SCRIPT_DIR/logs"
LOCK_FILE="$SCRIPT_DIR/.lock"
mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# Atomic function to claim a function for processing
claim_function() {
    local worker_id="$1"

    # Use flock for atomic access to state file
    (
        flock -x 200

        # Get next unmatched function with < 10 attempts
        local func=$(jq -r '
            to_entries |
            map(select(.value.status == "unmatched" and (.value.attempts // 0) < 10 and (.value.claimed // false) == false)) |
            sort_by(.value.complexity) |
            .[0].key // empty
        ' state/functions.json)

        if [[ -n "$func" ]]; then
            # Mark as claimed
            local tmp=$(mktemp)
            jq ".[\"$func\"].claimed = true" state/functions.json > "$tmp" && mv "$tmp" state/functions.json
            echo "$func"
        fi
    ) 200>"$LOCK_FILE"
}

# Release claim on a function
release_function() {
    local func="$1"
    local status="$2"  # "matched" or "failed"

    (
        flock -x 200
        local tmp=$(mktemp)

        if [[ "$status" == "matched" ]]; then
            jq ".[\"$func\"].status = \"matched\" | .[\"$func\"].claimed = false" state/functions.json > "$tmp"
            echo "$func" >> state/matched.txt
        else
            local attempts=$(jq -r ".[\"$func\"].attempts // 0" state/functions.json)
            jq ".[\"$func\"].attempts = $((attempts + 1)) | .[\"$func\"].claimed = false" state/functions.json > "$tmp"
        fi

        mv "$tmp" state/functions.json
    ) 200>"$LOCK_FILE"
}

# Worker function
worker() {
    local worker_id="$1"
    local worker_log="$LOG_DIR/worker_${worker_id}.log"

    echo "[Worker $worker_id] Started" >> "$worker_log"

    while true; do
        # Claim a function
        local func=$(claim_function "$worker_id")

        if [[ -z "$func" ]]; then
            echo "[Worker $worker_id] No more functions available" >> "$worker_log"
            break
        fi

        echo "[Worker $worker_id] Processing: $func" >> "$worker_log"
        log "[Worker $worker_id] Processing: $func"

        local attempt_log="$LOG_DIR/${func}_w${worker_id}_$(date +%Y%m%d_%H%M%S).log"

        local prompt="You are decompiling Dwarf Fortress, a C++ game.

TARGET: $func

## Tools Available (run via Bash)
- tools/disasm $func          # Get x86_64 assembly
- tools/decompile $func       # Get pseudocode hints
- tools/context $func         # See function relationships
- tools/docker-build <file.cpp>           # Compile (Linux x86_64)
- tools/docker-compare $func <file.cpp>   # Verify match

## Workflow
1. Run tools/disasm to see the assembly
2. Write C++ code in src/<name>.cpp
3. Run tools/docker-build to compile
4. Run tools/docker-compare to check match
5. Iterate until MATCH or give up after a few tries

START: Run tools/disasm $func"

        if $DRY_RUN; then
            echo "[Worker $worker_id] DRY RUN: $func" >> "$worker_log"
            release_function "$func" "failed"
            continue
        fi

        # Run Claude
        claude -p "$prompt" \
            --allowedTools "Bash(tools/*),Bash(src/*),Edit,Write,Read" \
            --max-turns 50 \
            --permission-mode bypassPermissions \
            > "$attempt_log" 2>&1 || true

        # Check result
        if grep -q "MATCH" "$attempt_log"; then
            log "[Worker $worker_id] SUCCESS: $func"
            release_function "$func" "matched"
        else
            log "[Worker $worker_id] No match: $func"
            release_function "$func" "failed"
        fi

        # Small delay to avoid API rate limits
        sleep 2
    done

    echo "[Worker $worker_id] Finished" >> "$worker_log"
}

# Main
log "=== Parallel Dwarf Fortress Decompilation ==="
log "Workers: $WORKERS"

# Clear any stale claims
jq 'map_values(.claimed = false)' state/functions.json > /tmp/f.json && mv /tmp/f.json state/functions.json

# Start workers in background
pids=()
for i in $(seq 1 $WORKERS); do
    worker "$i" &
    pids+=($!)
    log "Started worker $i (PID: ${pids[-1]})"
    sleep 1  # Stagger starts
done

# Wait for all workers
log "All workers started. Press Ctrl+C to stop."
log "Monitor progress: ./tools/list matched"

trap 'log "Stopping workers..."; kill ${pids[@]} 2>/dev/null; exit' INT TERM

wait "${pids[@]}"

log "=== All workers complete ==="
./tools/list matched | tail -5
