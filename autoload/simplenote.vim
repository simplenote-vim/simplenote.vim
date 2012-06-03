"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Usage:
"   :Simplenote -l => list all notes
"   :Simplenote -u => update a note from buffer
"   :Simplenote -d => move note to trash
"   :Simplenote -n => create new note from buffer
"   :Simplenote -D => delete note in current buffer
"   :Simplenote -t => tag note in current buffer
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

" vertical buffer
if exists("g:SimplenoteVertical")
  let s:vbuff = g:SimplenoteVertical
else
  let s:vbuff = 0
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

" Everything is displayed in a scratch buffer named SimpleNote
let g:simplenote_scratch_buffer = 'Simplenote'

" Function that opens or navigates to the scratch buffer.
function! s:ScratchBufferOpen(name)
	let exe_new = "new "
	let exe_split = "split "

	if s:vbuff > 0
		let exe_new = "vert " . exe_new
		let exe_split = "vert " . exe_split
	endif


    let scr_bufnum = bufnr(a:name)
    if scr_bufnum == -1
        exe exe_new . a:name
    else
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum != -1
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            exe  exe_split . "+buffer" . scr_bufnum
        endif
    endif
    call s:ScratchBuffer()
endfunction

" After opening the scratch buffer, this sets some properties for it.
function! s:ScratchBuffer()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
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

import urllib
import urllib2
from urllib2 import HTTPError
import base64
try:
    import json
except ImportError:
    try:
        import simplejson as json
    except ImportError:
        # For Google AppEngine
        from django.utils import simplejson as json

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
        except HTTPError, e:
            return e, -1
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
        request = Request(url, urllib.quote(json.dumps(note)))
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

    def get_note_list(self, qty=float("inf")):
        """ function to get the note list

        The function can be passed an optional argument to limit the
        size of the list returned. If omitted a list of all notes is
        returned.

        Arguments:
            - quantity (integer number): of notes to list

        Returns:
            An array of note objects with all properties set except
            `content`.

        """
        # initialize data
        status = 0
        ret = []
        response = {}
        notes = { "data" : [] }

        # get the note index
        if qty < NOTE_FETCH_LENGTH:
            params = 'auth=%s&email=%s&length=%s' % (self.get_token(), self.username,
                                                 qty)
        else:
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
        while response.has_key("mark") and len(notes["data"]) < qty:
            if (qty - len(notes["data"])) < NOTE_FETCH_LENGTH:
                vals = (self.get_token(), self.username, response["mark"], qty - len(notes["data"]))
            else:
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
        if (status == -1):
            return note, status
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
        note, status = self.trash_note(note_id)
        if (status == -1):
            return note, status

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



import vim
import time
import math as m
from threading import Thread
from Queue import Queue

DEFAULT_SCRATCH_NAME = vim.eval("g:simplenote_scratch_buffer")
SN_USER = vim.eval("s:user")
SN_PASSWORD = vim.eval("s:password")

