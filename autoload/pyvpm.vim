function! pyvpm#Init()
py3 << EOF
import os
import vim
import time
import json
import subprocess
import multiprocessing


class ProjectData(object):
    CPU_COUNT = multiprocessing.cpu_count()
    LOCAL = 'local'
    REMOTE = 'remote'

    def __init__(self, project_name, project_type,
                 local_path=None, local_path_filters=None,
                 remote_server=None, remote_path=None, remote_path_filters=None, ram_storage=True):
        self.project_name = project_name
        self.project_type = project_type
        self.local_path = local_path.strip().rstrip('/')
        self.local_path_filters = local_path_filters
        self.remote_server = remote_server
        self.remote_path = remote_path.strip().rstrip('/')
        self.remote_path_filters = remote_path_filters
        self.ram_storage = ram_storage

        self.ssh_args = [self.remote_server] if self.project_type == self.REMOTE else None

        self.project_files = []
        self.project_dirs = []
        self.project_nodes = set()
        self.project_hierarchy = {}

    def load_project_data(self):
        load_start_time = time.time()
        part_start_time = time.time()

        self._show_progress('Loading...', 1, load_start_time, part_start_time, 'calculating find filepaths plan')
        part_start_time = time.time()

        root_path = self.local_path if self.project_type == self.LOCAL else self.remote_path
        path_filters = self.local_path_filters if self.project_type == self.LOCAL else self.remote_path_filters
        
        plan = self._calc_find_plan(root_path)
        pool = multiprocessing.Pool(self.CPU_COUNT)

        self._show_progress('Loading...', 30, load_start_time, part_start_time, 'multiprocessing finding filepaths')
        part_start_time = time.time()

        all_files = pool.map(self._get_files, [(root_path, path, depth, path_filters) for path, depth in plan])
        all_files = sum(all_files, [])

        self._show_progress('Loading...', 60, load_start_time, part_start_time, 'calculating 2 indexes')
        part_start_time = time.time()

        self.project_files = all_files
        self.project_dirs = list({'/'.join(x.split('/')[:-1]) for x in self.project_files if len(x.split('/')) > 1})
        self.project_hierarchy, self.project_nodes = self._calc_structure(self.project_files)

        self._show_progress('Loading done', 100, load_start_time, part_start_time, 'loaded {} files'.format(
            len(self.project_files)
        ))

    def search_filepath(self, query, limit=100):
        founded = []
        for filepath in self.project_files:
            if query in filepath:
                founded.append(filepath)
            if len(founded) >= limit:
                break
        return founded

    def search_substring(self, query, relpath='', limit=100):
        load_start_time = time.time()
        
        root_path = self.local_path if self.project_type == self.LOCAL else self.remote_path
        full_path = '{}/{}'.format(root_path, relpath) if relpath else root_path

        matches = self._get_matches((root_path, full_path, query))
        matches = [x for x in matches if x]

        self._show_progress('Searching done', 100, load_start_time, load_start_time, 'loaded {} matches'.format(
            len(matches)
        ))
        return matches

    def autocomplete_filepath(self, path, limit=100):
        path_parts = path.split('/')
        last_path_item = path_parts[-1]
        prefix_path = '{}/'.format('/'.join(path_parts[:-1])) if len(path_parts) > 1 else ''

        root = self.project_hierarchy
        for item in path_parts[:-1]:
            if item not in root:
                return []
            root = root[item]

        candidates = []
        for item in root:
            if item.startswith(last_path_item):
                candidates.append('{}{}'.format(prefix_path, item))
            if len(candidates) >= limit:
                break
        return candidates

    def autocomplete_node(self, path, limit=100):
        last_path_item = path.split('/')[-1]

        candidates = []
        for node in self.project_nodes:
            if node.startswith(last_path_item):
                candidates.append(node)
        return candidates

    def load_project_data_from_cache(self):
        if not os.path.exists(self._get_cachefile()):
            return False

        load_start_time = time.time()
        self._show_progress('Loading from cache...', 1, load_start_time, load_start_time, 'loading indexes from file')

        try:
            with open(self._get_cachefile(), 'r') as rfile:
                data = json.load(rfile)
                self.project_files = data.get('project_files', [])
                self.project_dirs = data.get('project_dirs', [])
                self.project_hierarchy = data.get('project_hierarchy', {})
                self.project_nodes = data.get('project_nodes', set())
        except Exception:
            return False

        self._show_progress('Loading from cache done', 100, load_start_time, load_start_time, 'loaded {} files'.format(
            len(self.project_files)
        ))
        return True

    def dump_project_data_to_cache(self):
        dump_start_time = time.time()

        try:
            with open(self._get_cachefile(), 'w') as wfile:
                data = {
                    'project_files': self.project_files,
                    'project_dirs': self.project_dirs,
                    'project_hierarchy': self.project_hierarchy,
                    'project_nodes': list(self.project_nodes),
                }
                json.dump(data, wfile, indent=4)
        except Exception:
            vim.command('call vpm#Echo("Dump ProjectData to cachefile failed")')
            return False
        return True

    def _calc_structure(self, all_files):
        nodes = set()
        hierarchy = {}
        for path in all_files:
            if not path:
                continue
 
            root = hierarchy
            splitted_path = path.split('/')
            for idx, item in enumerate(splitted_path):
                indexed_item = item.split('.')[0] if idx >= (len(splitted_path) - 1) else item
                nodes.add(indexed_item)
                if item not in root:
                    root[item] = {}
                root = root[item]
        return hierarchy, nodes

    def _calc_find_plan(self, path):
        subdirs = []
        last_dirs_level = [path]
        while (len(subdirs) + len(last_dirs_level)) < ProjectData.CPU_COUNT * 3:
            subdirs += last_dirs_level

            sub_dirs = []
            for subpath in last_dirs_level: 
                 sub_dirs += unix_find(subpath, 'd', 1, self.ssh_args, background=False)
            last_dirs_level = sub_dirs

            if not last_dirs_level:
                break

        plan = [(p, 1) for p in subdirs]
        plan += [(p, None) for p in last_dirs_level]

        return plan

    def _get_files(self, args):
        root_path, path, depth, path_filters = args
        list_files = unix_find(path, 'f', depth, self.ssh_args, background=False)
        list_files = [x.replace('{}/'.format(root_path), '') for x in list_files]

        return list_files

    def _get_matches(self, args):
        root_path, path, pattern = args
        list_matches = unix_grep(path, pattern, ssh_args=self.ssh_args, background=False)
        list_matches = [x.replace('{}/'.format(root_path), '') for x in list_matches]

        return list_matches 

    def _get_cachefile(self):
        return os.path.join(os.path.expanduser('~'), '.vim/.vpm.{}.cache'.format(self.project_name))

    def _show_progress(self, prefix, perc, load_start_time, part_start_time, postfix):
        end_time = time.time()
        vim.command('call vpm#ShowProgress("{}", {}, "{:.2f}s/{:.2f}s {}")'.format(
            prefix, perc, end_time - part_start_time, end_time - load_start_time, postfix
        ))


