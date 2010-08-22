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
" API functions
"

" function to get simplenote auth token
function! s:SimpleNoteAuth(user, password)
  let url = 'https://simple-note.appspot.com/api/login'
  let auth_params = 'email='.a:user.'&password='.a:password
  let auth_b64 = call s:Base64Encode(auth_params)
  let curl_params = '-s -X POST -d'.auth_b64
  let token = system('curl '.curl_params)
  if res =~# 'Traceback'
    echoerr "Simplenote: Auth failed."
  else
    return res
  endif
endfunction

" function to get a specific note
function! s:GetNote(user, token, noteid)
  let url = 'https://simple-note.appspot.com/api/note?'
  let params = 'key='.a:noteid.'&auth='.a:token.'&email='.a:user
  let note = system('curl -s '.url.params)
  return note
endfunction


"
" Helper functions
"

" function to wrap openssl base64 encoding
function! s:Base64Encode(string)
  return system('echo -n "'.a:string.'| openssl base64')
endfunction
