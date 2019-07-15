function! s:OpenFilepath(filepath, buffer_busy)
    if a:buffer_busy == 'NONE'
        let buffer_busy = vpm#IsCurrentBufferBusy()
    endif

    let cmd = vpm#GetOpenFilepathCommand(a:filepath, a:buffer_busy)
    silent! exec cmd
endfunc


function! s:GrepInProject(...)
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let search_query = a:1
    if a:0 > 1
        let relpath = a:2
    else
        let relpath = ''
    endif

    let matched_lines = pyvpm#SearchSubstring(search_query, relpath)
    let s:buffer_busy = vpm#IsCurrentBufferBusy()

    if len(matched_lines) < 1
        call vpm#Echo('Pattern ' . search_query . ' not found')
        return 0
    endif

    cgetexpr matched_lines
    exe 'copen 10'
    let w:quickfix_title = 'vpm#codesearch'

    let b:statusline = 'Search code: ' . search_query
    setlocal statusline=%{b:statusline}
endfunc


function! g:SelectCodeSearchDialogItem()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let selected_line = getline('.')
    let line_parts = split(selected_line, '|')
    let filepath = line_parts[0]
    let position = split(line_parts[1], ' ')
    let number_line = position[0]

    if len(position) > 1
        let number_col = position[2]
    else
        let number_col = 0
    endif

    call g:CloseCodeSearchDialog()
    call s:OpenFilepath(filepath, s:buffer_busy)
    exec ":" . number_line
endfunc


function! g:CloseCodeSearchDialog()
    cclose
endfunc


function! g:GrepRelPath(query, relpath)
    call s:GrepInProject(a:query, a:relpath)
endfunc


command! -nargs=* VpmGrep :call s:GrepInProject(<f-args>)
