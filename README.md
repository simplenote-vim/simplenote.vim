[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](http://opensource.org/licenses/MIT)

# simplenote.vim

A vim plugin to interact with the [simplenote][1] API. You can create an account
[here][2] if you don't already have one.

Now you can take simple notes directly from your favourite editor.

## Installation

Install manually by copying `simplenote.vim` into your plugin folder or use the
included `mk_vimball.sh` to generate a vimball to install.

if using [Pathogen][3]:

    git clone https://github.com/mrtazz/simplenote.vim.git
    ~/.vim/bundle/simplenote.vim

**Note** for both manual and Pathogen installs you will then need to run

    git submodule update --init

in the `autoload/simplenote.py` directory (since simplenote.vim [now][4]
references [simplenote.py][5] as a git submodule).

But it's easier to use a plugin manager:

### [Vundle](https://github.com/gmarik/vundle)

    Add Plugin 'mrtazz/simplenote.vim' to .vimrc
    Run :PluginInstall

### [NeoBundle](https://github.com/Shougo/neobundle.vim)

    Add NeoBundle 'mrtazz/simplenote.vim' to .vimrc
    Run :NeoBundleInstall

### [vim-plug](https://github.com/junegunn/vim-plug)

    Add Plug 'mrtazz/simplenote.vim' to .vimrc
    Run :PlugInstall

Your credentials can be stored in your `vimrc`:

    let g:SimplenoteUsername = "your simplenote username"
    let g:SimplenotePassword = "your simplenote password"

If you don't want to have the credentials in your `vimrc` (if you manage it with
git for example), you can just set the variables in a different file (like
`~/.simplenoterc`) and source it with `source ~/.simplenoterc` in your `vimrc`.

Alternatively, if you don't set these global variables then Simplenote.vim will
prompt you for a username and password when you start using it.

By default all notes are treated as plain text. If you usually write all of your
notes in some other format (like markdown or restructured text) you can set
`g:SimplenoteFiletype` to the preferred vim filetype.

## Usage

The plugin provides several commands to interact with your Simplenote account.
In order to retrieve a list of your notes execute one of the following:

    :SimplenoteList
    :SimplenoteList todo,shopping

The first option returns all notes, the second option shows passing a comma
separated list of tags; this will only list notes which have at least one of
those tags.  This opens a new scratch buffer with a line-wise listing of your
notes. With `let g:SimplenoteListSize=X` set, the scratch buffer will come up X
lines tall.  Alternatively when `let g:SimplenoteVertical=1` is set, it is
opened as a vertical rather than horizontal split window and
`g:SimplenoteListSize=X` sets the width of the list index.  You can then
navigate through the with the arrow keys and enter a note on hitting `Return`.

