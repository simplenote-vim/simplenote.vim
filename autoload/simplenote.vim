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

" note format
if exists("g:SimplenoteNoteFormat")
  let s:noteformat = g:SimplenoteNoteFormat
else
  let s:noteformat = "%N%>[%T] [%D]"
endif

" strftime format
if exists("g:SimplenoteStrftime")
  let s:strftime_fmt = g:SimplenoteStrftime
else
  let s:strftime_fmt = "%a, %d %b %Y %H:%M:%S"
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

"
" Helper functions
"

" Everything is displayed in a scratch buffer named SimpleNote
let g:simplenote_scratch_buffer = 'Simplenote'
" Initialise the window number that notes will be displayed in. This needs to start as 0.
let g:simplenote_note_winnr = 0

" Function that opens or navigates to the scratch buffer.
" TODO: This is a complicated mess and could be improved
function! s:ScratchBufferOpen(name)
    let exe_new = "new "
    let exe_split = "split "

    if s:vbuff > 0
        let exe_new = "vert " . exe_new
        let exe_split = "vert " . exe_split
    endif

    "Find buffer number
    let scr_bufnum = bufnr(a:name)
    "If buffer doesn't exist, create new window or buffer
    if scr_bufnum == -1
        "If no notes open or single window mode isn't set
        if g:simplenote_note_winnr == 0 || !exists("g:SimplenoteSingleWindow")
            "Opens a new window
            exe exe_new . a:name
            "Make the only window if the list index
            if (a:name == g:simplenote_scratch_buffer) && NoModifiedBuffers()
                exe 'only'
            else
                "Find window number created and set global variable to that, but only initially
                let g:simplenote_note_winnr = winnr()
            endif
        else
            "If single window mode open note in the existing window as long as that window is actually there
            if (g:simplenote_note_winnr <= winnr('$')) && exists("g:SimplenoteSingleWindow")
                exe g:simplenote_note_winnr . "wincmd w"
                exe "badd " . a:name
                exe "buffer " . a:name
            else
                "The window must have been closed so open a new window again
                exe exe_new . a:name
                let g:simplenote_note_winnr = winnr()
            endif
        endif
    else
        "Find window for buffer number
        let scr_winnum = bufwinnr(scr_bufnum)
        "If window is open for that buffer
        if scr_winnum != -1
            "Switches to existing window for buffer
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            "If single window mode open note in the existing window as long as that window is actually there
            if (g:simplenote_note_winnr <= winnr('$')) && exists("g:SimplenoteSingleWindow")
                exe g:simplenote_note_winnr . "wincmd w"
                exe "buffer " . scr_bufnum
			else
                "The window must have been closed so open a new window again
				"If buffer exists, but that isn't displayed, bring to front
				exe  exe_split . "+buffer" . scr_bufnum
				"If note index make the only window
				if (a:name == g:simplenote_scratch_buffer) && NoModifiedBuffers()
					exe 'only'
				endif
				"set this again since original must have been closed
				let g:simplenote_note_winnr = winnr()
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
import simplenote
import datetime
import re
import time
import math as m
from threading import Thread
from Queue import Queue

DEFAULT_SCRATCH_NAME = vim.eval("g:simplenote_scratch_buffer")

