-- Set leader keys before plugins load
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = true

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath
  })
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
require('lazy').setup({
  spec = {
    { import = 'ozzyaaron.plugins' },
    { import = 'ozzyaaron.plugins.lsp' },
  },
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
  },
})

-- Load configuration modules
require('ozzyaaron.options')
require('ozzyaaron.keymaps')
require('ozzyaaron.autocmds')
require('ozzyaaron.lsp')
