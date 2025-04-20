local uv = vim.uv

local function spawn(cmd, args, callback)
  local handle
  local stdout = uv.new_pipe(false)

  local process = {}

  local function on_read(err, chunk)
    if err then
      vim.notify('ripgrep.nvim: ' .. err, vim.log.levels.ERROR)
      process.kill()
    elseif chunk then
      vim.schedule(function () callback(chunk) end)
    end
  end

  function process.read_resume()
    stdout:read_start(on_read)
  end

  function process.read_pause()
    stdout:read_stop()
  end

  function process.kill()
    handle:kill('sigkill')
  end

  handle = vim.uv.spawn(
    cmd,
    {
      args = args,
      stdio = {nil, stdout, nil},
    },
    function ()
      stdout:read_stop()
      stdout:close()
      handle:close()
    end
  )

  -- TODO: if handle is nil close stdout

  process.read_resume()

  return process
end

return spawn
