# Changelog

## 0.10.1 (11/05/2015)
- Remove errant tabs from code

## 0.10.0 (09/27/2015)
- Minor fix/improvement to regex in script for generating release
- Add "single window" mode to emulate behaviour of website
- prompt for user/pass when missing. From @yuex
- Add Great Firewall of China usage note to README. From @yuex
- When deleting a note also remove it from the note index list

## 0.9.1 (11/24/2014)
- Make list index work again when Vim is compiled without conceal
- Quick fix for titles with single quotes causing error in list index
- Fix alignment of titles/tags with multibyte characters in list index
- Re-order commands to avoid BufReadPost overriding intended filetype

## 0.9.0 (07/20/2014)
- Add reduced vimrc for running Vader tests and other test related changes
- Force autocommand processing of notes opened via Simplenote.vim. For example, to enable modeline processing. From @insanum
- New list index format options and syntax highlighting. From @insanum
- New commands to pin/unpin notes. From @insanum 
- Add script to generate vimball. From @jeromebaum
- Add more detailed installation instructions and mention contains git submodule

## 0.8.0 (01/11/2014)
- Add a script to help automate release management
- Add tests using Vader.vim
- Reference Simplenote.py externally rather than include inline
- Updating a non existing note creates a new one
- Toggle markdown flag in Simplenote to match current buffer filetype
- Auto set buffer filetype to markdown if checked as markdown in Simplenote
- No longer uses buffhidden=delete on scratch buffers
- Make the Simplenote list/index the only window on screen
- Fix for double enocding issue.
- Change optional qty to optional since date for `get_note_list()`

## 0.7.0 (10/21/2012)
- add vim help file
- add custom sort orders
- add -o option to open note for given key directly
- show notes tags in the list view

## 0.6.0 (09/30/2012)

- add the possibility to restrict note listing to tags
- respect pinned notes in note index
- set initial number of notes to load to 100
- add config option to specify a preferred filetype
- add modifydate to `update_note()` function

## 0.5.0 (06/03/2012)

- make pretty formatting for note list
- allow vertical splitting of scratch buffer
- listing command (-l) takes parameter of max notes to fetch
- update to simplenote.py v0.2.0
- incorrectly fetched notes are not displayed anymore

## 0.4.0 (02/08/2012)

- refactor into autload plugin

## 0.3.1 (11/23/2011)

- add documentation for usage behind proxy
- buffer write command updates note

## 0.3.0 (07/17/2011)

- UTF-8 support
- create new notes from buffer via :Simplenote -n
- update note when buffer is written
- support direct deletion of notes via :Simplenote -D
- support tagging of notes via :Simplenote -t
- distinct buffer for every note
- use simplenote.py for API interaction
- encapsulate interface methods in Python class

## 0.2.0 (05/30/2011)

- change interface function to Simplenote
- truncate long note titles in list
- display modified date instead of note key in list
- load all notes for index
- don't display notes from trash
- deferred token retrieval and simple caching
- Wrapped username, password and token in urllib2's quote method
- improve time needed for listing notes

## 0.1.0 (05/10/2011)

- SimpleNote -l: list notes in scratch buffer
- SimpleNote -u: update note from buffer
- SimpleNote -d: move note to trash

