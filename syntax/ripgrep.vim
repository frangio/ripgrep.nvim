if exists('b:current_syntax')
  finish
endif

function! s:hi(group, color, attrs)
  if len(a:attrs)
    let l:joined_attrs = join(a:attrs, ',')
    let l:maybe_attrs = 'cterm=' . l:joined_attrs . ' gui=' . l:joined_attrs
  else
    let l:maybe_attrs = ''
  endif
  execute 'highlight default' a:group l:maybe_attrs
        \ 'ctermfg=' . a:color
        \ 'guifg=' . get(g:, 'terminal_color_' . a:color)
endfunction

call s:hi('rgFileName',    5, [])
call s:hi('rgMatch',       1, ['bold'])

let b:current_syntax = 'ripgrep'
