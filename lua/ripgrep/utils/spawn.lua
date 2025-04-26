local function spawn(cmd, args, callback)
  local process_handle
  local stdout = vim.uv.new_pipe(false)

  local process = {}

  local function on_read(err, chunk)
    if err then
      vim.notify('ripgrep.nvim: ' .. err, vim.log.levels.ERROR)
      process.stop()
    elseif chunk then
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

return spawn
