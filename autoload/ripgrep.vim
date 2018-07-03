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

function! s:parse_query(query_string)
  let l:matches = matchlist(a:query_string, '^rg://\([^/]*\)$')

  return {
    \ 'pattern': l:matches[1],
    \ }
endfunction

function! s:build_command(query)
  return ['rg', '--heading', '--line-number', a:query.pattern]
endfunction

function! s:on_stdout(buffer, id, data, event)
  let [l:last_line] = nvim_buf_get_lines(a:buffer, -2, -1, v:true)

  let a:data[0] = l:last_line . a:data[0]

  let l:modifiable = getbufvar(a:buffer, '&modifiable')
  call setbufvar(a:buffer, '&modifiable', 1)

  call nvim_buf_set_lines(a:buffer, -2, -1, v:true, a:data)

  if a:data == ['']
    call nvim_buf_set_lines(a:buffer, -2, -1, v:true, [])
  endif

  call setbufvar(a:buffer, '&modifiable', l:modifiable)
endfunction

function! s:read_command_output(buffer, command)
  return jobstart(a:command,
        \ {
        \   'on_stdout': function('s:on_stdout', [a:buffer]),
        \ })
endfunction

function! s:clear_buffer(buffer)
  let l:modifiable = getbufvar(a:buffer, '&modifiable')
  call setbufvar(a:buffer, '&modifiable', 1)

  call nvim_buf_set_lines(a:buffer, 0, -1, v:true, [])

  call setbufvar(a:buffer, '&modifiable', l:modifiable)
endfunction

function! ripgrep#init_buffer(buffer, query_string)
  let l:query = <SID>parse_query(a:query_string)
  let l:command = <SID>build_command(l:query)

  call <SID>clear_buffer(a:buffer)

  let l:job = <SID>read_command_output(a:buffer, l:command)

  call setbufvar(a:buffer, '&filetype', 'ripgrep')

  call setbufvar(a:buffer, 'rg_query', l:query)
  call setbufvar(a:buffer, 'rg_job', l:job)
endfunction
