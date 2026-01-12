# CLAUDE.md - Neovim Configuration

This file provides guidance to Claude Code when working with this Neovim configuration.

## Overview

This is a modern Neovim setup using:
- **lazy.nvim** as package manager
- **blink.cmp** for completion
- **Telescope** for fuzzy finding
- **Treesitter** for syntax highlighting
- Native LSP with **mason.nvim** for server management

Primary languages: **Ruby on Rails, Go, JavaScript, HTML**

## Directory Structure

```
~/.config/nvim/
├── init.lua                 # Entry point, loads lazy.nvim
├── REFERENCE.md             # User-facing keybinding reference (KEEP UPDATED)
├── CLAUDE.md                # This file
├── lsp/                     # Native LSP server configurations
│   ├── ruby_lsp.lua
│   ├── gopls.lua
│   ├── ts_ls.lua
│   ├── html.lua
│   └── cucumber_language_server.lua
└── lua/ozzyaaron/
    ├── options.lua          # Vim options
    ├── keymaps.lua          # Core keybindings
    ├── autocmds.lua         # Autocommands
    ├── lsp.lua              # LSP attach handlers, enables servers
    └── plugins/             # Plugin specifications
        ├── lsp/
        │   ├── mason.lua    # Mason setup + ensure_installed
        │   └── blink.lua    # Completion
        ├── telescope.lua
        ├── treesitter.lua
        ├── gitsigns.lua
        ├── harpoon.lua
        ├── vim-test.lua
        ├── conform.lua      # Formatting
        ├── vim-rails.lua
        ├── copilot.lua
        ├── avante.lua
        └── ...
```

## Key Configuration Files

| File | Purpose |
|------|---------|
| `lua/ozzyaaron/lsp.lua` | Enables LSP servers with `vim.lsp.enable()` |
| `lua/ozzyaaron/plugins/lsp/mason.lua` | Lists servers for Mason to auto-install |
| `lua/ozzyaaron/plugins/treesitter.lua` | Lists parsers in `ensure_installed` |
| `lsp/*.lua` | Individual LSP server configurations |

## Important Patterns

### Adding a New Language Server

1. Create config in `lsp/{server_name}.lua`:
```lua
vim.lsp.config("server_name", {
  cmd = { "server-command" },
  capabilities = capabilities,
  filetypes = { "filetype" },
  root_markers = { "marker_file" },
  settings = {},
})
```

2. Enable in `lua/ozzyaaron/lsp.lua`:
```lua
vim.lsp.enable('server_name')
```

3. Add to Mason in `lua/ozzyaaron/plugins/lsp/mason.lua`:
```lua
ensure_installed = {
  -- ...existing servers
  "server-name",
}
```

### Adding Treesitter Parsers

Edit `lua/ozzyaaron/plugins/treesitter.lua` and add to `ensure_installed`.

### Adding Formatters

Edit `lua/ozzyaaron/plugins/conform.lua` and add to `formatters_by_ft`.

## CRITICAL: Keeping Documentation Updated

**When making ANY changes to keybindings, plugins, or functionality:**

1. **ALWAYS update `REFERENCE.md`** to reflect the changes
2. Keep the reference focused on practical, time-saving features
3. Maintain the table format for quick scanning
4. Group related keybindings together
5. Highlight the most useful features at the top

The user relies on REFERENCE.md as their primary way to discover and remember features.

## Current Plugin List

Core:
- telescope.nvim (fuzzy finder)
- neo-tree.nvim (file tree)
- harpoon (file bookmarks)
- gitsigns.nvim (git integration)
- vim-test (test runner)
- conform.nvim (formatting)

LSP/Completion:
- nvim-lspconfig + mason.nvim
- blink.cmp (completion)
- fidget.nvim (LSP progress)

Languages:
- vim-rails (Rails navigation)
- nvim-treesitter

AI:
- copilot.lua + CopilotChat.nvim
- avante.nvim

Editing:
- nvim-surround
- mini.nvim
- tabular

UI:
- tokyonight.nvim (colorscheme)
- which-key.nvim
- dressing.nvim

## Testing Changes

After modifying config:
1. Restart Neovim or run `:Lazy reload {plugin}`
2. Check `:checkhealth` for issues
3. Verify LSP with `:LspInfo`
4. Verify Treesitter with `:TSInstallInfo`
