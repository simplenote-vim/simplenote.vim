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

" set the simplenote command
command! -nargs=+ Simplenote :call simplenote#SimpleNote(<f-args>)

if exists('g:simplenote_prefix')
  execute "command! -nargs=? " . g:simplenote_prefix . 'list'      . "  :call simplenote#SimpleNote('-l', <f-args>)"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'update'    . "  :call simplenote#SimpleNote('-u')"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'delete'    . "  :call simplenote#SimpleNote('-d')"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'new'       . "  :call simplenote#SimpleNote('-n')"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'deletebuf' . "  :call simplenote#SimpleNote('-D')"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'tag'       . "  :call simplenote#SimpleNote('-t')"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'pin'       . "  :call simplenote#SimpleNote('-p')"
  execute "command! -nargs=0 " . g:simplenote_prefix . 'unpin'     . "  :call simplenote#SimpleNote('-P')"
  execute "command! -nargs=1 " . g:simplenote_prefix . 'key'       . "  :call simplenote#SimpleNote('-o')"
endif

