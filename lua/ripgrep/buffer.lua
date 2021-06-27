local class = require('ripgrep.class')
local spawn_json_producer = require('ripgrep.utils.spawn_json_producer')
local split_lines = require('ripgrep.utils.split_lines')
local api = vim.api

local Buffer = class()

function Buffer:initialize(bufnr)
    self.bufnr = bufnr
    self.matches = {}
    self.windows = {}
    self.appended = false

    self:set_options()
    self:spawn()
end

function Buffer:close()
    self.process.kill()
end

function Buffer:setup_window(window)
    api.nvim_win_set_option(window, 'number', false)
    api.nvim_win_set_option(window, 'relativenumber', false)
    table.insert(self.windows, window)
end

function Buffer:set_options()
    api.nvim_buf_set_option(self.bufnr, 'filetype', 'ripgrep')
    api.nvim_buf_set_option(self.bufnr, 'buftype', 'nowrite')
    api.nvim_buf_set_option(self.bufnr, 'bufhidden', 'hide')
    api.nvim_buf_set_option(self.bufnr, 'swapfile', false)
    api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

function Buffer:append(lines)
    vim.schedule(function () self:pause_or_resume() end)

    local start = self.appended and -1 or -2

    self.appended = true

    api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
    api.nvim_buf_set_lines(self.bufnr, start, -1, true, lines)
    api.nvim_buf_set_option(self.bufnr, 'modifiable', false)

    return api.nvim_buf_line_count(self.bufnr) - 1
end

function Buffer:begin_file(filename)
    local title = {filename}

    if self.appended then
        table.insert(title, 1, '')
    end

    local line = self:append(title)
    api.nvim_buf_add_highlight(self.bufnr, -1, 'rgFileName', line, 0, -1)
end

function Buffer:add_file_match(line, submatches)
    local index = self:append(split_lines(line))

    for _, submatch in ipairs(submatches) do
        api.nvim_buf_add_highlight(self.bufnr, -1, 'rgMatch', index, submatch.start, submatch['end'])
    end

    self.last_line = index
end

function Buffer:spawn()
    local options, pattern = self:parse()
    local args = vim.tbl_flatten({'--json', options, '--', pattern})
    self.process = spawn_json_producer('rg', args, {
        begin = function (data)
            print('begin', vim.inspect(data))
            self:begin_file(data.path.text)
        end,
        match = function (data)
            if data.lines.bytes or data.path.bytes then
                return
            end
            self:add_file_match(data.lines.text, data.submatches)
        end,
    })
end

function Buffer:parse()
    local query = api.nvim_buf_get_name(self.bufnr)
    local options, pattern = query:match("rg://([^/]*)/(.*)")
    if options == nil then
        error('bad ripgrep uri (rg://[options]/pattern)')
    elseif options:len() == 0 then
        options = {}
    else
        options = vim.split(options, ' +')
    end
    return options, pattern
end

function Buffer:get_max_cur_line()
    local max_cur_line = -1
    local win_height = 0
    for idx, winid in pairs(self.windows) do
        local success, cursor = pcall(api.nvim_win_get_cursor, window)
        if not success then
            -- assume window doesn't exist anymore
            self.windows[idx] = nil
        else
            local cur_line = unpack(cursor)
            if cur_line > max_cur_line then
                max_cur_line = cur_line
                win_height = api.nvim_win_get_height(window)
            end
        end
    end
    return max_cur_line, win_height
end

function Buffer:cursor_moved(window)
    self:pause_or_resume(window)
end

function Buffer:pause_or_resume(window)
    local cur_line, win_height
    if window then
        cur_line = unpack(api.nvim_win_get_cursor(window))
        win_height = api.nvim_win_get_height(window)
    else
        cur_line, win_height = self:get_max_cur_line()
    end

    local line_count = api.nvim_buf_line_count(self.bufnr)
    if cur_line > line_count - win_height then
        self.process:read_resume()
    else
        self.process:read_pause()
    end
end

function Buffer:go_to_match(window)
    local cur_line, cur_col = unpack(api.nvim_win_get_cursor(window))
    local match = self.matches[cur_line - 1]
    if match then
        local pos = match.line_number .. 'G' .. (cur_col + 1) .. '|'
        api.nvim_command('edit +keepjumps\\ normal\\ ' .. pos .. ' ' .. match.path)
    end
end

return Buffer
