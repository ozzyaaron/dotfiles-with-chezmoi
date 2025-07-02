return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 100,
          keymap = {
            accept = "<Tab>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = { enabled = false },
        server_opts_overrides = {
          -- Disable copilot LSP functionality
          trace = "off",
          settings = {
            advanced = {
              listCount = 0, -- Disable completion list
              inlineSuggestCount = 3,
            }
          }
        }
      })
    end,
  },
  -- {
  --   "zbirenbaum/copilot-cmp",
  --   enabled = false,
  --   after = {
  --     "copilot.lua",
  --     "nvim-cmp",
  --   },
  --   config = function()
  --     require("copilot_cmp").setup()
  --   end
  -- },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
    },
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
    },
    -- See Commands section for default commands if you want to lazy load on them
  },
}
