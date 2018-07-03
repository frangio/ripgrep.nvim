setlocal buftype=nowrite
setlocal bufhidden=hide

setlocal nonumber
setlocal foldmethod=syntax
setlocal foldtext=getline(v:foldstart)
setlocal foldcolumn=2
setlocal foldlevel=2

setlocal nomodifiable

nnoremap <buffer> <Return> :call ripgrep#go_to_match()<CR>
