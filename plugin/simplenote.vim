"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Version: 0.1.0
" Usage:
"   :SimpleNote -l
"   :SimpleNote -u
"   :SimpleNote -d
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

" the id of the note currently edited is stored in a global variable
let g:simplenote_current_note_id = ""

" Everything is displayed in a scratch buffer named SimpleNote
let g:simplenote_scratch_buffer = 'SimpleNote'

" Function that opens or navigates to the scratch buffer.
function! s:ScratchBufferOpen(name)

    let scr_bufnum = bufnr(a:name)
    if scr_bufnum == -1
        exe "new " . a:name
    else
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum != -1
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            exe "split +buffer" . scr_bufnum
        endif
    endif
    call ScratchBuffer()
endfunction

" After opening the scratch buffer, this sets some properties for it.
function! ScratchBuffer()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal buflisted
    setlocal cursorline
    setlocal filetype=txt
endfunction


"
" python functions
"

python << ENDPYTHON
import vim
import urllib2
import base64
import json

AUTH_URL = 'https://simple-note.appspot.com/api/login'
DATA_URL = 'https://simple-note.appspot.com/api2/data/'
INDX_URL = 'https://simple-note.appspot.com/api2/index?'
DEFAULT_SCRATCH_NAME = vim.eval("g:simplenote_scratch_buffer")

def scratch_buffer(sb_name = DEFAULT_SCRATCH_NAME):
    """ Opens a scratch buffer from python """
    vim.command("call s:ScratchBufferOpen('%s')" % sb_name)

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
# @return the desired note

def get_note(user, token, noteid):
    # request note
    params = '%s?auth=%s&email=%s' % (str(noteid), token, user)
    request = urllib2.Request(DATA_URL+params)
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return None
    note = json.loads(response.read())
    return note

#
# @brief function to update a specific note object
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param note -> note object to update
#
# @return True on success, False with error message  otherwise
#
def update_note_object(user, token, note):
    url = '%s%s?auth=%s&email=%s' % (DATA_URL, note["key"], token, user)
    request = urllib2.Request(url, json.dumps(note))
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return False, e
    return True, "Ok."

#
# @brief function to update a note's content
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param content -> new content
# @param key -> key of the note to update
#
# @return True on success, False with error message  otherwise
#
def update_note_content(user, token, content, key=None):
    """update only the content of a note"""
    if key is not None:
        note = {"key": key}
    else:
        note = {"key": ""}
    note["content"] = content
    return update_note_object(SN_USER, SN_TOKEN, note)

#
# @brief function to get the note list
#
# @param user -> simplenote username
# @param token -> simplenote API token
#
# @return list of note titles and success status
#
def get_note_list(user, token):
    params = 'auth=%s&email=%s' % (token, user)
    request = urllib2.Request(INDX_URL+params)
    status = 0
    try:
      response = json.loads(urllib2.urlopen(request).read())
    except IOError, e:
      status = -1
      response = { "data" : [] }
    ret = []
    # parse data fields in response
    for d in response["data"]:
        ret.append(d["key"])

    return ret, status

#
# @brief function to move a note to the trash
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param note_id -> id of the note to trash
#
# @return list of note titles and success status
#
def trash_note(user, token, note_id):
    # get note
    note = get_note(SN_USER, SN_TOKEN, note_id)
    # set deleted property
    note["deleted"] = 1
    # update note
    return update_note_object(SN_USER, SN_TOKEN, note)

# retrieve a token to interact with the API
SN_USER = vim.eval("s:user")
SN_TOKEN = simple_note_auth(SN_USER, vim.eval("s:password"))

ENDPYTHON

"
" interface functions
"


" function to get a note and display in current buffer
function! s:GetNoteToCurrentBuffer()
python << EOF
# get the notes id which is shown in brackets in the current line
line = vim.current.line.split("[")[-1].split("]")[0]
# store it as a global script variable
vim.command(""" let g:simplenote_current_note_id="%s" """ % line)
note = get_note(SN_USER, SN_TOKEN, line)
buffer = vim.current.buffer
# remove cursorline
vim.command("setlocal nocursorline")
buffer[:] = map(lambda x: str(x), note["content"].split("\n"))
EOF
endfunction

" function to update the note from the current buffer
function! s:UpdateNoteFromCurrentBuffer()
python << EOF
note_id = vim.eval("g:simplenote_current_note_id")
content = "\n".join(str(line) for line in vim.current.buffer[:])
result, err_msg = update_note_content(SN_USER, SN_TOKEN, content, note_id)
if result == True:
    print "Update successful."
else:
    print "Update failed.: %s" % err_msg
EOF
endfunction

" function to trash the note in the current buffer
function! s:TrashCurrentNote()
python << EOF
note_id = vim.eval("g:simplenote_current_note_id")
result, err_msg = trash_note(SN_USER, SN_TOKEN, note_id)
if result == True:
    print "Note moved to trash."
else:
    print "Moving note to trash failed.: %s" % err_msg
EOF
endfunction

function! s:SimpleNote(param)
python << EOF
param = vim.eval("a:param")
if param == "-l":
    # Initialize the scratch buffer
    scratch_buffer()
    buffer = vim.current.buffer
    notes, status = get_note_list(SN_USER, SN_TOKEN)
    if status == 0:
        note_titles = []
        for n in notes:
            # get note from server
            note = get_note(SN_USER, SN_TOKEN, n)
            # fetch first line and display as title
            note_lines = note["content"].split("\n")
            if len(note_lines) > 0:
                title = "%s  [%s]" % (note_lines[0],n)
            else:
                title = "%s  [%s]" % (n,n)

            note_titles.append(str(title))

        buffer[:] = note_titles

    else:
        print "Error: Unable to connect to server."

    # map <CR> to call get_note()
    vim.command("map <buffer> <CR> <Esc>:call <SID>GetNoteToCurrentBuffer()<CR>")

elif param == "-d":
    vim.command("call <SID>TrashCurrentNote()")

elif param == "-u":
    vim.command("call <SID>UpdateNoteFromCurrentBuffer()")
else:
    print "Unknown argument"

EOF
endfunction


" set the simplenote command
command! -nargs=1 SimpleNote :call <SID>SimpleNote(<f-args>)
