augroup ripgrep
  autocmd!
  autocmd BufReadCmd  rg://*  call <SID>init_buffer(expand("<abuf>"))
  autocmd BufWinEnter rg://*  call <SID>setup_window(expand("<abuf>"), win_getid())
  autocmd CursorMoved rg://*  call <SID>cursor_moved(expand("<abuf>"), win_getid())
augroup end

command! -nargs=? Rg call <SID>open_search('', <q-args>)
command! -nargs=? Rgi call <SID>open_search('-i', <q-args>)
command! -nargs=? Rgw call <SID>open_search('-w', <q-args>)

function! s:init_buffer(buffer)
  let l:buffer = str2nr(a:buffer)
  call luaeval('require("ripgrep").init_buffer(_A.buffer)', l:)
endfunction

function! s:setup_window(buffer, window)
  let l:buffer = str2nr(a:buffer)
  let l:window = a:window
  call luaeval('require("ripgrep").get_buffer(_A.buffer):setup_window(_A.window)', l:)
endfunction

function! s:cursor_moved(buffer, window)
  let l:buffer = str2nr(a:buffer)
  let l:window = a:window
  call luaeval('require("ripgrep").get_buffer(_A.buffer):cursor_moved(_A.window)', l:)
endfunction

function! s:open_search(options, pattern)
  call luaeval('require("ripgrep").open_search(_A.options, _A.pattern)', a:)
endfunction
