"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" Last Change: 21-Aug-2010.
" Version: ??
" WebPage: http://github.com/mrtazz/simplenote-vim
" License: MIT
" Usage:
"
"
"

if &cp || (exists('g:loaded_simplenote_vim') && g:loaded_simplenote_vim)
  finish
endif
let g:loaded_simplenote_vim = 1

if !executable('curl')
  echoerr "Simplenote: 'curl' command required"
  finish
endif
