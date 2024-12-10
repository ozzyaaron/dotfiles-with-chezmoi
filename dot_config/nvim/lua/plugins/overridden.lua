return {
  -- customize treesitter parsers
  -- {
  --   "jay-babu/mason-null-ls.nvim",
  --   opts = function(_, opts)
  --     null_ls.setup {
  --       sources = {
  --         null_ls.builtins.diagnostics.rubocop.with {
  --           command = "bundle",
  --           args = { "exec", "rubocop", "--format", "json", "--force-exclusion", "--stdin", "$FILENAME" },
  --         },
  --         null_ls.builtins.formatting.rubocop.with {
  --           command = "bundle",
  --           args = { "exec", "rubocop", "--auto-correct", "--stdin", "$FILENAME" },
  --         },
  --       },
  --     }
  --   end,
  -- },
  -- {
  --   "williamboman/mason-lspconfig.nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     opts.ensure_installed =
  --       require("astrocore").list_insert_unique(opts.ensure_installed, { "solargraph" })
  --
  --     -- opts.signcolumn = "yes"
  --     -- vim.api.nvim_create_autocmd("FileType", {
  --     --   pattern = "ruby",
  --     --   callback = function()
  --     --     vim.lsp.start {
  --     --       name = "rubocop",
  --     --       cmd = { "bundle", "exec", "rubocop", "--lsp" },
  --     --     }
  --     --   end,
  --     -- })
  --   end,
  -- },
  -- {
  --   "WhoIsSethDaniel/mason-tool-installer.nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     opts.ensure_installed =
  --       require("astrocore").list_insert_unique(opts.ensure_installed, { "solargraph" })
  --   end,
  -- },
  -- {
  --   "mfussenegger/nvim-dap",
  --   optional = true,
  --   dependencies = { "suketa/nvim-dap-ruby", config = true },
  -- },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        ruby = { "rubocop" },
      },
    },
  },
}
