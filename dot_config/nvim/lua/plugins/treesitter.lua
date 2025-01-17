-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    -- list like portions of a table cannot be merged naturally and require the user to merge it manually
    -- check to make sure the key exists
    if not opts.ensure_installed then opts.ensure_installed = {} end
    vim.list_extend(opts.ensure_installed, {
      "lua",
      "vim",
      "ruby",
      "typescript",
      "javascript",
      -- add more arguments for adding more treesitter parsers
    })

    if not opts.highlight then opts.highlight = {} end
    opts.highlight.enabled = true
    opts.highlight.additional_vim_regex_highlighting = { "ruby" }

    if not opts.indent then opts.indent = {} end
    opts.indent.enable = true
    if not opts.indent.disable then opts.indent.disable = {} end
    opts.indent.disable = { "ruby" }

    if not opts.endwise then opts.endwise = {} end
    opts.endwise.enabled = true
  end,
}
