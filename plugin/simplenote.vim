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
"""
    simplenote.py
    ~~~~~~~~~~~~~~

    Python library for accessing the Simplenote API

    :copyright: (c) 2011 by Daniel Schauenberg
    :license: MIT, see LICENSE for more details.
"""

import urllib2
import base64
import json

AUTH_URL = 'https://simple-note.appspot.com/api/login'
DATA_URL = 'https://simple-note.appspot.com/api2/data'
INDX_URL = 'https://simple-note.appspot.com/api2/index?'
NOTE_FETCH_LENGTH = 20

class Simplenote(object):
    """ Class for interacting with the simplenote web service """

    def __init__(self, username, password):
        """ object constructor """
        self.username = urllib2.quote(username)
        self.password = urllib2.quote(password)
        self.token = None

    def authenticate(self, user, password):
        """ Method to get simplenote auth token

        Arguments:
            - user (string):     simplenote email address
            - password (string): simplenote password

        Returns:
            Simplenote API token as string

        """
        auth_params = "email=%s&password=%s" % (user, password)
        values = base64.encodestring(auth_params)
        request = Request(AUTH_URL, values)
        try:
            res = urllib2.urlopen(request).read()
            token = urllib2.quote(res)
        except IOError: # no connection exception
            token = None
        return token

    def get_token(self):
        """ Method to retrieve an auth token.

        The cached global token is looked up and returned if it exists. If it
        is `None` a new one is requested and returned.

        Returns:
            Simplenote API token as string

        """
        if self.token == None:
            self.token = self.authenticate(self.username, self.password)
        return self.token


    def get_note(self, noteid):
        """ method to get a specific note

        Arguments:
            - noteid (string): ID of the note to get

        Returns:
            A tuple `(note, status)`

            - note (dict): note object
            - status (int): 0 on sucesss and -1 otherwise

        """
        # request note
        params = '/%s?auth=%s&email=%s' % (str(noteid), self.get_token(),
                                           self.username)
        request = Request(DATA_URL+params)
        try:
            response = urllib2.urlopen(request)
        except IOError, e:
            return e, -1
        note = json.loads(response.read())
        # use UTF-8 encoding
        note["content"] = note["content"].encode('utf-8')
        note["tags"] = [t.encode('utf-8') for t in note["tags"]]
        return note, 0

    def update_note(self, note):
        """ function to update a specific note object, if the note object does not
        have a "key" field, a new note is created

        Arguments
            - note (dict): note object to update

        Returns:
            A tuple `(note, status)`

            - note (dict): note object
            - status (int): 0 on sucesss and -1 otherwise

        """
        # use UTF-8 encoding
        note["content"] = unicode(note["content"], 'utf-8')
        if note.has_key("tags"):
            note["tags"] = [unicode(t, 'utf-8') for t in note["tags"]]

        # determine whether to create a new note or updated an existing one
        if note.has_key("key"):
            url = '%s/%s?auth=%s&email=%s' % (DATA_URL, note["key"],
                                              self.get_token(), self.username)
        else:
            url = '%s?auth=%s&email=%s' % (DATA_URL, self.get_token(), self.username)
        request = Request(url, json.dumps(note))
        response = ""
        try:
            response = urllib2.urlopen(request).read()
        except IOError, e:
            return e, -1
        return json.loads(response), 0

    def add_note(self, note):
        """wrapper function to add a note

        The function can be passed the note as a dict with the `content`
        property set, which is then directly send to the web service for
        creation. Alternatively, only the body as string can also be passed. In
        this case the parameter is used as `content` for the new note.

        Arguments:
            - note (dict or string): the note to add

        Returns:
            A tuple `(note, status)`

            - note (dict): the newly created note
            - status (int): 0 on sucesss and -1 otherwise

        """
        if type(note) == str:
            return self.update_note({"content": note})
        elif (type(note) == dict) and note.has_key("content"):
            return self.update_note(note)
        else:
            return "No string or valid note.", -1

    def get_note_list(self):
        """ function to get the note list

        Returns:
            An array of note objects with all properties set except
            `content`.

        """
        # initialize data
        status = 0
        ret = []
        response = {}
        notes = { "data" : [] }

        # get the full note index
        params = 'auth=%s&email=%s&length=%s' % (self.get_token(), self.username,
                                                 NOTE_FETCH_LENGTH)
        # perform initial HTTP request
        try:
            request = Request(INDX_URL+params)
            response = json.loads(urllib2.urlopen(request).read())
            notes["data"].extend(response["data"])
        except IOError:
            status = -1

        # get additional notes if bookmark was set in response
        while response.has_key("mark"):
            vals = (self.get_token(), self.username, response["mark"], NOTE_FETCH_LENGTH)
            params = 'auth=%s&email=%s&mark=%s&length=%s' % vals

            # perform the actual HTTP request
            try:
                request = Request(INDX_URL+params)
                response = json.loads(urllib2.urlopen(request).read())
                notes["data"].extend(response["data"])
            except IOError:
                status = -1

        # parse data fields in response
        ret = notes["data"]

        return ret, status

    def trash_note(self, note_id):
        """ method to move a note to the trash

        Arguments:
            - note_id (string): key of the note to trash

        Returns:
            A tuple `(note, status)`

            - note (dict): the newly created note or an error message
            - status (int): 0 on sucesss and -1 otherwise

        """
        # get note
        note, status = self.get_note(note_id)
        # set deleted property
        note["deleted"] = 1
        # update note
        return self.update_note(note)

    def delete_note(self, note_id):
        """ method to permanently delete a note

        Arguments:
            - note_id (string): key of the note to trash

        Returns:
            A tuple `(note, status)`

            - note (dict): an empty dict or an error message
            - status (int): 0 on sucesss and -1 otherwise

        """
        # notes have to be trashed before deletion
        self.trash_note(note_id)

        params = '/%s?auth=%s&email=%s' % (str(note_id), self.get_token(),
                                           self.username)
        request = Request(url=DATA_URL+params, method='DELETE')
        try:
            urllib2.urlopen(request)
        except IOError, e:
            return e, -1
        return {}, 0


class Request(urllib2.Request):
    """ monkey patched version of urllib2's Request to support HTTP DELETE
        Taken from http://python-requests.org, thanks @kennethreitz
    """

    def __init__(self, url, data=None, headers={}, origin_req_host=None,
                unverifiable=False, method=None):
        urllib2.Request.__init__(self, url, data, headers, origin_req_host, unverifiable)
        self.method = method

    def get_method(self):
        if self.method:
            return self.method

        return urllib2.Request.get_method(self)



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
elif param == "-n":
    content = "\n".join(str(line) for line in vim.current.buffer[:])
    result, note = update_note_content(SN_USER, get_token(), content)
    if result == True:
        vim.command(""" let g:simplenote_current_note_id="%s" """ % note["key"])
        print "New note created."
    else:
        print "Update failed.: %s" % key
else:
    print "Unknown argument"

EOF
endfunction


" set the simplenote command
command! -nargs=1 Simplenote :call <SID>SimpleNote(<f-args>)
