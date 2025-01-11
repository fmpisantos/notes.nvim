local M = {};

local oil = require("oil");
local oilAutoCMD = require("awman.myPlugins.oilAutoCmd.init");
local tags = require("awman.myPlugins.notes.constants").tags;
local _state = require("awman.myPlugins.notes.src.state");
local state, save = _state.state, _state.save;

if not state then
    return
end

local floating_window = {
    buf = -1,
    win = -1
}

M.parse_path_helper = function(path)
    if path == nil then
        return path;
    end
    path = oilAutoCMD.get_actual_path(path);
    path = string.gsub(path, "\\", "/");
    path = string.gsub(path, "//", "/");
    return path;
end


M.parse_path = function(path)
    if path == nil then
        return path;
    end
    path = M.parse_path_helper(path);
    if state.path then
        path = string.gsub(path, state.path, "./");
    end
    return path;
end

M.contains = function(str1, str2)
    local clean_str1 = M.parse_path(str1:lower():gsub("%[.*%]", ""):gsub("[()%[%]]", ""))
    local clean_str2 = M.parse_path(str2:lower():gsub("%[.*%]", ""):gsub("[()%[%]]", ""))
    return clean_str1:find(clean_str2, 1, true) ~= nil
end

M.make_full_path = function(path)
    if path == nil then
        return path;
    end
    path = M.parse_path_helper(path);
    if state.path and M.contains(path, "./") then
        path = M.parse_path_helper(string.gsub(path, "%./", state.path .. "/"));
    end
    return path;
end

M.get_file_extension = function(filename)
    return filename:match("^.+(%..+)$")
end

M.is_directory = function(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == "directory"
end

M.open_buffer = function(destination)
    local buf_list = vim.api.nvim_list_bufs()
    local buf_exists = false
    for _, buf in ipairs(buf_list) do
        if vim.api.nvim_buf_get_name(buf) == destination then
            buf_exists = true
            vim.api.nvim_set_current_buf(buf)
            vim.cmd("edit!")
            break
        end
    end

    if not buf_exists then
        vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), destination)
        vim.cmd("edit!")
    end
end

M.open_floating_window = function()
    if floating_window.win ~= -1 and vim.api.nvim_win_is_valid(floating_window.win) then
        vim.api.nvim_win_hide(floating_window.win)
        return
    end
    floating_window = CreateFloatingWindow { buf = floating_window.buf, keepStyle = true };
end

M.get_location_from_type = function(type)
    if type == "todo" then
        return M.todosPath;
    else
        if type == "done" then
            return M.todosDonePath;
        end
    end
    return M.notesPath
end

M.deserialize_todos_md_line = function(line)
    local checkbox = line:match("%- %[(%S)%]") == "x";
    local title = line:match("%[(.-)%]");
    local path = line:match("%((.-)%)");
    return checkbox, title, path;
end

M.move_file = function(source, destination, dontOpenBuffer)
    source = M.make_full_path(source)
    if M.is_directory(destination) then
        destination = destination .. "/" .. vim.fn.expand(source, ":t")
    end
    destination = M.make_full_path(destination)
    local success, err = os.rename(source, destination)
    if not success then
        vim.print("Error moving file:", err)
        return
    end

    if dontOpenBuffer then
        return
    end
    M.open_buffer(destination);
end

M.update_first_line = function(newPath, newType)
    if newPath == nil or newPath == "" then
        return;
    end
    local file = io.open(newPath, "r");
    if not file then
        return;
    end
    local lines = file:lines();
    local newLines = {}
    local newLine = newType == "todo" and tags.todo or tags.done[1];
    for line in lines do
        if #newLines == 0 then
            for _, tag in ipairs(tags.done) do
                if M.contains(line, tag) then
                    if newType == "notes" then
                        goto continue
                    end
                    table.insert(newLines, newLine);
                    goto continue
                end
            end
            if M.contains(line, tags.todo) then
                if newType == "notes" then
                    goto continue
                end
                table.insert(newLines, newLine);
                goto continue
            end
            table.insert(newLines, newLine);
            table.insert(newLines, "\n");
            goto continue
        end
        if #newLines == 1 and (line == "" or line == "\n") and newType == "notes" then
            goto continue
        end
        table.insert(newLines, line);
        ::continue::
    end
    file:close();
    file = io.open(newPath, "w");
    if file then
        for i, line in ipairs(newLines) do
            if i ~= 1 then
                file:write("\n");
            end
            file:write(line);
        end
        file:close();
    end
end


