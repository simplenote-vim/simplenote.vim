"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" Last Change: 21-Aug-2010.
" Version: ??
" WebPage: http://github.com/mrtazz/simplenote.vim
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

if !executable('openssl')
  echoerr "Simplenote: 'openssl' command required"
  finish
endif
"
" Helper functions
"

" function to wrap openssl base64 encoding
function! s:Base64Encode(string)
  return system('echo -n "'.a:string.'" | openssl base64')
endfunction



"
" API functions
"

" function to get simplenote auth token
function! s:SimpleNoteAuth(user, password)
  let url = 'https://simple-note.appspot.com/api/login'
  let auth_params = 'email='.a:user.'&password='.a:password
  let auth_b64 = s:Base64Encode(auth_params)
  let curl_params = '-s -X POST -d'.auth_b64
  let token = system('curl '.curl_params)
  if token =~# 'Traceback'
    echoerr "Simplenote: Auth failed."
  else
    return token
  endif
endfunction

" function to get a specific note
function! s:GetNote(user, token, noteid)
  let url = 'https://simple-note.appspot.com/api/note?'
  let params = 'key='.a:noteid.'&auth='.a:token.'&email='.a:user
  let note = system('curl -s '.url.params)
  return note
endfunction

" function to update a specific note
function! s:UpdateNote(user, token, noteid, content)
  let url = 'https://simple-note.appspot.com/api/note?'
  let params = 'key='.a:noteid.'&auth='.a:token.'&email='.a:user
  let enc_content = s:Base64Encode(content)
  let curl_params = '-X POST -d'.enc_content
  system('curl -s '.curl_params.' '.url.params)
endfunction

" function to get the note list
function! s:GetNoteList(user, token)
  let url = 'https://simple-note.appspot.com/api/index?'
  let params = 'auth='.a:token.'&email='.a:user
  let res = system('curl -s '.url.params)
endfunction

"
" User interface
"

function! s:SimpleNote(line1, line2, ...)
  let args = (a:0 > 0) ? split(a:1, ' ') : []
  for arg in args
    if arg =~ '^\(-l\|--list\)$'
      let listnotes = 1
    elseif arg =~ '^\(-u\|--update\)$'
      let updatenote = 1
    elseif len(arg) > 0
      echoerr 'Invalid arguments'
      unlet args
      return 0
    endif
  endfor
  unlet args
  if listnotes == 1
    let notes = s:GetNoteList(s:user, s:token)
    let winnum = bufwinnr(bufnr('note: index'))
    if winnum != -1
      if winnum != bufwinnr('%')
        exe "normal \<c-w>".winnum."w"
      endif
      setlocal modifiable
    else
      exec 'silent split note: index'
    endif
  endif

endfunction

let s:token = s:SimpleNoteAuth(g:user, g:password)

" set the simplenote command
command! -nargs=? -range=% SimpleNote :call <SID>SimpleNote(<line1>, <line2>, <f-args>)
" vim:set et:
