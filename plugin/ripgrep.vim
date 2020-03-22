augroup ripgrep
  autocmd!
  autocmd BufReadCmd  rg://*  call <SID>init_buffer(expand("<abuf>"), expand("<afile>"))
  autocmd BufWinEnter rg://*  call <SID>setup_window(win_getid())
augroup end

function! s:init_buffer(buffer, query)
  call luaeval('require("ripgrep").init_buffer(_A.buffer, _A.query)', a:)
endfunction

function! s:setup_window(window)
  call luaeval('require("ripgrep").setup_window(_A.window)', a:)
endfunction

command! -nargs=? Rg exec <q-mods> 'new rg://' . <q-args>
