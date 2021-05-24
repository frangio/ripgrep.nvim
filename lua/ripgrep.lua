local Buffer = require("buffer")

local ripgrep = {}
ripgrep.buffers = {}

function ripgrep.init_buffer(buffer)
    if ripgrep.buffers[buffer] ~= nil then
        ripgrep.buffers[buffer]:close()
    end
    ripgrep.buffers[buffer] = Buffer:new(buffer)
end

function ripgrep.get_buffer(buffer)
    return ripgrep.buffers[buffer] or error('not an active ripgrep buffer!')
end

return ripgrep
