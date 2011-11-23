"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Version: 0.3.1
" Usage:
"   :Simplenote -l => list all notes
"   :Simplenote -u => update a note from buffer
"   :Simplenote -d => move note to trash
"   :Simplenote -n => create new note from buffer
"   :Simplenote -D => delete note in current buffer
"   :Simplenote -t => tag note in current buffer
"
"

if &cp || (exists('g:loaded_simplenote_vim') && g:loaded_simplenote_vim)
  finish
endif
let g:loaded_simplenote_vim = 1

let s:save_cpo = &cpo
set cpo&vim
" set the simplenote command
command! -nargs=1 Simplenote :call simplenote#SimpleNote(<f-args>)
let &cpo = s:save_cpo
unlet s:save_cpo
