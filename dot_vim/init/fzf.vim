" FZF setup
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-s': 'split',
  \ 'ctrl-v': 'vsplit' }
let $FZF_DEFAULT_COMMAND='ag -g ""'
let $FZF_DEFAULT_OPTS='--color=bg+:-1 --inline-info'
let g:fzf_layout = { 'down': '10' }
let g:fzf_buffers_jump = 0
augroup fzf
autocmd! FileType fzf
  " close on Esc
  autocmd FileType fzf tnoremap <Esc> <C-c>
  " hide status line
  autocmd FileType fzf set laststatus=0 noshowmode noruler
        \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler
augroup END

nnoremap <silent> <leader>f :Files<CR>
