# Changelog

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

