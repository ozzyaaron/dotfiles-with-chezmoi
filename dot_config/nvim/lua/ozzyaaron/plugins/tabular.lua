return {
  {
    'godlygeek/tabular',
    config = function()
      -- Function to align on pipe and shift left by 1 character
      local function align_and_shift()
        vim.cmd('Tabularize /|')
        vim.cmd('normal! gv')
        vim.cmd("'<,'>s/^.//")
      end

      -- Visual mode mapping for aligning on pipe character
      vim.keymap.set('v', 'fct', align_and_shift,
        { desc = 'Align selection on pipe character and remove leading space' })
    end,
  },
}
