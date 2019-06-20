function! vpm#IsProjectLoaded()
    if !exists('g:vpm#project_name') || !exists('g:vpm#local_path')
        echo 'Run VmpLoadProject <project_name> befor!!!'
        return 1
    endif
    return 0
endfunc


function! vpm#IsRemoteProjectLoaded()
    if !vpm#IsProjectLoaded() || !exists('g:vpm#remote_server') || !exists('g:vpm#remote_path')
        echo 'Run VmpLoadProject <project_name> befor!!!'
        return 1
    endif
    return 0
endfunc


function! vpm#ShowProgress(prefix, percentage, postfix)
    execute "normal \<C-l>:\<C-u>"                                                                                  
    echon a:prefix . ' ' . a:percentage . '% [' . a:postfix . ']'
endfunc


function! vpm#FilterListFiles(all_files, path_filters)
    for pattern in a:path_filters
        call filter(a:all_files, 'match(v:val, "' . pattern . '") == -1')
    endfor
    return a:all_files
endfunc


function! vpm#SearchByListFiles(all_files, query)
    let searched = []
    for filepath in a:all_files
        if a:query == '' || len(split(filepath, a:query)) > 1
            call add(searched, filepath)
        endif
    endfor
    return searched
endfunc


function! vpm#GetListRemoteFiles(remote_server, remote_path, path_filters, ssh_flags)
    let list_remote_files_cmd = 'ssh ' . a:ssh_flags . ' ' . a:remote_server . ' find ' . a:remote_path . ' -type f'
    let all_remote_files = split(system(list_remote_files_cmd), '\n')
    return vpm#FilterListFiles(all_remote_files, a:path_filters)
endfunc


function! vpm#GetListLocalFiles(local_path, path_filters)
    let list_local_files_cmd = 'find ' . a:local_path . ' -type f'
    let all_local_files = split(system(list_local_files_cmd), '\n')
    return vpm#FilterListFiles(all_local_files, a:path_filters)
endfunc


function! vpm#DownloadRemote(remote_server, remote_path, local_path, scp_flags)
    let download_cmd = 'scp ' . a:scp_flags . ' ' . a:remote_server . ':' . a:remote_path . ' ' . a:local_path
    call system(download_cmd)
endfunc


function! vpm#UploadRemote(remote_server, remote_path, local_path, scp_flags)
    let upload_cmd = 'scp ' . a:scp_flags . ' ' . a:local_path . ' ' . a:remote_server . ':' . a:remote_path
    call system(upload_cmd)
endfunc
