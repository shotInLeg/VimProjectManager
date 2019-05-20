function! s:CheckLoadedConfig()
    if !exists('s:remote_server') || !exists('s:remote_project_path') || !exists('s:local_project_path')
        echo 'Run ScpLoadFromConfig <project_name> befor!!!'
        return 1
    endif
    return 0
endfunc


function! s:ShowProgress(prefix, percentage, postfix)
    execute "normal \<C-l>:\<C-u>"                                                                                  
    echon a:prefix . ' ' . a:percentage . '% [' . a:postfix . ']'
endfunc


function! s:GetRemoteFiles(server, remote_path, path_filter, flags)
    if a:flags == ''
        let flags = '-type f'
    else
        let flags = a:flags
    endif

    let list_remote_files_cmd = 'ssh ' . a:server . ' find ' . a:remote_path . ' ' . flags
    let all_remote_files = split(system(list_remote_files_cmd), '\n')

    for pattern in a:path_filter
        call filter(all_remote_files, 'match(v:val, "' . pattern . '") == -1')
    endfor

    return all_remote_files
endfunc


function! s:GetLocalFiles(local_path, path_filter, flags)
    if a:flags == ''
        let flags = '-type f'
    else
        let flags = a:flags
    endif

    let list_local_files_cmd = 'find ' . a:local_path . ' ' . flags
    let all_local_files = split(system(list_local_files_cmd), '\n')

    for pattern in a:path_filter
        call filter(all_local_files, 'match(v:val, "' . pattern . '") == -1')
    endfor

    return all_local_files
endfunc


function! s:DownloadRemote(server, remote_path, local_path, flags)
    let download_cmd = 'scp ' . a:flags . ' ' . a:server . ':' . a:remote_path . ' ' . a:local_path
    call system(download_cmd)
endfunc


function! s:UploadRemote(server, remote_path, local_path, flags)
    let upload_cmd = 'scp ' . a:flags . ' ' . a:local_path . ' ' . a:server . ':' . a:remote_path
    call system(upload_cmd)
endfunc


function! s:LoadConfig(project_name)
    if !exists('g:scp_sync_config')
        echo 'Define g:scp_sync_config in your vimrc'
        return
    endif

    let config = g:scp_sync_config[a:project_name]
    
    if !has_key(config, 'local_project_path') || !has_key(config, 'remote_server') || !has_key(config, 'remote_project_path')
        echo 'Define local_project_path, remote_server, remote_project_path in g:scp_sync_config'
        return
    endif

    let s:remote_server = config['remote_server']
    let s:remote_project_path = config['remote_project_path']
    let s:local_project_path = config['local_project_path']
    let s:remote_project_filter = []
    let s:local_project_filter = []
    let s:auto_upload_on_save = 0
    exec 'cd ' . g:local_project_path

    if has_key(config, 'remote_project_filter')
        let s:remote_project_filter = config['remote_project_filter']
    endif

    if has_key(config, 'local_project_filter')
        let s:local_project_filter = config['local_project_filter']
    endif

    if has_key(config, 'auto_upload_on_save')
        let s:auto_upload_on_save = config['auto_upload_on_save']
    endif
endfunc


function! s:LoadConfigByCwd()
    let cwd = getcwd(0)
    let cwd_s = cwd . '/'
    for project_name in keys(g:scp_sync_config)
        let config = g:scp_sync_config[project_name]

        if !has_key(config, 'local_project_path') || !has_key(config, 'remote_server') || !has_key(config, 'remote_project_path')
            continue
        endif

        if config['local_project_path'] == cwd || config['local_project_path'] == cwd_s
            call s:LoadConfig(project_name)
            return
        endif
    endfor

    echo 'Not found config for ' . cwd
endfunc


function! s:DownloadProject()
    if s:CheckLoadedConfig()
        return
    endif

    let all_remote_files = s:GetRemoteFiles(s:remote_server, s:remote_project_path, s:remote_project_filter, '')

    let counter = 0
    for remote_filepath in all_remote_files
        let local_filepath = substitute(remote_filepath, s:remote_project_path, s:local_project_path, 'g')
        let local_filebasedir = fnamemodify(local_filepath, ':h')

        if empty(glob(local_filebasedir))
            let mkdir_cmd = 'mkdir -p ' . local_filebasedir
            call system(mkdir_cmd)
        endif

        call s:DownloadRemote(s:remote_server, remote_filepath, local_filepath, '')
        
        " Show progress
        let counter = counter + 1
        let progess = counter * 100 / len(all_remote_files)
        let relative_filepath = substitute(remote_filepath, s:remote_project_path, '', 'g')
        call s:ShowProgress('Downloaded', progess, relative_filepath)
    endfor
    call s:ShowProgress('Downloaded', 100, 'ALL DONE')
endfunc


function! s:UploadFile()
    if s:CheckLoadedConfig()
        return
    endif

    let local_filepath = fnamemodify(expand('%'), ':p')
    let remote_filepath = substitute(local_filepath, s:local_project_path, s:remote_project_path, 'g')

    call s:UploadRemote(s:remote_server, remote_filepath, local_filepath, '')

    let relative_filepath = substitute(local_filepath, s:local_project_path, '', 'g')
    call s:ShowProgress('Uploaded', 100, relative_filepath)
endfunc


function! s:AutoUploadFile()
    if exists('s:auto_upload_on_save') && s:auto_upload_on_save == 1
        call s:UploadFile()
    endif
endfunc


function! s:AutoLoadConfigByCwd()
    if exists('g:scp_sync_auto_load_config_by_cwd') && g:scp_sync_auto_load_config_by_cwd == 1
        call s:LoadConfigByCwd()
    endif
endfunc


command! -nargs=* ScpLoadFromConfig :call s:LoadConfig(<f-args>)
command! -nargs=* ScpLoadConfigByCwd :call s:LoadConfigByCwd()
command! -nargs=0 ScpDownloadProject :call s:DownloadProject()
command! -nargs=0 ScpUploadFile :call s:UploadFile()

autocmd VimEnter * :call s:AutoLoadConfigByCwd()
autocmd BufWritePost * :call s:AutoUploadFile()
" autocmd BufReadPre * :call SftpAutoDownload()
