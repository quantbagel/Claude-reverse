#!/bin/bash
# driver.sh - Main orchestration loop for automated decompilation
# Usage: driver.sh [--single <func>] [--continuous] [--dry-run]
#
# This script:
# 1. Selects the next function to decompile (via scorer.py)
# 2. Invokes Claude Code CLI with the appropriate tools
# 3. Handles rate limits with exponential backoff
# 4. Updates state and auto-commits successful matches
# 5. Logs all output for debugging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load config
if [[ ! -f "config.sh" ]]; then
    echo "ERROR: config.sh not found. Run init.sh first."
    exit 1
fi
source config.sh

# Parse arguments
MODE="single"  # single, continuous
SINGLE_FUNC=""
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --single)
            MODE="single"
            SINGLE_FUNC="$2"
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
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: driver.sh [options]"
            echo ""
            echo "Options:"
            echo "  --single <func>   Attempt a single specific function"
            echo "  --continuous      Keep running until all functions are done"
            echo "  --dry-run         Show what would be done without running Claude"
            echo "  --verbose, -v     Show more output"
            echo ""
            echo "Default: Attempt one function selected by scorer"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Rate limit handling
BACKOFF_BASE=60
BACKOFF_MAX=3600
CURRENT_BACKOFF=$BACKOFF_BASE

# Logging
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
SESSION_LOG="$LOG_DIR/session_$(date +%Y%m%d_%H%M%S).log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$SESSION_LOG"
}

log_verbose() {
    if $VERBOSE; then
        log "$1"
    fi
}

# State management
STATE_FILE="$SCRIPT_DIR/state/functions.json"