class SimplenoteVimInterface(object):
    """ Interface class to provide functions for interacting with VIM """

    def __init__(self, username, password):
        self.simplenote = simplenote.Simplenote(username, password)
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

    def format_title_build(self, title, fmt_char, value_str, conceal_str):
        """ function to replace a format tag in the title

        Arguments:
        title       -- title line for the note object
        fmt_char    -- the format tag to replace
        value_str   -- the string to insert in place of the format tag
        conceal_str -- concealment string to insert for syntax highlighting

        Returns a new title line with the format tag replaced
        """
        # build the regex for the given format tag and search for it
        regex = "^(.*)%([-]*)([0-9]*)" + fmt_char + "(.*)$"
        fmt = re.search(regex, title)
        if fmt == None:
            # the tag doesn't exist so no change is make
            return title
        if fmt.group(3):
            # if the format has a specified width then apply that now
            field = "{:"
            if fmt.group(2) == "-": field = field + "<"
            else:                   field = field + ">"
            field = field + fmt.group(3) + "}"
            value_str = field.format(value_str[:int(fmt.group(3))])
        # build a new title with concealment tags for syntax highlighting
        if vim.eval("has('conceal')") == "1":
            return fmt.group(1) +                              \
                   "|" + conceal_str + "|" + value_str + "|" + \
                   fmt.group(4)
        else:
            return fmt.group(1) + value_str + fmt.group(4)

    def format_title_len_no_conceal(self, title):
        """ function to get the visible length of the title by excluding any
        concealed syntax tags

        Arguments:
        title -- title line for the note object

        Returns the visible length of the title
        """
        length = len(title)
        if vim.eval("has('conceal')") == "1":
            # exclude the "|F|...|" syntax tag
            title = re.sub(r"(.*?)\|F\|(.*?)\|(.*?)", r"\1\2\3", title)
            # exclude the "|T|...|" syntax tag
            title = re.sub(r"(.*?)\|T\|(.*?)\|(.*?)", r"\1\2\3", title)
            # exclude the "|D|...|" syntax tag
            title = re.sub(r"(.*?)\|D\|(.*?)\|(.*?)", r"\1\2\3", title)
            # exclude the "|[dwmya]|...|" syntax tag
            title = re.sub(r"(.*?)\|[dwmya]\|(.*?)\|(.*?)", r"\1\2\3", title)
            # To use strdisplaywidth as per below need to ensure title doesn't contain single quotes
            # This is very hacky/kludgy and should be done a better way
            title = re.sub(r"'", r"_", title)
            length = int(vim.eval("strdisplaywidth('"+title+"')"))
        return length

    def format_title(self, note):
        """ function to format the title for a note object

        Various formatting tags are supporting for dynamically building
        the title string. Each of these formatting tags supports a width
        specifier (decimal) and a left justification (-) like that supported
        by printf.

        %F -- flags ('*' for pinned, 'm' for markdown)
        %T -- tags
        %D -- date
        %N -- note title
        %> -- right justify the rest of the title

        Examples:

        %N    -- entire note title
        %50N  -- note title, max width of 50 characters and right justified
        %-50N -- note title, max width of 50 characters and left justified

        If the 'conceal' feature is enabled in vim then syntax highlighting is
        also supported. For each of the formatting tags above a special hidden
        string is injected into the title line that is used by the syntax
        highlighting match groups. The "..." below is the actual text
        specified by the format tag.

        %F -- becomes: |F|...|
        %T -- becomes: |T|...|
        %D -- becomes: |D|...|
        %N -- less than a day old becomes:         |d|...|
        %N -- less than a week old becomes:        |w|...|
        %N -- less than a month old becomes:       |m|...|
        %N -- less than a year old becomes:        |y|...|
        %N -- older than a year (ancient) becomes: |a|...|

        Arguments:
        note -- note object to format the title for

        Returns the formatted title
        """
        # fetch first line and display as title
        note_lines = note["content"].split("\n")

        # get window width for proper formatting
        width = vim.current.window.width

        # get note flags
        if note.has_key("systemtags"):
            flags = ""
            if ("pinned" in note["systemtags"]):   flags = flags + "*"
            else:                                  flags = flags + " "
            if ("markdown" in note["systemtags"]): flags = flags + "m"
            else:                                  flags = flags + " "
        else:
            flags = "  "

        # get note tags
        tags = "%s" % ",".join(note["tags"])

        # format date
        mt = time.localtime(float(note["modifydate"]))
        mod_time = time.strftime(vim.eval("s:strftime_fmt"), mt)

        # get the age of the note used for syntax highlighting
        dt = datetime.datetime.fromtimestamp(time.mktime(mt))
        if dt > datetime.datetime.now() - datetime.timedelta(days=1):
            note_age = "d" # less than a day old
        elif dt > datetime.datetime.now() - datetime.timedelta(weeks=1):
            note_age = "w" # less than a week old
        elif dt > datetime.datetime.now() - datetime.timedelta(weeks=4):
            note_age = "m" # less than a month old
        elif dt > datetime.datetime.now() - datetime.timedelta(weeks=52):
            note_age = "y" # less than a year old
        else:
            note_age = "a" # ancient

        if len(note_lines) > 0:
            title = str(note_lines[0])
        else:
            title = str(note["key"])

        # get the format string to be used for the note title
        title_line = vim.eval("s:noteformat")

        tleft  = title_line
        tright = None

        # search for a right alignment format
        # if there is one, break the title line up into a left and right
        fmt = re.search("^(.*)%>(.*)$", title_line)
        if fmt:
            tleft  = fmt.group(1)
            tright = fmt.group(2)

        if tright:
            # if there is a right title then do formats
            tright = self.format_title_build(tright, "F", flags, "F")
            tright = self.format_title_build(tright, "D", mod_time, "D")
            tright = self.format_title_build(tright, "T", tags, "T")
            tright = self.format_title_build(tright, "N", title, note_age)
        else:
            tright = ""

        if tleft:
            # if there is a left title then do formats
            tleft = self.format_title_build(tleft, "F", flags, "F")
            tleft = self.format_title_build(tleft, "D", mod_time, "D")
            tleft = self.format_title_build(tleft, "T", tags, "T")
            tleft = self.format_title_build(tleft, "N", title, note_age)
        else:
            tleft = ""

        # get the 'visible' title lengths
        # string length without the concealment syntax highlighting tags
        tleft_len  = self.format_title_len_no_conceal(tleft)
        tright_len = self.format_title_len_no_conceal(tright)

        # get the space allowed for the left title, this is the width
        #   of the console minus the length of the right title
        # if the left title is shorter than that allowed, pad the string
        #   so the right title is fully right justified
        # if the left title is longer than that allowed, the right title
        #   will be pushed off the screen (bummers)..
        padding = ""
        max_tleft_len = width - tright_len - 1
        if (max_tleft_len >= tleft_len):
            padding = " " * (max_tleft_len - tleft_len)

        return tleft + padding + " " + tright

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
        if int(vim.eval("exists('g:vader_file')")) == 0:
            vim.command("""call s:ScratchBufferOpen("%s")""" % note_id)
        self.set_current_note(note_id)
        buffer = vim.current.buffer
        # remove cursorline
        vim.command("setlocal nocursorline")
        vim.command("setlocal modifiable")
        vim.command("setlocal buftype=acwrite")
        vim.command("au! BufWriteCmd <buffer> call s:UpdateNoteFromCurrentBuffer()")
        buffer[:] = map(lambda x: str(x), note["content"].split("\n"))
        vim.command("setlocal nomodified")
        vim.command("doautocmd BufReadPost")
        # BufReadPost can cause auto-selection of filetype based on file content so set filetype after this
        if int(vim.eval("exists('g:SimplenoteFiletype')")) == 1:
            vim.command("setlocal filetype="+vim.eval("g:SimplenoteFiletype"))
        # But let simplenote markdown flag override the above
        if note.has_key("systemtags"):
            if ("markdown" in note["systemtags"]):
                vim.command("setlocal filetype=markdown")

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
            if int(vim.eval("exists('g:vader_file')")) == 0:
                vim.command("quit!")
        else:
            print "Moving note to trash failed.: %s" % note

    def delete_current_note(self):
        """ trash the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.delete_note(note_id)
        if status == 0:
            print "Note deleted."
            """ when running tests don't want to manipulate or close buffer """
            if int(vim.eval("exists('g:vader_file')")) == 0:
                self.remove_note_from_index(note_id)
                vim.command("bdelete!")
        else:
            print "Deleting note failed.: %s" % note

    def pin_current_note(self):
        """ pin the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.get_note(note_id)
        if status == 0:
            if note.has_key("systemtags"):
                if ("pinned" in note["systemtags"]):
                    print "Note is already pinned."
                    return
            else:
                note["systemtags"] = []
            note["systemtags"].append("pinned")
            n, st = self.simplenote.update_note(note)
            if st == 0:
                print "Note pinned."
            else:
                print "Note could not be pinned."
        else:
            print "Error fetching note data."

    def unpin_current_note(self):
        """ unpin the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.get_note(note_id)
        if status == 0:
            if ((not note.has_key("systemtags")) or
                ("pinned" not in note["systemtags"])):
                print "Note is already unpinned."
                return
            note["systemtags"].remove("pinned")
            n, st = self.simplenote.update_note(note)
            if st == 0:
                print "Note unpinned."
            else:
                print "Note could not be unpinned."
        else:
            print "Error fetching note data."

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
            self.set_current_note(note["key"])
            vim.command("doautocmd BufReadPost")
            # BufReadPost can cause auto-selection of filetype based on file content so reset filetype after this
            if int(vim.eval("exists('g:SimplenoteFiletype')")) == 1:
                vim.command("setlocal filetype="+vim.eval("g:SimplenoteFiletype"))
            #But let simplenote markdown flag override the above
            if markdown:
                vim.command("setlocal filetype=markdown")
            print "New note created."
        else:
            print "Update failed.: %s" % note["key"]

    def remove_note_from_index(self, note_id):
        try:
            position = self.note_index.index(note_id)
            #switch to note index buffer so can make modifiable temporarily in order to delete line
            vim.command("buffer Simplenote")
            vim.command("setlocal modifiable")
            del vim.current.buffer[position]
            vim.command("setlocal nomodifiable")
            #Switch back to note buffer so it can be deleted from function calling this one
            vim.command("buffer "+note_id)
            #Also delete from note_index so opening notes works as expected
            del self.note_index[position]
        except ValueError:
            #Handle improbable situation of trying to remove a note that wasn't there
            print "Unable to remove deleted note from list index"

    def list_note_index_in_scratch_buffer(self, since=None, tags=[]):
        """ get all available notes and display them in a scratchbuffer """
        # Initialize the scratch buffer
        if int(vim.eval("exists('g:vader_file')")) == 0:
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
        vim.command("setlocal filetype=simplenote")



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

