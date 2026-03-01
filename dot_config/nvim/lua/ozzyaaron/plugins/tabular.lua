return {
  {
    'godlygeek/tabular',
    cmd = 'Tabularize',
    keys = {
      { 'fct', function()
        vim.cmd('Tabularize /|')
        vim.cmd('normal! gv')
        vim.cmd("'<,'>s/^.//")
      end, mode = 'v', desc = 'Align selection on pipe character and remove leading space' },
    },
  },
}
