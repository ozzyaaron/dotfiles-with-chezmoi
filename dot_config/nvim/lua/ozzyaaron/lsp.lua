-- LSP Configuration

-- Define capabilities BEFORE enabling LSP servers (they reference this global)
local blink_capabilities = require('blink.cmp').get_lsp_capabilities()
blink_capabilities.general = blink_capabilities.general or {}
blink_capabilities.general.positionEncodings = { 'utf-16' }

-- Enhanced capabilities for better completion
blink_capabilities.textDocument = blink_capabilities.textDocument or {}
blink_capabilities.textDocument.completion = blink_capabilities.textDocument.completion or {}
blink_capabilities.textDocument.completion.completionItem = {
  documentationFormat = { 'markdown', 'plaintext' },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      'documentation',
      'detail',
      'additionalTextEdits',
      'labelDetails',
    },
  },
}

-- Signature help capabilities
blink_capabilities.textDocument.signatureHelp = {
  dynamicRegistration = false,
  signatureInformation = {
    documentationFormat = { 'markdown', 'plaintext' },
    parameterInformation = { labelOffsetSupport = true },
    activeParameterSupport = true,
  },
}

-- Make capabilities available globally for lsp/ config files
_G.capabilities = blink_capabilities

-- Enable LSP servers (uses configs from lsp/ directory)
vim.lsp.enable('ruby_lsp')
vim.lsp.enable('gopls')
vim.lsp.enable('ts_ls')
vim.lsp.enable('html')

-- LSP attach handler
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('user-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Navigation
    map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
    map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
    map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
    map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

    -- Search symbols
    map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
    map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

    -- Actions
    map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
    map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

    -- Set offset encoding
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client then
      client.offset_encoding = 'utf-16'
    end

    -- Document highlight on cursor hold
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_augroup = vim.api.nvim_create_augroup('user-lsp-highlight', { clear = false })

      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('user-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds({ group = 'user-lsp-highlight', buffer = event2.buf })
        end,
      })
    end

    -- Inlay hints toggle
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
      end, '[T]oggle Inlay [H]ints')
    end
  end,
})

-- Diagnostic configuration
local diagnostic_config = {
  virtual_text = {
    spacing = 4,
    source = 'if_many',
    prefix = '●',
  },
  float = {
    source = 'if_many',
    border = 'rounded',
  },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
}

if vim.g.have_nerd_font then
  local signs = { ERROR = '', WARN = '', INFO = '', HINT = '' }
  local diagnostic_signs = {}
  for type, icon in pairs(signs) do
    diagnostic_signs[vim.diagnostic.severity[type]] = icon
  end
  diagnostic_config.signs = { text = diagnostic_signs }
else
  diagnostic_config.signs = true
end

vim.diagnostic.config(diagnostic_config)
