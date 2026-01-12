# Neovim Quick Reference

> Your most powerful keybindings at a glance. Leader key is `<Space>`.

## Biggest Time Savers

| Keys | Action | Why It Matters |
|------|--------|----------------|
| `<leader>fg` | Live grep with args | Search entire codebase instantly |
| `<leader>ff` | Find files | Jump to any file by name |
| `<leader><leader>` | Buffer list | Switch between open files |
| `gd` | Go to definition | Jump to where something is defined |
| `<leader>a` | Harpoon add | Bookmark frequently used files |
| `<leader>1-5` | Harpoon jump | Instant access to bookmarked files |
| `<C-e>` | Harpoon menu | See all bookmarked files |
| `<leader>tn` | Test nearest | Run test under cursor |
| `<leader>cf` | Format code | Auto-format current file |
| `:A` | Alternate file | Jump between test/implementation |
| `<leader>?` | Open this reference | Quick reminder of keybindings |

---

## Navigation

### File Finding (Telescope)
| Keys | Action |
|------|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep (search text in all files) |
| `<leader>fw` | Search word under cursor |
| `<leader><leader>` | List open buffers |
| `<leader>s.` | Recent files |
| `<leader>/` | Fuzzy search in current buffer |
| `<leader>s/` | Search in open files only |
| `<leader>fc` | Search neovim config files |
| `<leader>sr` | Resume last search |

**Tip:** In Telescope, press `<C-/>` (insert) or `?` (normal) to see all Telescope keybindings.

### Harpoon (File Bookmarks)
| Keys | Action |
|------|--------|
| `<leader>a` | Add current file to harpoon |
| `<C-e>` | Toggle harpoon quick menu |
| `<leader>1` | Jump to harpoon file 1 |
| `<leader>2` | Jump to harpoon file 2 |
| `<leader>3` | Jump to harpoon file 3 |
| `<leader>4` | Jump to harpoon file 4 |
| `<leader>5` | Jump to harpoon file 5 |
| `<C-S-P>` | Previous harpoon file |
| `<C-S-N>` | Next harpoon file |

### Window Management
| Keys | Action |
|------|--------|
| `<C-h/j/k/l>` | Move between windows/tmux panes |
| `<leader>z` | Toggle zoom (maximize/restore window) |
| `\` | Toggle file tree (neo-tree) |

---

## Code Intelligence (LSP)

### Navigation
| Keys | Action |
|------|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gI` | Go to implementation |
| `<leader>D` | Go to type definition |
| `<leader>ds` | Document symbols (functions, classes, etc.) |
| `<leader>ws` | Workspace symbols |

### Actions
| Keys | Action |
|------|--------|
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action (quick fixes, refactors) |
| `<leader>cf` | Format code |
| `<leader>th` | Toggle inlay hints |

### Diagnostics
| Keys | Action |
|------|--------|
| `<leader>e` | Show error message |
| `<leader>q` | Open diagnostics list |
| `[d` / `]d` | Previous/next diagnostic |
| `<leader>sd` | Search all diagnostics |

---

## Testing (vim-test)

| Keys | Action |
|------|--------|
| `<leader>tn` | Test nearest (run test under cursor) |
| `<leader>tf` | Test file (run all tests in file) |
| `<leader>ts` | Test suite (run all tests) |
| `<leader>tl` | Test last (re-run last test) |
| `<leader>tv` | Test visit (go to last test file) |

---

## Git (gitsigns)

### Navigation
| Keys | Action |
|------|--------|
| `]c` | Next git change |
| `[c` | Previous git change |

### Actions
| Keys | Action |
|------|--------|
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage entire buffer |
| `<leader>hu` | Undo stage hunk |
| `<leader>hR` | Reset entire buffer |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |
| `<leader>hd` | Diff against index |
| `<leader>hD` | Diff against last commit |

### Toggles
| Keys | Action |
|------|--------|
| `<leader>tb` | Toggle line blame |
| `<leader>tD` | Toggle show deleted |

