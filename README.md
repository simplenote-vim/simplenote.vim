# simplenote.vim
A vim plugin to interact with the [simplenote][1] API. You can create an
account [here](https://simple-note.appspot.com/create) if you don't already
have one.
Now you can take simple notes directly from your favourite editor.

## Installation
Just copy `simplenote.vim` into your plugin folder. But you really want to use
[pathogen][5] for your plugin management.

Your credentials have to be stored in your `vimrc`:

    let g:SimplenoteUserName = "your simplenote username"
    let g:SimplenotePassword = "your simplenote password"

## Usage
The plugin provides several commands to interact with your Simplenote account.
In order to retrieve a list of your notes execute

    :Simplenote -l

This opens a new scratch buffer with a line-wise listing of your notes. You can
navigate through these with the arrow keys and enter a note on hitting
`Return`. Now that you see the content of the note, you can interact with this
specific note:

    :Simplenote -u

updates the content of the current note with the content of the current buffer.
If you want to delete the note, execute

    :Simplenote -d

This moves the current note to the trash.

## Dependencies
Version 2 of the SimpleNote API relies heavily on JSON. As JSON and VimL don't
really play nice together, basic parts of this plugin are implemented in
python. Therefore your vim has to be compiled with python support in order to
use this plugin.

## Development
- [Planned features](http://www.pivotaltracker.com/projects/288621)
- [Bugs and issue tracker](https://github.com/mrtazz/simplenote.vim/issues)

## Contribute
- Fork the project
- Make your additions/fixes/improvements (Bonus points for topic branches)
- Send a pull request

## Thanks
[mattn][2], [Tim Pope][3] and [Scrooloose][4] who write awesome vim plugins
which I took as a basis to learn how to write vim plugins.

[1]: http://simplenoteapp.com/
[2]: http://github.com/mattn
[3]: http://github.com/tpope
[4]: http://github.com/scrooloose
[5]: http://github.com/tpope/vim-pathogen
