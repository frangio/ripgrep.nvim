local utils = {}

function utils.spawn(cmd, args, callback)
  local process_handle
  local stdout = vim.uv.new_pipe(false)

  local process = {}

  local function on_read(err, chunk)
    if err then
      vim.notify('ripgrep.nvim: ' .. err, vim.log.levels.ERROR)
      process.stop()
    else
      vim.schedule(function () callback(chunk) end)
    end
  end

  function process.resume()
    stdout:read_start(on_read)
  end

  function process.pause()
    stdout:read_stop()
  end

  function process.stop()
    process_handle:kill('sigkill')
  end

  process_handle = vim.uv.spawn(
    cmd,
    {
      args = args,
      stdio = {nil, stdout, nil},
    },
    function ()
      stdout:read_stop()
      stdout:close()
      process_handle:close()
    end
  )

  -- TODO: if process_handle is nil close stdout

  process.resume()

  return process
end

function utils.spawn_lines(cmd, args, callback)
  local next_line = '' --- @type string?
  return utils.spawn(cmd, args, function (chunk)
    if chunk == nil then
      callback(next_line)
      next_line = nil
    else
      local cursor = 1
      while cursor <= chunk:len() do
        local line_end = chunk:find('\n', cursor)
        next_line = next_line .. chunk:sub(cursor, line_end)
        if line_end == nil then
          break
        end
        callback(next_line)
        next_line = ''
        cursor = line_end + 1
      end
    end
  end)
end

function utils.list_concat(...)
  local res = {}
  for _, list in ipairs({...}) do
    vim.list_extend(res, list)
  end
  return res
end

return utils
