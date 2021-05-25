augroup ripgrep
  autocmd!
  autocmd BufReadCmd  rg://*  call <SID>init_buffer(expand("<abuf>"))
  autocmd BufWinEnter rg://*  call <SID>setup_window(expand("<abuf>"), win_getid())
  autocmd CursorMoved rg://*  call <SID>pause_or_resume(expand("<abuf>"), win_getid())
  autocmd BufWriteCmd rg://*  call <SID>on_write(expand("<abuf>"))
augroup end

function! s:init_buffer(buffer)
  let l:buffer = str2nr(a:buffer)
  call luaeval('require("ripgrep").init_buffer(_A.buffer)', l:)
endfunction

function! s:setup_window(buffer, window)
  let l:buffer = str2nr(a:buffer)
  let l:window = a:window
  call luaeval('require("ripgrep").get_buffer(_A.buffer):setup_window(_A.window)', l:)
endfunction

function! s:pause_or_resume(buffer, window)
  let l:buffer = str2nr(a:buffer)
  let l:window = a:window
  call luaeval('require("ripgrep").get_buffer(_A.buffer):pause_or_resume(_A.window)', l:)
endfunction

function! s:on_write(buffer)
  let l:buffer = str2nr(a:buffer)
  call luaeval('require("ripgrep").get_buffer(_A.buffer):on_write()', l:)
endfunction

command! -nargs=? Rg call ripgrep#search('', <q-args>)
command! -nargs=? Rgi call ripgrep#search('-i', <q-args>)
command! -nargs=? Rgw call ripgrep#search('-w', <q-args>)

" command! -nargs=? Rg exec 'edit rg:///' . <q-args>
" command! -nargs=? Rgi exec 'edit rg://-i/' . <q-args>
" command! -nargs=? Rgw exec 'edit rg://-w/' . <q-args>
