-- Keymaps configuration
local map = vim.keymap.set

-- Clear highlights on search when pressing <Esc> in normal mode
map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror' })
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })

-- Exit terminal mode with a easier shortcut
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Window navigation (CTRL+hjkl to switch between windows)
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Open Neovim reference guide in default macOS app
map('n', '<leader>?', function()
  vim.fn.system('open ~/.config/nvim/REFERENCE.md')
end, { desc = 'Open Neovim reference guide' })

-- Toggle zoom: maximize current window or restore equal splits
local zoom_state = false
map('n', '<leader>z', function()
  if zoom_state then
    vim.cmd('wincmd =')
    zoom_state = false
  else
    vim.cmd('wincmd |')
    vim.cmd('wincmd _')
    zoom_state = true
  end
end, { desc = 'Toggle window zoom' })
