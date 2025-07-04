#!/bin/bash

# Claude Code Notification Script with Tmux Integration
# This script sends a notification when Claude is ready for input
# and allows clicking to return to the correct tmux session/window


TEMP_DIR="/tmp/claude-tmux"
CONTEXT_FILE="$TEMP_DIR/context"
RESTORE_SCRIPT="$HOME/.claude/restore-tmux.sh"

# Ensure temp directory exists
mkdir -p "$TEMP_DIR"

# Detect terminal application and check if it has focus
TERMINAL_APP=""
HAS_FOCUS=false

if pgrep -f "iTerm" > /dev/null; then
    TERMINAL_APP="com.googlecode.iterm2"
    # Check if iTerm has focus
    FOCUSED_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
    if [[ "$FOCUSED_APP" == "iTerm2" ]]; then
        HAS_FOCUS=true
    fi
elif pgrep -f "Terminal" > /dev/null; then
    TERMINAL_APP="com.apple.Terminal"
    # Check if Terminal has focus
    FOCUSED_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
    if [[ "$FOCUSED_APP" == "Terminal" ]]; then
        HAS_FOCUS=true
    fi
else
    # Default to Terminal.app
    TERMINAL_APP="com.apple.Terminal"
fi

# Exit early if terminal already has focus (no notification needed)
if [ "$HAS_FOCUS" = true ]; then
    exit 0
fi

# Check if we're in a tmux session
if [ -n "$TMUX" ]; then
    # Get current tmux session and window
    SESSION=$(tmux display-message -p '#S')
    WINDOW=$(tmux display-message -p '#I')
    WINDOW_NAME=$(tmux display-message -p '#W')

    # Save context to file
    echo "SESSION=$SESSION" > "$CONTEXT_FILE"
    echo "WINDOW=$WINDOW" >> "$CONTEXT_FILE"
    echo "WINDOW_NAME=$WINDOW_NAME" >> "$CONTEXT_FILE"
    echo "TERMINAL_APP=$TERMINAL_APP" >> "$CONTEXT_FILE"

    MESSAGE="Claude is ready for input (tmux: $SESSION:$WINDOW_NAME)"
else
    # Not in tmux, just save terminal app
    echo "TERMINAL_APP=$TERMINAL_APP" > "$CONTEXT_FILE"
    MESSAGE="Claude is ready for input"
fi

# Create restoration command for terminal-notifier -execute
RESTORE_CMD="osascript -e \"tell application id \\\"$TERMINAL_APP\\\" to activate\""

# Add tmux restoration if we're in a tmux session
if [ -n "$TMUX" ] && [ -n "$SESSION" ] && [ -n "$WINDOW" ]; then
    RESTORE_CMD="$RESTORE_CMD && sleep 0.5 && tmux select-session -t '$SESSION' 2>/dev/null || true && tmux select-window -t '$SESSION:$WINDOW' 2>/dev/null || true"
fi

# Send notification using terminal-notifier
# Note: For persistent notifications, go to System Preferences > Notifications > terminal-notifier
# and change the alert style from "Banners" to "Alerts"
terminal-notifier \
    -message "$MESSAGE" \
    -title "Claude Code" \
    -group "claude-code" \
    -activate "$TERMINAL_APP" \
    -execute "$RESTORE_CMD"