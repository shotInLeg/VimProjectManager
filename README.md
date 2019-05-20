# vim-scp-sync
[ Vim Script ] Scp project sync for Vim

## Install

Vundle
```vim
Plugin 'shotInLeg/vim-scp-sync'
```

## Settings
```vim
let g:scp_sync_auto_load_config_by_cwd = 0
let g:scp_sync_config = {
\    'project_name': {
\        'remote_server': 'myserver.mydomain.ru',
\        'local_project_path': '/local/absolute/path/to/project/',
\        'remote_project_path': '/remote/absolute/path/to/project/',
\        'remote_project_filter': ['.pyc$'],
\        'auto_upload_on_save': 0
\    }
\}
```

**g:scp_sync_auto_load_config_by_cwd** - Search project for load by matching cwd and local_project_path on start vim.
**g:scp_sync_config['project_name']['remote_server']** - Remote server address (ip, dns)
**g:scp_sync_config['project_name']['local_project_path']** - Local absolute path to project
**g:scp_sync_config['project_name']['remote_project_path']** - Remote absolute path to project
**g:scp_sync_config['project_name']['remote_project_filter']** - List patterns for skip on download
**g:scp_sync_config['project_name']['auto_upload_on_save']** - Run upload to remote server on save file


## Using

Active project
```vim
:ScpLoadFromConfig project_name
```

Download project from remote server
```vim
:ScpDownloadProject
```

Upload file to remote server
```vim
:ScpUploadFile
```
