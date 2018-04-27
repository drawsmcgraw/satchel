execute pathogen#infect()
syntax on
filetype plugin indent on
set tabstop=4
set shiftwidth=4
set expandtab

" Force using the Jinja2 template syntax file (0) for Django
let g:sls_use_jinja_syntax = 1

" Use Saltstack syntax highlighting for '.jinja' files.
autocmd BufRead,BufNewFile *.jinja set filetype=sls
