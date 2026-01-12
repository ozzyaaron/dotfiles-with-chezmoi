-- Autocommands configuration
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight when yanking (copying) text
autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = augroup('user-yank-highlight', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Create directories when saving files
autocmd('BufWritePre', {
  desc = 'Create parent directories on save',
  group = augroup('user-auto-mkdir', { clear = true }),
  callback = function(event)
    if event.match:match('^%w%w+://') then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})
