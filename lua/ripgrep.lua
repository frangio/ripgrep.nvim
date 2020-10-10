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
  return buffers[buffer]
end

function ripgrep.setup_window(window)
  api.nvim_win_set_option(window, 'number', false)
end

function Buffer:initialize(buffer)
  self.buffer = buffer
  self.matches = {}
  self.done_callbacks = {}

  self:set_options()
  self:spawn()
end

function Buffer:close()
  loop.read_stop(self.child_stdout)
  loop.process_kill(self.child, 'SIGTERM')
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
  self.child, self.child_stdout = spawn('rg', args, each_line(function (line)
    local obj = dkjson.decode(line)
    if self[obj.type] then
      self[obj.type](self, obj.data)
    end
  end))
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
    options = vim.split(options, ' ')
  end
  if pattern:len() == 0 then
    error('empty pattern')
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
  local handle
  local stdout = loop.new_pipe(false)

  function on_read(err, chunk)
    if err then
      error(err)
    end
    vim.schedule(function () callback(chunk) end)
  end

  function on_exit(code, signal)
    stdout:read_stop()
    stdout:close()
    handle:close()
  end

  handle = loop.spawn(cmd, {
    args = args,
    stdio = {nil, stdout, nil},
  }, on_exit)

  loop.read_start(stdout, on_read)

  return handle, stdout
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
