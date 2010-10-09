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

"
" API functions
"

" function to get simplenote auth token
function! s:SimpleNoteAuth(user, password)
python << ENDPYTHON
import vim, urllib, urllib2, base64
url = 'https://simple-note.appspot.com/api/login'
# params parsing
user = vim.eval("a:user")
password = vim.eval("a:password")
auth_params = "email=%s&password=%s" % (user, password)
auth_b64 = base64.encodestring(auth_params)
values = urllib.urlencode(auth_b64)
request = urllib2.Request(url, values)
try:
  token = urllib2.urlopen(request)
except IOError, e: # no connection exception
  vim.command('echoerr "Simplenote: Auth failed."')
  vim.command("return -1")
vim.command("return %s" % token)
ENDPYTHON
endfunction

" function to get a specific note
function! s:GetNote(user, token, noteid)
python << ENDPYTHON
import vim, urllib2, json
# params
user = vim.eval("a:user")
token = vim.eval("a:token")
noteid = vim.eval("a:noteid")
# request note
url = 'https://simple-note.appspot.com/api2/data/'
params = '%s?auth=%s&email=%s' % (noteid, token, user)
request = urllib2.Request(url+params)
try:
    response = urllib2.urlopen(request)
except IOError, e:
    vim.command('echoerr "Connection failed."')
    response = ""
note = json.loads(response.read())
vim.command("return %s" % note["content"])
ENDPYTHON
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
