return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    { '<leader>a', function() require('harpoon'):list():add() end, desc = 'Harpoon: Add file' },
    { '<C-e>', function() local h = require('harpoon'); h.ui:toggle_quick_menu(h:list()) end, desc = 'Harpoon: Toggle menu' },
    { '<leader>1', function() require('harpoon'):list():select(1) end, desc = 'Harpoon: File 1' },
    { '<leader>2', function() require('harpoon'):list():select(2) end, desc = 'Harpoon: File 2' },
    { '<leader>3', function() require('harpoon'):list():select(3) end, desc = 'Harpoon: File 3' },
    { '<leader>4', function() require('harpoon'):list():select(4) end, desc = 'Harpoon: File 4' },
    { '<leader>5', function() require('harpoon'):list():select(5) end, desc = 'Harpoon: File 5' },
    { '<C-S-P>', function() require('harpoon'):list():prev() end, desc = 'Harpoon: Previous' },
    { '<C-S-N>', function() require('harpoon'):list():next() end, desc = 'Harpoon: Next' },
  },
  config = function()
    require('harpoon'):setup({
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
      },
    })
  end,
}
