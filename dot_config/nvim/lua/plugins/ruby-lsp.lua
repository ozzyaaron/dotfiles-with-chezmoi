-- This is setup via astolsp as its using standard nvim-lspconfig now
--
if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

return {
  -- Configure lspconfig
  -- {
  --   "williamboman/mason-lspconfig.nvim",
  --   opts = {
  --     ensure_installed = { "ruby_lsp" }, -- automatically install lsp
  --   },
  -- },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = {
          -- Ruby LSP configuration
          cmd = { "bundle", "exec", "ruby-lsp" },
          filetypes = { "ruby" },
          root_dir = require("lspconfig.util").root_pattern("Gemfile", ".git"),
          init_options = {
            formatter = "auto",
          },
          settings = {
            -- Add any specific settings here
            ruby = {
              lint = {
                enable = true,
              },
              format = {
                enable = true,
              },
            },
          },
        },
      },
    },
  },
}
