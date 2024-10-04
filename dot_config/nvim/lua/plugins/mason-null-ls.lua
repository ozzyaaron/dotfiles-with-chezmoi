return {
  "jay-babu/mason-null-ls.nvim",
  opts = {
    ensure_installed = { "rubocop" },
    handlers = {
      rubocop = function()
        require("null-ls").register(require("null-ls").builtins.diagnostics.rubocop.with {
          command = "bundle",
          args = { "exec", "rubocop", "--format", "json", "--force-exclusion", "--stdin", "$FILENAME" },
        })
        require("null-ls").register(require("null-ls").builtins.formatting.rubocop.with {
          command = "bundle",
          args = { "exec", "rubocop", "--auto-correct", "--stdin", "$FILENAME" },
        })
      end,
    },
  },
}
