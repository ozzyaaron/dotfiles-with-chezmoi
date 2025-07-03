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
            -- accept = "<Tab>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = { enabled = false },
        copilot_node_command = 'node',
        server_opts_overrides = {
          name = nil,
        },
      })

      -- Override the LspRestart command to exclude copilot
      vim.api.nvim_create_user_command('LspRestart', function(opts)
        local clients = vim.lsp.get_clients()
        for _, client in ipairs(clients) do
          if client.name ~= 'copilot' then
            if opts.args == "" or client.name == opts.args then
              vim.lsp.stop_client(client.id, true)
              vim.cmd('edit') -- Trigger LSP attach for current buffer
            end
          end
        end
      end, { nargs = '?', complete = function()
        local clients = vim.lsp.get_clients()
        local names = {}
        for _, client in ipairs(clients) do
          if client.name ~= 'copilot' then
            table.insert(names, client.name)
          end
        end
        return names
      end })
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
