function! ripgrep#go_to_match()
  let l:buffer = bufnr()
  let l:window = win_getid()
  call luaeval('require("ripgrep").get_buffer(_A.buffer):go_to_match(_A.window)', l:)
endfunction

function! ripgrep#search(options, pattern)
    let l:options = a:options
    let l:pattern = a:pattern

    call luaeval('require("ripgrep").search(_A.options, _A.pattern)', l:)
endfunction
