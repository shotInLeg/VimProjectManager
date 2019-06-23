function! vpm#IsProjectLoaded()
    if !exists('g:vpm#project_name')
        echo 'Run :VmpLoadProject <project_name> befor!!!'
        return 0
    endif
    return 1
endfunc


function! vpm#IsRemoteProjectLoaded()
    if !vpm#IsProjectLoaded() || !exists('g:vpm#remote_server') || !exists('g:vpm#remote_path')
        echo 'Run VmpLoadProject <project_name> befor!!!'
        return 0
    endif
    return 1
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


function! vpm#LoadListFiles(project_name, remote_server, remote_path, path_filters)
py3 << EOF
import os
import vim
import time
import subprocess
import multiprocessing


project_name = vim.eval('a:project_name')
remote_server = vim.eval('a:remote_server')
remote_path = vim.eval('a:remote_path')
path_filters = vim.eval('a:path_filters')


def strip(path):
    return path.strip().rstrip('/').rstrip('\\')


def popen_to_list_lines(subproc):
    return str(subproc.communicate()[0], 'utf-8').split('\n')


def get_dirs(server, path, depth):
    path = strip(path)
    args = ['find', path, '-type', 'd'] + ['-maxdepth', str(depth)] if depth else []
    nargs = args if server == 'localhost' else ['ssh', server, ' '.join(args)]
    subproc = subprocess.Popen(nargs, stdout=subprocess.PIPE)
    return subproc


def get_files(server, path, depth=None):
    path = strip(path)
    args = ['find', path, '-type', 'f'] + (['-maxdepth', str(depth)] if depth else [])
    nargs = args if server == 'localhost' else ['ssh', server, ' '.join(args)]
    subproc = subprocess.Popen(nargs, stdout=subprocess.PIPE)
    return subproc


def get_cache_file(project, chunk):
    return os.path.join(os.path.expanduser('~'), '.vim/.vpm.{}.cache.{}'.format(project, chunk))


def get_top_level_dirs_pool(server, path, top_level_dirs_count=0):
    path = strip(path)

    top_level_dirs = [(path, 1)]
    dirpaths = popen_to_list_lines(get_dirs(server, path, depth=1))

    dirs_count = len(dirpaths) + top_level_dirs_count
    if dirs_count < 4:
        top_level_dirs += [(x, 1) for x in dirpaths if x.strip() and strip(x) != path]

        for dirpath in dirpaths:
            top_level_dirs += get_top_level_dirs_pool(server, dirpath, dirs_count)
            dirs_count += len(dirpaths)
    else:
        top_level_dirs += [(x, None) for x in dirpaths if x.strip() and strip(x) != path]

    return top_level_dirs


def recurce_get_files(args_obj):
    project, server, path, cpu_count, args = args_obj
    idx, (dirpath, depth) = args
    chunk_num = idx % cpu_count

    count_files = 0
    subproc = get_files(server, dirpath, depth)
    with open(get_cache_file(project, chunk_num), 'w' if idx < cpu_count else 'a') as wfile:
        for filepath in popen_to_list_lines(subproc):
            filepath = filepath.strip().replace(path, '')
            if not filepath:
                continue
            wfile.write('{}\n'.format(filepath))
            count_files += 1
    return count_files


def load_list_remote_files(project, server, path, filteres):
    cpu_count = multiprocessing.cpu_count()
    top_level_dirs = get_top_level_dirs_pool(server, path)

    pool = multiprocessing.Pool(cpu_count)
    counts_files = pool.map(recurce_get_files, [(project, server, path, cpu_count, x) for x in enumerate(top_level_dirs)])
    count_files = sum(counts_files)

    return cpu_count, count_files


start = time.time()
chunks_count, files_count  = load_list_remote_files(project_name, remote_server, remote_path, path_filters)
vim.command('let s:chunkscount = {}'.format(chunks_count))
print('Loaded remote files: {} ({}s)'.format(files_count, time.time() - start))
EOF
endfunc


function! vpm#FindLoadedFilename(project_name, query)
    let search_results = []
py3 << EOF
import vim
import time
import multiprocessing

project_name = vim.eval('a:project_name')
search_query = vim.eval('a:query')
chunkscount = int(vim.eval('s:chunkscount'))

print(project_name, search_query, chunkscount)


def search_by_chunk(args):
    result = []
    project, chunk_num, query = args
    cachefile = os.path.join(
        os.path.expanduser('~'),
        '.vim/.vpm.{}.cache.{}'.format(project, chunk_num)

    )
    print(cachefile)
    with open(cachefile) as rfile:
        for line in rfile:
            line = line.strip()
            if not line:
                continue
            if len(result) > 20:
                break
            if query in line:
                result.append(line)
    return result


def search_filepaths(project, chunks_count, query):
    pool = multiprocessing.Pool(multiprocessing.cpu_count())
    search_result = pool.map(search_by_chunk, [(project, x, query) for x in range(chunks_count)])
    search_result = sum(search_result, [])

    return search_result


sre = search_filepaths(project_name, chunkscount, search_query)
print('Founded: {}'.format(len(sre)))
vim.command('let search_results = {}'.format(sre))
EOF
    echo search_results
    return search_results
endfunc
