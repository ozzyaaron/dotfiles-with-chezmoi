local on_attach = function(client, bufnr)
  -- (Optional) Set up buffer-local keymaps or commands here.
  -- e.g., vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', { noremap = true, silent = true })
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

require('lspconfig').ruby_lsp.setup {
  cmd = { 'bundle', 'exec', 'ruby-lsp' },
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    formatting = false,
    -- Add any Ruby LSP-specific settings here.
    -- For example, if the server supports custom settings:
    -- ruby = { diagnostics = { rubocop = { enable = true } } },
  }, -- Server-specific settings. See `:help lspconfig-setup`
}
