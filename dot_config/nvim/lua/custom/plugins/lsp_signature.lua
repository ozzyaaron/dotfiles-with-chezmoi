return {
  {
    "ray-x/lsp_signature.nvim",
    event = "LspAttach",
    opts = {
      bind = true, -- This is mandatory, otherwise border config won't get registered.
      handler_opts = {
        border = "rounded"
      },
      -- Show hint in a floating window, see :help nvim_open_win()
      floating_window = true,
      floating_window_above_cur_line = true,
      floating_window_off_x = 0, -- adjust float windows x position.
      floating_window_off_y = 0, -- adjust float windows y position.

      -- Appearance
      hint_enable = true, -- virtual hint enable
      hint_prefix = "🔍 ", -- Panda for parameter
      hint_scheme = "String",

      -- Automatically show signature help when typing
      always_trigger = false, -- sometime triggle signature help in string literal
      auto_close_after = nil, -- autoclose after n seconds

      -- Toggle key
      toggle_key = nil, -- toggle signature on and off in insert mode,  e.g. toggle_key = '<M-x>'
      toggle_key_flip_floatwin_setting = false, -- flip hint/floating window

      -- Select signature
      select_signature_key = nil, -- cycle to next signature, e.g. '<M-n>' function overloading
      move_cursor_key = nil, -- imap, use nvim_set_current_win to move cursor between current win and floating

      -- Parameter hints
      max_height = 12, -- max height of signature floating_window
      max_width = 80, -- max_width of signature floating_window
      wrap = true, -- allow doc/signature text wrap inside floating_window, useful if your lsp return doc/sig is too long

      -- Transparency
      transparency = nil, -- disabled by default, allow floating win transparent value 1~100
      shadow_blend = 36, -- if you using shadow as border use this set the opacity
      shadow_guibg = 'Black', -- if you using shadow as border use this set the color e.g. 'Green' or '#121315'

      -- Other options
      timer_interval = 200, -- default timer check interval set to lower value if you want to reduce latency
      extra_trigger_chars = {}, -- Array of extra characters that will trigger signature completion, e.g., {"(", ","}
      zindex = 200, -- by default it will be on top of all floating windows, set to <= 50 send it to bottom

      -- Debug
      debug = false, -- set to true to enable debug logging
      log_path = vim.fn.stdpath("cache") .. "/lsp_signature.log", -- log dir when debug is on
      verbose = false, -- show debug line number

      -- Padding
      padding = '', -- character to pad on left and right of signature can be ' ', or '|'  etc

      doc_lines = 10, -- will show two lines of comment/doc(if there are more than two lines in doc, will be truncated);
                      -- set to 0 if you DO NOT want any API comments be shown
                      -- This setting only take effect in insert mode, it does not affect signature help in normal
                      -- mode, 10 by default

      hi_parameter = "LspSignatureActiveParameter", -- how your parameter will be highlight
      handler_opts = {
        border = "rounded"   -- double, rounded, single, shadow, none
      },
    },
    config = function(_, opts)
      require("lsp_signature").setup(opts)
    end,
  },
}