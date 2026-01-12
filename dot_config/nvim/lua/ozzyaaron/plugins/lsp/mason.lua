return {
  "williamboman/mason-lspconfig.nvim",
  dependencies = {
    {
      "williamboman/mason.nvim",
      opts = {
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      },
    },
    "neovim/nvim-lspconfig",
    { 
      "j-hui/fidget.nvim",
      opts = {},
    },
  },
  ensure_installed = {
    "lua_ls",
    "cucumber_language_server",
    "gopls",
    "typescript-language-server",
    "vscode-langservers-extracted",
  },
}
