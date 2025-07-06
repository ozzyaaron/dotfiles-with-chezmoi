# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the `.claude` directory which contains Claude Code's configuration and session data. This is not a traditional code repository but rather Claude Code's working directory containing:

- `settings.json` - Claude Code configuration file
- `todos/` - Session-specific todo lists for tracking tasks
- `projects/` - Project-specific session data and conversation history
- `statsig/` - Analytics and feature flag data
- Shell scripts for tmux integration (`restore-tmux.sh`, `focus-tmux.sh`)

## Key Files and Structure

- **settings.json**: Contains Claude Code configuration including API keys, model preferences, and tool settings
- **todos/**: JSON files storing todo lists for different sessions, enabling task tracking across conversations
- **projects/**: JSONL files containing conversation history and context for specific projects
- **statsig/**: Analytics data for feature usage and performance tracking

## Development Context

This directory serves as Claude Code's persistent state storage. When working here:

1. Be cautious with configuration changes in `settings.json`
2. Todo files are automatically managed by the TodoWrite/TodoRead tools
3. Project files contain conversation history and should not be manually edited
4. Shell scripts are for tmux window management integration

## Important Notes

- This is not a traditional development repository with build/test commands
- No package managers or build tools are present
- Focus on configuration management and understanding Claude Code's internal structure
- Changes to settings should be made through proper Claude Code configuration methods