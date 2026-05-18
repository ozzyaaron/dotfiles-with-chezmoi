return {
  cmd = { 'bundle', 'exec', 'ruby-lsp' },
  filetypes = { 'ruby', 'eruby' },
  root_markers = { 'Gemfile', '.ruby-version', '.git' },
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
