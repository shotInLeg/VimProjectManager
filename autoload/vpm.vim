function! vpm#Echo(text)
    execute "normal \<C-l>:\<C-u>"                                                                                  
    echon a:text
endfunc


function! vpm#ShowProgress(prefix, percentage, postfix)
    call vpm#Echo(a:prefix . ' ' . a:percentage . '% [' . a:postfix . ']')
endfunc


function! vpm#IsProjectLoaded()
    if !exists('g:vpm#project_name') || !g:vpm#project_name
        call vpm#Echo('Run VmpLoadProject <project_name> befor!!!')
        return 0
    endif
    return 1
endfunc


function! vpm#IsRemoteProjectLoaded()
    if !vpm#IsProjectLoaded() || !exists('g:vpm#remote_server') || !exists('g:vpm#remote_path')
        call vpm#Echo('Run VmpLoadProject <project_name> befor!!!')
        return 0
    endif
    return 1
endfunc


function! vpm#IsCurrentBufferBusy() 
    if bufname('%') != ''
        return 1
    endif

    let buflist = tabpagebuflist(tabpagenr())
    for bufnr in buflist
        if getbufvar(bufnr, '&modified')
            return 1
        endif
    endfor
    return 0
endfunc


function! vpm#ProjectNamesCompleter(A, L, P)
    if !exists('g:vpm#projects')
        return []
    endif

    let all_files = []
    for project_name in keys(g:vpm#projects)
        echom project_name
        call add(all_files, project_name)
    endfor

    call filter(all_files, 'match(v:val, "^' . a:A . '") != -1')
    return all_files
endfunc


function! vpm#RemoteFilepathCompleter(A, P, L)
    let prefix = ''
    let root_tree = g:vpm#project_filepaths_tree

    if substitute(a:A, '/', '', 'g') == a:A
        let last_item = a:A
    else
        let splitted_items = split(a:A, '/')
        let last_item = splitted_items[-1]
        for item in splitted_items[:-1]
            if has_key(root_tree, item)
                let root_tree = root_tree[item]
                let prefix = prefix . item . '/'
            else
                break
            endif
        endfor
    endif

    let list_candidates = []
    for item in keys(root_tree)
        call add(list_candidates, item)
    endfor
    let list_candidates = filter(list_candidates, 'match(v:val, "^' . last_item . '") != -1')

    let list_completions = []
    for item in list_candidates
        call add(list_completions, prefix . item)
    endfor

    return list_completions
endfunc


function! vpm#GetFilepathCompleter()
    if g:vpm#project_type == 'remote'
        return 'customlist,vpm#RemoteFilepathCompleter'
    else
        return 'file'
    endif
endfunc


function! vpm#GetOpenFilepathCommand(filepath, buffer_busy)
    if a:buffer_busy
        let cmd = 'tabe'
    else
        let cmd = 'e'
    endif

    if g:vpm#project_type == 'remote'
        let cmd = cmd . ' scp://' . g:vpm#remote_server . '/' . g:vpm#remote_path . '/' . a:filepath
    elseif g:vpm#project_type == 'local' || g:vpm#project_type == 'sync'
        let cmd = cmd . ' ' . g:vpm#local_path . '/' . a:filepath
    endif

    return cmd
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
import re
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


def macth_path_filters(filepath, path_filters):
    for pattern in path_filters:
        m = re.match(pattern, filepath)
        if m:
            return m
    return None


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
            if not filepath or macth_path_filters(filepath, path_filters):
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
vim.command('call vpm#Echo("Loaded remote files: {} ({}s)")'.format(files_count, time.time() - start))
EOF
endfunc


function! vpm#LoadFilepathsTree(project_name)
    let filepaths_tree = {}
py3 << EOF
import vim
import time
import multiprocessing

project_name = vim.eval('a:project_name')
chunkscount = int(vim.eval('s:chunkscount'))


def tree_by_chunk(args):
    result = {}
    project, chunk_num = args
    cachefile = os.path.join(
        os.path.expanduser('~'),
        '.vim/.vpm.{}.cache.{}'.format(project, chunk_num)

    )
    with open(cachefile) as rfile:
        for line in rfile:
            line = line.strip()
            if not line:
                continue
 
            root = result
            for item in line.split('/'):
                if item not in root:
                    root[item] = {}
                root = root[item]
    return result


def tree_filepaths(project, chunks_count):
    pool = multiprocessing.Pool(multiprocessing.cpu_count())
    filepaths_trees = pool.map(tree_by_chunk, [(project, x) for x in range(chunks_count)])
    filepaths_tree = {}
    for tree in filepaths_trees:
        filepaths_tree.update(tree)
    return filepaths_tree


start = time.time()
tree = tree_filepaths(project_name, chunkscount)
vim.command('let filepaths_tree = {}'.format(tree))
vim.command('call vpm#Echo("Filepaths tree loaded: {}s")'.format(time.time() - start))
EOF
    let g:vpm#project_filepaths_tree = filepaths_tree
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
