#!/bin/bash
# Claude Code hook: update tmux window indicator and write state file
# Used by: SessionStart, UserPromptSubmit, Stop, StopFailure, SessionEnd, PreToolUse(AskUserQuestion), PostToolUse(AskUserQuestion)

# Bail if not in tmux
[ -z "$TMUX" ] && exit 0

# Read hook input from stdin
input=$(cat)
event=$(echo "$input" | jq -r '.hook_event_name // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

[ -z "$event" ] && exit 0

# Get tmux window target from current pane
pane_id="$TMUX_PANE"
window_target=$(tmux display-message -t "$pane_id" -p '#{session_name}:#{window_index}' 2>/dev/null)
[ -z "$window_target" ] && exit 0

STATE_DIR="/tmp/claude-tmux"
STATE_FILE="$STATE_DIR/pane-${pane_id}.json"

set_indicator() {
    local icon="$1"
    local state="$2"
    tmux set-option -w -t "$window_target" @claude "$icon" 2>/dev/null

    # Write state file
    mkdir -p "$STATE_DIR"
    local session_name window_name repo branch
    session_name=$(tmux display-message -t "$pane_id" -p '#{session_name}' 2>/dev/null)
    window_name=$(tmux display-message -t "$pane_id" -p '#{window_name}' 2>/dev/null)

    repo=""
    branch=""
    if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
        branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    fi

    cat > "$STATE_FILE" <<EOF
{"pane_id":"$pane_id","session":"$session_name","window":"$window_name","state":"$state","cwd":"$cwd","repo":"$repo","branch":"$branch","updated":"$(date -u +%Y-%m-%dT%H:%M:%S)"}
EOF
}

clear_indicator() {
    tmux set-option -wu -t "$window_target" @claude 2>/dev/null
    rm -f "$STATE_FILE"
}

tool_name=$(echo "$input" | jq -r '.tool_name // empty')

case "$event" in
    SessionStart|UserPromptSubmit)
        set_indicator "⏳" "work"
        ;;
    PreToolUse)
        case "$tool_name" in
            AskUserQuestion|ExitPlanMode) set_indicator "🔴" "attn" ;;
        esac
        ;;
    PermissionRequest)
        set_indicator "🔴" "attn"
        ;;
    PostToolUse)
        set_indicator "⏳" "work"
        ;;
    Stop|StopFailure)
        # Don't override 🔴 if already waiting on user (AskUserQuestion/ExitPlanMode/PermissionRequest)
        current_state=$(jq -r '.state // empty' "$STATE_FILE" 2>/dev/null)
        [ "$current_state" != "attn" ] && set_indicator "🟢" "done"
        ;;
    SessionEnd)
        clear_indicator
        ;;
esac