If you want to refresh the list index just run `:SimplenoteList` again. With
version 2.1 an in-memory cache is used to speed up subsequent updates of the
list index. With 2.2 this is extended so any call to `:SimplenoteList` also
updates an on-disk cache so startup is also fast (the very first load before
you have a cache can still be slow if you have a lot of notes). Also
see [Single Window Mode](#single-window-mode).

Now that you see the content of the note, you can interact with this specific
note:

    :SimplenoteUpdate

updates the content of the current note with the content of the current buffer.
It will use Simplenote's merge functionality to merge in any remote changes that
have been made as well. The buffer write command `:w` is also mapped to update
the current note, but you can still use `:w <file>` and `:saveas <file>` to
write out a not locally.

To display the current version and note key/ID of a note use:

    :SimplenoteVersionInfo

If you want to retrieve a specific version of a note use:

    :SimplenoteVersion X

where X is an integer version number. To restore that version of a note you
would just use `:Simplenote -u`. To get back to the most recent version of a
note use:

    :SimplenoteVersion

Therefore you can also use `:Simplenote -v` when no local changes have been made
to pull in the most recent changes from the remote note. To delete the note,
execute

    :SimplenoteTrash

This moves the current note to the trash. If you want to completely delete a
note, use

    :SimplenoteDelete

as it will directly delete the note and not only move it to the trash.  There
also exists a command to create new notes.

    :SimplenoteNew

creates a new note with the contents of the current buffer. Once the note is
created, `:Simplenote -u` updates the newly created note, also with the contents
of the current buffer.

Tagging notes is also supported. If you enter

    :SimplenoteTag

on a buffer containing a valid note, you get an input dialog, prefilled with
existing comma-separated tags for the note, which you can then edit. Tags have
to be comma separated and hitting `Enter` will then update the note with the new
tag list.

Notes can be pinned with

    :SimplenotePin

on a buffer containing a valid note. Likewise a note can be unpinned with

    :SimplenoteUnpin

on a buffer containing a valid note.

There is also an option to open notes directly from a given key:

    :SimplenoteOpen <notekey>

While this is not very useful in everyday usage, it can be used very effectively
to create shortcuts to notes you use often. Example:

    " add :Todo command
    command Todo SimplenoteOpen <yourtodonotekey>

Now you can jump to your todo note directly with `:Todo` in vim.


## Note sorting

simplenote.vim supports simple note ordering. Per default the sort order is
pinned notes first followed by modified date from newest to oldest. The order
can be changed by setting the `g:SimplenoteSortOrder` variable. It should be set
to a comma separated list of values which represents the sort order.  Allowed
values are `pinned` (pinned before unpinned), `tags` (notes with tags before
untagged ones), `title`, `modifydate` and `createdate` (both newer before
older).

## Formatting

The format of the note titles in the list are configurable using the
`g:SimplenoteNoteFormat` option.

Various formatting tags are supporting for dynamically building the title
string. Each of these formatting tags supports a width specifier (decimal) and
a left justification (-) like that supported by printf.

    %F -- flags, always two characters ('*'=pinned, 'm'=markdown)
    %T -- tags
    %D -- date
    %N -- note title
    %> -- right justify the rest of the title

Examples:

    %N    -- entire note title
    %50N  -- note title, max width of 50 characters and right justified
    %-50N -- note title, max width of 50 characters and left justified

The default title format is `"%N%>[%T] [%D]"`.

The format of the date string is also configurable using the
`g:SimplenoteStrftime` option. The default strftime is
`"%a, %d %b %Y %H:%M:%S"`.

### Colors

If the `+conceal` feature is enabled in vim then syntax highlighting is
supported for the Simplenote note list. The highlight groups supported are:

    SN_NoteFlags       note flags ('%F' format)
    SN_NoteDate        last updated date of the note ('%D' format)
    SN_NoteTags        tags assigned to the note ('%T' format)
    SN_NoteAgeDay      note title - less than a day old ('%N' format)
    SN_NoteAgeWeek     note title - less than a week old ('%N' format)
    SN_NoteAgeMonth    note title - less than a month old ('%N' format)
    SN_NoteAgeYear     note title - less than a year old ('%N' format)
    SN_NoteAgeAncient  note title - ancient ('%N' format)

## Single Window Mode

By default simplenote.vim will open notes in new windows. If you would prefer
simplenote.vim to emulate the behaviour of the Simplenote website and native
applications then set `g:SimplenoteSingleWindow` (to anything) in your `.vimrc`
and simplenote.vim will try as much as possible to re-use one window for
opening all notes. Note: due to the way Vim handles and numbers windows, this
behaviour can't be perfect and if you manually open a window between the note
index and the first note opened then this new window will be targetted for
notes.

## Dependencies

Version 2 of the SimpleNote API relies heavily on JSON. As JSON and VimL don't
really play nice together, basic parts of this plugin are implemented in
python.  Therefore your vim has to be compiled with python 2.7+ or 3.2+ support
in order to use this plugin.

## Usage behind proxy

Since the plugin uses Python's urllib2 for making HTTP requests, you just have
to add these lines (with the correct values) to your `.vimrc`:

    let $HTTP_PROXY =
    'http://<proxyuser>:<proxypassword>@<proxyurl>:<proxyport>' let $HTTPS_PROXY
    = 'http://<proxyuser>:<proxypassword>@<proxyurl>:<proxyport>'


## Special issue concerning GFW

For Chinese mainland users, since the authentication service of [simplenote][1] is hosted
on [appspot](http://appspot.com), a VPN connection has to be configured to use
simplenote.vim. The configurations of a VPN connection is surely beyond the scope of
this doc. But if you have done that, you can add a shell alias or script
exploiting `proxychains` to ease the invoking of simplenote.vim

    # as for zsh
    alias simplenote="proxychains -q vim -c 'Simplenote -l'"

## Development

- [Bugs and issue tracker](https://github.com/mrtazz/simplenote.vim/issues)


## Thanks

[mattn][6], [Tim Pope][7] and [Scrooloose][8] who write awesome vim
plugins which I took as a basis to learn how to write vim plugins.

[1]: http://simplenoteapp.com/
[2]: https://simple-note.appspot.com/create
[3]: https://github.com/tpope/vim-pathogen
[4]: https://github.com/mrtazz/simplenote.vim/commit/cbe046fd63f1fd9762be26f476527132e486457f
[5]: https://github.com/mrtazz/simplenote.py
[6]: http://github.com/mattn
[7]: http://github.com/tpope
[8]: http://github.com/scrooloose

