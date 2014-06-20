
" Syntax File: simplenote.vim
" WebPage: http://github.com/mrtazz/simplenote.vim

if has("conceal")

    syn clear
    syn sync fromstart

    setlocal concealcursor+=nciv
    setlocal conceallevel=3

    hi link SN_NoteFlags SpecialChar
    hi link SN_NoteDate  String
    hi link SN_NoteTags  Statement
    syntax region SN_NoteFlags matchgroup=Todo start="\v\|F\|" end="\v\|" concealends
    syntax region SN_NoteDate  matchgroup=Todo start="\v\|D\|" end="\v\|" concealends
    syntax region SN_NoteTags  matchgroup=Todo start="\v\|T\|" end="\v\|" concealends

    hi link SN_NoteAgeDay     PreProc
    hi link SN_NoteAgeWeek    Type
    hi link SN_NoteAgeMonth   Constant
    hi link SN_NoteAgeYear    Comment
    hi link SN_NoteAgeAncient Identifier
    syntax region SN_NoteAgeDay     matchgroup=Todo start="\v\|d\|" end="\v\|" concealends
    syntax region SN_NoteAgeWeek    matchgroup=Todo start="\v\|w\|" end="\v\|" concealends
    syntax region SN_NoteAgeMonth   matchgroup=Todo start="\v\|m\|" end="\v\|" concealends
    syntax region SN_NoteAgeYear    matchgroup=Todo start="\v\|y\|" end="\v\|" concealends
    syntax region SN_NoteAgeAncient matchgroup=Todo start="\v\|a\|" end="\v\|" concealends

endif

