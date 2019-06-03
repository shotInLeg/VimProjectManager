function! s:CheckLoadedProject()
    if !exists('s:remote_server') || !exists('s:remote_path') || !exists('s:local_path')
        echo 'Run VmpLoadProject <project_name> befor!!!'
        return 1
    endif
    return 0
endfunc


function! s:LoadProject(project_name)
    if !exists('g:vpm#remote#projects')
        echo 'Define g:vpm#remote#projects in your vimrc'
        return
    endif

    let config = g:vpm#remote#projects[a:project_name]
    
    if !has_key(config, 'local_path') || !has_key(config, 'remote_server') || !has_key(config, 'remote_path')
        echo 'Define remote_server, remote_path, local_path in g:vpm#remote#projects'
        return
    endif

    let s:remote_server = config['remote_server']
    let s:remote_path = config['remote_path']
    let s:local_path = config['local_path']
    let s:remote_path_filters = []
    let s:local_path_filters = []
    let s:upload_on_save = 0
    exec 'cd ' . s:local_path

    if has_key(config, 'remote_path_filters')
        let s:remote_path_filters = config['remote_path_filters']
    endif

    if has_key(config, 'local_path_filters')
        let s:local_path_filter = config['local_path_filters']
    endif

    if has_key(config, 'upload_on_save')
        let s:upload_on_save = config['upload_on_save']
    endif
endfunc


function! s:LoadProjectByCwd()
    let cwd = getcwd(0)
    let cwd_s = cwd . '/'
    for project_name in keys(g:vpm#remote#projects)
        let config = g:vpm#remote#projects[project_name]

        if !has_key(config, 'local_path') || !has_key(config, 'remote_server') || !has_key(config, 'remote_path')
            continue
        endif

        if config['local_path'] == cwd || config['local_path'] == cwd_s
            call s:LoadProject(project_name)
            return
        endif
    endfor

    echo 'Not found config for ' . cwd
endfunc


function! s:DownloadProject()
    if s:CheckLoadedProject()
        return
    endif

    let all_remote_files = s:GetListRemoteFiles(s:remote_server, s:remote_path, s:remote_path_filters, '')

    let counter = 0
    for remote_filepath in all_remote_files
        let local_filepath = substitute(remote_filepath, s:remote_path, s:local_path, 'g')
        let local_filebasedir = fnamemodify(local_filepath, ':h')

        if empty(glob(local_filebasedir))
            let mkdir_cmd = 'mkdir -p ' . local_filebasedir
            call system(mkdir_cmd)
        endif

        call s:DownloadRemote(s:remote_server, remote_filepath, local_filepath, '')
        
        " Show progress
        let counter = counter + 1
        let progess = counter * 100 / len(all_remote_files)
        let relative_filepath = substitute(remote_filepath, s:remote_path, '', 'g')
        call s:ShowProgress('Downloaded', progess, relative_filepath)
    endfor
    call s:ShowProgress('Downloaded', 100, 'ALL DONE')
endfunc


function! s:UploadFile()
    if s:CheckLoadedProject()
        return
    endif

    let local_filepath = fnamemodify(expand('%'), ':p')
    let remote_filepath = substitute(local_filepath, s:local_path, s:remote_path, 'g')

    call s:UploadRemote(s:remote_server, remote_filepath, local_filepath, '')

    let relative_filepath = substitute(local_filepath, s:local_path, '', 'g')
    call s:ShowProgress('Uploaded', 100, relative_filepath)
endfunc


function! s:AutoUploadFile()
    if exists('s:upload_on_save') && s:upload_on_save
        call s:UploadFile()
    endif
endfunc


function! s:AutoLoadConfigByCwd()
    if exists('g:vpm#remote#autoload_project') && g:vpm#remote#autoload_project
        silent! call s:LoadProjectByCwd()
    endif
endfunc


function! s:AutoEnableProjectManager()
    if exists('g:vpm#enable_project_manager') && g:vpm#enable_project_manager 
        autocmd VimEnter * :call s:AutoLoadConfigByCwd()
        autocmd BufWritePost * :call s:AutoUploadFile()
        autocmd BufRead scp://* :set bt=acwrite
    endif
endfunc


command! -nargs=* VpmRemoteLoad :call s:LoadProject(<f-args>)
command! -nargs=* VpmRemoteLoadByCwd :call s:LoadProjectByCwd()
command! -nargs=0 VpmRemoteDownloadProject :call s:DownloadProject()
command! -nargs=0 VpmRemoteUploadFile :call s:UploadFile()


autocmd VimEnter * :call s:AutoEnableProjectManager()
