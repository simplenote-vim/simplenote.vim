"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
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

" line height
if exists("g:SimplenoteListHeight")
  let s:lineheight = g:SimplenoteListHeight
else
  let s:lineheight = 0
endif

" line height
if exists("g:SimplenoteSortOrder")
  let s:sortorder = g:SimplenoteSortOrder
else
  let s:sortorder = "pinned, modifydate"
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
        if a:name == g:simplenote_scratch_buffer && NoModifiedBuffers()
            exe 'only'
        endif
    else
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum != -1
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            exe  exe_split . "+buffer" . scr_bufnum
            if a:name == g:simplenote_scratch_buffer && NoModifiedBuffers()
                exe 'only'
            endif
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
    if exists("g:SimplenoteFiletype")
      exe "setlocal filetype=" . g:SimplenoteFiletype
    else
      setlocal filetype=txt
    endif

    if (s:vbuff == 0) && (s:lineheight > 0)
        exe "resize " . s:lineheight
    endif
endfunction

function! NoModifiedBuffers()
    let tablist = []
    let noModifiedBuffers = 1
    call extend(tablist, tabpagebuflist(tabpagenr()))
    "if any open modified buffers in tab, not ok to set 'only' for index list
    for n in tablist
        if getbufvar(n,"&mod")
            let noModifiedBuffers = 0
        endif
    endfor
    return noModifiedBuffers
endfunction

"
" python functions
"

python << ENDPYTHON

import os
import vim
sys.path.append(vim.eval("expand('<sfile>:p:h')") + "/simplenote.py/simplenote/")
from simplenote import Simplenote
import datetime
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

        # get note tags
        tags = "[%s]" % ",".join(note["tags"])

        # format date
        mt = time.localtime(float(note["modifydate"]))
        mod_time = time.strftime("[%a, %d %b %Y %H:%M:%S]", mt)

        if len(note_lines) > 0:
            title = str(note_lines[0])
        else:
            title = str(note["key"])


        # Compress everything into the appropriate number of columns
        title_meta_length = len(tags) + len(mod_time) + 1
        title_width = width - title_meta_length
        if len(title) > title_width:
            title = title[:title_width]
        elif len(title) < title_width:
            title = title.ljust(title_width)

        return "%s %s %s" % (title, tags, mod_time)


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

    def display_note_in_scratch_buffer(self, note_id=None):
        """ displays the note corresponding to the given key in the scratch
        buffer
        """
        # get the notes id which is shown in brackets in the current line if we
        # didn't got passed a key
        if note_id is None:
            line, col = vim.current.window.cursor
            note_id = self.note_index[int(line) - 1]

        # get note and open it in scratch buffer
        note, status = self.simplenote.get_note(note_id)
        if not vim.eval("exists('g:vader_file')"):
            vim.command("""call s:ScratchBufferOpen("%s")""" % note_id)
        self.set_current_note(note_id)
        buffer = vim.current.buffer
        # remove cursorline
        vim.command("setlocal nocursorline")
        vim.command("setlocal modifiable")
        vim.command("setlocal buftype=acwrite")
        vim.command("au! BufWriteCmd <buffer> call s:UpdateNoteFromCurrentBuffer()")
        buffer[:] = map(lambda x: str(x), note["content"].split("\n"))
        if note.has_key("systemtags"):
            if ("markdown" in note["systemtags"]):
                vim.command("setlocal filetype=markdown")
        vim.command("setlocal nomodified")

    def update_note_from_current_buffer(self):
        """ updates the currently displayed note to the web service or creates new"""
        note_id = self.get_current_note()
        content = "\n".join(str(line) for line in vim.current.buffer[:])
        # Need to get note details first to assess remote markdown status
        note, status = self.simplenote.get_note(note_id)
        if status == 0:
            if (vim.eval("&filetype") == "markdown"):
                if note.has_key("systemtags"):
                    if ("markdown" not in note["systemtags"]):
                        note["systemtags"].append("markdown")
                else:
                    note["systemtags"] = ["markdown"]
            else:
                if note.has_key("systemtags"):
                    if ("markdown" in note["systemtags"]):
                        note["systemtags"].remove("markdown")
            note, status = self.simplenote.update_note({"content": content,
                                                      "key": note_id,
                                                      "systemtags": note["systemtags"]})
            if status == 0:
                print "Update successful."
                vim.command("setlocal nomodified")
            else:
                print "Update failed.: %s" % note
        elif note.code == 404:
            # API returns 404 if note doesn't exist, so create new
            self.create_new_note_from_current_buffer()
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
            """ when running tests don't want to close buffer """
            if not vim.eval("exists('g:vader_file')"):
                vim.command("quit!")
        else:
            print "Moving note to trash failed.: %s" % note

    def delete_current_note(self):
        """ trash the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.delete_note(note_id)
        if status == 0:
            print "Note deleted."
            """ when running tests don't want to close buffer """
            if not vim.eval("exists('g:vader_file')"):
                vim.command("quit!")
        else:
            print "Deleting note failed.: %s" % note

    def create_new_note_from_current_buffer(self):
        """ get content of the current buffer and create new note """
        content = "\n".join(str(line) for line in vim.current.buffer[:])
        markdown = (vim.eval("&filetype") == "markdown")
        if markdown:
            note, status = self.simplenote.update_note({"content": content,
                                                        "systemtags": ["markdown"]})
        else:
            note, status = self.simplenote.update_note({"content": content})
        if status == 0:
            self.transform_to_scratchbuffer()
            if markdown:
                vim.command("setlocal filetype=markdown")
            self.set_current_note(note["key"])
            print "New note created."
        else:
            print "Update failed.: %s" % note["key"]

    def list_note_index_in_scratch_buffer(self, since=None, tags=[]):
        """ get all available notes and display them in a scratchbuffer """
        # Initialize the scratch buffer
        if not vim.eval("exists('g:vader_file')"):
            self.scratch_buffer()
        vim.command("setlocal modifiable")
        # clear global note id storage
        buffer = vim.current.buffer
        note_list, status = self.simplenote.get_note_list(since)
        if (len(tags) > 0):
            note_list = [n for n in note_list if (n["deleted"] != 1 and
                            len(set(n["tags"]).intersection(tags)) > 0)]
        else:
            note_list = [n for n in note_list if n["deleted"] != 1]

        # set global notes index object to notes
        if status == 0:
            note_titles = []
            notes = self.get_notes_from_keys([n['key'] for n in note_list])
            notes.sort(cmp=compare_notes)
            note_titles = [self.format_title(n) for n in notes]
            self.note_index = [n["key"] for n in notes]
            buffer[:] = note_titles

        else:
            print "Error: Unable to connect to server."

        # map <CR> to call get_note()
        vim.command("setl nomodifiable")
        vim.command("setlocal nowrap")
        vim.command("nnoremap <buffer><silent> <CR> <Esc>:call <SID>GetNoteToCurrentBuffer()<CR>")



