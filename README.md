# simplenote.vim
A vim plugin to interact with the [simplenote][1] API.
Now you can take simple notes directly from your favourite editor.

## This is work in progress and won't probably work until at least v0.1.0

## Installation
Just copy `simplenote.vim` into your plugin folder. But you really want to use
[pathogen][5] for your plugin management.

## Usage
The plugin provides the following commands to interact with Simplenote:

    SimpleNote -l

Lists all the notes in your account, together with its first line.

    SimpleNote -d

Deletes the note in your current buffer.

    SimpleNote -u

Updates the note in the current buffer with its content. If the buffer has no
corresponding note, a new one is created.

    SimpleNote -s "searchterm"

Searches your notes for the given search term.

## Dependencies
The plugin relies on the following executables being in your `$PATH`:

* curl
* openssl

## Thanks
[mattn][2], [Tim Pope][3] and [Scrooloose][4] who write awesome vim plugins
which I took as a basis to learn how to write vim plugins.

[1]: http://simplenoteapp.com/
[2]: http://github.com/mattn
[3]: http://github.com/tpope
[4]: http://github.com/scrooloose
[5]: http://github.com/tpope/vim-pathogen
