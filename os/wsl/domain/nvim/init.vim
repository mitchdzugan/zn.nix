set nu rnu
set nocompatible
if has('filetype')
  filetype indent plugin on
endif
if has('syntax')
  syntax on
endif
set showtabline=2
set scl=yes
set hlsearch
set number
set cursorline
set hidden
set visualbell
set t_vb=
if has('mouse')
  set mouse=a
endif

set expandtab
set tabstop=2
set shiftwidth=2
set nowrap

set t_ZH=␛[3m
set t_ZR=␛[23m

let mapleader = "\\"
let maplocalleader = ","

autocmd BufReadPost * if @% !~# '\.git[\/\\]COMMIT_EDITMSG$' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

set background=dark
" catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha
" colorscheme catppuccin-mocha
" colorscheme moonfly
" colorscheme kanagawa-wave
" colorscheme rose-pine-main
" colorscheme tokyodark
"-
" set background=dark
" colorscheme oxocarbon
"-
"let g:aurora_italic = 1
"let g:aurora_transparent = 1
"let g:aurora_bold = 1
"let g:aurora_darker = 1
"colorscheme aurora
"hi! TabLineSel gui=none
"hi! TabLineSel cterm=none
"hi! CursorLineNr gui=none
"hi! CursorLineNr cterm=none
"-

set list lcs=trail:·,tab:🮙🮙,lead:🮙

syntax on
if has('termguicolors')
    set termguicolors
endif

set clipboard+=unnamedplus
set noshowcmd
hi MatchParen gui=underline

let g:vim_json_conceal = 0
let g:vim_markdown_conceal = 0

set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
  \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
  \,sm:block-blinkwait175-blinkoff150-blinkon175

" syn match ZTodoOpen /\[ \]/ conceal cchar=_
" syn match ZTodoWip /\[-\]/ conceal cchar=o
" function! SetSyntax()
  " :syn match ZTodoDoneL contained "\[" conceal cchar=⦗
  " :syn match ZTodoDoneM contained "x" conceal cchar=🗸
  " :syn match ZTodoDoneR contained "\]" conceal cchar=⦘
  " :syn match ZTodoDone "\[x\]" contains=ZTodoDoneL,ZTodoDoneM,ZTodoDoneR
  " :highlight! link ZTodoDone RenderMarkdownSuccess
" endfunction

" :command! -nargs=0 SetSyntax :call SetSyntax()
" set conceallevel=2
