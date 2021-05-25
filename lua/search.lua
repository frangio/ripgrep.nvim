local api = vim.api
local dkjson = require('dkjson')
local loop = vim.loop

local function spawn(cmd, args, on_read_callback, on_exit_callback)
  local reading = false
  local handle
  local stdout = loop.new_pipe(false)

  local function on_read(err, chunk)
    if err then error(err) end
    vim.schedule(function () on_read_callback(chunk) end)
  end

  local function on_exit(_, _)
    stdout:read_stop()
    stdout:close()
    handle:close()
    if type(on_exit_callback) == "function" then
        vim.schedule(function () on_exit_callback() end)
    end
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

function Search:new(options, pattern, on_begin, on_match, on_finished, get_index)
    local state = {
        options = options,
        pattern = pattern,
        matches = {},
        on_begin = nil,
        on_match = nil,
        on_finished = nil,
        process = nil
    }

    self.__index = self
    local _search = setmetatable(state, self)
    _search:set_callbacks(on_begin, on_match, on_finished, get_index)
    return _search
end

function Search:set_callbacks(on_begin, on_match, on_finished, get_index)
    if type(on_begin) == "function" then
        self.on_begin = on_begin
    end
    if type(on_match) == "function" then
        self.on_match = on_match
    end
    if type(on_finished) == "function" then
        self.on_finished = on_finished
    end
    if type(get_index) == "function" then
        self.get_index = get_index
    end
end

function Search:begin(data)
    if type(self.on_begin) == "funciton" then self.on_begin(data) end
end

function Search:match(data)
    if data.lines.bytes or data.path.bytes then
        return
    end

    if type(self.on_match) == "function" then self.on_match(data) end
    local index, line
    if type(self.get_index) == "function" then
        index = self.get_index()
        line = index
    else
        index = #self.matches + 1
    end

    self.matches[index] = {
        line = line,
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
end

function Search:read_pause()
    self.process.read_pause()
end

function Search:read_resume()
    self.process.read_resume()
end

return Search
