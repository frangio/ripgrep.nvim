function! s:BufReadCmd(buffer, file)
  call ripgrep#init_buffer(a:buffer, a:file)
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