M.starts_with = function(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

M.is_in_path_dir = function(base_path)
    local current_dir = M.parse_path_helper((oil.get_current_dir() or vim.fn.expand('%:p:h')) .. "/");
    base_path = M.parse_path_helper(base_path);
    if not current_dir or current_dir == "" then
        return false;
    end
    return M.contains(current_dir, base_path);
end

M.get_todo_info = function()
    local file = io.open(vim.fn.expand('%:p'), "r");
    if not file then
        return false, false
    end
    local line = file:read("*l")
    file:close();
    if M.contains(line, tags.todo) then
        for _, tag in ipairs(tags.done) do
            if M.contains(line, tag) then
                return true, true
            end
        end
        return true, false
    else
        return false, false;
    end
end

M.update_path = function(path)
    if (path == nil) then
        path = vim.fn.expand('%:p')
    end
    if (save == nil) then
        return
    end
    path = M.parse_path(path)
    state.path = path
    state.opened = {}
    state.closed = {}
    save(state)
end

M.create_dir = function(dir_path)
    dir_path = M.parse_path(dir_path)
    if vim.loop.fs_stat(dir_path) == nil then
        vim.loop.fs_mkdir(dir_path, 511)
    end
end

M.create_notes_directory = function()
    local projectName = vim.fn.input("Enter project name: ")
    if projectName == nil or projectName == "" then
        return
    end

    local path = oil.get_current_dir()
    local notes_path = M.parse_path_helper(path .. "/" .. projectName)


    M.create_dir(notes_path)

    M.create_dir(notes_path .. "/notes")
    M.create_dir(notes_path .. "/todos")
    M.create_dir(notes_path .. "/todos/done")
    M.create_dir(notes_path .. "/todos/deleted")

    io.open(M.parse_path(notes_path .. "/notes/.gitkeep"), "w"):close()
    io.open(M.parse_path(notes_path .. "/todos/.gitkeep"), "w"):close()
    io.open(M.parse_path(notes_path .. "/todos/done/.gitkeep"), "w"):close()

    local todo_file = io.open(M.parse_path(notes_path .. "/todos.md"), "w")
    if todo_file then
        todo_file:write("# TODOS:\n\n## Open:\n\n## Closed:")
        todo_file:close()
    end

    vim.cmd(":edit!");
    oil.open(projectName);
    vim.cmd(":edit!");
    M.update_path(notes_path);
end

M.type_of_file_location = function(path)
    path = M.parse_path(path)
    local current_file = vim.fn.expand(path .. ":p")
    current_file = M.parse_path(current_file)
    local base_path = M.parse_path(state.path)
    if not current_file or current_file == "" then
        return false
    end
    if M.contains(current_file, base_path .. "/todos/done") then
        return "done"
    end
    if M.contains(current_file, base_path .. "/todos") then
        return "todo"
    end
    return "note"
end

M.update_state = function(oldType, newType, oldPath, newPath, title)
    if state == nil then
        return;
    end
    if state.closed == nil then
        state.closed = {};
    end
    if state.opened == nil then
        state.opened = {};
    end
    if oldType == "todo" then
        state.opened[oldPath] = nil;
    else
        if oldType == "done" then
            state.closed[oldPath] = nil;
        end
    end
    if newType == "todo" then
        state.opened[newPath] = title;
    else
        if newType == "done" then
            state.closed[newPath] = title;
        end
    end

    save(state);
end

M.get_title = function(path)
    local file = io.open(path, "r");
    if not file then
        return nil;
    end
    for line in file:lines() do
        if line:find("#") then
            file:close();
            return line;
        end
    end
    file:close();
    return nil;
end

M.get_files = function(directory, filetype)
    directory = M.parse_path(directory);
    local uv = vim.loop
    local handle = uv.fs_opendir(directory)
    if not handle then
        print("Error opening directory: " .. directory)
        return
    end

    local files = {}

    while true do
        local entry = uv.fs_readdir(handle)
        if not entry then break end
        for _, file in ipairs(entry) do
            if file.type == "file" then
                if M.get_file_extension(file.name) == ".md" then
                    local path = directory .. "/" .. file.name;
                    files[path] = M.get_title(path);
                    M.update_first_line(path, filetype);
                end
            end
        end
    end

    uv.fs_closedir(handle)

    return files
end

M.get_next_id = function(path, prefix)
    local notes = vim.fn.glob(path .. "/" .. prefix .. "*.md", false, true)
    local max = 0
    for _, note in ipairs(notes) do
        local id = tonumber(note:match(prefix .. "(%d+).md"))
        if not id then
            goto continue
        end
        if id > max then
            max = id
        end
        ::continue::
    end
    return max + 1
end

return M;
