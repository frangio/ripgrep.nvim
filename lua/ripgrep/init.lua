local Buffer = require("ripgrep.buffer")
local Search = require("ripgrep.search")

local ripgrep = {}
ripgrep.buffers = {}

function ripgrep.add_buffer(buffer)
    if ripgrep.buffers[buffer.buffer] ~= nil then
        ripgrep.buffers[buffer.buffer]:close()
    end
    ripgrep.buffers[buffer.buffer] = buffer
end

function ripgrep.get_buffer(buffer)
    return ripgrep.buffers[buffer] or error('not an active ripgrep buffer!')
end

function ripgrep.search(options, pattern)
    local bufname = "rg://" .. options .. "/" .. pattern
    vim.cmd("edit " .. bufname)
    local bufnr = vim.fn.str2nr(vim.fn.bufnr(bufname))

    if options:len() == 0 then
        options = {}
    else
        options = vim.split(options, ' +')
    end

    local search = Search:new(options, pattern)
    local buffer = Buffer:new(bufnr, search)

    ripgrep.add_buffer(buffer)
end

return ripgrep
