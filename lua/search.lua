local api = vim.api
local dkjson = require('dkjson')
local loop = vim.loop

local function spawn(cmd, args, callback)
  local reading = false
  local handle
  local stdout = loop.new_pipe(false)

  local function on_read(err, chunk)
    if err then error(err) end
    vim.schedule(function () callback(chunk) end)
  end

  local function on_exit(code, signal)
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

local function each_line(callback)
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
    while true do
      if chunk then
        error('unexpected chunk after end of stream')
      end
      coroutine.yield()
    end
  end)
  return feed
end

local function split_lines(str)
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

local Search = {}

function Search:new(options, pattern, on_begin, on_match, on_finished)
    local state = {
        options = options,
        pattern = pattern,
        matches = {},
        cur_file_name = '',
        on_begin = nil,
        on_match = nil,
        on_finished = nil,
        process = nil
    }

    if type(on_begin) == "function" then
        state.on_begin = on_begin
    end
    if type(on_match) == "function" then
        state.on_match = on_match
    end
    if type(on_finished) == "function" then
        state.on_finished = on_finished
    end

    self.__index = self
    return setmetatable(state, self)
end

function Search:begin(data)
    self.on_begin(data)
end

function Search:match(data)
    if data.lines.bytes or data.path.bytes then
        return
    end

    local index = self.on_match(data)

    for _, match in ipairs(data.submatches) do
        api.nvim_buf_add_highlight(self.buffer, -1, 'rgMatch', index, match.start, match['end'])
    end

    self.matches[index] = {
        line = index,
        line_number = data.line_number,
        path = data.path.text,
        text = data.lines.text,
    }
end

function Search:search()
  local args = vim.tbl_flatten({'--json', self.options, '--', self.pattern})

  local line_callback = each_line(function (line)
    local obj = dkjson.decode(line)
    if self[obj.type] then

      self[obj.type](self, obj.data)
    end
  end)

  self.process = spawn('rg', args, function (chunk)
    vim.schedule(function () self:read_resume() end)
    line_callback(chunk)
  end)
  print(vim.inspect(self.process))
end

function Search:read_pause()
    self.process.read_pause()
end

function Search:read_resume()
    self.process.read_resume()
end

return Search
