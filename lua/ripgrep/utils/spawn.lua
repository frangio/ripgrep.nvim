local loop = vim.loop

local function spawn(cmd, args, callback)
  local reading = false
  local handle
  local stdout = loop.new_pipe(false)

  local function on_read(err, chunk)
    if err then error(err) end
    vim.schedule(function () callback(chunk) end)
  end

  local function on_exit()
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
    loop.process_kill(handle, 'SIGKILL')
  end

  handle = loop.spawn(cmd, {
    args = args,
    stdio = {nil, stdout, nil},
  }, on_exit)

  process.read_resume()

  return process
end

return spawn
