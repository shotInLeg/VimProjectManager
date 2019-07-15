function! s:LoadProjectFilepathsData(lazy)
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    if g:vpm#project_type == 'remote'
        call pyvpm#LoadProjectFiles(a:lazy)
        return 1
    elseif g:vpm#project_type == 'local' || g:vpm#project_type == 'sync'
        call pyvpm#LoadProjectFiles(a:lazy)
        return 1
    endif

    return 0
endfunc


function! s:LoadProjectFilepathsDataIfNeeded()
    if !exists('s:project_filepaths_data_loaded') || !s:project_filepaths_data_loaded
        call s:LoadProjectFilepathsData(1)
        let s:project_filepaths_data_loaded = 1
    endif
endfunc


function! s:OpenFilepath(filepath, buffer_busy)
    if a:buffer_busy == 'NONE'
        let buffer_busy = vpm#IsCurrentBufferBusy()
    endif

    if a:filepath == ""
        return 0
    endif

    let cmd = vpm#GetOpenFilepathCommand(a:filepath, a:buffer_busy)
    silent! exec cmd

    return 1
endfunc


function! s:SearchFilepath(search_query)
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call s:LoadProjectFilepathsDataIfNeeded()

    call vpm#Echo('Searching filepaths: ' . a:search_query)

    let matched_filepargs = pyvpm#SearchFilepath(a:search_query)
    cgetexpr matched_filepargs
    exe 'copen 10'
    let w:quickfix_title = 'vpm#searchfile'

    let b:statusline = 'Search file: ' . a:search_query
    setlocal statusline=%{b:statusline}

    if len(getqflist()) < 1
        cclose
        call vpm#Echo('Couldnt not find filepaths matching ' . a:search_query)
    endif
endfunc


function! g:SearchFilepathDialog()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call s:LoadProjectFilepathsDataIfNeeded()

    let s:buffer_busy = vpm#IsCurrentBufferBusy()
    let completer = vpm#GetFilepathNodeCompleter()

    let search_query = input('Search file: ', '', completer)

    silent! call s:SearchFilepath(search_query)
endfunc


function! g:SelectSearchFilepathDialogItem()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let selected_line = getline('.')
    let filepath = substitute(selected_line, '|| ', '', 'g')

    call g:CloseSearchFilepathDialog()
    call s:OpenFilepath(filepath, s:buffer_busy)

    return 1
endfunc


function! g:CloseSearchFilepathDialog()
    cclose
    return 1
endfunc


function! g:OpenFilepathDialog()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let completer = vpm#GetFilepathCompleter()

    let filepath = input('Open file: ', '', completer)

    call s:OpenFilepath(filepath, 'NONE')
endfunc


function! s:AutoSetupFinder()
    if g:vpm#enable_project_manager
        map <silent> <C-p> :call g:SearchFilepathDialog()<cr>
        map <silent> <C-o> :call g:OpenFilepathDialog()<cr>
    endif
endfunc


command! -nargs=? VpmLoadProjectData :call s:LoadProjectFilepathsData(1)
command! -nargs=? VpmReloadProjectData :call s:LoadProjectFilepathsData(0)
command! -nargs=? VpmSearchFilepath :call s:SearchFilepath('<args>')
command! -nargs=? VpmOpenFilepath :call s:OpenFilepath('<args>')


autocmd VimEnter * :call s:AutoSetupFinder()
