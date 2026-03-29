#!/bin/sh

# Read JSON input from stdin
input=$(cat)

# Single jq call - extract all fields as newline-separated values
# Use a unique sentinel for empty values since read swallows blank lines
jq_out=$(echo "$input" | jq -r '
  (.model.display_name // "__EMPTY__"),
  (.workspace.current_dir // "__EMPTY__"),
  (.output_style.name // "default"),
  ((.context_window.used_percentage // "null") | tostring),
  ((.context_window.current_usage.input_tokens // 0) | tostring),
  ((.context_window.current_usage.cache_creation_input_tokens // 0) | tostring),
  ((.context_window.current_usage.cache_read_input_tokens // 0) | tostring),
  ((.rate_limits.five_hour.used_percentage // "null") | tostring),
  ((.rate_limits.seven_day.used_percentage // "null") | tostring),
  (.session_name // "__EMPTY__"),
  (.agent.name // "__EMPTY__"),
  (.worktree.branch // "__EMPTY__")
')

# Read effort level from settings (not available in statusline input)
effort_level=$(jq -r '.effortLevel // "__EMPTY__"' ~/.claude/settings.json 2>/dev/null)

# Parse line by line using line number
i=0
while IFS= read -r line; do
    case $i in
        0) model="$line" ;;
        1) cwd="$line" ;;
        2) output_style="$line" ;;
        3) used_pct="$line" ;;
        4) input_tokens="$line" ;;
        5) cache_creation="$line" ;;
        6) cache_read="$line" ;;
        7) rate_5h="$line" ;;
        8) rate_7d="$line" ;;
        9) session_name="$line" ;;
        10) agent_name="$line" ;;
        11) worktree_branch="$line" ;;
    esac
    i=$((i + 1))
done <<EOF
$jq_out
EOF

# Normalize sentinels
[ "$session_name" = "__EMPTY__" ] && session_name=""
[ "$agent_name" = "__EMPTY__" ] && agent_name=""
[ "$worktree_branch" = "__EMPTY__" ] && worktree_branch=""
[ "$effort_level" = "__EMPTY__" ] && effort_level=""

# Context info - use pre-calculated percentage, add cache detail
context_info=""
if [ "$used_pct" != "null" ]; then
    used_int=$(printf '%.0f' "$used_pct" 2>/dev/null || echo "$used_pct")
    context_info="${used_int}% used"
    # Add cache hit indicator from raw tokens
    case "$cache_read" in
        ''|*[!0-9]*) ;;
        *)
            case "$input_tokens$cache_creation$cache_read" in
                ''|*[!0-9]*) ;;
                *)
                    current_total=$((input_tokens + cache_creation + cache_read))
                    if [ "$cache_read" -gt 0 ] && [ "$current_total" -gt 0 ]; then
                        cache_pct=$((cache_read * 100 / current_total))
                        context_info="${context_info}, ${cache_pct}% cached"
                    fi
                    ;;
            esac
            ;;
    esac
fi

# Rate limit info
rate_info=""
if [ "$rate_5h" != "null" ] && [ -n "$rate_5h" ]; then
    rate_5h_int=$(printf '%.0f' "$rate_5h" 2>/dev/null || echo "$rate_5h")
    rate_info="5h:${rate_5h_int}%"
fi
if [ "$rate_7d" != "null" ] && [ -n "$rate_7d" ]; then
    rate_7d_int=$(printf '%.0f' "$rate_7d" 2>/dev/null || echo "$rate_7d")
    if [ -n "$rate_info" ]; then
        rate_info="${rate_info} 7d:${rate_7d_int}%"
    else
        rate_info="7d:${rate_7d_int}%"
    fi
fi

# Git information
git_branch=""
repo_name=""
repo_root=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    if [ -n "$worktree_branch" ]; then
        git_branch="$worktree_branch"
    else
        git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    fi

    repo_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
    repo_name=$(basename "$repo_root")
fi

# Shorten model name (strip "Claude " prefix if present)
short_model="${model#Claude }"

# Build status line
parts=""
add_part() {
    if [ -n "$parts" ]; then
        parts="$parts | $1"
    else
        parts="$1"
    fi
}

# Session name (if set via /rename)
[ -n "$session_name" ] && add_part "🏷️ $session_name"

# Agent name (if using --agent)
[ -n "$agent_name" ] && add_part "🤖 $agent_name"

# Repository and branch
if [ -n "$repo_name" ] && [ -n "$git_branch" ]; then
    add_part "🌿 ${repo_name}:${git_branch}"
fi

# Model name (shortened)
add_part "$short_model"

# Effort level
[ -n "$effort_level" ] && add_part "💪 $effort_level"

# Context usage
[ -n "$context_info" ] && add_part "🧠 $context_info"

# Rate limits
[ -n "$rate_info" ] && add_part "⚡ $rate_info"

# Output style (only show if not default)
if [ "$output_style" != "default" ] && [ "$output_style" != "null" ]; then
    add_part "style: $output_style"
fi

# Directory - show relative path within repo, or basename if at root / not in repo
if [ -n "$repo_root" ]; then
    rel_path="${cwd#$repo_root}"
    rel_path="${rel_path#/}"
    [ -n "$rel_path" ] && add_part "📂 $rel_path"
else
    add_part "📂 $(basename "$cwd")"
fi

echo "$parts"
