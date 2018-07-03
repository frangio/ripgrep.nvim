function! ripgrep#parse_query(file)
  let l:matches = matchlist(a:file, '^rg://\([^/]*\)$')

  return {
    \ 'pattern': l:matches[1],
    \ }
endfunction

function! ripgrep#highlight_apply()
  if !exists('w:rg_match_id') && exists('b:rg_query')
    let w:rg_match_id = matchadd('rgMatch', '\%([^\n]\n.*\)\@<=' . b:rg_query.pattern)
  endif
endfunction

function! ripgrep#highlight_clear()
  if exists('w:rg_match_id')
    call matchdelete(w:rg_match_id)
    unlet w:rg_match_id
  endif
endfunction

function! ripgrep#highlight_reset()
  call ripgrep#highlight_clear()
  call ripgrep#highlight_apply()
endfunction

function! ripgrep#go_to_match()
  let l:line = matchstr(getline('.'), '^\d\+')
  let l:file_name_line = search('\%(\%^\|^\n\)\zs', 'bn')
  execute 'edit' ('+' . l:line) getline(l:file_name_line)
endfunction
