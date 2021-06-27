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

return split_lines
