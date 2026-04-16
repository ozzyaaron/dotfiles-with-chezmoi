#!/bin/bash
# List all Claude Code agents across tmux panes
# Usage: tmux display-popup -E -w 100 -h 30 "~/.claude/tmux-agents.sh"

STATE_DIR="/tmp/claude-tmux"

# ANSI colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
DIM='\033[2m'
RESET='\033[0m'

relative_time() {
    local updated="$1"
    [ -z "$updated" ] && echo "?" && return
    local now then diff
    now=$(date -u +%s)
    then=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "$updated" +%s 2>/dev/null) || { echo "?"; return; }
    diff=$((now - then))
    if   [ $diff -lt 10 ];    then echo "just now"
    elif [ $diff -lt 60 ];    then echo "${diff}s ago"
    elif [ $diff -lt 3600 ];  then echo "$((diff/60))m ago"
    else                           echo "$((diff/3600))h ago"
    fi
}

# Sort order: attn=0, work=1, done=2
sort_key() {
    case "$1" in
        attn) echo "0" ;;
        work) echo "1" ;;
        done) echo "2" ;;
        *)    echo "3" ;;
    esac
}

raw=()

if [ -d "$STATE_DIR" ]; then
    for f in "$STATE_DIR"/pane-*.json; do
        [ -f "$f" ] || continue
        pane_id=$(jq -r '.pane_id'         "$f" 2>/dev/null)
        [ -z "$pane_id" ] && continue

        if ! tmux display-message -t "$pane_id" -p '' >/dev/null 2>&1; then
            rm -f "$f"; continue
        fi

        state=$(jq -r   '.state   // "?"' "$f")
        session=$(jq -r '.session // "?"' "$f")
        window=$(jq -r  '.window  // "?"' "$f")
        repo=$(jq -r    '.repo    // ""'  "$f")
        branch=$(jq -r  '.branch  // ""'  "$f")
        cwd=$(jq -r     '.cwd     // ""'  "$f")
        updated=$(jq -r '.updated // ""'  "$f")

        raw+=("$(sort_key "$state")|$state|$session|$window|$repo|$branch|$cwd|$updated|$pane_id")
    done
fi

if [ ${#raw[@]} -eq 0 ]; then
    printf "\n  ${DIM}No Claude agents running.${RESET}\n\n"
    read -r -s -n 1
    exit 0
fi

# Sort by priority
IFS=$'\n' sorted=($(printf '%s\n' "${raw[@]}" | sort))
unset IFS

# Build display lines and counts
entries=()
n_attn=0; n_work=0; n_done=0

for r in "${sorted[@]}"; do
    IFS='|' read -r _ state session window repo branch cwd updated pane_id <<< "$r"

    case "$state" in
        attn) icon="🔴"; label=$(printf "${RED}waiting ${RESET}"); n_attn=$((n_attn+1)) ;;
        work) icon="⏳"; label=$(printf "${YELLOW}working ${RESET}"); n_work=$((n_work+1)) ;;
        done) icon="🟢"; label=$(printf "${GREEN}done    ${RESET}"); n_done=$((n_done+1)) ;;
        *)    icon="  "; label=$(printf "${DIM}unknown ${RESET}") ;;
    esac

    age=$(relative_time "$updated")

    # Truncate long values
    loc="${session}:${window}"
    [ ${#loc}    -gt 24 ] && loc="${loc:0:23}…"
    [ ${#repo}   -gt 22 ] && repo="${repo:0:21}…"
    [ ${#branch} -gt 30 ] && branch="${branch:0:29}…"

    display=$(printf "%s %s  ${CYAN}%-24s${RESET}  %-22s  %-30s  ${DIM}%s${RESET}" \
        "$icon" "$label" "$loc" "$repo" "$branch" "$age")

    entries+=("${display}	${pane_id}")
done

# Summary counts for header
header_counts=""
[ $n_attn -gt 0 ] && header_counts+="${RED}${n_attn} waiting${RESET}  "
[ $n_work -gt 0 ] && header_counts+="${YELLOW}${n_work} working${RESET}  "
[ $n_done -gt 0 ] && header_counts+="${GREEN}${n_done} done${RESET}"

total=${#entries[@]}
header=$(printf "  Claude Agents  ·  ${total} total    ${header_counts}")

col_header=$(printf "  ${DIM}     %-10s  %-24s  %-22s  %-30s  %s${RESET}" \
    "state" "location" "repo" "branch" "last activity")

selected=$(printf '%s\n' "${entries[@]}" | fzf \
    --ansi \
    --delimiter='	' \
    --with-nth=1 \
    --header-first \
    --header="$(printf '%b\n%b' "$header" "$col_header")" \
    --no-sort \
    --reverse \
    --prompt="  ❯ " \
    --pointer="▶" \
    --highlight-line \
    --border=rounded \
    --padding="1,2" \
    --color="bg:#1e1e2e,bg+:#313244,border:#585b70,header:#cba6f7,hl+:#cba6f7,info:#cba6f7,pointer:#cba6f7,prompt:#89b4fa,fg:#cdd6f4,fg+:#cdd6f4,gutter:#1e1e2e" \
    --height=100%)

[ -z "$selected" ] && exit 0

target_pane=$(printf '%s' "$selected" | cut -f2)
[ -z "$target_pane" ] && exit 0

target_window=$(tmux display-message -t "$target_pane" -p '#{session_name}:#{window_index}' 2>/dev/null)
[ -z "$target_window" ] && exit 0

tmux switch-client -t "$target_window"
