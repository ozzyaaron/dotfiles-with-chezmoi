return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        -- suggestion = {
        --   enabled = true,
        --   auto_trigger = true,
        --   debounce = 100,
        -- },
        panel = { enabled = false },
      })
    end,
  },
  {
    "zbirenbaum/copilot-cmp",
    enabled = false,
    after = {
      "copilot.lua",
      "nvim-cmp",
    },
    config = function()
      require("copilot_cmp").setup()
    end
  }
}