SN_USER = vim.eval("s:user")
SN_PASSWORD = vim.eval("s:password")
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
def reset_user_pass(warning=None):
    if int(vim.eval("exists('g:SimplenoteUsername')")) == 0:
        vim.command("let s:user=''")
    if int(vim.eval("exists('g:SimplenotePassword')")) == 0:
        vim.command("let s:password=''")
    if warning:
        vim.command("redraw!")
        vim.command("echohl WarningMsg")
        vim.command("echo '%s'" % warning)
        vim.command("echohl none")

def Simplenote_cmd():
    if vim.eval('s:user') == '' or vim.eval('s:password') == '':
        try:
            vim.command("let s:user=input('email:', '')")
            vim.command("let s:password=inputsecret('password:', '')")
        except KeyboardInterrupt:
            reset_user_pass('KeyboardInterrupt')
            return
    #If a logon error has occurred, user may have corrected their globals since reset
    else:
        if vim.eval("exists('g:SimplenoteUsername')") == 1:
            vim.command("let s:user=g:SimplenoteUsername")
        if vim.eval("exists('g:SimplenotePassword')") == 1:
            vim.command("let s:password=g:SimplenotePassword")

    SN_USER = vim.eval("s:user")
    SN_PASSWORD = vim.eval("s:password")
    interface.simplenote.username = SN_USER
    interface.simplenote.password = SN_PASSWORD

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

    elif param == "-p":
        interface.pin_current_note()

    elif param == "-P":
        interface.unpin_current_note()

    elif param == "-o":
        if optionsexist:
            interface.display_note_in_scratch_buffer(vim.eval("a:1"))
        else:
            print "No notekey given."

    else:
        print "Unknown argument"
try:
    Simplenote_cmd()
except simplenote.SimplenoteLoginFailed:
    #Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed')
EOF
endfunction

