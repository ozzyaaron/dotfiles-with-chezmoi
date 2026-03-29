#!/bin/sh

# Read JSON input from stdin
input=$(cat)

# Single jq call - extract all fields as newline-separated values
# Use a unique sentinel for empty values since read swallows blank lines
jq_out=$(echo "$input" | jq -r '
  (.model.display_name // "-"),
  (.workspace.current_dir // "-"),
  (.output_style.name // "default"),
  (.vim.mode // "-"),
  ((.context_window.used_percentage // "null") | tostring),
  ((.context_window.context_window_size // 0) | tostring),
  ((.context_window.current_usage.input_tokens // 0) | tostring),
  ((.context_window.current_usage.cache_creation_input_tokens // 0) | tostring),
  ((.context_window.current_usage.cache_read_input_tokens // 0) | tostring),
  ((.rate_limits.five_hour.used_percentage // "null") | tostring),
  ((.rate_limits.seven_day.used_percentage // "null") | tostring),
  (.session_name // "-"),
  (.agent.name // "-"),
  (.worktree.branch // "-")
')

# Parse line by line using line number
i=0
while IFS= read -r line; do
    case $i in
        0) model="$line" ;;
        1) cwd="$line" ;;
        2) output_style="$line" ;;
        3) vim_mode="$line" ;;
        4) used_pct="$line" ;;
        5) context_size="$line" ;;
        6) input_tokens="$line" ;;
        7) cache_creation="$line" ;;
        8) cache_read="$line" ;;
        9) rate_5h="$line" ;;
        10) rate_7d="$line" ;;
        11) session_name="$line" ;;
        12) agent_name="$line" ;;
        13) worktree_branch="$line" ;;
    esac
    i=$((i + 1))
done <<EOF
$jq_out
EOF

# Normalize sentinels
[ "$vim_mode" = "-" ] && vim_mode=""
[ "$session_name" = "-" ] && session_name=""
[ "$agent_name" = "-" ] && agent_name=""
[ "$worktree_branch" = "-" ] && worktree_branch=""

# Context info - use pre-calculated percentage, add cache detail
context_info=""
if [ "$used_pct" != "null" ]; then
    # Round float to integer
    used_int=$(printf '%.0f' "$used_pct" 2>/dev/null || echo "$used_pct")
    context_info="${used_int}% used"
    # Add cache hit indicator from raw tokens
    current_total=$((input_tokens + cache_creation + cache_read))
    if [ "$cache_read" -gt 0 ] 2>/dev/null && [ "$current_total" -gt 0 ] 2>/dev/null; then
        cache_pct=$((cache_read * 100 / current_total))
        context_info="${context_info}, ${cache_pct}% cached"
    fi
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
git_status=""
repo_root=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Use worktree branch if in a worktree session, otherwise detect from git
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
    add_part "🏷️ ${repo_name}:${git_branch}"
fi

# Model name (shortened)
add_part "$short_model"

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
    rel_path="${cwd#"$repo_root"}"
    rel_path="${rel_path#/}"
    [ -n "$rel_path" ] && add_part "📂 $rel_path"
else
    add_part "📂 $(basename "$cwd")"
fi

echo "$parts"
