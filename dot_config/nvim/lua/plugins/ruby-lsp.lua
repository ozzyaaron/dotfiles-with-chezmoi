return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = {
          enabled = true,
          mason = false,
          cmd = { "bundle", "exec", "ruby-lsp" },
        },
        solargraph = {
          enabled = false,
        },
        rubocop = {
          -- If Solargraph and Rubocop are both enabled as an LSP,
          -- diagnostics will be duplicated because Solargraph
          -- already calls Rubocop if it is installed
          enabled = true,
          mason = false,
          cmd = { "bundle", "exec", "rubocop", "--lsp" },
        },
        standardrb = {
          enabled = false,
        },
      },
    },
  },
}