class SimplenoteVimInterface(object):
    """ Interface class to provide functions for interacting with VIM """

    def __init__(self, username, password):
        self.simplenote = Simplenote(username, password)
        self.note_index = []

    def get_current_note(self):
        """ returns the key of the currently edited note """
        key = vim.eval("expand('%:t')")
        return key

    def set_current_note(self, key):
        """ sets the key of the currently edited note """
        vim.command(""" silent exe "file %s" """ % key)

    def transform_to_scratchbuffer(self):
        """ transforms the current buffer into a scratchbuffer """
        vim.command("call s:ScratchBuffer()")
        vim.command("setlocal nocursorline")
        vim.command("setlocal buftype=acwrite")
        vim.command("setlocal bufhidden=delete")
        vim.command("setlocal nomodified")
        vim.command("au! BufWriteCmd <buffer> call s:UpdateNoteFromCurrentBuffer()")

    def format_title(self, note):
        """ function to format the title for a note object

        Arguments:
        note -- note object to format the title for

        Returns the formatted title

        """
        # fetch first line and display as title
        note_lines = note["content"].split("\n")

        # get window width for proper formatting
        width = vim.current.window.width

        # Make room for the numbers regardless of their presence
        # min num width is 5
        width -= max(m.floor(m.log(len(vim.current.buffer))) + 2, 5)
        width = int(width)


        # format date
        mt = time.localtime(float(note["modifydate"]))
        mod_time = time.strftime("[%a, %d %b %Y %H:%M:%S]", mt)

        if len(note_lines) > 0:
            title = str(note_lines[0])
        else:
            title = str(note["key"])

        # Compress everything into the appropriate number of columns
        title_width = width - len(mod_time) - 1
        if len(title) > title_width:
            title = title[:title_width]
        elif len(title) < title_width:
            title = title.ljust(title_width)

        return "%s %s" % (title, mod_time)


    def get_notes_from_keys(self, key_list):
        """ fetch all note objects for a list of keys via threads and return
        them in a list

        Arguments:
        key_list - list of keys to fetch the key from

        Returns list of fetched notes
        """
        queue = Queue()
        note_list = []
        for key in key_list:
            queue.put(key)
            t = NoteFetcher(queue, note_list, self.simplenote)
            t.start()

        queue.join()
        return note_list

    def scratch_buffer(self, sb_name = DEFAULT_SCRATCH_NAME):
        """ Opens a scratch buffer from python

        Arguments:
        sb_name - name of the scratch buffer
        """
        vim.command("call s:ScratchBufferOpen('%s')" % sb_name)

    def display_note_in_scratch_buffer(self):
        """ displays the note corresponding to the given key in the scratch
        buffer
        """
        # get the notes id which is shown in brackets in the current line
        line, col = vim.current.window.cursor
        note_id = self.note_index[int(line) - 1]
        # store it as a global script variable
        note, status = self.simplenote.get_note(note_id)
        vim.command("""call s:ScratchBufferOpen("%s")""" % note_id)
        self.set_current_note(note_id)
        buffer = vim.current.buffer
        # remove cursorline
        vim.command("setlocal nocursorline")
        vim.command("setlocal modifiable")
        vim.command("setlocal buftype=acwrite")
        vim.command("setlocal bufhidden=delete")
        vim.command("au! BufWriteCmd <buffer> call s:UpdateNoteFromCurrentBuffer()")
        buffer[:] = map(lambda x: str(x), note["content"].split("\n"))
        vim.command("setlocal nomodified")

    def update_note_from_current_buffer(self):
        """ updates the currently displayed note to the web service """
        note_id = self.get_current_note()
        content = "\n".join(str(line) for line in vim.current.buffer[:])
        note, status = self.simplenote.update_note({"content": content,
                                                  "key": note_id})
        if status == 0:
            print "Update successful."
            vim.command("setlocal nomodified")
        else:
            print "Update failed.: %s" % note

    def set_tags_for_current_note(self):
        """ set tags for the current note"""
        note_id = self.get_current_note()
        note, status = self.simplenote.get_note(note_id)
        if status == 0:
            tags = vim.eval('input("Enter tags: ", "%s")'
                            % ",".join(note["tags"]))
            note["tags"] = tags.split(",")
            n, st = self.simplenote.update_note(note)
            if st == 0:
                print "Tags updated."
            else:
                print "Tags could not be updated."
        else:
            print "Error fetching note data."


    def trash_current_note(self):
        """ trash the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.trash_note(note_id)
        if status == 0:
            print "Note moved to trash."
            vim.command("quit!")
        else:
            print "Moving note to trash failed.: %s" % note

    def delete_current_note(self):
        """ trash the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.delete_note(note_id)
        if status == 0:
            print "Note deleted."
            vim.command("quit!")
        else:
            print "Deleting note failed.: %s" % note

    def create_new_note_from_current_buffer(self):
        """ get content of the current buffer and create new note """
        content = "\n".join(str(line) for line in vim.current.buffer[:])
        note, status = self.simplenote.update_note({"content": content})
        if status == 0:
            self.transform_to_scratchbuffer()
            self.set_current_note(note["key"])
            print "New note created."
        else:
            print "Update failed.: %s" % note["key"]

    def list_note_index_in_scratch_buffer(self, qty=float("inf")):
        """ get all available notes and display them in a scratchbuffer """
        # Initialize the scratch buffer
        self.scratch_buffer()
        vim.command("setlocal modifiable")
        # clear global note id storage
        buffer = vim.current.buffer
        note_list, status = self.simplenote.get_note_list(qty)
        # set global notes index object to notes
        if status == 0:
            note_titles = []
            notes = self.get_notes_from_keys([n['key'] for n in note_list])
            notes.sort(key=lambda k: k['modifydate'])
            notes.reverse()
            note_titles = [self.format_title(n) for n in notes if n["deleted"] != 1]
            self.note_index = [n["key"] for n in notes if n["deleted"] != 1]
            buffer[:] = note_titles

        else:
            print "Error: Unable to connect to server."

        # map <CR> to call get_note()
        vim.command("setl nomodifiable")
        vim.command("setlocal nowrap")
        vim.command("nnoremap <buffer><silent> <CR> <Esc>:call <SID>GetNoteToCurrentBuffer()<CR>")


class NoteFetcher(Thread):
    """ class to fetch a note running in a thread

    The note key is fetched from a queue object and
    the note is then retrieved and put in

    """
    def __init__(self, queue, note_list, simplenote):
        Thread.__init__(self)
        self.queue = queue
        self.note_list = note_list
        self.simplenote = simplenote

    def run(self):
        key = self.queue.get()
        note, status = self.simplenote.get_note(key)
        if status != -1:
          self.note_list.append(note)

        self.queue.task_done()

interface = SimplenoteVimInterface(SN_USER, SN_PASSWORD)


ENDPYTHON

"
" interface functions
"


" function to get a note and display in current buffer
function! s:GetNoteToCurrentBuffer()
python << EOF
interface.display_note_in_scratch_buffer()
EOF
endfunction

" function to update note from buffer content
function! s:UpdateNoteFromCurrentBuffer()
python << EOF
interface.update_note_from_current_buffer()
EOF
endfunction

function! simplenote#SimpleNote(param, ...)
python << EOF
param = vim.eval("a:param")
optionsexist = True if (float(vim.eval("a:0"))>=1) else False
if param == "-l":
    if optionsexist:
        try:
            interface.list_note_index_in_scratch_buffer(int(float(vim.eval("a:1"))))
        except:
            interface.list_note_index_in_scratch_buffer()
    else:
        interface.list_note_index_in_scratch_buffer()

elif param == "-d":
    interface.trash_current_note()

elif param == "-u":
    interface.update_note_from_current_buffer()

elif param == "-n":
    interface.create_new_note_from_current_buffer()

elif param == "-D":
    interface.delete_current_note()

elif param == "-t":
    interface.set_tags_for_current_note()

else:
    print "Unknown argument"

EOF
endfunction

