function! s:LoadListFilepaths()
    if !vpm#IsProjectLoaded()
        echom "Project not loaded"
        return 0
    endif

    if g:vpm#project_type == 'remote'
        call vpm#LoadListFiles(g:vpm#project_name, g:vpm#remote_server, g:vpm#remote_path, g:vpm#remote_path_filters)
        return 1
    elseif g:vpm#project_type == 'local'
        call vpm#LoadListFiles(g:vpm#project_name, 'localhost', g:vpm#local_path, g:vpm#local_path_filters)
        return 1
    endif

    return 0
endfunc


function! s:SearchFilepath(name, query)
    echom "Searching filepaths: " . a:query
    let matched_filepargs = vpm#FindLoadedFilename(g:vpm#project_name, a:query)
    cgetexpr matched_filepargs
    exe 'copen 10'

    let b:csearch_args = a:query
    setlocal statusline=%{b:csearch_args}

    if len(getqflist()) < 1
        cclose
        echohl ErrorMsg | echo "Couldn't find code matching '" . a:args . "'" | echohl None
    endif
endfunc


function! ShowOpenDialog()
    if !vpm#IsProjectLoaded()
        echom "Project not loaded"
        return 0
    endif

    let filepath = input('>>> ')
    if g:vpm#project_type == 'remote'
        let cmd = 'tabe scp://' . g:vpm#remote_server . '/' . g:vpm#remote_path . '/' . filepath
    elseif g:vpm#project_type == 'local'
        let cmd = 'tabe ' . g:vpm#local_path . '/' . filepath
    endif
    silent! exec cmd
endfunc


function! ShowSearchDialog()
    if !vpm#IsProjectLoaded()
        echom "Project not loaded"
        return 0
    endif

    if !exists('s:init')
        call s:LoadListFilepaths()
        let s:init = 1
    endif

    let search_query = input('>>> ')
    silent! call s:SearchFilepath('search', search_query)
endfunc


function! SelectSearchDialogItem()
    if !vpm#IsProjectLoaded()
        echom "Project not loaded"
        return 0
    endif

    let selected_line = getline('.')
    let filepath = substitute(selected_line, '|| ', '', 'g')
    if g:vpm#project_type == 'remote'
        let cmd = 'tabe scp://' . g:vpm#remote_server . '/' . g:vpm#remote_path . '/' . filepath
    elseif g:vpm#project_type == 'local'
        let cmd = 'tabe ' . g:vpm#local_path . '/' . filepath
    endif
    cclose
    silent! exec cmd
endfunc


function! CloseSearchDialog()
    cclose
endfunc


command! -nargs=? VpmLoadFilepaths :call s:LoadListFilepaths()
command! -nargs=? VpmSearchFilepaths :call s:ShowSearchDialog()

map <C-p> :call ShowSearchDialog()<cr>
map <C-o> :call ShowOpenDialog()<cr>
autocmd BufReadPost quickfix map <Enter> :call SelectSearchDialogItem()<cr>
autocmd BufReadPost quickfix map t :call SelectSearchDialogItem()<cr>
autocmd BufReadPost quickfix map q :call CloseSearchDialog()<cr>
