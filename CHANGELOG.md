# Changelog

## 0.6.0 (09/30/2012)

- add the possibility to restrict note listing to tags
- respect pinned notes in note index
- set initial number of notes to load to 100
- add config option to specify a preferred filetype
- add modifydate to update_note() function

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

