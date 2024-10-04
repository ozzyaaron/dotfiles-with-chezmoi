return {
  -- customize treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- list like portions of a table cannot be merged naturally and require the user to merge it manually
      -- check to make sure the key exists
      if not opts.ensure_installed then opts.ensure_installed = {} end
      vim.list_extend(opts.ensure_installed, {
        "lua",
        "vim",
        "ruby",
        "typescript",
        "javascript",
        -- "solargraph",
        -- "rubocop",
        -- add more arguments for adding more treesitter parsers
      })

      if not opts.highlight then opts.highlight = {} end
      opts.highlight.enabled = true
      opts.highlight.additional_vim_regex_highlighting = { "ruby" }

      if not opts.indent then opts.indent = {} end
      opts.indent.enable = true
      if not opts.indent.disable then opts.indent.disable = {} end
      opts.indent.disable = { "ruby" }

      if not opts.endwise then opts.endwise = {} end
      opts.endwise.enabled = true
    end,
  },
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
