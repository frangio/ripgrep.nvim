function! s:on_stdout(buffer, id, data, event)
  let [l:last_line] = nvim_buf_get_lines(a:buffer, -2, -1, v:true)

  let a:data[0] = l:last_line . a:data[0]

  call setbufvar(a:buffer, '&modifiable', 1)
  call nvim_buf_set_lines(a:buffer, -2, -1, v:true, a:data)
  call setbufvar(a:buffer, '&modifiable', 0)
endfunction

function! s:BufReadCmd(buffer, file)
  let b:rg_query = ripgrep#parse_query(a:file)

  let b:rg_job = jobstart(['rg', '--heading', '--line-number', b:rg_query.pattern],
        \ {
        \   'on_stdout': function('s:on_stdout', [a:buffer]),
        \ })

  set filetype=ripgrep
endfunction

function! s:BufWinEnter()
  call ripgrep#highlight_reset()
endfunction

function! s:WinNew()
  " this autocmd is needed because BufWinEnter doesn't run for :split
  call ripgrep#highlight_apply()
endfunction

augroup ripgrep
  autocmd!

  autocmd BufReadCmd  rg://*  call <SID>BufReadCmd(str2nr(expand("<abuf>")), expand("<afile>"))

  autocmd BufWinEnter *       call <SID>BufWinEnter()
  autocmd WinNew      *       call <SID>WinNew()
augroup end