def compare_notes(note1, note2):
    """ determine the sort order for two passed in notes

        Parameters:
          note1 - first note object
          note2 - second note object

        Returns -1 if the first note is considered smaller, 0 for equal
        notes and 1 if the first note is considered larger
    """
    # setup compare functions
    def compare_pinned(note1, note2):
        if ("pinned" in note1["systemtags"] and
            "pinned" not in note2["systemtags"]):
            return -1
        elif ("pinned" in note2["systemtags"] and
            "pinned" not in note1["systemtags"]):
            return 1
        else:
            return 0


    def compare_modified(note1, note2):
        if float(note1["modifydate"]) < float(note2["modifydate"]):
            return 1
        elif float(note1["modifydate"]) > float(note2["modifydate"]):
            return -1
        else:
            return 0

    def compare_created(note1, note2):
        if float(note1["createdate"]) < float(note2["createdate"]):
            return 1
        elif float(note1["createdate"]) > float(note2["createdate"]):
            return -1
        else:
            return 0

    def compare_tags(note1, note2):
        if note1["tags"] < note2["tags"]:
            return 1
        if note1["tags"] > note2["tags"]:
            return -1
        else:
            return 0

    # dict for dynamically calling compare functions
    sortfuncs = { "pinned": compare_pinned,
                  "createdate": compare_created,
                  "modifydate": compare_modified,
                  "tags": compare_tags
                }

    sortorder = vim.eval("s:sortorder").split(",")

    for key in sortorder:
        res = sortfuncs.get(key.strip(),lambda x,y: 0)(note1, note2)
        if res != 0:
            return res

    # return equal if no comparison hit
    return 0




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
            # check for valid date string
            datetime.datetime.strptime(vim.eval("a:1"), "%Y-%m-%d")
            interface.list_note_index_in_scratch_buffer(since=vim.eval("a:1"))
        except ValueError:
            interface.list_note_index_in_scratch_buffer(tags=vim.eval("a:1").split(","))
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

elif param == "-o":
    if optionsexist:
        interface.display_note_in_scratch_buffer(vim.eval("a:1"))
    else:
        print "No notekey given."

else:
    print "Unknown argument"

EOF
endfunction

