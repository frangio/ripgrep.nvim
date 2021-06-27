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

return each_line
