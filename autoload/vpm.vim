function! vpm#Echo(text)
    redraw
    echon a:text
    redraw
endfunc


function! vpm#ShowProgress(prefix, percentage, postfix)
    call vpm#Echo(a:prefix . ' ' . a:percentage . '% [' . a:postfix . ']')
endfunc


function! vpm#IsProjectLoaded()
    if !exists('g:vpm#project_name') || g:vpm#project_name == ''
        call vpm#Echo('Run VmpLoadProject <project_name> befor!!!')
        return 0
    endif
    return 1
endfunc


function! vpm#IsRemoteProjectLoaded()
    if !vpm#IsProjectLoaded() || !exists('g:vpm#remote_server') || !exists('g:vpm#remote_path')
        call vpm#Echo('Run VmpLoadProject <project_name> befor!!!')
        return 0
    endif
    return 1
endfunc


function! vpm#IsCurrentBufferBusy() 
    if bufname('%') != ''
        return 1
    endif

    let buflist = tabpagebuflist(tabpagenr())
    for bufnr in buflist
        if getbufvar(bufnr, '&modified')
            return 1
        endif
    endfor
    return 0
endfunc


function! vpm#ProjectNamesCompleter(A, L, P)
    if !exists('g:vpm#projects')
        return []
    endif

    let all_files = []
    for project_name in keys(g:vpm#projects)
        call add(all_files, project_name)
    endfor

    call filter(all_files, 'match(v:val, "^' . a:A . '") != -1')
    return all_files
endfunc


function! vpm#GetFilepathCompleter()
    if g:vpm#project_type == 'remote'
        return 'customlist,pyvpm#RemoteFilepathCompleter'
    else
        return 'file'
    endif
endfunc


function! vpm#GetFilepathNodeCompleter()
    if g:vpm#project_type == 'remote'
        return 'customlist,pyvpm#FilepathNodeCompleter'
    else
        return 'customlist,pyvpm#FilepathNodeCompleter'
    endif
endfunc


function! vpm#GetOpenFilepathCommand(filepath, buffer_busy)
    if a:buffer_busy
        let cmd = 'tabe'
    else
        let cmd = 'e'
    endif

    if g:vpm#project_type == 'remote'
        let cmd = cmd . ' scp://' . g:vpm#remote_server . '/' . g:vpm#remote_path . '/' . a:filepath
    elseif g:vpm#project_type == 'local' || g:vpm#project_type == 'sync'
        let cmd = cmd . ' ' . g:vpm#local_path . '/' . a:filepath
    endif

    return cmd
endfunc


function! vpm#OpenFilepath(filepath, buffer_busy)
    if a:buffer_busy == 'NONE'
        let buffer_busy = vpm#IsCurrentBufferBusy()
    endif

    if a:filepath == ""
        return 0
    endif

    let filepath_parts = split(a:filepath, ':')
    let [filepath, row_number, col_number] = [filepath_parts[0], 0, 0]
    if len(filepath_parts) > 1
        let row_number = filepath_parts[1]
    endif
    if len(filepath_parts) > 2
        let col_number = filepath_parts[2] 
    endif
 
    silent! exec vpm#GetOpenFilepathCommand(filepath, a:buffer_busy)
    silent! call cursor(row_number, col_number)

    return 1
endfunc


function! vpm#SelectQuickfixItem()
    if exists('w:quickfix_title') && w:quickfix_title == 'vpm#codesearch'
        call g:SelectCodeSearchDialogItem()
    elseif exists('w:quickfix_title') && w:quickfix_title == 'vpm#searchfile'
        call g:SelectSearchFilepathDialogItem()
    endif
endfunc


function! vpm#CloseQuickfixItem()
    if exists('w:quickfix_title') && w:quickfix_title == 'vpm#codesearch'
        call g:CloseCodeSearchDialog()
    elseif exists('w:quickfix_title') && w:quickfix_title == 'vpm#searchfile'
        call g:CloseSearchFilepathDialog()
    else
        cclose
    endif
endfunc
