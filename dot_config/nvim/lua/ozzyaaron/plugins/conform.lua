return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>cf',
      function()
        require('conform').format({ async = true, lsp_fallback = true })
      end,
      mode = { 'n', 'v' },
      desc = '[C]ode [F]ormat',
    },
  },
  opts = {
    notify_on_error = true,
    format_on_save = function(bufnr)
      -- Disable autoformat for certain filetypes
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      end
      return {
        timeout_ms = 500,
        lsp_fallback = true,
      }
    end,
    formatters_by_ft = {
      go = { 'goimports', 'gofmt' },
      javascript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescript = { 'prettier' },
      typescriptreact = { 'prettier' },
      html = { 'prettier' },
      css = { 'prettier' },
      scss = { 'prettier' },
      json = { 'prettier' },
      yaml = { 'prettier' },
      markdown = { 'prettier' },
      ruby = { 'rubocop' },
      eruby = { 'erb_format' },
      lua = { 'stylua' },
    },
  },
}
