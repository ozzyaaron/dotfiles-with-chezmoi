-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'tpope/vim-rails',
    name = 'vim-rails',
    opts = {},
    config = function() end,
  },
  {
    'pocco81/auto-save.nvim',
    name = 'auto-save.nvim',
    opts = {
      debounce_delay = 5000,
    },
    config = function(_, opts)
      require("auto-save").setup(opts)
    end
  },
}
