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

local function opener(flags)
  return function (opts)
    require('ripgrep').open_search(flags, table.concat(opts.fargs, ' '))
  end
end

vim.api.nvim_create_user_command('Rg',  opener(''),   { nargs = '?' })
vim.api.nvim_create_user_command('Rgi', opener('-i'), { nargs = '?' })
vim.api.nvim_create_user_command('Rgw', opener('-w'), { nargs = '?' })
