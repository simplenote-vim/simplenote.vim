"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
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

" user auth settings
let s:rcfile = '`echo $HOME`/.vim/simplenoterc'
let s:user = ""
let s:password = ""

let s:user = system('head -n1 '.s:rcfile.' 2>/dev/null | tr -d "\n"')
let s:password = system('tail -n1 '.s:rcfile.' 2>/dev/null | tr -d "\n"')

if (s:user == "") || (s:password == "")
  echoerr "No valid username or password."
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
  let curl_params = '-s -X POST -d "'.auth_b64.'"'
  let token = system('curl '.curl_params.' "'.url.'"')
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
  let note = system('curl -s "'.url.params.'"')
  return note
endfunction

" function to update a specific note
function! s:UpdateNote(user, token, noteid, content)
  let url = 'https://simple-note.appspot.com/api/note?'
  let params = 'key='.a:noteid.'&auth='.a:token.'&email='.a:user
  let enc_content = s:Base64Encode(content)
  let curl_params = '-X POST -d "'.enc_content.'"'
  system('curl -s '.curl_params.' "'.url.params.'"')
endfunction

" function to get the note list
function! s:GetNoteList(user, token)
  let url = 'https://simple-note.appspot.com/api/index?'
  let params = 'auth='.a:token.'&email='.a:user
  let res = system('curl -s "'.url.''.params.'"')
  return res
endfunction

"
" User interface
"

function! s:SimpleNote(line1, line2, ...)
  let listnotes = 0
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
    let winnum = bufwinnr(bufnr('notes:'.s:user))
    if winnum != -1
      if winnum != bufwinnr('%')
        exe "normal \<c-w>".winnum."w"
      endif
      setlocal modifiable
    else
      exec 'silent split notes:'.s:user
    endif
  endif

endfunction

let s:token = s:SimpleNoteAuth(s:user, s:password)

" set the simplenote command
command! -nargs=? -range=% SimpleNote :call <SID>SimpleNote(<line1>, <line2>, <f-args>)
" vim:set et:
