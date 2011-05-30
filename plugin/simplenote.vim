"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Version: 0.2.0
" Usage:
"   :Simplenote -l
"   :Simplenote -u
"   :Simplenote -d
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
if exists("g:SimplenoteUsername")
  let s:user = g:SimplenoteUsername
else
  let s:user = ""
endif

if exists("g:SimplenotePassword")
  let s:password = g:SimplenotePassword
else
  let s:password = ""
endif

if (s:user == "") || (s:password == "")
  let errmsg = "Simplenote credentials missing. Set g:SimplenoteUsername and "
  let errmsg = errmsg . "g:SimplenotePassword. If you don't have an account you can "
  let errmsg = errmsg . "create one at https://simple-note.appspot.com/create/."
  echoerr errmsg
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
import time
from threading import Thread
from Queue import Queue

AUTH_URL = 'https://simple-note.appspot.com/api/login'
DATA_URL = 'https://simple-note.appspot.com/api2/data/'
INDX_URL = 'https://simple-note.appspot.com/api2/index?'
DEFAULT_SCRATCH_NAME = vim.eval("g:simplenote_scratch_buffer")
NOTE_INDEX = []
SN_USER = urllib2.quote(vim.eval("s:user"))
SN_TOKEN = None
NOTE_FETCH_LENGTH = 20

def scratch_buffer(sb_name = DEFAULT_SCRATCH_NAME):
    """ Opens a scratch buffer from python """
    vim.command("call s:ScratchBufferOpen('%s')" % sb_name)

def simple_note_auth(user, password):
    """ function to get simplenote auth token

    Arguments
    user     -- simplenote email address
    password -- simplenote password

    Returns Simplenote API token

    """
    auth_params = "email=%s&password=%s" % (user, password)
    values = base64.encodestring(auth_params)
    request = urllib2.Request(AUTH_URL, values)
    try:
        res = urllib2.urlopen(request).read()
        token = urllib2.quote(res)
    except IOError, e: # no connection exception
        token = None
    return token

def get_token():
    """ function to retrieve an auth token """
    global SN_TOKEN
    if SN_TOKEN == None:
        SN_TOKEN = simple_note_auth(SN_USER, urllib2.quote(vim.eval("s:password")))
    return SN_TOKEN


def get_note(user, token, noteid):
    """ function to get a specific note

    Arguments
    user   -- simplenote username
    token  -- simplenote API token
    noteid -- ID of the note to get

    Returns the desired note

    """
    # request note
    params = '%s?auth=%s&email=%s' % (str(noteid), token, user)
    request = urllib2.Request(DATA_URL+params)
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return None
    note = json.loads(response.read())
    return note

def update_note_object(user, token, note):
    """ function to update a specific note object

    Arguments
    user  -- simplenote username
    token -- simplenote API token
    note  -- note object to update

    Returns True on success, False with error message  otherwise

    """
    url = '%s%s?auth=%s&email=%s' % (DATA_URL, note["key"], token, user)
    request = urllib2.Request(url, json.dumps(note))
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return False, e
    return True, "Ok."

def update_note_content(user, token, content, key=None):
    """ function to update a note's content

    Arguments
    user    -- simplenote username
    token   -- simplenote API token
    content -- new content
    key     -- key of the note to update

    Return True on success, False with error message  otherwise

    """
    if key is not None:
        note = {"key": key}
    else:
        note = {"key": ""}
    note["content"] = content
    return update_note_object(SN_USER, get_token(), note)

def get_note_list(user, token):
    """ function to get the note list

    Arguments
    user -> simplenote username
    token -> simplenote API token

    Return list of note titles and success status

    """
    # initialize data
    status = 0
    ret = []
    response = {}
    notes = { "data" : [] }

    # get the full note index
    params = 'auth=%s&email=%s&length=%s' % (token, user, NOTE_FETCH_LENGTH)
    # perform initial HTTP request
    try:
      request = urllib2.Request(INDX_URL+params)
      response = json.loads(urllib2.urlopen(request).read())
      notes["data"].extend(response["data"])
    except IOError, e:
      status = -1

    # get additional notes if bookmark was set in response
    while response.has_key("mark"):
        params = 'auth=%s&email=%s&mark=%s&length=%s' % (token, user,
                                                         response["mark"],
                                                         NOTE_FETCH_LENGTH)

        # perform the actual HTTP request
        try:
          request = urllib2.Request(INDX_URL+params)
          response = json.loads(urllib2.urlopen(request).read())
          notes["data"].extend(response["data"])
        except IOError, e:
          status = -1

    # parse data fields in response
    for n in notes["data"]:
        ret.append(n["key"])

    return ret, status

def trash_note(user, token, note_id):
    """ function to move a note to the trash

    Arguments
    user    -- simplenote username
    token   -- simplenote API token
    note_id -- id of the note to trash

    Return list of note titles and success status

    """
    # get note
    auth_token = get_token()
    note = get_note(SN_USER, auth_token, note_id)
    # set deleted property
    note["deleted"] = 1
    # update note
    return update_note_object(SN_USER, auth_token, note)


def format_title(note):
    """ function to format the title for a note object

        Arguments:
        note -- note object to format the title for

        Returns the formatted title

    """
    # fetch first line and display as title
    note_lines = note["content"].split("\n")
    # format date
    mt = time.localtime(float(note["modifydate"]))
    mod_time = time.strftime("%a, %d %b %Y %H:%M:%S", mt)
    if len(note_lines) > 0:
        title = "%s [%s]" % (note_lines[0], mod_time)
    else:
        title = "%s [%s]" % (note["key"], mod_time)

    return (str(title)[0:80])

class NoteFetcher(Thread):
    """ class to fetch a note running in a thread

        The note key is fetched from a queue object and
        the note is then retrieved and put in

    """
    def __init__(self, queue, note_list):
        Thread.__init__(self)
        self.queue = queue
        self.note_list = note_list

    def run(self):
        key = self.queue.get()
        note = get_note(SN_USER, get_token(), key)
        self.note_list.append(note)
        self.queue.task_done()

def get_notes_from_keys(key_list):
    """ fetch all note objects for a list of keys via threads and return them
        in a list

    """
    queue = Queue()
    note_list = []
    for key in key_list:
        queue.put(key)
        t = NoteFetcher(queue, note_list)
        t.start()

    queue.join()
    return note_list




ENDPYTHON

"
" interface functions
"


" function to get a note and display in current buffer
function! s:GetNoteToCurrentBuffer()
python << EOF
# unmap <CR>
vim.command("unmap <buffer> <CR>")
# get the notes id which is shown in brackets in the current line
line, col = vim.current.window.cursor
note_id = NOTE_INDEX[int(line) - 1]
# store it as a global script variable
vim.command(""" let g:simplenote_current_note_id="%s" """ % note_id)
note = get_note(SN_USER, get_token(), note_id)
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
result, err_msg = update_note_content(SN_USER, get_token(), content, note_id)
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
result, err_msg = trash_note(SN_USER, get_token(), note_id)
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
    # clear global note id storage
    vim.command(""" let g:simplenote_current_note_id="" """)
    buffer = vim.current.buffer
    auth_token = get_token()
    note_list, status = get_note_list(SN_USER, auth_token)
    # set global notes index object to notes
    global NOTE_INDEX
    NOTE_INDEX = []
    if status == 0:
        note_titles = []
        notes = get_notes_from_keys(note_list)
        notes.sort(key=lambda k: k['modifydate'])
        notes.reverse()
        note_titles = [format_title(n) for n in notes if n["deleted"] != 1]
        NOTE_INDEX = [n["key"] for n in notes if n["deleted"] != 1]
        buffer[:] = note_titles

    else:
        print "Error: Unable to connect to server."

    # map <CR> to call get_note()
    vim.command("map <buffer> <CR> <Esc>:call <SID>GetNoteToCurrentBuffer()<CR>")

elif param == "-d":
    vim.command("call <SID>TrashCurrentNote()")
    vim.command("call <SID>SimpleNote(\"-l\")")

elif param == "-u":
    vim.command("call <SID>UpdateNoteFromCurrentBuffer()")
else:
    print "Unknown argument"

EOF
endfunction


" set the simplenote command
command! -nargs=1 Simplenote :call <SID>SimpleNote(<f-args>)
