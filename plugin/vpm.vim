if !exists('g:vpm#enable_project_manager')
    let g:vpm#enable_project_manager = 0
endif

if !exists('g:vpm#autoload_project_by_cwd')
    let g:vpm#autoload_project_by_cwd = 0
endif

if !exists('g:vpm#projects')
    let g:vpm#projects = {}
endif

if !exists('g:vpm#project_name')
    let g:vpm#project_name = ''
endif

if !exists('g:vpm#project_type')
    let g:vpm#project_type = ''
endif

if !exists('g:vpm#remote_server')
    let g:vpm#remote_server = ''
endif

if !exists('g:vpm#remote_path')
    let g:vpm#remote_path = ''
endif

if !exists('g:vpm#local_path')
    let g:vpm#local_path = ''
endif

if !exists('g:vpm#remote_path_filters')
    let g:vpm#remote_path_filters = []
endif

if !exists('g:vpm#local_path_filters')
    let g:vpm#local_path_filters = []
endif

if !exists('g:vpm#upload_on_save')
    let g:vpm#upload_on_save = 0
endif
