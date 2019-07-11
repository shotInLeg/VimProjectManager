if !exists('g:vpm#codesearch_max_results')
    let g:vpm#codesearch_max_results = 100
endif

if !exists('g:vpm#ya_path') || !g:vpm#ya_path
    let g:vpm#ya_path = '/home/' . $USER . '/svn/arcadia/ya'
endif

let s:grep_cmd = 'grep -r -n'
let s:ya_grep_cmd = g:vpm#ya_path . ' grep --no-colors --vim-friendly -m ' . g:vpm#codesearch_max_results
let s:ya_grep_arcadia_cmd = s:ya_grep_cmd . ' --remote'


function! s:OpenFilepath(filepath, buffer_busy)
    if a:buffer_busy == 'NONE'
        let buffer_busy = vpm#IsCurrentBufferBusy()
    endif

    let cmd = vpm#GetOpenFilepathCommand(a:filepath, a:buffer_busy)
    silent! exec cmd
endfunc


function! s:YaGrepInProject(search_query)
    if g:vpm#project_type == 'remote'
        let project_path = g:vpm#remote_path
        let cmd = 'ssh ' . g:vpm#remote_server . ' ' . s:ya_grep_cmd . " --dirs '" . g:vpm#remote_path . "' '" . a:search_query . "'"
    elseif g:vpm#project_type == 'local' || g:vpm#project_type == 'sync'
        let project_path = g:vpm#local_path
        let cmd = s:ya_grep_cmd . " --dirs '" . g:vpm#local_path . "' '" . a:search_query . "'"
    endif

    let matched_lines = []
    for line in split(system(cmd), '\n')
        let line = substitute(line, project_path, '', 'g')
        call add(matched_lines, line)
    endfor

    let s:buffer_busy = vpm#IsCurrentBufferBusy()

    cgetexpr matched_lines
    exe 'copen 10'
    let w:quickfix_title = 'vpm#codesearch'

    let b:statusline = 'Search code: ' . a:search_query
    setlocal statusline=%{b:statusline}
endfunc


function! s:CodeSearchInProject(search_query)
    if g:vpm#project_type == 'remote'
        let project_path = g:vpm#remote_path
        let cmd = 'ssh ' . g:vpm#remote_server . ' ' . s:grep_cmd . " '" . a:search_query . "' " . g:vpm#remote_path
    elseif g:vpm#project_type == 'local' || g:vpm#project_type == 'sync'
        let project_path = g:vpm#local_path
        let cmd = s:grep_cmd . " '" . a:search_query . "' " . g:vpm#local_path
    endif

    let matched_lines = []
    for line in split(system(cmd), '\n')
        let line = substitute(line, project_path, '', 'g')
        call add(matched_lines, line)
    endfor

    let s:buffer_busy = vpm#IsCurrentBufferBusy()

    cgetexpr matched_lines
    exe 'copen 10'
    let w:quickfix_title = 'vpm#codesearch'

    let b:statusline = 'Search code: ' . a:search_query
    setlocal statusline=%{b:statusline}
endfunc


function! s:CodeSearchInProjectDialog()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let completer = vpm#GetFilepathCompleter()

    let search_query = input('Search code: ')
    silent! call s:CodeSearchInProject(search_query)
endfunc


function! g:SelectCodeSearchDialogItem()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    let selected_line = getline('.')
    let line_parts = split(selected_line, '|')
    let filepath = line_parts[0]
    let position = split(line_parts[1], ' ')
    let number_line = position[0]

    if len(position) > 1
        let number_col = position[2]
    else
        let number_col = 0
    endif

    call g:CloseCodeSearchDialog()
    call s:OpenFilepath(filepath, s:buffer_busy)
    exec ":" . number_line
endfunc


function! g:CloseCodeSearchDialog()
    cclose
endfunc


function! s:AutoSetupFinder()
    if g:vpm#enable_project_manager
        map <silent> <C-f> :VpmCodeSearchInProjectDialog<cr>
    endif
endfunc


command! -nargs=? VpmCodeSearchInProject :call s:CodeSearchInProject('<args>')
command! -nargs=? VpmYaGrepInProject :call s:YaGrepInProject('<args>')
command! -nargs=? VpmCodeSearchInProjectDialog :call s:CodeSearchInProjectDialog()


autocmd VimEnter * :call s:AutoSetupFinder()
