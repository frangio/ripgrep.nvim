function! ripgrep#go_to_match()
  let l:buffer = bufnr()
  let l:window = win_getid()
  call luaeval('ripgrep.get_buffer(_A.buffer):go_to_match(_A.window)', l:)
endfunction
