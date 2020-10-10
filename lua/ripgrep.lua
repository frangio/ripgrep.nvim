if ripgrep then
  return
end

ripgrep = {}

local dkjson = require('dkjson')
local api = vim.api
local loop = vim.loop

local buffers = {}

function class()
  local klass = {}
  local meta = {__index = klass}
  function klass.new(...)
    local instance = {}
    setmetatable(instance, meta)
    if instance.initialize ~= nil then
      instance:initialize(...)
    end
    return instance
  end
  return klass
end

local Buffer = class()

function ripgrep.init_buffer(buffer)
  if buffers[buffer] ~= nil then
    buffers[buffer]:close()
  end
  buffers[buffer] = Buffer.new(buffer)
end

function ripgrep.get_buffer(buffer)
  return buffers[buffer] or error('not an active ripgrep buffer!')
end

function Buffer:initialize(buffer)
  self.buffer = buffer
  self.matches = {}
  self.done_callbacks = {}
  self.windows = {}

  self:set_options()
  self:spawn()
end

function Buffer:setup_window(window)
  api.nvim_win_set_option(window, 'number', false)
  table.insert(self.windows, window)
end

function Buffer:close()
  self.process.kill()
end

function Buffer:set_options()
  api.nvim_buf_set_option(self.buffer, 'filetype', 'ripgrep')
  api.nvim_buf_set_option(self.buffer, 'buftype', 'nowrite')
  api.nvim_buf_set_option(self.buffer, 'bufhidden', 'hide')
  api.nvim_buf_set_option(self.buffer, 'swapfile', false)
  api.nvim_buf_set_option(self.buffer, 'modifiable', false)
end

function Buffer:spawn()
  local options, pattern = self:parse()
  local args = vim.tbl_flatten({'--json', options, '--', pattern})
  local line_callback = each_line(function (line)
    local obj = dkjson.decode(line)
    if self[obj.type] then
      self[obj.type](self, obj.data)
    end
  end)
  self.process = spawn('rg', args, function (chunk)
    vim.schedule(function () self:pause_or_resume() end)
    line_callback(chunk)
  end)
end

function Buffer:get_max_cur_line()
  local max_cur_line = -1
  local win_height = 0
  for idx, winid in pairs(self.windows) do
    local success, cursor = pcall(api.nvim_win_get_cursor, window)
    if not success then
      -- assume window doesn't exist anymore
      self.windows[idx] = nil
    else
      local cur_line = unpack(cursor)
      if cur_line > max_cur_line then
        max_cur_line = cur_line
        win_height = api.nvim_win_get_height(window)
      end
    end
  end
  return max_cur_line, win_height
end

function Buffer:pause_or_resume(window)
  local cur_line, win_height
  if window then
    cur_line = unpack(api.nvim_win_get_cursor(window))
    win_height = api.nvim_win_get_height(window)
  else
    cur_line, win_height = self:get_max_cur_line()
  end
  local line_count = api.nvim_buf_line_count(self.buffer)
  if cur_line > line_count - win_height then
    self.process.read_resume()
  else
    self.process.read_pause()
  end
end

function Buffer:go_to_match(window)
  local cur_line, cur_col = unpack(api.nvim_win_get_cursor(window))
  local match = self.matches[cur_line - 1]
  if match then
    local pos = match.line_number .. 'G' .. (cur_col + 1) .. '|'
    api.nvim_command('edit +keepjumps\\ normal\\ ' .. pos .. ' ' .. match.path)
  end
end

function Buffer:parse()
  local query = api.nvim_buf_get_name(self.buffer)
  local options, pattern = query:match("rg://([^/]*)/(.*)")
  if options:len() == 0 then
    options = {}
  else
    options = vim.split(options, ' +')
  end
  return options, pattern
end

function Buffer:append(lines)
  local start = self.appended and -1 or -2
  self.appended = true
  api.nvim_buf_set_option(self.buffer, 'modifiable', true)
  api.nvim_buf_set_lines(self.buffer, start, -1, true, lines)
  api.nvim_buf_set_option(self.buffer, 'modifiable', false)
  return api.nvim_buf_line_count(self.buffer) - 1
end

function Buffer:begin(data)
  local title = {data.path.text}
  if self.appended then
    table.insert(title, 1, '')
  end
  local line = self:append(title)
  api.nvim_buf_add_highlight(self.buffer, -1, 'rgFileName', line, 0, -1)
end

function Buffer:match(data)
  if data.lines.bytes or data.path.bytes then
    return
  end
  local line = self:append(split_lines(data.lines.text))
  for i, m in ipairs(data.submatches) do
    api.nvim_buf_add_highlight(self.buffer, -1, 'rgMatch', line, m.start, m['end'])
  end
  self.matches[line] = {
    line = line,
    line_number = data.line_number,
    path = data.path.text,
  }
end

function spawn(cmd, args, callback)
  local reading = false
  local handle
  local stdout = loop.new_pipe(false)

  function on_read(err, chunk)
    if err then error(err) end
    vim.schedule(function () callback(chunk) end)
  end

  function on_exit(code, signal)
    stdout:read_stop()
    stdout:close()
    handle:close()
  end

  local process = {}

  function process.read_resume()
    if not reading then
      loop.read_start(stdout, on_read)
    end
  end

  function process.read_pause()
    loop.read_stop(stdout)
  end

  function process.kill()
    loop.read_stop(stdout)
    loop.process_kill(handle, 'SIGTERM')
  end

  handle = loop.spawn(cmd, {
    args = args,
    stdio = {nil, stdout, nil},
  }, on_exit)

  process.read_resume()

  return process
end

function split_lines(str)
  local lines = {}
  local len = str:len()
  local pos = 1
  while pos <= len do
    local b, e = str:find("\r?\n", pos)
    if b then
      table.insert(lines, str:sub(pos, b - 1))
      pos = e + 1
    else
      table.insert(lines, str:sub(pos))
      break
    end
  end
  return lines
end

function each_line(callback)
  local feed
  feed = coroutine.wrap(function (chunk)
    local line = ''
    local cursor = 1
    while chunk do
      local newline = chunk:find('\n', cursor)
      line = line .. chunk:sub(cursor, newline)
      if newline then
        cursor = newline + 1
        callback(line)
        line = ''
      else
        chunk = coroutine.yield()
        cursor = 1
      end
    end
  end)
  return feed
end
