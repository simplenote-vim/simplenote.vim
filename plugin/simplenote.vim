"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Version: 1.2.0
" Usage:
"   :SimplenoteList X => list X number of notes; omit X to list all
"   :SimplenoteList tags,moretags => list notes which feature one of the tags
"   :SimplenoteUpdate => update a note from buffer
"   :SimplenoteTrash => move note to trash
"   :SimplenoteNew => create new note from buffer
"   :SimplenoteDelete => delete note in current buffer
"   :SimplenoteTag => tag note in current buffer
"   :SimplenotePin => pin note in current buffer
"   :SimplenoteUnpin => unpin note in current buffer
"   :SimplenoteOpen key => open note with given key directly
"
" This is only the interface part of the script. For the actual implementation
" see plugin/simplenote.vim
"

" set the simplenote command
command! -nargs=+ SimplenoteDelete :call simplenote#SimplenoteDelete()
command! -nargs=+ SimplenoteList :call simplenote#SimplenoteList(<f-args>)
command! -nargs=+ SimplenoteUpdate :call simplenote#SimplenoteUpdate()
command! -nargs=+ SimplenoteVersion :call simplenote#SimplenoteVersion(<f-args>)
command! -nargs=+ SimplenoteVersionInfo :call simplenote#SimplenoteVersionInfo()
command! -nargs=+ SimplenoteTrash :call simplenote#SimplenoteTrash()
command! -nargs=+ SimplenoteNew :call simplenote#SimplenoteNew()
command! -nargs=+ SimplenoteTag :call simplenote#SimplenoteTag()
command! -nargs=+ SimplenoteUnpin :call simplenote#SimplenoteUnpin()
command! -nargs=+ SimplenoteOpen :call simplenote#SimplenoteOpen(<f-args>)
command! -nargs=+ SimplenotePin :call simplenote#SimplenotePin()
