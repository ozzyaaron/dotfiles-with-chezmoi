#!/bin/bash

# Claude Code Tmux Restoration Script
# This script is executed when the notification is clicked
# It brings focus to the terminal and switches to the correct tmux session/window

TEMP_DIR="/tmp/claude-tmux"
CONTEXT_FILE="$TEMP_DIR/context"

# Check if context file exists
if [ ! -f "$CONTEXT_FILE" ]; then
    echo "No context file found. Just activating terminal."
    exit 0
fi

# Source the context
source "$CONTEXT_FILE"

# Activate the terminal application
if [ -n "$TERMINAL_APP" ]; then
    osascript <<EOF
tell application id "$TERMINAL_APP"
    activate
end tell
EOF
fi

# If we have tmux session info, switch to it
if [ -n "$SESSION" ] && [ -n "$WINDOW" ]; then
    # Check if tmux is running and session exists
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        # Switch to the session and window
        tmux select-session -t "$SESSION"
        tmux select-window -t "$SESSION:$WINDOW"
    fi
fi

# Clean up the context file
rm -f "$CONTEXT_FILE"