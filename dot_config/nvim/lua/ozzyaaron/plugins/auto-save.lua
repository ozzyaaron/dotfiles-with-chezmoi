return {
  {
    'okuuva/auto-save.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      debounce_delay = 2000,
    },
  },
}
