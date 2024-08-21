let g:vim_pbcopy_local_cmd = "pbcopy"

vnoremap <silent> cy :<C-U>call <SID>copyVisualSelection(visualmode(), 1)<CR>
nnoremap <silent> cy :set opfunc=<SID>copyVisualSelection<CR>g@

function! s:getVisualSelection()
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][:col2 - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][col1 - 1:]
    return lines
endfunction

" 检测操作系统并设置适当的 netcat 命令
function! s:setNetcatCommand()
    if has('mac') || system('uname') =~# 'Darwin'
        let g:vim_pbcopy_nc_cmd = "nc localhost 2224"
    else
        let g:vim_pbcopy_nc_cmd = "nc -q 0 localhost 2224"
    endif
endfunction

call s:setNetcatCommand()

" 使用更可靠的方法检测是否在本地运行
function! s:isRunningLocally()
    return empty($SSH_TTY) && empty($SSH_CLIENT) && empty($SSH_CONNECTION)
endfunction

function! s:copyVisualSelection(type, ...)
    let sel_save = &selection
    let &selection = "inclusive"
    let reg_save = @@

    if a:0  " Invoked from Visual mode, use '< and '> marks.
        silent exe "normal! `<" . a:type . "`>y"
    elseif a:type == 'line'
        silent exe "normal! '[V']y"
    elseif a:type == 'block'
        silent exe "normal! `[\<C-V>`]y"
    else
        silent exe "normal! `[v`]y"
    endif

    let lines = split(@@, "\n")
    let error = s:sendTextToPbCopy(lines)

    let &selection = sel_save
    let @@ = reg_save

    if error == 0
        echo "Text copied to clipboard"
    else
        echoerr "Failed to copy text to clipboard"
    endif
endfunction

" 改进的发送文本到pbcopy函数，不使用 shellescape
function! s:sendTextToPbCopy(lines)
    let text = join(a:lines, "\n")
    " 使用 printf 来确保换行符被正确处理
    let cmd = printf("printf %%s %s | %s", shellescape(text), g:vim_pbcopy_nc_cmd)
    let output = system(cmd)
    if v:shell_error
        echoerr "Clipboard copy failed: " . output
        return 1
    endif
    return 0
endfunction

" 设置快捷键
vnoremap <silent> cy :<C-U>call <SID>copyVisualSelection(visualmode(), 1)<CR>
nnoremap <silent> cy :set opfunc=<SID>copyVisualSelection<CR>g@
