return {
  'vim-test/vim-test',
  dependencies = {
    'preservim/vimux', -- Optional: for running tests in tmux pane
  },
  keys = {
    { '<leader>tn', ':TestNearest<CR>', desc = '[T]est [N]earest' },
    { '<leader>tf', ':TestFile<CR>', desc = '[T]est [F]ile' },
    { '<leader>ts', ':TestSuite<CR>', desc = '[T]est [S]uite' },
    { '<leader>tl', ':TestLast<CR>', desc = '[T]est [L]ast' },
    { '<leader>tv', ':TestVisit<CR>', desc = '[T]est [V]isit (go to last test file)' },
  },
  config = function()
    -- Use neovim's built-in terminal by default
    vim.g['test#strategy'] = 'neovim'

    -- If in tmux, use vimux instead for a better experience
    if vim.env.TMUX then
      vim.g['test#strategy'] = 'vimux'
    end

    -- Ruby/Rails settings
    vim.g['test#ruby#rspec#executable'] = 'bundle exec rspec'
    vim.g['test#ruby#minitest#executable'] = 'bundle exec rails test'

    -- Go settings
    vim.g['test#go#gotest#options'] = '-v'

    -- JavaScript settings
    vim.g['test#javascript#runner'] = 'jest'
  end,
}
