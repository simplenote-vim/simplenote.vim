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

" check for python
if !has("python")
  echoerr "Simplenote: Plugin needs vim to be compiled with python support."
  finish
endif

" user auth settings
let s:user = ""
let s:password = ""

let s:user = g:SimpleNoteUserName
let s:password = g:SimpleNotePassword

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

python << ENDPYTHON
import vim
import urllib2
import base64
import json

AUTH_URL = 'https://simple-note.appspot.com/api/login'
DATA_URL = 'https://simple-note.appspot.com/api2/data/'
INDX_URL = 'https://simple-note.appspot.com/api2/index?'

#
# @brief function to get simplenote auth token
#
# @param user -> simplenote email address
# @param password -> simplenote password
#
# @return simplenote API token
#
def simple_note_auth(user, password):
    auth_params = "email=%s&password=%s" % (user, password)
    values = base64.encodestring(auth_params)
    request = urllib2.Request(AUTH_URL, values)
    try:
        token = urllib2.urlopen(request).read()
    except IOError, e: # no connection exception
        token = None
    return token

#
# @brief function to get a specific note
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param noteid -> ID of the note to get
#
# @return content of the desired note

def get_note(user, token, noteid):
    # request note
    params = '%s?auth=%s&email=%s' % (noteid, token, user)
    request = urllib2.Request(DATA_URL+params)
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return None
    note = json.loads(response.read())
    return note["content"]

#
# @brief function to update a specific note
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param noteid -> noteid to update
# @param content -> content of the note to update
#
# @return
#
def update_note(user, token, noteid, content):
    params = '%s?auth=%s&email=%s' % (noteid, token, user)
    noteobject = {}
    noteobject["content"] = content
    note = json.dumps(noteobject)
    values = urllib.urlencode(note)
    request = urllib2.Request(DATA_URL+params, values)
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return False
    return True

#
# @brief function to get the note list
#
# @param user -> simplenote username
# @param token -> simplenote API token
#
# @return list of note titles
#
def get_note_list(user, token):
    params = 'auth=%s&email=%s' % (token, user)
    request = urllib2.Request(INDX_URL+params)
    try:
      response = json.loads(urllib2.urlopen(request).read())
    except IOError, e:
      response = { "data" : [] }
    ret = []
    # parse data fields in response
    for d in response["data"]:
        ret.append(d["key"])

    return ret

# retrieve a token to interact with the API
SN_TOKEN = simple_note_auth(vim.eval("s:user"), vim.eval("s:password"))

ENDPYTHON

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
    else
      exec 'silent split notes:'.s:user
    endif
    silent %d _
    exec 'silent r! '.s:GetNoteList(s:user, s:token).''
  endif

endfunction


" set the simplenote command
command! -nargs=? -range=% SimpleNote :call <SID>SimpleNote(<line1>, <line2>, <f-args>)
