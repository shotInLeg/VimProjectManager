function! s:SearchFinderDialog(name, query, all_files)
    silent! execute "botright pedit " . a:name
    noautocmd wincmd P
    set buftype=nofile

    let cwd = getcwd()
    for filepath in vpm#SearchByListFiles(a:all_files, a:query)
        let shorted_filepath = substitute(filepath, cwd . '/', '', 'g')
        silent! execute "r! echo " . shorted_filepath
    endfor
    silent! execute "redraw!"

    let search_query = input('>>> ')
    call s:SearchFinderDialog(a:name, search_query, a:all_files)
endfunc


function! s:OpenFinderDialog(name)
    let find_cmd = 'find ' . getcwd() . ' -type f'
    let all_files = split(system(find_cmd), '\n')

    echom len(all_files[0])

    call s:SearchFinderDialog(a:name, '', all_files)
endfunc


command! -nargs=? VpmFinderDialog :call s:OpenFinderDialog("ls")
