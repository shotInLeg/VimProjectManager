function! s:LoadProjectFilepathsData()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    if g:vpm#project_type == 'remote'
        call vpm#LoadListFiles(g:vpm#project_name, g:vpm#remote_server, g:vpm#remote_path, g:vpm#remote_path_filters)
        call vpm#LoadFilepathsTree(g:vpm#project_name)
        return 1
    elseif g:vpm#project_type == 'local' || g:vpm#project_type == 'sync'
        call vpm#LoadListFiles(g:vpm#project_name, 'localhost', g:vpm#local_path, g:vpm#local_path_filters)
        return 1
    endif

    return 0
endfunc



function! s:LoadProjectFilepathsDataIfNeeded()
    if !exists('s:project_filepaths_data_loaded') || !s:project_filepaths_data_loaded
        call s:LoadProjectFilepathsData()
        let s:project_filepaths_data_loaded = 1
    endif
endfunc


function! s:OpenFilepath(filepath, buffer_busy)
    if a:buffer_busy == 'NONE'
        let buffer_busy = vpm#IsCurrentBufferBusy()
    endif

    let cmd = vpm#GetOpenFilepathCommand(a:filepath, a:buffer_busy)
    silent! exec cmd
endfunc


function! s:SearchFilepath(search_query)
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call s:LoadProjectFilepathsDataIfNeeded()

    call vpm#Echo('Searching filepaths: ' . a:search_query)
    redraw

    let matched_filepargs = vpm#FindLoadedFilename(g:vpm#project_name, a:search_query)
    cgetexpr matched_filepargs
    exe 'copen 10'

    let b:statusline = 'Search file: ' . a:search_query
    setlocal statusline=%{b:statusline}

    if len(getqflist()) < 1
        cclose
        call vpm#Echo('Couldnt not find filepaths matching ' . a:search_query)
    endif
endfunc


function! s:SearchFilepathDialog()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call s:LoadProjectFilepathsDataIfNeeded()

    let s:buffer_busy = vpm#IsCurrentBufferBusy()
    let completer = vpm#GetFilepathCompleter()

    let search_query = input('Search file: ', '', completer)

    silent! call s:SearchFilepath(search_query)
endfunc


function! SelectSearchFilepathDialogItem()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let selected_line = getline('.')
    let filepath = substitute(selected_line, '|| ', '', 'g')

    call CloseSearchFilepathDialog()
    call s:OpenFilepath(filepath, s:buffer_busy)
endfunc


function! CloseSearchFilepathDialog()
    cclose
endfunc


function! s:OpenFilepathDialog()
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
        map <silent> <C-p> :VpmSearchFilepathDialog<cr>
        map <silent> <C-o> :echo "AHAHAH"<cr>:VpmOpenFilepathDialog<cr>
        autocmd BufReadPost quickfix map <silent> <Enter> :call SelectSearchFilepathDialogItem()<cr>
        autocmd BufReadPost quickfix map <silent> t :call SelectSearchFilepathDialogItem()<cr>
        autocmd BufReadPost quickfix map <silent> q :call CloseSearchFilepathDialog()<cr>
    endif
endfunc


command! -nargs=? VpmLoadProjectFilepathsData :call s:LoadProjectFilepathsData()
command! -nargs=? VpmSearchFilepathDialog :call s:SearchFilepathDialog()
command! -nargs=? VpmOpenFilepathDialog :call s:OpenFilepathDialog()
command! -nargs=? VpmSearchFilepath :call s:SearchFilepath('<args>')
command! -nargs=? VpmOpenFilepath :call s:OpenFilepath('<args>')


autocmd VimEnter * :call s:AutoSetupFinder()
