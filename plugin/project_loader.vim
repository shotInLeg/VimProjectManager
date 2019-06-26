function! s:LoadProjectByCwd()
    if !exists('g:vpm#projects')
        return 0
    endif

    let cwd = getcwd(0)
    let cwd_s = cwd . '/'

    for project_name in keys(g:vpm#projects)
        let config = g:vpm#projects[project_name]

        if !has_key(config, 'local_path')
            continue
        endif

        if (config['local_path'] == cwd || config['local_path'] == cwd_s) && s:LoadProject(project_name) != 0
            echo 'Project ' . project_name . ' loaded'
            return 1
        endif
    endfor

    echo 'Not found config for ' . cwd
    return 0
endfunc


function! s:LoadProject(project_name)
    if !exists('g:vpm#projects')
        call vpm#Echo('Define g:vpm#projects in your vimrc')
        return 0
    endif

    if !has_key(g:vpm#projects, a:project_name)
        call vpm#Echo('Project ' . a:project_name . ' not found in g:vpm#projects')
        return 0
    endif

    let config = g:vpm#projects[a:project_name]

    let g:vpm#project_name = ''
    let g:vpm#project_type = ''
    let g:vpm#remote_server = ''
    let g:vpm#remote_path = ''
    let g:vpm#local_path = ''
    let g:vpm#remote_path_filters = []
    let g:vpm#local_path_filters = []
    let g:vpm#upload_on_save = 0

    if has_key(config, 'remote_server') && has_key(config, 'remote_path')
        call s:LoadRemoteProject(a:project_name, config)
        let g:vpm#project_type = 'remote'
    elseif has_key(config, 'local_path')
        call s:LoadLocalProject(a:project_name, config)
        let g:vpm#project_type = 'local'
    else
        call vpm#Echo('Define local_path in g:vpm#projects')
        return 0
    endif

    let g:vpm#project_name = a:project_name
    exec 'cd ' . g:vpm#local_path

    call vpm#Echo('Loaded project ' . g:vpm#project_name . '(' . g:vpm#project_type . ')')
    return 1
endfunc


function! s:LoadRemoteProject(project_name, project_config)
    let g:vpm#remote_server = a:project_config['remote_server']
    let g:vpm#remote_path = a:project_config['remote_path']

    if has_key(a:project_config, 'local_path')
        let g:vpm#local_path = a:project_config['local_path']
    endif

    if has_key(a:project_config, 'remote_path_filters')
        let g:vpm#remote_path_filters = a:project_config['remote_path_filters']
    endif

    if has_key(a:project_config, 'local_path_filters')
        let g:vpm#local_path_filters = a:project_config['local_path_filters']
    endif

    if has_key(a:project_config, 'upload_on_save')
        let g:vpm#upload_on_save = a:project_config['upload_on_save']
    endif
endfunc


function! s:LoadLocalProject(project_name, project_config)
    let g:vpm#local_path = a:project_config['local_path']
    let g:vpm#local_path_filters = []

    if has_key(a:project_config, 'local_path_filters')
        let g:vpm#local_path_filters = a:project_config['local_path_filters']
    endif
endfunc


function! s:LoadProjectDialog()
    let project_name = input('Load project: ', '', 'customlist,vpm#ProjectNamesCompleter')
    if project_name != ''
        call s:LoadProject(project_name)
    endif
endfunc


function! s:AutoLoadProjectByCwd()
    if exists('g:vpm#autoload_project_by_cwd') && g:vpm#autoload_project_by_cwd
        silent! call s:LoadProjectByCwd() 
    endif
endfunc


function! s:AutoSetupProjectLoader()
    if g:vpm#enable_project_manager
        call s:AutoLoadProjectByCwd()
        map <silent> <C-n> :VpmLoadProjectDialog<cr>
    endif
endfunc


command! -nargs=? VpmLoadProject :call s:LoadProject('<args>')
command! -nargs=? VpmLoadProjectByCwd :call s:LoadProjectByCwd()
command! -nargs=? VpmLoadProjectDialog :call s:LoadProjectDialog()


autocmd VimEnter * :call s:AutoSetupProjectLoader()
