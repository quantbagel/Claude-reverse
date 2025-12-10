#!/usr/bin/env python3
"""
scorer.py - Function selection logic for decompilation

Selects the next best function to attempt decompilation on based on:
1. Complexity score (lower is better - simpler functions first)
2. Number of previous attempts (skip functions with >= 10 attempts)
3. Status (only consider unmatched functions)

Usage:
    python3 scorer.py              # Print next recommended function
    python3 scorer.py --all        # Print all functions sorted by score
    python3 scorer.py --update     # Recalculate complexity scores
"""

import json
import sys
import os
from pathlib import Path

# Find project root
SCRIPT_DIR = Path(__file__).parent.resolve()
STATE_FILE = SCRIPT_DIR / "state" / "functions.json"
MAX_ATTEMPTS = 10


def load_state():
    """Load the functions state file."""
    if not STATE_FILE.exists():
        print(f"ERROR: State file not found at {STATE_FILE}", file=sys.stderr)
        print("Run init.sh first to analyze the binary.", file=sys.stderr)
        sys.exit(1)

    with open(STATE_FILE) as f:
        return json.load(f)


def save_state(state):
    """Save the functions state file."""
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def calculate_complexity(func_data):
    """
    Calculate complexity score for a function.
    Lower scores = simpler functions = higher priority.

    Current heuristic:
    - Base: instruction count
    - Penalty for branches/jumps
    - Penalty for calls (dependencies)
    """
    instructions = func_data.get("instructions", 0)
    size = func_data.get("size", 0)
    branches = func_data.get("branches", 0)
    calls = func_data.get("calls", 0)

    # Simple heuristic: prioritize smaller functions
    # Score is roughly proportional to difficulty
    score = (
        instructions * 0.1 +      # Each instruction adds 0.1
        branches * 0.3 +          # Branches are harder
        calls * 0.2 +             # Calls mean dependencies
        (size / 100) * 0.1        # Size as tiebreaker
    )

    return round(score, 3)


def get_candidates(state):
    """Get list of candidate functions for decompilation."""
    candidates = []

    for name, data in state.items():
        # Skip already matched functions
        if data.get("status") == "matched":
            continue

        # Skip functions with too many failed attempts
        if data.get("attempts", 0) >= MAX_ATTEMPTS:
            continue

        # Skip very small functions (likely stubs/thunks)
        if data.get("instructions", 0) < 3:
            continue

        candidates.append({
            "name": name,
            "complexity": data.get("complexity", calculate_complexity(data)),
            "attempts": data.get("attempts", 0),
            "instructions": data.get("instructions", 0),
            "size": data.get("size", 0),
        })

    return candidates


def select_next(state):
    """Select the next function to attempt."""
    candidates = get_candidates(state)

    if not candidates:
        return None

    # Sort by complexity (lower first), then by attempts (fewer first)
    candidates.sort(key=lambda x: (x["complexity"], x["attempts"]))

    return candidates[0]["name"]


def update_scores(state):
    """Recalculate complexity scores for all functions."""
    for name, data in state.items():
        data["complexity"] = calculate_complexity(data)

    save_state(state)
    print(f"Updated complexity scores for {len(state)} functions.")


def main():
    args = sys.argv[1:]

    state = load_state()

    if "--update" in args:
        update_scores(state)
        return

    if "--all" in args:
        candidates = get_candidates(state)
        candidates.sort(key=lambda x: (x["complexity"], x["attempts"]))

        print(f"{'FUNCTION':<40} {'COMPLEXITY':<12} {'ATTEMPTS':<10} {'INSTRUCTIONS':<12}")
        print("-" * 80)

        for c in candidates:
            name = c["name"]
            if len(name) > 38:
                name = name[:35] + "..."
            print(f"{name:<40} {c['complexity']:<12.3f} {c['attempts']:<10} {c['instructions']:<12}")

        print("-" * 80)
        print(f"Total candidates: {len(candidates)}")
        return

    # Default: print next recommended function
    next_func = select_next(state)

    if next_func:
        print(next_func)
    else:
        print("No functions available to attempt.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
