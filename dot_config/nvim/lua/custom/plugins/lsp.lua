return {
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'saghen/blink.cmp',
      { 'j-hui/fidget.nvim', opts = {} },
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = {
          -- "ts_ls",
          "cucumber_language_server",
          "cssls",
          "html",
        },
        automatic_enabled = false,
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- Find references for the word under your cursor.
          -- Note: Neovim 0.11+ has built-in 'grr' mapping for references, so we don't override 'gr'
          -- map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
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
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Change diagnostic symbols in the sign column (gutter)
      if vim.g.have_nerd_font then
        local signs = { ERROR = '', WARN = '', INFO = '', HINT = '' }
        local diagnostic_signs = {}
        for type, icon in pairs(signs) do
          diagnostic_signs[vim.diagnostic.severity[type]] = icon
        end
        vim.diagnostic.config {
          signs = { text = diagnostic_signs },
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = '●',
          },
          float = {
            source = "if_many",
            border = "rounded",
          },
          underline = true,
          update_in_insert = false,
          severity_sort = true,
        }
      else
        vim.diagnostic.config {
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = '●',
          },
          float = {
            source = "if_many",
            border = "rounded",
          },
          signs = true,
          underline = true,
          update_in_insert = false,
          severity_sort = true,
        }
      end

      -- Add a keymap to show diagnostics in a floating window
      vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror' })
      vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
      vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })

      -- Force enable diagnostic handlers (in case they were disabled)
      vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
        vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = '●',
          },
          signs = true,
          underline = true,
          update_in_insert = false,
        }
      )

      -- local capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      capabilities.general = capabilities.general or {}
      capabilities.general.positionEncodings = { 'utf-16' }

      -- Enhanced capabilities for better completion details and signatures
      capabilities.textDocument = capabilities.textDocument or {}
      capabilities.textDocument.completion = capabilities.textDocument.completion or {}
      capabilities.textDocument.completion.completionItem = {
        documentationFormat = { "markdown", "plaintext" },
        snippetSupport = true,
        preselectSupport = true,
        insertReplaceSupport = true,
        labelDetailsSupport = true,
        deprecatedSupport = true,
        commitCharactersSupport = true,
        tagSupport = { valueSet = { 1 } },
        resolveSupport = {
          properties = {
            "documentation",
            "detail",
            "additionalTextEdits",
            "labelDetails",
          },
        },
      }

      -- Enable signature help capabilities
      capabilities.textDocument.signatureHelp = {
        dynamicRegistration = false,
        signatureInformation = {
          documentationFormat = { "markdown", "plaintext" },
          parameterInformation = {
            labelOffsetSupport = true,
          },
          activeParameterSupport = true,
        },
      }

      vim.lsp.config("ruby_lsp",
        {
          cmd = { 'bundle', 'exec', 'ruby-lsp' }, -- Ensure `ruby-lsp` runs with Bundler
          capabilities = capabilities,
          init_options = {
            enabledFeatures = {
              documentHighlights = false,
              diagnostics = true,
            },
          },
          settings = {
            rubyLsp = {
              featuresConfiguration = {
                inlayHint = {
                  enableAll = false,
                },
              },
              -- Exclude common directories that don't need indexing
              indexing = {
                excludedPatterns = {
                  "**/node_modules/**",
                  "**/tmp/**",
                  "**/log/**",
                  "**/coverage/**",
                  "**/vendor/**",
                  "**/.git/**",
                },
              },
            },
          },
        }
      )

      vim.lsp.enable("ruby_lsp")
      vim.lsp.enable("cucumber_language_server")
    end,
  },
}
