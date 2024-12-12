return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      {
        "<leader>fz",
        function()
          local pickers = require "telescope.pickers"
          local finders = require "telescope.finders"
          local make_entry = require "telescope.make_entry"
          local conf = require("telescope.config").values

          local opts = {}
          opts.cwd = opts.cwd or vim.loop.cwd()

          local finder = finders.new_async_job {
            command_generator = function(prompt)
              if not prompt or prompt == "" then return nil end

              local pieces = vim.split(prompt, " ")
              local args = { "rg" }

              vim.schedule(function()
                local command_str = table.concat(pieces, " ")
                print("Executing: " .. command_str)
                -- Also log to a file for persistence
                local log_file = io.open(vim.fn.stdpath "cache" .. "/multigrep.log", "a")
                if log_file then
                  log_file:write(os.date "%Y-%m-%d %H:%M:%S" .. " Command: " .. command_str .. "\n")
                  log_file:close()
                end
              end)

              if pieces[1] then
                table.insert(args, "-e")
                table.insert(args, pieces[1])
              end

              if pieces[2] then
                table.insert(args, "-g")
                table.insert(args, pieces[2])
              end

              local cmd = vim.tbl_flatten {
                args,
                { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
              }

              -- Log the complete command
              vim.schedule(function()
                local command_str = table.concat(cmd, " ")
                print("Executing: " .. command_str)
                -- Also log to a file for persistence
                local log_file = io.open(vim.fn.stdpath "cache" .. "/multigrep.log", "a")
                if log_file then
                  log_file:write(os.date "%Y-%m-%d %H:%M:%S" .. " Command: " .. command_str .. "\n")
                  log_file:close()
                end
              end)

              return cmd
            end,

            entry_maker = make_entry.gen_from_vimgrep(opts),
            cwd = opts.cwd,
          }

          pickers
            .new(opts, {
              debounce = 100,
              prompt_title = "Multi Grep",
              finder = finder,
              previewer = conf.grep_previewer(opts),
              sorter = require("telescope.sorters").empty(),
            })
            :find()
        end,
        desc = "Multi Grep Search",
      },
    },
  },
}
