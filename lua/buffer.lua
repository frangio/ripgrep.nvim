local api = vim.api

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

local Buffer = {}

function Buffer:new(buffer, search)
    local state = {
        buffer = buffer,
        search = search,
        last_line = 0,
        done_callbacks = {},
        windows = {},
        appended = false
    }

    self.__index = self
    local _buffer = setmetatable(state, self)
    _buffer:set_options()
    _buffer:spawn()
    return _buffer
end

function Buffer:close()
    self.search.process.kill()
end

function Buffer:setup_window(window)
    api.nvim_win_set_option(window, 'number', false)
    api.nvim_win_set_option(window, 'relativenumber', false)
    table.insert(self.windows, window)
end

function Buffer:set_options()
    api.nvim_buf_set_option(self.buffer, 'filetype', 'ripgrep')
    api.nvim_buf_set_option(self.buffer, 'buftype', 'acwrite')
    api.nvim_buf_set_option(self.buffer, 'bufhidden', 'hide')
    api.nvim_buf_set_option(self.buffer, 'swapfile', false)
end

function Buffer:append(lines)
    local start = self.appended and -1 or -2

    self.appended = true

    api.nvim_buf_set_lines(self.buffer, start, -1, true, lines)
    api.nvim_buf_set_option(self.buffer, 'modified', false)

    return api.nvim_buf_line_count(self.buffer) - 1
end

function Buffer:begin(data)
    local title = {data.path.text}

    if self.appended then
        table.insert(title, 1, '')
    end

    local line = self:append(title)
    api.nvim_buf_add_highlight(self.buffer, -1, 'rgFileName', line, 0, -1)
end

function Buffer:match(data)
    local index = self:append(split_lines(data.lines.text))

    for _, match in ipairs(data.submatches) do
        api.nvim_buf_add_highlight(self.buffer, -1, 'rgMatch', index, match.start, match['end'])
    end

    self.last_line = index
end

function Buffer:get_index()
    return self.last_line
end

function Buffer:on_write()
  local changes = {}

  local message = "Are you sure you would like to overwrite the following files?\n"
  local filenames = {}

  for ind, match in pairs(self.search.matches) do
    local filename = match.path
    local lines, new_text = self:make_change(match)

    if lines then
      table.insert(changes, {
        filename = filename,
        lines = lines,
        match_ind = ind,
        new_text = new_text
      })

      if not vim.tbl_contains(filenames, filename) then
        table.insert(filenames, filename)
      end
    end
  end

  if #changes > 0 then
    message = message .. table.concat(filenames, " ")
    print(message .. " (y/N) ")

    local input = vim.fn.nr2char(vim.fn.getchar()):lower()
    if input == 'y' then
      for _, change in ipairs(changes) do
        vim.fn.writefile(change.lines, change.filename)
        self.search.matches[change.match_ind].text = change.new_text

        api.nvim_buf_set_option(self.buffer, 'modified', false)
      end
    end
  end
end

function Buffer:make_change(match)
  local original = match.text
  original = string.sub(original, 1, #original - 1)
  local changed = vim.fn.getline(match.line + 1)

  if original ~= changed then
    local lines = vim.fn.readfile(match.path)
    lines[match.line_number] = changed

    return lines, changed
  end
end

function Buffer:spawn()
    self.search:set_callbacks(
        function(data) self:begin(data) end,
        function(data) return self:match(data) end,
        function() end,
        function() return self:get_index() end
    )
    self.search:search()
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

function Buffer:pause_or_resume(window)
    local cur_line, win_height
    if window then
        cur_line = unpack(api.nvim_win_get_cursor(window))
        win_height = api.nvim_win_get_height(window)
    else
        cur_line, win_height = self:get_max_cur_line()
    end

    local line_count = api.nvim_buf_line_count(self.buffer)
    if cur_line > line_count - win_height then
        self.search:read_resume()
    else
        self.search:read_pause()
    end

end

function Buffer:go_to_match(window)
    local cur_line, cur_col = unpack(api.nvim_win_get_cursor(window))
    local match = self.search.matches[cur_line - 1]
    if match then
        local pos = match.line_number .. 'G' .. (cur_col + 1) .. '|'
        api.nvim_command('edit +keepjumps\\ normal\\ ' .. pos .. ' ' .. match.path)
    end
end

return Buffer
