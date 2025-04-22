local group = vim.api.nvim_create_augroup('ripgrep', { clear = true })

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = 'rg://*',
  callback = function (ev)
    require('ripgrep').init_buffer(ev.buf)
  end
})

vim.api.nvim_create_autocmd('BufWinEnter', {
  group = group,
  pattern = 'rg://*',
  callback = function (ev)
    local window = vim.api.nvim_get_current_win()
    require('ripgrep').get_buffer(ev.buf):setup_window(window)
  end
})

vim.api.nvim_create_autocmd('BufDelete', {
  group = group,
  pattern = 'rg://*',
  callback = function (ev)
    require('ripgrep').get_buffer(ev.buf):close()
  end
})

vim.api.nvim_create_autocmd('CursorMoved', {
  group = group,
  pattern = 'rg://*',
  callback = function (ev)
    local window = vim.api.nvim_get_current_win()
    require('ripgrep').get_buffer(ev.buf):cursor_moved(window)
  end
})

vim.api.nvim_create_user_command('Rg',  'edit rg:///<args>',   { nargs = '?' })
vim.api.nvim_create_user_command('Rgi', 'edit rg://-i/<args>', { nargs = '?' })
vim.api.nvim_create_user_command('Rgw', 'edit rg://-w/<args>', { nargs = '?' })
