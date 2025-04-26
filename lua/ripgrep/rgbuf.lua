local utils = require('ripgrep.utils')

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

local function decode(data)
  if data.bytes ~= nil then
    return vim.base64.decode(data.bytes)
  else
    return data.text
  end
end

local function rglines(bufname, callback)
  local options, pattern = parse(bufname)
  local args = utils.list_concat({'--json'}, options, {'--', pattern})

  local process = utils.spawn_lines('rg', args, function(line)
    local ok, obj = pcall(vim.json.decode, line)
    if not ok then
      return
    elseif obj.type == 'begin' then
      local path = decode(obj.data.path)
      callback({text = path, newline = true, hls = {{'rgFileName', 0, -1}}})
    elseif obj.type == 'match' then
      local data = obj.data
      -- TODO: support multiline
      local text = decode(data.lines):gsub("([^\n]*).*", "%1")
      local hls = vim.iter(data.submatches):map(function (submatch)
        return {'rgMatch', submatch.start, submatch['end']}
      end):totable()
      local action = function (col)
        local pos = data.line_number .. 'G' .. (col + 1) .. '|'
        vim.api.nvim_command('edit +keepjumps\\ normal\\ ' .. pos .. ' ' .. decode(data.path))
      end
      callback({text = text, hls = hls, action = action})
    end
  end)
  return process
end

local function rgbuf(bufnr)
  vim.api.nvim_set_option_value('filetype', 'ripgrep', { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'nowrite', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  local needed_rows = 0

  local function update_needed_rows(window)
    local cursor_row = unpack(vim.api.nvim_win_get_cursor(window))
    local win_height = vim.api.nvim_win_get_height(window)
    needed_rows = math.max(needed_rows, cursor_row + win_height)
  end

  vim.api.nvim_create_autocmd('BufWinEnter', {
    buffer = bufnr,
    group = group,
    callback = function ()
      vim.api.nvim_set_option_value('number', false, { win = 0 })
      vim.api.nvim_set_option_value('relativenumber', false, { win = 0 })
      update_needed_rows(0)
    end
  })

  local ns = vim.api.nvim_create_namespace('')
  local started = false
  local actions = {}

  local pause_or_resume

  local line_producer = rglines(vim.api.nvim_buf_get_name(bufnr), function (line)
    local lines = {line.text}

    if line.newline and started then
      table.insert(lines, 1, '')
    end

    local start = started and -1 or -2

    vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, start, -1, true, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

    local lnum = vim.api.nvim_buf_line_count(bufnr) - 1

    for _, hl in ipairs(line.hls) do
      vim.hl.range(bufnr, ns, hl[1], {lnum, hl[2]}, {lnum, hl[3]})
    end

    actions[lnum] = line.action
    started = true
    pause_or_resume()
  end)

  function pause_or_resume()
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if needed_rows > line_count then
      line_producer.resume()
    else
      line_producer.pause()
    end
  end

  vim.api.nvim_create_autocmd({'CursorMoved', 'WinScrolled'}, {
    buffer = bufnr,
    group = group,
    callback = function ()
      update_needed_rows(vim.api.nvim_get_current_win())
      pause_or_resume()
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
    line_producer.stop()
    vim.api.nvim_clear_autocmds({ buffer = bufnr, group = group })
    vim.api.nvim_buf_del_keymap(bufnr, 'n', '<Return>')
    vim.api.nvim_buf_del_keymap(bufnr, 'n', '<2-LeftMouse>')
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

return rgbuf
