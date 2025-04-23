local group = vim.api.nvim_create_augroup('ripgrep', { clear = true })

local function handle_bufread(pattern, load_buf)
  vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = pattern,
    group = group,
    callback = function (ev)
      local unload = load_buf(ev.buf)
      vim.api.nvim_create_autocmd('BufUnload', {
        once = true,
        buffer = ev.buf,
        callback = unload,
      })
    end
  })
end

handle_bufread('rg://*', function (bufnr)
  return require('ripgrep.rgbuf')(bufnr)
end)

vim.api.nvim_create_user_command('Rg',  'edit rg:///<args>',   { nargs = '?' })
vim.api.nvim_create_user_command('Rgi', 'edit rg://-i/<args>', { nargs = '?' })
vim.api.nvim_create_user_command('Rgw', 'edit rg://-w/<args>', { nargs = '?' })
