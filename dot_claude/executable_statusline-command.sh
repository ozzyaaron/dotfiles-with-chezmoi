#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name // "default"')
vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')

# Context window calculation (using current_usage, not cumulative)
usage=$(echo "$input" | jq '.context_window.current_usage')
context_info=""
if [ "$usage" != "null" ]; then
    input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
    cache_creation=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
    current_total=$((input_tokens + cache_creation + cache_read))
    context_size=$(echo "$input" | jq '.context_window.context_window_size')

    if [ "$context_size" -gt 0 ]; then
        pct=$((current_total * 100 / context_size))
        context_info="${pct}%"

        # Add cache hit indicator if we're using cache
        if [ "$cache_read" -gt 0 ]; then
            cache_pct=$((cache_read * 100 / current_total))
            context_info="${context_info} (${cache_pct}% cached)"
        fi
    fi
fi

# Git information (skip locks for safety)
git_branch=""
repo_name=""
git_status=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Get branch name
    git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

    # Get repository name
    repo_name=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)")

    # Check if working directory is clean
    if ! git -C "$cwd" --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then
        git_status="*"
    fi
fi

# Build status line parts
parts=()

# Repository and branch
if [ -n "$repo_name" ] && [ -n "$git_branch" ]; then
    parts+=("${repo_name}:${git_branch}${git_status}")
fi

# Model name
parts+=("$model")

# Context usage
if [ -n "$context_info" ]; then
    parts+=("ctx: $context_info")
fi

# Output style (only show if not default)
if [ "$output_style" != "default" ] && [ "$output_style" != "null" ]; then
    parts+=("style: $output_style")
fi

# Vim mode (if enabled)
if [ -n "$vim_mode" ]; then
    parts+=("vim: $vim_mode")
fi

# Current directory (shortened)
dir_name=$(basename "$cwd")
parts+=("$dir_name")

# Join parts with " | "
result=""
for i in "${!parts[@]}"; do
    if [ $i -eq 0 ]; then
        result="${parts[$i]}"
    else
        result="$result | ${parts[$i]}"
    fi
done

echo "$result"
