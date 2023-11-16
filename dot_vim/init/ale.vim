" "Define linters
"let g:ale_linters = {
      "\ 'ruby': ['rubocop', 'solargraph'],
      "\ 'javascript': ['eslint'],
      "\ }

"" Disable showing the issues as comments in the code
"let g:ale_virtualtext_cursor = 0

"" Lint Ruby files with binstub
"let g:ale_ruby_rubocop_executable = 'bin/rubocop'

"" Set the executable for ALE to call to get Solargraph
"" up and running in a given session
"let g:ale_ruby_solargraph_executable = 'bin/solargraph'
"let g:ale_ruby_solargraph_options = {}

"" Tune linter's error and warning signs
"let g:ale_sign_error = '\u2022'
"let g:ale_sign_warning = '\u2022'

"" Let's leave a column for the signs so that the left side of the window doesn't move
"let g:ale_sign_column_always = 1

"" You should not turn this setting on if you wish to use ALE as a completion
"" source for other completion plugins, like Deoplete.
"let g:ale_completion_enabled = 1

"" Only run linters defined rather than any that ALE thinks should be used
"let g:ale_linters_explicit = 1

""function! LinterStatus() abort
  ""let l:counts = ale#statusline#Count(bufnr(''))

  ""let l:all_errors = l:counts.error + l:counts.style_error
  ""let l:all_non_errors = l:counts.total - l:all_errors

  ""return l:counts.total == 0 ? '✨ all good ✨' : printf(
        ""\   '😞 %dW %dE',
        ""\   all_non_errors,
        ""\   all_errors
        ""\)
""endfunction

""set statusline=
""set statusline+=%m
""set statusline+=\ %f
""set statusline+=%=
""set statusline+=\ %{LinterStatus()}

"" Fixes the bug identified in this issue:
"" https://github.com/w0rp/ale/issues/1700
""set completeopt=menu,menuone,preview,noselect,noinsert
