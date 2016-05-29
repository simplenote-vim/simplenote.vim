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
if !has("python") && !has("python3")
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
" TODO: This is a complicated mess and it would be nice to improve it, but I'm really not sure how.
function! s:ScratchBufferOpen(name, number)
    " Need someway of updating python since buffer could have been closed.
    let exe_new = "new "
    let exe_split = "split "

    if s:vbuff > 0
        let exe_new = "vert " . exe_new
        let exe_split = "vert " . exe_split
    endif

    let scr_bufnum = a:number
    " But, buffer could have been closed anyway so still need to check if it still exists.
    if !bufexists(a:number)
        let scr_bufnum = -1
        " -1 is no buffer
    endif
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
let s:scriptpath = resolve(expand('<sfile>:p:h')) 
if has("python3")
    execute 'py3file ' . s:scriptpath . "/SimplenoteUtilities.py"
endif

"
" interface functions
"


" function to get a note and display in current buffer
function! s:GetNoteToCurrentBuffer()
if has("python3")
python3 << EOF
interface.display_note_in_scratch_buffer()
EOF
endif
endfunction

" function to update note from buffer content
function! s:UpdateNoteFromCurrentBuffer()
if has("python3")
python3 << EOF
interface.update_note_from_current_buffer()
EOF
endif
endfunction

function! simplenote#SimpleNote(param, ...)
if has("python3")
    execute 'py3file ' . s:scriptpath . "/SimplenoteCmd.py" 
endif
endfunction
" vim: expandtab
