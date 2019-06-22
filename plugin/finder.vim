function! s:SearchFinderDialog(name, query, all_files)
    silent! execute "botright pedit " . a:name
    noautocmd wincmd P
    set buftype=nofile

    let cwd = getcwd()
    for filepath in vpm#SearchByListFiles(a:all_files, a:query)
        let shorted_filepath = substitute(filepath, cwd . '/', '', 'g')
        silent! execute "r! echo " . shorted_filepath
    endfor
    silent! execute "redraw!"

    let search_query = input('>>> ')
    call s:SearchFinderDialog(a:name, search_query, a:all_files)
endfunc


function! s:OpenLocalFinderDialog(name)
    vpm#GetListLocalFiles(getcwd(), )
    let find_cmd = 'find ' . getcwd() . ' -type f'
    let all_files = split(system(find_cmd), '\n')

    echom len(all_files[0])

    call s:SearchFinderDialog(a:name, '', all_files)
endfunc


function! s:LoadListRemoteFilepaths()
    call vpm#LoadListRemoteFiles(g:vpm#project_name, g:vpm#remote_server, g:vpm#remote_path, g:vpm#remote_path_filters)
endfunc


function! s:SearchRemoteFilepath(name, query)
    silent! execute "botright pedit " . a:name
    noautocmd wincmd P
    set buftype=nofile

    if a:query != ''
        for filepath in vpm#FindLoadedFilename(g:vpm#project_name, a:query)
            let shorted_filepath = substitute(filepath, g:vpm#remote_path . '/', '', 'g')
            silent! execute "r! echo " . shorted_filepath
        endfor
    endif
    silent! execute "redraw!"

    let search_query = input('>>> ')
    call s:SearchRemoteFilepath(a:name, search_query)
endfunc


command! -nargs=? VpmLoadRemoteFilepaths :call s:LoadListRemoteFilepaths()
command! -nargs=? VpmSearchFilepaths :call s:SearchRemoteFilepath('search', '')
