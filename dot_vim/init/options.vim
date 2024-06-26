scriptencoding utf-8

set guioptions-=T               " Remove GUI toolbar
set guioptions-=rL              " Remove scrollbars
set guicursor=a:blinkon0        " Turn off the blinking cursor

set visualbell                  " Suppress audio/visual error bell

set notimeout                   " No command timeout
set ttimeout                    " Add back a timeout for terminal vim
set ttimeoutlen=100             " Keep the timeout very short

set showcmd                     " Show typed command prefixes while waiting for operator
set mouse=a                     " Use mouse support in XTerm/iTerm.

set colorcolumn=100 " show a marker at 100 char width

" Show relative and absolute line numbers
set relativenumber
set nu

set expandtab                   " Use soft tabs
set tabstop=2                   " Tab settings
set autoindent
set smarttab                    " Use shiftwidth to tab at line beginning
set shiftwidth=2                " Width of autoindent
set nowrap                      " No wrapping
set backspace=indent,eol,start " Let backspace work over anything.

set list                        " Show whitespace
set listchars=trail:·

set showmatch                   " Show matching brackets
set hidden                      " Allow hidden, unsaved buffers
set splitright                  " Add new windows towards the right
set splitbelow                  " ... and bottom
set wildmode=list:longest       " Bash-like tab completion
set scrolloff=3                 " Scroll when the cursor is 3 lines from edge

set laststatus=2                " Always show statusline

set incsearch                   " Incremental search
set history=1024                " History size
set smartcase                   " Smart case-sensitivity when searching (overrides ignorecase)

set autoread                    " No prompt for file changes outside Vim

set swapfile                    " Keep swapfiles
set directory=~/.vim-tmp,~/tmp,/var/tmp,/tmp
set backupdir=~/.vim-tmp,~/tmp,/var/tmp,/tmp

set hls                         " search with highlights by default

" Write all writeable buffers when changing buffers or losing focus.
set autowriteall                " Save when doing various buffer-switching things.
autocmd BufLeave,FocusLost * silent! wall  " Save anytime we leave a buffer or MacVim loses focus.

let g:sql_type_default="postgresql"
