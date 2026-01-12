-- Editor options configuration
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Mouse mode
opt.mouse = 'a'

-- Don't show mode (already in statusline)
opt.showmode = false

-- Sync clipboard with OS (scheduled for faster startup)
vim.schedule(function()
  opt.clipboard = 'unnamedplus'
end)

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.breakindent = true

-- Line wrapping
opt.wrap = false

-- Undo history
opt.undofile = true

-- Search
opt.ignorecase = true
opt.smartcase = true

-- UI
opt.signcolumn = 'yes'
opt.cursorline = true
opt.scrolloff = 10

-- Timing
opt.updatetime = 250
opt.timeoutlen = 300

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Whitespace display
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Live substitution preview
opt.inccommand = 'split'

-- Folding
opt.foldmethod = 'indent'
opt.foldenable = false

-- Disable modeline and editorconfig (prevent option overrides)
opt.modeline = false
vim.g.editorconfig = false
