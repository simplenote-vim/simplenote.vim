"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Version: 0.7.0
" Usage:
"   :Simplenote -l X => list X number of notes; omit X to list all
"   :Simplenote -l tags,moretags => list notes which feature one of the tags
"   :Simplenote -u => update a note from buffer
"   :Simplenote -d => move note to trash
"   :Simplenote -n => create new note from buffer
"   :Simplenote -D => delete note in current buffer
"   :Simplenote -t => tag note in current buffer
"   :Simplenote -o key => open note with given key directly
"
" This is only the interface part of the script. For the actual implementation
" see plugin/simplenote.vim
"

" set the simplenote command
command! -nargs=+ Simplenote :call simplenote#SimpleNote(<f-args>)