---

## Rails Development (vim-rails)

### Quick Navigation
| Command | Action |
|---------|--------|
| `:A` | Alternate file (test <-> implementation) |
| `:R` | Related file |
| `:Emodel <name>` | Edit model |
| `:Econtroller <name>` | Edit controller |
| `:Eview <name>` | Edit view |
| `:Emigration <name>` | Edit migration |
| `:Eschema` | Edit schema.rb |
| `:Eroutes` | Edit routes.rb |

### View Components
| Command | Action |
|---------|--------|
| `:Ecomponent <name>` | Edit component class |
| `:Ecomponentspec <name>` | Edit component spec |

**Tip:** Use `gf` on a partial name like `render 'shared/header'` to jump to that partial.

---

## AI Assistance

### Copilot (inline suggestions)
| Keys | Action |
|------|--------|
| `<Tab>` | Accept suggestion (default) |
| `<M-]>` | Next suggestion |
| `<M-[>` | Previous suggestion |
| `<C-]>` | Dismiss suggestion |

### Copilot Chat
| Command | Action |
|---------|--------|
| `:CopilotChat` | Open chat window |
| `:CopilotChatExplain` | Explain selected code |
| `:CopilotChatFix` | Fix selected code |
| `:CopilotChatOptimize` | Optimize selected code |
| `:CopilotChatTests` | Generate tests |

### Avante (AI editing)
| Command | Action |
|---------|--------|
| `:AvanteAsk` | Ask AI about code |
| `:AvanteEdit` | AI-assisted editing |

---

## Completion (blink.cmp)

| Keys | Action |
|------|--------|
| `<C-Space>` | Open completion menu |
| `<C-n>` / `<C-p>` | Navigate completions |
| `<C-y>` | Accept completion |
| `<C-e>` | Close menu |
| `<C-k>` | Toggle signature help |

---

## Text Editing

### Surround (nvim-surround)
| Keys | Action |
|------|--------|
| `ys{motion}{char}` | Add surround (e.g., `ysiw"` surrounds word with quotes) |
| `cs{old}{new}` | Change surround (e.g., `cs"'` changes " to ') |
| `ds{char}` | Delete surround (e.g., `ds"` removes quotes) |

### Alignment (Tabular)
| Keys | Action |
|------|--------|
| `fct` (visual) | Align on pipe character |
| `:Tabularize /{pattern}` | Align on any pattern |

---

## Miscellaneous

| Keys | Action |
|------|--------|
| `<leader>?` | Open this reference guide |
| `<Esc>` | Clear search highlights |
| `<Esc><Esc>` | Exit terminal mode |
| `<leader>sk` | Search all keymaps |
| `<leader>sh` | Search help |
| `<leader>ss` | Search Telescope pickers |

---

## Language Servers Configured

| Language | Server | Features |
|----------|--------|----------|
| Ruby | ruby-lsp | Diagnostics, completion, go-to-def |
| Go | gopls | Full LSP, staticcheck, gofumpt |
| JavaScript/TypeScript | ts_ls | Full LSP, inlay hints |
| HTML | html | Completion, formatting |
| Lua | lua_ls | For neovim config editing |
| Cucumber | cucumber_language_server | Gherkin support |

---

## Auto-Formatting on Save

Formatters are configured for:
- **Go**: goimports, gofmt
- **JavaScript/TypeScript**: prettier
- **HTML/CSS/JSON/YAML**: prettier
- **Ruby**: rubocop
- **ERB**: erb_format
- **Lua**: stylua

Use `<leader>cf` to manually format, or just save the file.

---

## Tips

1. **Use `:checkhealth`** to verify your setup is working correctly
2. **Run `:Mason`** to install/update language servers
3. **Run `:TSUpdate`** to update treesitter parsers
4. **Run `:Lazy`** to manage plugins
5. **Press `K`** on any word to see documentation (if LSP supports it)
6. **Use `<C-]>` in help** to follow tags, `<C-t>` to go back
