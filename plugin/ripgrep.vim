augroup ripgrep
  autocmd!

  autocmd BufReadCmd  rg://*  call ripgrep#autocmd#BufReadCmd(str2nr(expand("<abuf>")), expand("<afile>"))

  autocmd BufWinEnter *       call ripgrep#autocmd#BufWinEnter()
  autocmd WinNew      *       call ripgrep#autocmd#WinNew()
augroup end
