# simplenote.vim
A vim plugin to interact with the [simplenote][1] API. You can create an account
[here][2] if you don't already have one.

Now you can take simple notes directly from your favourite editor.

## Installation
Install manually by copying `simplenote.vim` into your plugin folder or if using
[Pathogen][3]:

    git clone https://github.com/mrtazz/simplenote.vim.git
    ~/.vim/bundle/simplenote.vim

**Note** for both manual and Pathogen installs you will then need to run

    git submodule update --init

in the `autoload/simplenote.py` directory (since simplenote.vim [now][4]
references [simplenote.py][5] as a git submodule).

But it's easier to use a plugin manager:

### [Vundle](https://github.com/gmarik/vundle)

    Add Bundle 'mrtazz/simplenote.vim' to .vimrc
    Run :BundleInstall

### [NeoBundle](https://github.com/Shougo/neobundle.vim)

    Add NeoBundle 'mrtazz/simplenote.vim' to .vimrc
    Run :NeoBundleInstall

### [vim-plug](https://github.com/junegunn/vim-plug)

    Add Plug 'mrtazz/simplenote.vim' to .vimrc
    Run :PlugInstall

Your credentials have to be stored in your `vimrc`:

    let g:SimplenoteUsername = "your simplenote username"
    let g:SimplenotePassword = "your simplenote password"

If you don't want to have the credentials in your `vimrc` (if you manage it with
git for example), you can just set the variables in a different file (like
`~/.simplenoterc`) and source it with `source ~/.simplenoterc` in your `vimrc`.

By default all notes are treated as plain text. If you usually write all of your
notes in some other format (like markdown or restructured text) you can set
`g:SimplenoteFiletype` to the preferred vim filetype.

## Usage
The plugin provides several commands to interact with your Simplenote account.
In order to retrieve a list of your notes execute one of the following:

    :Simplenote -l
    :Simplenote -l YYYY-MM-DD
    :Simplenote -l todo,shopping

The first option returns all notes, the second returns only those notes modified
since YYYY-MM-DD, the third option shows passing a comma separated list of tags;
this will only list notes which have at least one of those tags.  This opens a
new scratch buffer with a line-wise listing of your notes. With `let
g:SimplenoteListHeight=X` set, the scratch buffer will come up X lines tall.
Alternatively when `let g:SimplenoteVertical=1` is set, it is opened as a
vertical rather than horizontal split window.  You can then navigate through the
with the arrow keys and enter a note on hitting `Return`. Now that you see the
content of the note, you can interact with this specific note:

    :Simplenote -u

updates the content of the current note with the content of the current buffer.
The buffer write command `:w` is also mapped to update the current note.  If you
want to delete the note, execute

    :Simplenote -d

This moves the current note to the trash. If you want to completely delete a
note, use

    :Simplenote -D

as it will directly delete the note and not only move it to the trash.  There
also exists a command to create new notes.

    :Simplenote -n

creates a new note with the contents of the current buffer. Once the note is
created, `:Simplenote -u` updates the newly created note, also with the contents
of the current buffer.

Tagging notes is also supported. If you enter

    :Simplenote -t

on a buffer containing a valid note, you get an input dialog, prefilled with
existing comma-separated tags for the note, which you can then edit. Tags have
to be comma separated and hitting `Enter` will then update the note with the new
tag list.

Notes can be pinned with

    :Simplenote -p

on a buffer containing a valid note. Likewise a note can be unpinned with

    :Simplenote -P

on a buffer containing a valid note.

There is also an option to open notes directly from a given key:

    :Simplenote -o <notekey>

While this is not very useful in everyday usage, it can be used very effectively
to create shortcuts to notes you use often. Example:

    " add :Todo command
    command Todo Simplenote -o <yourtodonotekey>

Now you can jump to your todo note directly with `:Todo` in vim.

## Note sorting
simplenote.vim supports simple note ordering. Per default the sort order is
pinned notes first followed by modified date from newest to oldest. The order
can be changed by setting the `g:SimplenoteSortOrder` variable. It should be set
to a comma separated list of values which represents the sort order.  Allowed
values are `pinned` (pinned before unpinned), `tags` (notes with tags before
untagged ones), `modifydate` and `createdate` (both newer before older).

## Dependencies
Version 2 of the SimpleNote API relies heavily on JSON. As JSON and VimL don't
really play nice together, basic parts of this plugin are implemented in python.
Therefore your vim has to be compiled with python support in order to use this
plugin.

## Usage behind proxy
Since the plugin uses Python's urllib2 for making HTTP requests, you just have
to add these lines (with the correct values) to your `.vimrc`:

    let $HTTP_PROXY =
    'http://<proxyuser>:<proxypassword>@<proxyurl>:<proxyport>' let $HTTPS_PROXY
    = 'http://<proxyuser>:<proxypassword>@<proxyurl>:<proxyport>'


## Development
- [Bugs and issue tracker](https://github.com/mrtazz/simplenote.vim/issues)

## Contribute
- Fork the project
- Make your additions/fixes/improvements
- Send a pull request

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

