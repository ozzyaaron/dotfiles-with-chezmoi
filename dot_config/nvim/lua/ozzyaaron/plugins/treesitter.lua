return {
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    opts = {
      ensure_installed = {
        'bash',
        'css',
        'diff',
        'go',
        'gomod',
        'gosum',
        'html',
        'javascript',
        'json',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'ruby',
        'scss',
        'tsx',
        'typescript',
        'vim',
        'vimdoc',
        'yaml',
      },
      auto_install = false,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = {
        enable = true,
        disable = { 'ruby' },
      },
    },
  },
  { -- Add/change/delete surrounding characters
    'kylechui/nvim-surround',
    event = 'VeryLazy',
    config = true,
  },
}
