#!/bin/bash

# Claude Code Notification Script with Tmux Integration
# This script sends a notification when Claude is ready for input
# and allows clicking to return to the correct tmux session/window


TEMP_DIR="/tmp/claude-tmux"
CONTEXT_FILE="$TEMP_DIR/context"
RESTORE_SCRIPT="$HOME/.claude/restore-tmux.sh"

# Ensure temp directory exists
mkdir -p "$TEMP_DIR"

# Detect terminal application
# Inside tmux, $TERM_PROGRAM is "tmux", so walk the client's process tree
# to find the actual terminal emulator (works even after session restore)
DETECTED_TERMINAL=""
if [ -n "$TMUX" ]; then
    CLIENT_PID=$(tmux display-message -p '#{client_pid}' 2>/dev/null)
    if [ -n "$CLIENT_PID" ]; then
        CUR_PID=$CLIENT_PID
        for i in $(seq 1 10); do
            PNAME=$(ps -p "$CUR_PID" -o comm= 2>/dev/null)
            case "$PNAME" in
                */ghostty)       DETECTED_TERMINAL="ghostty"; break ;;
                */iTerm2)        DETECTED_TERMINAL="iTerm.app"; break ;;
                */Terminal)      DETECTED_TERMINAL="Apple_Terminal"; break ;;
            esac
            PARENT_PID=$(ps -p "$CUR_PID" -o ppid= 2>/dev/null | tr -d ' ')
            [ -z "$PARENT_PID" ] || [ "$PARENT_PID" = "0" ] || [ "$PARENT_PID" = "1" ] && break
            CUR_PID=$PARENT_PID
        done
    fi
fi
: "${DETECTED_TERMINAL:=$TERM_PROGRAM}"

TERMINAL_APP=""
TERMINAL_PROCESS_NAME=""

case "$DETECTED_TERMINAL" in
    "iTerm.app")
        TERMINAL_APP="com.googlecode.iterm2"
        TERMINAL_PROCESS_NAME="iTerm2"
        ;;
    "ghostty")
        TERMINAL_APP="com.mitchellh.ghostty"
        TERMINAL_PROCESS_NAME="ghostty"
        ;;
    "Apple_Terminal")
        TERMINAL_APP="com.apple.Terminal"
        TERMINAL_PROCESS_NAME="Terminal"
        ;;
    *)
        TERMINAL_APP="com.apple.Terminal"
        TERMINAL_PROCESS_NAME="Terminal"
        ;;
esac

# Exit early if this terminal already has focus (no notification needed)
FOCUSED_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
if [[ "$FOCUSED_APP" == "$TERMINAL_PROCESS_NAME" ]]; then
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