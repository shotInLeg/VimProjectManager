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

        self.ssh_args = [self.remote_server]

        self.project_files = []
        self.project_nodes = set()
        self.project_hierarchy = {}

    def load_project_data(self):
        root_path = self.local_path if self.project_type == self.LOCAL else self.remote_path
        path_filters = self.local_path_filters if self.project_type == self.LOCAL else self.remote_path_filters
        
        plan = self._calc_find_plan(root_path)
        pool = multiprocessing.Pool(ProjectData.CPU_COUNT)

        all_files = pool.map(self._get_files, [(root_path, path, depth, path_filters) for path, depth in plan])
        all_files = sum(all_files, [])

        self.project_files = all_files
        self.project_hierarchy, self.project_nodes = self._calc_structure(self.project_files)

    def search_filepath(self, query, limit=100):
        founded = []
        for filepath in self.project_files:
            if query in filepath:
                founded.append(filepath)
            if len(founded) >= limit:
                break
        return founded

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

        try:
            with open(self._get_cachefile(), 'r') as rfile:
                data = json.load(rfile)
                self.project_files = data.get('project_files', [])
                self.project_hierarchy = data.get('project_hierarchy', {})
                self.project_nodes = data.get('project_nodes', set())
        except Exception:
            return False

        return True

    def dump_project_data_to_cache(self):
        try:
            with open(self._get_cachefile(), 'w') as wfile:
                data = {
                    'project_files': self.project_files,
                    'project_hierarchy': self.project_hierarchy,
                    'project_nodes': list(self.project_nodes),
                }
                json.dump(data, wfile, indent=4)
        except Exception:
            print('Dump ProjectData to cachefile failed')
            return False
        return True

    def _calc_structure(self, all_files):
        nodes = set()
        hierarchy = {}
        for path in all_files:
            if not path:
                continue
 
            root = hierarchy
            for item in path.split('/'):
                nodes.add(item)
                if item not in root:
                    root[item] = {}
                root = root[item]
        return hierarchy, nodes

    def _calc_find_plan(self, path):
        subdirs = []
        last_dirs_level = [path]
        while (len(subdirs) + len(last_dirs_level)) < ProjectData.CPU_COUNT * 3:
            subdirs += last_dirs_level

            dirs = []
            for subpath in last_dirs_level: 
                dirs += unix_find(subpath, 'd', 1, self.ssh_args, background=False)

            if not dirs:
                break
            last_dirs_level = dirs

        plan = [(p, 1) for p in subdirs]
        plan += [(p, None) for p in last_dirs_level]

        return plan

    def _get_files(self, args):
        root_path, path, depth, path_filters = args
        list_files = unix_find(path, 'f', depth, self.ssh_args, background=False)
        list_files = [x.replace('{}/'.format(root_path), '') for x in list_files]

        return list_files

    def _get_cachefile(self):
        return os.path.join(os.path.expanduser('~'), '.vim/.vpm.{}.cache'.format(self.project_name))


def unix_find(start_path, items_type, maxdepth=None, ssh_args=None, background=True):
    cmd = ['find', start_path, '-type', items_type, '-not', '-path', r'*/\\.*']
    cmd += ['-maxdepth', str(maxdepth)] if maxdepth else []
    cmd = ['ssh'] + ssh_args + cmd if ssh_args is not None else cmd

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    return process if background else cast_unix_find_output(process.communicate()[0], start_path)


def cast_unix_find_output(stdout, start_path):
    def strip_path(path):
        return path.strip().rstrip('/').rstrip('\\')

    def is_good_path(path, subpath):
        stripped_path = strip_path(path)
        stripped_subpath = strip_path(subpath)
        return stripped_subpath and stripped_path != stripped_subpath

    lines = str(stdout, 'utf8').split('\n')
    return [x for x in map(strip_path, lines) if is_good_path(start_path, x)]
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

lazy = vim.eval('a:lazy')

s = time.time()
if not lazy or not PROJECT_DATA.load_project_data_from_cache():
    PROJECT_DATA.load_project_data()
    PROJECT_DATA.dump_project_data_to_cache() 
print(' Loading project files done {}s'.format(time.time() - s))
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
