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

function ripgrep.get_buffer(buffer)
  if buffers[buffer] == nil then
    buffers[buffer] = Buffer.new(buffer)
  end
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

function Buffer:set_options()
  api.nvim_buf_set_option(self.buffer, 'filetype', 'ripgrep')
  api.nvim_buf_set_option(self.buffer, 'buftype', 'nofile')
  api.nvim_buf_set_option(self.buffer, 'bufhidden', 'hide')
  api.nvim_buf_set_option(self.buffer, 'swapfile', false)
  api.nvim_buf_set_option(self.buffer, 'modifiable', false)
  api.nvim_buf_set_option(self.buffer, 'modified', true)
end

function Buffer:spawn()
  spawn('rg', {'--json', '--', self:get_pattern()}, function (err, output)
    local len = output:len()
    local pos = 1
    while pos <= len do
      local obj, err
      obj, pos = dkjson.decode(output, pos)
      if obj and self[obj.type] then
        self[obj.type](self, obj.data)
      end
    end
  end)
end

function Buffer:go_to_match(window)
  local cur_line, cur_col = unpack(api.nvim_win_get_cursor(window))
  local match = self.matches[cur_line - 1]
  if match then
    local pos = match.line_number .. 'G' .. (cur_col + 1) .. '|'
    api.nvim_command('edit +keepjumps\\ normal\\ ' .. pos .. ' ' .. match.path.text)
  end
end

function Buffer:get_pattern()
  local query = api.nvim_buf_get_name(self.buffer)
  return query:match("rg://(.*)")
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
  local line = self:append(split_lines(data.lines.text))
  for i, m in ipairs(data.submatches) do
    api.nvim_buf_add_highlight(self.buffer, -1, 'rgMatch', line, m.start, m['end'])
  end
  data.line = line
  self.matches[line] = data
end

function spawn(cmd, args, callback)
  local handle
  local chunks = {}
  local stdout = loop.new_pipe(false)

  function on_read(err, chunk)
    if err then
      vim.schedule(function () callback(err) end)
    elseif chunk then
      table.insert(chunks, chunk)
    end
  end

  function on_exit(code, signal)
    stdout:read_stop()
    stdout:close()
    handle:close()
    vim.schedule(function () callback(nil, table.concat(chunks)) end)
  end

  handle = loop.spawn(cmd, {
    args = args,
    stdio = {nil, stdout, nil},
  }, on_exit)

  loop.read_start(stdout, on_read)
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
