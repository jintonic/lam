#!/usr/bin/env python3
import sys
import json

def get_status():
    try:
        # Read JSON from Letta's stdin
        data = json.load(sys.stdin)
        
        # Get active input tokens
        used = data.get("context_window", {}).get("total_input_tokens", 0)
        
        # Your target threshold (200k)
        target = 200000
        pct = (used / target) * 100

        # ANSI Color Coding
        # Green < 70% | Yellow < 90% | Red > 95%
        color = "\033[92m" # Green
        if pct > 70: color = "\033[93m" # Yellow
        if pct > 95: color = "\033[91m" # Red
        reset = "\033[0m"

        # Output format: Tokens: 45,200 (22.6%)
        return f"Tokens: {used:,} ({color}{pct:.1f}%{reset})"
    except Exception:
        # Default fallback if data is missing or empty
        return "Tokens: 0 (0.0%)"

if __name__ == "__main__":
    print(get_status(), end="")