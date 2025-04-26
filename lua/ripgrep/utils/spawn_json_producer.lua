local spawn = require('ripgrep.utils.spawn')
local each_line = require('ripgrep.utils.each_line')

local function spawn_json_producer(cmd, args, visitors)
  local callback = each_line(function (line)
    local obj = vim.json.decode(line)
    if visitors[obj.type] then
      visitors[obj.type](obj.data)
    end
  end)
  return spawn(cmd, args, callback)
end

return spawn_json_producer
