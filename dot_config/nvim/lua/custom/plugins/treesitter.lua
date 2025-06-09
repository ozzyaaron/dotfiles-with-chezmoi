return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects', -- Additional textobjects via treesitter
    },
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'diff',
        'html',
        'lua',
        'luadoc',
        'javascript',
        'markdown',
        'markdown_inline',
        'ruby',
        'vim',
        'vimdoc',
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
      textobjects = {
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            [']f'] = { query = '@function.outer', desc = 'Next function start' },
            [']c'] = { query = '@class.outer', desc = 'Next class start' },
          },
          goto_previous_start = {
            ['[f'] = { query = '@function.outer', desc = 'Next function start' },
            ['[c'] = { query = '@class.outer', desc = 'Next class start' },
          },
        },
      },
    },
  },
  { -- Add/change/delete surrounding characters
    'kylechui/nvim-surround',
    event = 'VeryLazy',
    config = true,
  },
}
