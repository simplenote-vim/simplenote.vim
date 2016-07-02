"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Version: 1.2.0
" Usage:
"   :Simplenote -l X => list X number of notes; omit X to list all
"   :Simplenote -l tags,moretags => list notes which feature one of the tags
"   :Simplenote -u => update a note from buffer
"   :Simplenote -d => move note to trash
"   :Simplenote -n => create new note from buffer
"   :Simplenote -D => delete note in current buffer
"   :Simplenote -t => tag note in current buffer
"   :Simplenote -p => pin note in current buffer
"   :Simplenote -P => unpin note in current buffer
"   :Simplenote -o key => open note with given key directly
"
" This is only the interface part of the script. For the actual implementation
" see plugin/simplenote.vim
"

if !exists('g:SimplenotePrefix')
  g:SimplenotePrefix = "Simplenote"
endif

" set the simplenote command
command! -nargs=+ Simplenote :call simplenote#SimpleNote(<f-args>)

if g:SimplenotePrefix != ''
  execute "command! -nargs=? " . g:SimplenotePrefix . 'List'        . "  :call simplenote#SimpleNote('-l', <f-args>)"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'Update'      . "  :call simplenote#SimpleNote('-u')"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'VersionInfo' . "  :call simplenote#SimpleNote('-V')"
  execute "command! -nargs=? " . g:SimplenotePrefix . 'Version'     . "  :call simplenote#SimpleNote('-v', <f-args>)"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'Trash'       . "  :call simplenote#SimpleNote('-d')"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'Delete'      . "  :call simplenote#SimpleNote('-D')"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'New'         . "  :call simplenote#SimpleNote('-n')"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'Tags'        . "  :call simplenote#SimpleNote('-t')"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'Pin'         . "  :call simplenote#SimpleNote('-p')"
  execute "command! -nargs=0 " . g:SimplenotePrefix . 'Unpin'       . "  :call simplenote#SimpleNote('-P')"
  execute "command! -nargs=1 " . g:SimplenotePrefix . 'Open'        . "  :call simplenote#SimpleNote('-o')"
endif

