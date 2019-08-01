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


function! s:SearchFilepath(search_query)
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call s:LoadProjectFilepathsDataIfNeeded()

    call vpm#Echo('Searching filepaths: ' . a:search_query)

    let matched_filepaths = pyvpm#SearchFilepath(a:search_query)
    
    if len(matched_filepargs) < 1
        call vpm#Echo('Couldnt not find filepaths matching ' . a:search_query)
        return 0
    endif

    cgetexpr matched_filepaths
    exe 'copen 10'
    let w:quickfix_title = 'vpm#searchfile'

    let b:statusline = 'Search file: ' . a:search_query
    setlocal statusline=%{b:statusline}

    return 1
endfunc


function! g:SearchFilepathDialog()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call s:LoadProjectFilepathsDataIfNeeded()

    let completer = vpm#GetFilepathNodeCompleter()
    let search_query = input('Search file: ', '', completer)

    silent! call s:SearchFilepath(search_query)

    return 1
endfunc


function! g:SelectSearchFilepathDialogItem()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let selected_line = getline('.')
    let filepath = substitute(selected_line, '|| ', '', 'g')

    call g:CloseSearchFilepathDialog()

    let buffer_busy = vpm#IsCurrentBufferBusy()
    call vpm#OpenFilepath(filepath, 'NONE')

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

    let buffer_busy = vpm#IsCurrentBufferBusy()
    let completer = vpm#GetFilepathCompleter()
    let filepath = input('Open file: ', '', completer)

    call s:OpenFilepath(filepath, 'NONE')
endfunc


function! s:AutoSetupFinderMapping()
    if g:vpm#enable_project_manager
        map <silent> <C-p> :call g:SearchFilepathDialog()<cr>
        map <silent> <C-o> :call g:OpenFilepathDialog()<cr>
    endif
endfunc


command! -nargs=? VpmLoadProjectData :call s:LoadProjectFilepathsData(1)
command! -nargs=? VpmReloadProjectData :call s:LoadProjectFilepathsData(0)
command! -nargs=? VpmSearchFilepath :call s:SearchFilepath('<args>')
command! -nargs=? VpmOpenFilepath :call vpm#OpenFilepath('<args>', 'NONE')


autocmd VimEnter * :call s:AutoSetupFinderMapping()
