function! g:VpmLoadProjectFiles()
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    call pyvpm#LoadProjectFiles() 
endfunc


function! g:VpmSearchFilepath(query)
    if !vpm#IsProjectLoaded()
        call vpm#Echo('Project not loaded')
        return 0
    endif

    return pyvpm#SearchFilepath(a:query)
endfunc
