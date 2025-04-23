local spawn_json_producer = require('ripgrep.utils.spawn_json_producer')

local group = vim.api.nvim_create_augroup('ripgrep.virtbuf', { clear = false })

local function parse(bufname)
  local options, pattern = bufname:match('rg://([^/]*)/(.*)')
  if options == nil then
    error('bad ripgrep uri (rg://[options]/pattern)')
  elseif options:len() == 0 then
    options = {}
  else
    options = vim.split(options, ' +')
  end
  return options, pattern
end

local function rglines(bufname, callback)
  local options, pattern = parse(bufname)
  local args = vim.tbl_flatten({'--json', options, '--', pattern})
  local process = spawn_json_producer('rg', args, {
    begin = function (data)
      if data.path.bytes then
        return
      end
      callback(nil, {})
      callback(data.path.text, { {'rgFileName', 0, -1} })
    end,
    match = function (data)
      if data.lines.bytes or data.path.bytes then
        return
      end
      -- TODO: support multiline
      local text = data.lines.text:gsub("([^\n]*).*", "%1")
      local hls = vim.iter(data.submatches):map(function (submatch)
        return {'rgMatch', submatch.start, submatch['end']}
      end):totable()
      local action = function (col)
        local pos = data.line_number .. 'G' .. (col + 1) .. '|'
        vim.api.nvim_command('edit +keepjumps\\ normal\\ ' .. pos .. ' ' .. data.path.text)
      end
      callback(text, hls, action)
    end,
  })
  return process
end

local function rgbuf(bufnr)
  vim.api.nvim_set_option_value('filetype', 'ripgrep', { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'nowrite', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  local windows = {}

  vim.api.nvim_create_autocmd('BufWinEnter', {
    buffer = bufnr,
    group = group,
    callback = function ()
      vim.api.nvim_set_option_value('number', false, { win = 0 })
      vim.api.nvim_set_option_value('relativenumber', false, { win = 0 })
      table.insert(windows, vim.api.nvim_get_current_win())
    end
  })

  local actions = {}
  local appended = false

  local pause_or_resume

  local lines = rglines(vim.api.nvim_buf_get_name(bufnr), function (text, hls, action)
    local lines = {text}

    if text == nil then
      if not appended then
        return
      else
        lines = {''}
      end
    end

    local start = appended and -1 or -2

    vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, start, -1, true, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

    local line = vim.api.nvim_buf_line_count(bufnr) - 1

    for _, hl in ipairs(hls) do
      -- TODO: replace deprecated
      vim.api.nvim_buf_add_highlight(bufnr, -1, hl[1], line, hl[2], hl[3])
    end

    actions[line] = action

    appended = true
    vim.schedule(pause_or_resume)
  end)

  local function get_max_cur_line()
    local max_cur_line = -1
    local win_height = 0
    for idx, winid in pairs(windows) do
      local success, cursor = pcall(vim.api.nvim_win_get_cursor, winid)
      if not success then
        -- assume window doesn't exist anymore
        windows[idx] = nil
      else
        local cur_line = unpack(cursor)
        if cur_line > max_cur_line then
          max_cur_line = cur_line
          win_height = vim.api.nvim_win_get_height(winid)
        end
      end
    end
    return max_cur_line, win_height
  end

  function pause_or_resume(window)
    local cur_line, win_height
    if window then
      cur_line = unpack(vim.api.nvim_win_get_cursor(window))
      win_height = vim.api.nvim_win_get_height(window)
    else
      cur_line, win_height = get_max_cur_line()
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if cur_line > line_count - win_height then
      lines.resume()
    else
      lines.pause()
    end
  end


  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = bufnr,
    group = group,
    callback = function ()
      pause_or_resume(vim.api.nvim_get_current_win())
    end
  })

  -- TODO: handle SearchWrapped

  local function do_action()
    local cur_line, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    local action = actions[cur_line - 1]
    if action then
      action(cur_col)
    end
  end

  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<Return>', '', { callback = do_action })
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<2-LeftMouse>', '', { callback = do_action })

  return function ()
    lines.stop()
    vim.api.nvim_clear_autocmds({ buffer = bufnr, group = group })
    vim.api.nvim_buf_del_keymap(bufnr, 'n', '<Return>')
    vim.api.nvim_buf_del_keymap(bufnr, 'n', '<2-LeftMouse>')
  end
end

return rgbuf
