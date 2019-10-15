# Python classes and methods for simplenote.vim

import json
import os
import sys
import vim
sys.path.append(vim.eval("expand('<sfile>:p:h')") + "/simplenote.py/simplenote/")
import simplenote
sys.path.append(vim.eval("expand('<sfile>:p:h')"))
import datetime
import re
import time
import math as m
import functools
from threading import Thread
if sys.version_info > (3, 0):
    from queue import Queue
else:
    from Queue import Queue
import os.path

DEFAULT_SCRATCH_NAME = vim.eval("g:simplenote_scratch_buffer")
INDEX_CACHE_FILE = os.path.join(os.path.expanduser("~"),".snvim")

class SimplenoteVimInterface(object):
    """ Interface class to provide functions for interacting with VIM """

    def __init__(self, username, password):
        self.simplenote = simplenote.Simplenote(username, password)
        # Storing keys/ids for the note list
        self.note_index = []
        # Lightweight "cache" of note data for note index
        self.note_cache = {}
        if int(vim.eval("exists('g:vader_file')")) == 0:
            if os.path.isfile(INDEX_CACHE_FILE):
                try:
                    with open(INDEX_CACHE_FILE, 'r') as f:
                        cache_file = json.load(f)
                        self.note_cache = cache_file["cache"]
                        self.simplenote.current = cache_file["current"]
                        # Because a token might legitimately not exist in the cache, plus gives us a way to clear token manually
                        if "token" in cache_file:
                            self.simplenote.token = cache_file["token"]
                except IOError as e:
                    print("Error: Unable to read index cache to file - %s" % e)
        # TODO: Maybe possible to merge the following with note_cache now?
        self.note_version = {}
        # Map bufnums to noteids
        self.bufnum_to_noteid = {}
        # Default Window width for single window mode - other things override this
        self.vertical_window_width = 0

    def get_current_note(self):
        """ returns the key of the currently edited note """
        buffer = vim.current.buffer
        return self.bufnum_to_noteid[buffer.number]

    def set_current_note(self, buffertitle, note_id):
        """ sets the title of the currently edited note """
        # As much as it was clever not having the note key in the title, we need it there to ensure unique note titles
        fulltitle = buffertitle+"_"+note_id
        vim.command(""" silent exe "file %s" """ % fulltitle)

    def transform_to_scratchbuffer(self):
        """ transforms the current buffer into a scratchbuffer """
        vim.command("call s:ScratchBuffer()")
        vim.command("setlocal nocursorline")
        vim.command("setlocal buftype=acwrite")
        vim.command("setlocal nomodified")
        vim.command("au! BufWriteCmd <buffer> call s:UpdateNoteFromCurrentBuffer()")
        vim.command("au! BufFilePre <buffer> call s:PreRenameBuffer()")

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

        # get window width for proper formatting
        width = vim.current.window.width
        # But if vertical, then we want to adjust this
        if vim.eval('s:vbuff == 1') == "1":
            if vim.eval('s:listsize > 0') == "1":
                width = int(vim.eval('s:listsize'))
            else:
                # If no existing list index then store, otherwise use stored value
                if self.vertical_window_width == 0:
                    width = width/2
                    self.vertical_window_width = width
                else:
                    width = self.vertical_window_width
        # Adjust for numberwidth, plus extra 1 padding incase of using setlist, etc
        if vim.eval("&number") == "1":
            adjust = int(vim.eval("&numberwidth")) + 1
        else:
            adjust = 1
        width = width - adjust

        # get note flags
        if "systemtags" in note:
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

        title = get_note_title(note)

        # get the format string to be used for the note title
        title_line = vim.eval("s:noteformat")

        tleft =  title_line
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
            padding = " " * int(max_tleft_len - tleft_len)

        return tleft + padding + " " + tright

    def get_notes_from_keys(self, key_list):
        """ fetch all note objects for a list of keys via threads and return
        them in a list

        Arguments:
        key_list - list of keys to fetch the key from

        Returns list of fetched notes
        """
        queue = Queue()
        note_cache = {}
        for key in key_list:
            queue.put(key)
            t = NoteFetcher(queue, note_cache, self.simplenote)
            t.start()

        queue.join()
        return note_cache

    def scratch_buffer(self, sb_name = DEFAULT_SCRATCH_NAME, sb_number = -1):
        """ Opens a scratch buffer from python

        Arguments:
        sb_name - name of the scratch buffer
        sb_number - number of the buffer (if potentially existing)
        """
        vim.command("call s:ScratchBufferOpen('%s', %s)" % (sb_name, sb_number))

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
        # Replace any non alphanumeric characters to play safe with valid vim buffer names
        # otherwise vim will happily add them, but will fail to switch to them
        regex = re.compile("[^a-zA-Z0-9]")
        firstline = regex.sub("_", note["content"].split("\n")[0])
        buffertitle = "SN_%s" % firstline
        # Check to see if already mapped to a buffer
        try:
            buffernumber = [b for b, n in self.bufnum_to_noteid.items() if n == note_id ][0]
        except IndexError:
            buffernumber = -1
        if int(vim.eval("exists('g:vader_file')")) == 0:
            self.scratch_buffer(buffertitle, buffernumber)
        # TODO: Review this. Why are we setting this? Should be up to the user to set cursorline
        # remove cursorline
        vim.command("setlocal nocursorline")
        vim.command("setlocal buftype=acwrite")
        #And then, if it does already exist we don't need to do the below again
        if buffernumber == -1:
            self.set_current_note(buffertitle,note_id)
            buffer = vim.current.buffer
            # Update the version and buffer number
            # TODO: Is there potential for the same key to be in more than one buffer? Does that matter?
            self.note_version[note_id] = note["version"]
            self.bufnum_to_noteid[buffer.number] = note_id
            vim.command("setlocal modifiable")
            vim.command("au! BufWriteCmd <buffer> call s:UpdateNoteFromCurrentBuffer()")
            vim.command("au! BufFilePre <buffer> call s:PreRenameBuffer()")
            vim.command("let s:renaming = 0")
            try:
                buffer[:] = list(map(lambda x: str(x), note["content"].split("\n")))
            except UnicodeEncodeError:
                buffer[:] = list(map(lambda x: unicode(x), note["content"].split("\n")))
            vim.command("setlocal nomodified")
            vim.command("doautocmd BufReadPost")
            # BufReadPost can cause auto-selection of filetype based on file content so set filetype after this
            if int(vim.eval("exists('g:SimplenoteFiletype')")) == 1:
                vim.command("setlocal filetype="+vim.eval("g:SimplenoteFiletype"))
            # But let simplenote markdown flag override the above
            if "systemtags" in note:
                if ("markdown" in note["systemtags"]):
                    vim.command("setlocal filetype=markdown")

            # if vertical is on, we can try to resize the list window to the
            # desired size
            if vim.eval('s:vbuff == 1 && s:listsize > 0') == "1":
                vim.command("wincmd p")
                vim.command("vertical resize " + vim.eval("s:listsize"))
                vim.command("wincmd p")

            # if vertical is not on, we can try to resize the list window to the
            # desired size
            if vim.eval('s:vbuff == 0 && s:listsize > 0') == "1":
                vim.command("wincmd p")
                vim.command("resize " + vim.eval("s:listsize"))
                vim.command("wincmd p")

    def pre_rename_buffer(self):
        """ the only way to detect if user is saving with :saveas command.
            this function is executed before the actual saving """
        vim.command("let s:renaming = 1") # we just need to know if user is renaming this buffer

    def update_note_from_current_buffer(self):
        """ updates the currently displayed note to the web service or creates new """

        # what information do we have?
        amatch=vim.eval('expand("<amatch>")') # the desired path+file name (:w command parameter, for example)
        currentfile=vim.eval("expand('%:p')") # the filename of this buffer
        renaming=vim.eval("s:renaming")       # is the user changing THIS buffer's file name? (:saveas)

        if os.path.basename(currentfile) != os.path.basename(amatch):
            # user is executing :w <newfile>
            self.save_buffer_to_file()
        elif renaming == "0":
            # no renaming, so user is only trying to update note with :w
            self.update_note_to_web_service()
        else:
            # user is trying to :saveas
            self.save_buffer_to_file()
            # when :saveas-ing, a new buffer is created
            # let's delete it for now
            newBufferIndex = len(vim.buffers)
            vim.command("bd {0}".format(newBufferIndex))
            # this buffer is no longer a note...
            del self.bufnum_to_noteid[vim.current.buffer.number]
            vim.command("au! BufWriteCmd <buffer>")
            vim.command("au! BufFilePre <buffer>")
            vim.command("setlocal buftype=")

    def update_note_to_web_service(self):

            note_id = self.get_current_note()
            try:
                content = "\n".join(str(line) for line in vim.current.buffer[:])
            except UnicodeEncodeError:
                content = "\n".join(unicode(line) for line in vim.current.buffer[:])
            # Need to get note details first to assess remote markdown status
            note, status = self.simplenote.get_note(note_id)
            if status == 0:
                if (vim.eval("&filetype") == "markdown"):
                    if "systemtags" in note:
                        if ("markdown" not in note["systemtags"]):
                            note["systemtags"].append("markdown")
                    else:
                        note["systemtags"] = ["markdown"]
                else:
                    if "systemtags" in note:
                        if ("markdown" in note["systemtags"]):
                            note["systemtags"].remove("markdown")
                # To merge in we need to send version.
                note, status = self.simplenote.update_note({"content": content,
                                                        "key": note_id,
                                                        "version": self.note_version[note_id],
                                                        "systemtags": note["systemtags"],
                                                        "tags" : note["tags"]})
                if status == 0:
                    print("Update successful.")
                    self.note_version[note_id] = note["version"]
                    # Merging content.
                    if 'content' in note:
                        buffer = vim.current.buffer
                        try:
                            buffer[:] = list(map(lambda x: str(x), note["content"].split("\n")))
                        except UnicodeEncodeError:
                            buffer[:] = list(map(lambda x: unicode(x), note["content"].split("\n")))
                        print("Merged local content for %s" % note_id)
                    vim.command("setlocal nomodified")
                    #Need to (potentially) update buffer title, but we will just update anyway
                    regex = re.compile("[^a-zA-Z0-9]")
                    firstline = regex.sub("_", vim.current.buffer[0])
                    buffertitle = "SN_%s" % firstline
                    self.set_current_note(buffertitle, note["key"])
                    # But bufnum_to_noteid is ok so no need to change
                else:
                    print("Update failed.: %s" % note)

            elif note.code == 404:
                # API returns 404 if note doesn't exist, so create new
                self.create_new_note_from_current_buffer()
            else:
                print("Update failed.: %s" % note)
            vim.command("let s:renaming = 0")

    def save_buffer_to_file(self):
        """ save current buffer to file in pure python
            we need this because we have overwritten the native save functionality
            with our own using au! BufWriteCmd <buffer>
            ---
            copied shamelessly from:
            http://stackoverflow.com/questions/12324696/bufwritecmd-handler
            thanks ZyX!!!
        """

        abuf=int(vim.eval('expand("<abuf>")'))
        amatch=vim.eval('expand("<amatch>")')
        abang=bool(int(vim.eval('v:cmdbang')))
        cmdarg=vim.eval('v:cmdarg')

        if os.path.isdir(amatch):
            raise ValueError('Cannot write to directory {0}'.format(amatch))
        if not os.path.isdir(os.path.dirname(amatch)):
            raise ValueError('Directory {0} does not exist'.format(amatch))

        encoding=vim.eval('&encoding')

        opts={l[0] : l[1] if len(l)>1 else True
            for l in [s[2:].split('=')
                        for s in cmdarg.split()]}
        if 'ff' not in opts:
            opts['ff']=vim.eval('getbufvar({0}, "&fileformat")'.format(abuf))
            if not opts['ff']:
                opts['ff']='unix'
        if 'enc' not in opts:
            opts['enc']=vim.eval('getbufvar({0}, "&fileencoding")'.format(abuf))
            if not opts['enc']:
                opts['enc']=encoding
        if 'nobin' in opts:
            opts['bin']=False
        elif 'bin' not in opts:
            opts['bin']=vim.eval('getbufvar({0}, "&binary")'.format(abuf))

        if opts['bin']:
            opts['ff']='unix'
            eol=bool(int(vim.eval('getbufvar({0}, "&endofline")'.format(abuf))))
        else:
            eol=True

        eolbytes={'unix': '\n', 'dos': '\r\n', 'mac': '\r'}[opts['ff']]

        buf=vim.buffers[abuf]
        f=open(amatch, 'wb')
        first=True
        for line in buf:
            if opts['enc']!=encoding:
                # Does not handle invalid bytes.
                line=line.decode(encoding).encode(opts['enc'])
            if not first:
                f.write(eolbytes)
            else:
                first=False
            f.write(line)
        if eol:
            f.write(eolbytes)
        f.close()

        vim.command("set nomodified")

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
                print("Tags updated.")
            else:
                print("Tags could not be updated.")
        else:
            print("Error fetching note data.")

    def trash_current_note(self):
        """ trash the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.trash_note(note_id)
        if status == 0:
            print("Note moved to trash.")
            """ when running tests don't want to close buffer """
            if int(vim.eval("exists('g:vader_file')")) == 0:
                vim.command("quit!")
        else:
            print("Moving note to trash failed.: %s" % note)

    def delete_current_note(self):
        """ delete the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.delete_note(note_id)
        if status == 0:
            print("Note deleted.")
            """ when running tests don't want to manipulate or close buffer """
            if int(vim.eval("exists('g:vader_file')")) == 0:
                self.remove_note_from_index(note_id, vim.current.buffer.number)
                # Vim doesn't actually completely remove the buffer, but it does undo mappings, etc so we should forget this buffer.
                del self.bufnum_to_noteid[vim.current.buffer.number]
                # Also need to remove from our cache
                del self.note_cache[note_id]
                self.write_index_cache()
                vim.command("bdelete!")
        else:
            print("Deleting note failed.: %s" % note)

    def pin_current_note(self):
        """ pin the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.get_note(note_id)
        if status == 0:
            if "systemtags" in note:
                if ("pinned" in note["systemtags"]):
                    print("Note is already pinned.")
                    return
            else:
                note["systemtags"] = []
            note["systemtags"].append("pinned")
            n, st = self.simplenote.update_note(note)
            if st == 0:
                print("Note pinned.")
            else:
                print("Note could not be pinned.")
        else:
            print("Error fetching note data.")

    def unpin_current_note(self):
        """ unpin the currently displayed note """
        note_id = self.get_current_note()
        note, status = self.simplenote.get_note(note_id)
        if status == 0:
            if ((not "systemtags" in note) or
                ("pinned" not in note["systemtags"])):
                print("Note is already unpinned.")
                return
            note["systemtags"].remove("pinned")
            n, st = self.simplenote.update_note(note)
            if st == 0:
                print("Note unpinned.")
            else:
                print("Note could not be unpinned.")
        else:
            print("Error fetching note data.")

    def version_of_current_note(self, version=None):
        """ retrieve a specific version of current note """
        note_id = self.get_current_note()
        try:
            current_version = self.note_version[note_id]
            buffer = vim.current.buffer
            if version is None:
                # If no args then just print version of note
                print("Displaying note ID %s version %s" % (note_id, current_version))
            else:
                if (buffer.options["modified"] == False):
                    if version == "0":
                        note, status = self.simplenote.get_note(note_id)
                        if status == 0:
                            try:
                                buffer[:] = list(map(lambda x: str(x), note["content"].split("\n")))
                            except UnicodeEncodeError:
                                buffer[:] = list(map(lambda x: unicode(x), note["content"].split("\n")))
                            # Need to set as unmodified so can continue to browse through versions
                            vim.command("setlocal nomodified")
                            print("Displaying most recent version of note ID %s" % note_id)
                    else:
                        note, status = self.simplenote.get_note(note_id, version)
                        if status == 0:
                            try:
                                buffer[:] = list(map(lambda x: str(x), note["content"].split("\n")))
                            except UnicodeEncodeError:
                                buffer[:] = list(map(lambda x: unicode(x), note["content"].split("\n")))
                            # Need to set as unmodified so can continue to browse through versions
                            vim.command("setlocal nomodified")
                            print("Displaying note ID %s version %s. To restore, :Simplenote -u, to revert to most recent, :Simplenote -v" % (note_id, version))
                        else:
                            print("Error fetching note data. Perhaps that version isn't available.")
                else:
                    print("Save changes before trying to show another version")
        except KeyError:
            print("This isn't a Simplenote")

    def create_new_note_from_current_buffer(self):
        """ get content of the current buffer and create new note """
        try:
            content = "\n".join(str(line) for line in vim.current.buffer[:])
        except UnicodeEncodeError:
            content = "\n".join(unicode(line) for line in vim.current.buffer[:])

        markdown = (vim.eval("&filetype") == "markdown")
        if markdown:
            note, status = self.simplenote.update_note({"content": content,
                                                        "systemtags": ["markdown"]})
        else:
            note, status = self.simplenote.update_note({"content": content})
        if status == 0:
            self.note_version[note["key"]] = note["version"]
            self.transform_to_scratchbuffer()
            # Replace any non alphanumeric characters to play safe with valid vim buffer names
            # otherwise vim will happily add them, but will fail to switch to them
            regex = re.compile("[^a-zA-Z0-9]")
            firstline = regex.sub("_", vim.current.buffer[0])
            buffertitle = "SN_%s" % firstline
            self.set_current_note(buffertitle, note["key"])
            self.bufnum_to_noteid[vim.current.buffer.number] = note["key"]
            vim.command("doautocmd BufReadPost")
            # BufReadPost can cause auto-selection of filetype based on file content so reset filetype after this
            if int(vim.eval("exists('g:SimplenoteFiletype')")) == 1:
                vim.command("setlocal filetype="+vim.eval("g:SimplenoteFiletype"))
            # But let simplenote markdown flag override the above
            if markdown:
                vim.command("setlocal filetype=markdown")
            print("New note created.")
        else:
            print("Update failed.: %s" % note["key"])
        vim.command("let s:renaming = 0")

    def remove_note_from_index(self, note_id, buffrom):
        try:
            position = self.note_index.index(note_id)
            # switch to note index buffer so can make modifiable temporarily in order to delete line
            vim.command("buffer Simplenote")
            vim.command("setlocal modifiable")
            del vim.current.buffer[position]
            vim.command("setlocal nomodifiable")
            # Switch back to note buffer so it can be deleted from function calling this one
            #Need reverse look up again
            buffernumber = [b for b, n in self.bufnum_to_noteid.items() if n == note_id ][0]
            try:
                vim.command("buffer "+str(buffernumber))
            except UnicodeEncodeError:
                vim.command("buffer "+unicode(buffernumber))
            # Also delete from note_index so opening notes works as expected
            del self.note_index[position]
        except ValueError:
            # Handle improbable situation of trying to remove a note that wasn't there
            print("Unable to remove deleted note from list index")

    def list_note_index_in_scratch_buffer(self, tags=[]):
        """ get all available notes and display them in a scratchbuffer """
        # Initialize the scratch buffer
        # Check to see if already mapped to a buffer
        try:
            buffernumber = [b for b, n in self.bufnum_to_noteid.items() if n == DEFAULT_SCRATCH_NAME ][0]
        except IndexError:
            buffernumber = -1
        if int(vim.eval("exists('g:vader_file')")) == 0:
            self.scratch_buffer(DEFAULT_SCRATCH_NAME, buffernumber)
        vim.command("setlocal modifiable")
        # clear global note id storage
        buffer = vim.current.buffer
        # Need to also keep track of the list index in the bufnum dictionary
        self.bufnum_to_noteid[buffer.number] = DEFAULT_SCRATCH_NAME
        if self.simplenote.current:
            note_keys, status = self.simplenote.get_note_list(data=False, since=self.simplenote.current)
            note_cache = self.get_notes_from_keys([n['key'] for n in note_keys])
            # Merge with existing
            self.note_cache.update(note_cache)
        else:
            note_keys, status = self.simplenote.get_note_list(data=False)
            self.note_cache = self.get_notes_from_keys([n['key'] for n in note_keys])
        # Write out cache
        self.write_index_cache()
        note_list = list(self.note_cache.values())

        if (len(tags) > 0):
            note_list = [n for n in note_list if (n["deleted"] != 1 and
                            len(set(n["tags"]).intersection(tags)) > 0)]
        else:
            note_list = [n for n in note_list if n["deleted"] != 1]


        # set global notes index object to notes
        if status == 0:
            note_titles = []
            # Iterate through sorts here, need to reverse this because we finish with the primary sort
            sortorder = list(reversed(vim.eval("s:sortorder").split(",")))
            sorted_notes = note_list
            for compare_type in sortorder:
                compare_type = compare_type.strip()
                if compare_type == "pinned":
                    sorted_notes = sorted(sorted_notes, key=lambda n: "pinned" in n["systemtags"], reverse=True)
                elif compare_type == "modifydate":
                    sorted_notes = sorted(sorted_notes, key=lambda n: float(n["modifydate"]), reverse=True)
                elif compare_type == "createdate":
                    sorted_notes = sorted(sorted_notes, key=lambda n: float(n["createdate"]), reverse=True)
                elif compare_type == "tags":
                    # existence of a tag only
                    sorted_notes = sorted(sorted_notes, key=lambda n: len(n["tags"]) == 0)
                elif compare_type == "title":
                    # Ignore case
                    sorted_notes = sorted(sorted_notes, key=lambda n: str.lower(get_note_title(n)))
            notes = sorted_notes
            note_titles = [self.format_title(n) for n in notes]
            self.note_index = [n["key"] for n in notes]
            buffer[:] = note_titles

        else:
            print("Error: Unable to connect to server.")

        # map <CR> to call get_note()
        vim.command("setl nomodifiable")
        vim.command("setlocal nowrap")
        vim.command("nnoremap <buffer><silent> <CR> <Esc>:call <SID>GetNoteToCurrentBuffer()<CR>")
        vim.command("setlocal filetype=simplenote")

    def write_index_cache(self):
        if int(vim.eval("exists('g:vader_file')")) == 0:
            try:
                with open(INDEX_CACHE_FILE, 'w') as f:
                    json.dump({ "token": self.simplenote.token, "current": self.simplenote.current, "cache": self.note_cache}, f, indent=2)
                os.chmod(INDEX_CACHE_FILE, 0o600)
            except IOError as e:
                print("Error: Unable to write index cache to file - %s" % e)

def get_note_title(note):
    """ get title of note """
    try:
        return str(note["title"])
    except UnicodeEncodeError:
        return unicode(note["title"])


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
        # Strip down and store a lightweight version
        # Storing key "twice" as makes easier to convert to list later
        note_lines = note["content"].split("\n")
        note_title = note_lines[0] if len(note_lines) > 0 else note["key"]
        notelight = {
            "key": note["key"],
            "modifydate": note["modifydate"],
            "createdate": note["createdate"],
            "tags": note["tags"],
            "systemtags": note["systemtags"],
            "deleted": note["deleted"],
            "title": note_title
        }
        if status != -1:
            self.note_list[note["key"]] = notelight

        self.queue.task_done()

SN_USER = vim.eval("s:user")
SN_PASSWORD = vim.eval("s:password")
interface = SimplenoteVimInterface(SN_USER, SN_PASSWORD)
# vim: expandtab