update_state() {
    local func_name="$1"
    local field="$2"
    local value="$3"

    # Use jq to update the state file
    local tmp=$(mktemp)
    jq ".[\"$func_name\"].$field = $value" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

increment_attempts() {
    local func_name="$1"
    local current=$(jq -r ".[\"$func_name\"].attempts // 0" "$STATE_FILE")
    update_state "$func_name" "attempts" "$((current + 1))"
}

mark_matched() {
    local func_name="$1"
    local source_file="$2"

    update_state "$func_name" "status" '"matched"'
    update_state "$func_name" "source_file" "\"$source_file\""

    # Add to matched.txt
    echo "$func_name" >> "$SCRIPT_DIR/state/matched.txt"

    log "SUCCESS: $func_name matched! Source: $source_file"
}

# Git integration
auto_commit() {
    local func_name="$1"
    local source_file="$2"

    if [[ -d ".git" ]]; then
        git add "$source_file" state/functions.json state/matched.txt 2>/dev/null || true
        git commit -m "Match: $func_name

Decompiled $func_name to $source_file

🤖 Generated with Claude Code" 2>/dev/null || true
        log "Committed match for $func_name"
    fi
}

# Claude invocation
invoke_claude() {
    local func_name="$1"

    log "Invoking Claude for function: $func_name"

    # Create the prompt
    local prompt="You are decompiling the function '$func_name' from a binary.

Your goal is to write C code that compiles to assembly that EXACTLY matches the original binary.

IMPORTANT WORKFLOW:
1. First, use 'tools/disasm $func_name --compact' to see the assembly (compact mode reduces tokens)
2. Use 'tools/find-similar $func_name --matched-only --show-code' to see similar ALREADY DECOMPILED functions as examples
3. Use 'tools/context $func_name' to understand what functions it calls and any dependencies
4. Write your C implementation in src/${func_name}.c
5. Use tools/build to compile your code
6. Use tools/compare to check if your code matches the original
7. If there's a mismatch, analyze the diff and adjust your code
8. Repeat steps 5-7 until you get a MATCH or determine it's not possible

RULES:
- Write idiomatic C code, but prioritize matching assembly over readability
- You may need to use specific patterns (goto, pointer arithmetic) to match
- Include necessary headers from include/
- Learn from similar matched functions - they show patterns that work
- If you can't match after several attempts, explain why and stop

START NOW: Begin by running tools/disasm $func_name --compact"

    # Build the Claude command
    local claude_cmd="claude"
    claude_cmd="$claude_cmd -p \"$prompt\""
    claude_cmd="$claude_cmd --allowedTools \"Bash(tools/*),Bash(src/*),Edit,Write,Read\""
    claude_cmd="$claude_cmd --max-turns ${CLAUDE_MAX_TURNS:-50}"

    if $DRY_RUN; then
        log "DRY RUN: Would execute:"
        log "$claude_cmd"
        return 0
    fi

    # Create a log file for this attempt
    local attempt_log="$LOG_DIR/${func_name}_$(date +%Y%m%d_%H%M%S).log"

    # Run Claude and capture output
    log_verbose "Running: $claude_cmd"

    # Execute Claude
    set +e
    eval "$claude_cmd" 2>&1 | tee "$attempt_log"
    local exit_code=${PIPESTATUS[0]}
    set -e

    # Check for rate limiting
    if grep -qi "rate limit\|too many requests\|429" "$attempt_log" 2>/dev/null; then
        log "Rate limited, backing off for ${CURRENT_BACKOFF}s..."
        sleep $CURRENT_BACKOFF
        CURRENT_BACKOFF=$((CURRENT_BACKOFF * 2))
        if [[ $CURRENT_BACKOFF -gt $BACKOFF_MAX ]]; then
            CURRENT_BACKOFF=$BACKOFF_MAX
        fi
        return 2  # Signal rate limit
    fi

    # Reset backoff on success
    CURRENT_BACKOFF=$BACKOFF_BASE

    # Check if a match was achieved
    if grep -q "MATCH - SUCCESS" "$attempt_log" 2>/dev/null; then
        # Find the source file
        local source_file=$(grep -o 'src/[^ ]*\.c' "$attempt_log" | head -1)
        if [[ -z "$source_file" ]]; then
            source_file="src/${func_name}.c"
        fi

        mark_matched "$func_name" "$source_file"
        auto_commit "$func_name" "$source_file"
        return 0
    else
        increment_attempts "$func_name"
        log "No match achieved for $func_name"
        return 1
    fi
}

# Main function
attempt_function() {
    local func_name="$1"

    log "=== Attempting: $func_name ==="

    # Check attempts
    local attempts=$(jq -r ".[\"$func_name\"].attempts // 0" "$STATE_FILE")
    if [[ $attempts -ge ${MAX_ATTEMPTS:-10} ]]; then
        log "SKIP: $func_name has $attempts attempts (max: ${MAX_ATTEMPTS:-10})"
        return 1
    fi

    # Check status
    local status=$(jq -r ".[\"$func_name\"].status // \"unmatched\"" "$STATE_FILE")
    if [[ "$status" == "matched" ]]; then
        log "SKIP: $func_name is already matched"
        return 0
    fi

    invoke_claude "$func_name"
    return $?
}

# Signal handling for graceful shutdown
SHUTDOWN=false
trap 'SHUTDOWN=true; log "Shutdown requested, finishing current function..."' SIGINT SIGTERM

# Main loop
main() {
    log "=== Decompilation Driver Started ==="
    log "Mode: $MODE"
    log "Binary: $BINARY_PATH"
    log "Session log: $SESSION_LOG"
    echo ""

    if [[ "$MODE" == "single" ]]; then
        # Single function mode
        local func="$SINGLE_FUNC"

        if [[ -z "$func" ]]; then
            # Get next function from scorer
            func=$(python3 scorer.py 2>/dev/null) || {
                log "No functions available to attempt"
                exit 0
            }
        fi

        attempt_function "$func"

    elif [[ "$MODE" == "continuous" ]]; then
        # Continuous mode
        log "Running in continuous mode (Ctrl+C to stop)"

        while ! $SHUTDOWN; do
            # Get next function
            local func=$(python3 scorer.py 2>/dev/null) || {
                log "No more functions to attempt!"
                break
            }

            attempt_function "$func"
            local result=$?

            if [[ $result -eq 2 ]]; then
                # Rate limited, will retry
                continue
            fi

            # Brief pause between functions
            sleep 2
        done

        log "Continuous mode ended"
    fi

    # Print summary
    echo ""
    log "=== Session Summary ==="
    local matched=$(jq '[.[] | select(.status == "matched")] | length' "$STATE_FILE")
    local total=$(jq 'length' "$STATE_FILE")
    log "Matched: $matched / $total functions"
    log "Log file: $SESSION_LOG"
}

main
