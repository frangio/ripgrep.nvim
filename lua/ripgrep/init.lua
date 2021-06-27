local Buffer = require("ripgrep.buffer")

local ripgrep = {}
ripgrep.buffers = {}

function ripgrep.init_buffer(bufnr)
    if ripgrep.buffers[bufnr] ~= nil then
        ripgrep.buffers[bufnr]:close()
    end
    ripgrep.buffers[bufnr] = Buffer.new(bufnr)
end

function ripgrep.get_buffer(bufnr)
    return ripgrep.buffers[bufnr] or error('not an active ripgrep buffer!')
end

function ripgrep.open_search(options, pattern)
    local bufname = "rg://" .. options .. "/" .. pattern
    vim.cmd("edit " .. bufname)
end

return ripgrep
