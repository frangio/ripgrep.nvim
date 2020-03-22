lua require'ripgrep'

augroup ripgrep
  autocmd!
  autocmd BufReadCmd  rg://*  call <SID>init_buffer(expand("<abuf>"))
  autocmd BufWinEnter rg://*  call <SID>setup_window(win_getid())
augroup end

function! s:init_buffer(buffer)
  call luaeval('ripgrep.get_buffer(_A):init()', str2nr(a:buffer))
endfunction

function! s:setup_window(window)
  call luaeval('ripgrep.setup_window(_A)', a:window)
endfunction

command! -nargs=? Rg exec <q-mods> 'new rg://' . <q-args>
