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