def unix_find(start_path, items_type, maxdepth=None, ssh_args=None, background=True):
    cmd = ['find', start_path, '-type', items_type, '-not', '-path', r'*/\\.*']
    cmd += ['-maxdepth', str(maxdepth)] if maxdepth else []
    cmd = ['ssh'] + ssh_args + cmd if ssh_args is not None else cmd

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    return process if background else cast_unix_find_output(process.communicate()[0], start_path)


def unix_grep(start_path, pattern, maxdepth=None, recursive=False, ssh_args=None, background=True):
    cmd = "grep -n -r -s --binary-files=without-match --max-count=10 --exclude-dir '\.*' '{}' {}"
    cmd = cmd.format(pattern, start_path)
    cmd = 'ssh {} "{}"'.format(' '.join(ssh_args), cmd) if ssh_args is not None else cmd
    print(cmd)

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    return process if background else cast_unix_grep_output(process.communicate()[0], start_path)


def cast_unix_find_output(stdout, start_path):
    def strip_path(path):
        return path.strip().rstrip('/').rstrip('\\')

    def is_good_path(path, subpath):
        stripped_path = strip_path(path)
        stripped_subpath = strip_path(subpath)
        return stripped_subpath and stripped_path != stripped_subpath

    lines = str(stdout, 'utf8').split('\n')
    return [x for x in map(strip_path, lines) if is_good_path(start_path, x)]


def cast_unix_grep_output(stdout, start_path):
    lines = str(stdout, 'utf8').split('\n')
    return lines
EOF
endfunc


function! pyvpm#MakeProjectData()
py3 << EOF
import vim

project_name = vim.eval('g:vpm#project_name')
project_type = vim.eval('g:vpm#project_type')
local_path = vim.eval('g:vpm#local_path')
local_path_filters = vim.eval('g:vpm#local_path_filters')
remote_server = vim.eval('g:vpm#remote_server')
remote_path = vim.eval('g:vpm#remote_path')
remote_path_filters = vim.eval('g:vpm#remote_path_filters')

PROJECT_DATA = ProjectData(
    project_name=project_name,
    project_type=project_type,
    local_path=local_path,
    local_path_filters=local_path_filters,
    remote_server=remote_server,
    remote_path=remote_path,
    remote_path_filters=remote_path_filters,
)
EOF
endfunc


function! pyvpm#LoadProjectFiles(lazy)
py3 << EOF
import vim
import time

lazy = int(vim.eval('a:lazy'))

s = time.time()
if not lazy or not PROJECT_DATA.load_project_data_from_cache():
    PROJECT_DATA.load_project_data()
    PROJECT_DATA.dump_project_data_to_cache() 
EOF
endfunc


function! pyvpm#SearchFilepath(query)
    let founded_filepaths = []
py3 << EOF
import vim

query = vim.eval('a:query')
founded = PROJECT_DATA.search_filepath(query)
vim.command('let founded_filepaths = {}'.format(founded))
EOF
    return founded_filepaths
endfunc


function! pyvpm#SearchSubstring(query, relpath)
    let founded_substrings = []
py3 << EOF
import vim

query = vim.eval('a:query')
relpath = vim.eval('a:relpath')
founded = PROJECT_DATA.search_substring(query, relpath)
vim.command('let founded_substrings = {}'.format(founded))
EOF
    return founded_substrings
endfunc


function! pyvpm#RemoteFilepathCompleter(A, P, L)
    let list_completions = []
py3 << EOF
import vim

query = vim.eval('a:A')
list_completions = PROJECT_DATA.autocomplete_filepath(query)
vim.command('let list_completions = {}'.format(list_completions))
EOF
    return list_completions
endfunc


function! pyvpm#FilepathNodeCompleter(A, P, L)
    let list_completions = []
py3 << EOF
import vim

query = vim.eval('a:A')
list_completions = PROJECT_DATA.autocomplete_node(query)
vim.command('let list_completions = {}'.format(list_completions))
EOF
    return list_completions
endfunc
