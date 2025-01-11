local M = {}

local constants = require("awman.myPlugins.notes.constants");
local utils = require("awman.myPlugins.notes.src.utils");
local _state = require("awman.myPlugins.notes.src.state");
local state, save = _state.state, _state.save;

if not state then
    return
end


M.open = function(path)
    utils.open_floating_window();
    vim.cmd("edit " .. path);
    vim.cmd("normal! G$");
end

M.update_todos_md = function()
    local todo_file = io.open(M.todosFilePath, "w")
    if todo_file then
        todo_file:write("# TODOS:\n\n## Open:\n")
        for path, title in pairs(state.opened) do
            todo_file:write("- [ ] [" .. title .. "](" .. utils.parse_path(path) .. ")\n")
        end
        todo_file:write("\n## Closed:\n")
        for path, title in pairs(state.closed) do
            todo_file:write("- [x] [" .. title .. "](" .. utils.parse_path(path) .. ")\n")
        end
        todo_file:close()
    end
end

M.refresh = function()
    state.opened = utils.get_files(M.todosPath, "todo") or {};
    state.closed = utils.get_files(M.todosDonePath, "done") or {};
    M.update_todos_md();
    vim.cmd("e!");
end

M.is_note_folder = function()
    if not state.path then
        return
    end
    return utils.is_in_path_dir(state.path)
end

M.new_file = function(path)
    local todo, done = utils.get_todo_info();
    local type = "note";
    if done then
        type = "done";
    else
        if todo then
            type = "todo";
        end
    end
    utils.update_state(nil, type, nil, path, utils.get_title(path));
    M.update_todos_md();
end

M.update = function(_oldPath, newType, dont_update_todos_md, newPath, dontOpenBuffer)
    dont_update_todos_md = dont_update_todos_md or false;
    if not _oldPath then
        _oldPath = vim.fn.expand('%:p');
    end
    local oldType = utils.type_of_file_location(_oldPath);

    if not newType then
        local todo, done = utils.get_todo_info();
        if todo then
            if done then
                newType = "done";
            else
                newType = "todo";
            end
        else
            newType = "note";
        end
    else
        utils.update_first_line(_oldPath, newType);
    end
    newPath = newPath or utils.get_location_from_type(newType) .. "/" .. vim.fn.fnamemodify(_oldPath, ":t");

    local title = utils.get_title(_oldPath) or newPath;
    if newType ~= oldType then
        utils.update_state(oldType, newType, _oldPath, newPath, title)
        utils.move_file(_oldPath, newPath, dontOpenBuffer);
    end
    if not dont_update_todos_md then
        M.update_todos_md();
    end
end

M.update_dont_open = function(_oldPath, newType, dont_update_todos_md, newPath)
    M.update(_oldPath, newType, dont_update_todos_md, newPath, true);
end

M.on_file_delete = function(filepath)
    local type = utils.type_of_file_location(filepath);
    if type == "todo" then
        state.opened[filepath] = nil;
    else
        if type == "done" then
            state.closed[filepath] = nil;
        end
    end
    save(state);
    M.update_todos_md();
end

M.on_todos_md_updated = function()
    local file = io.open(M.todosFilePath, "r");
    if not file then
        return;
    end
    local lines = file:lines();
    local opened = {}
    local closed = {}
    local to_update = {}
    local to_remove = {}
    local hasStarted = false;
    for line in lines do
        if utils.starts_with(line, "## Open:") then
            hasStarted = true;
            goto continue
        end
        if utils.starts_with(line, "## Closed:") then
            hasStarted = true;
            goto continue
        end
        if not hasStarted then
            goto continue
        end
        if line and line ~= "" then
            local checkbox, title, path = utils.deserialize_todos_md_line(line);

            if checkbox then
                closed[path] = title;
                if not state.closed[path] then
                    to_update[path] = { type = "done", title };
                end
            else
                opened[path] = title;
                if not state.opened[path] then
                    to_update[path] = { type = "todo", title };
                end
            end
        end
        ::continue::
    end
    file:close();
    for path, _ in pairs(state.opened) do
        if not closed[path] and not opened[path] then
            to_remove[path] = true;
        end
    end
    for path, _ in pairs(state.closed) do
        if not closed[path] and not opened[path] then
            to_remove[path] = true;
        end
    end
    for path, title in pairs(to_update) do
        M.update_dont_open(path, title.type, true, utils.get_location_from_type(title.type) .. "/" .. vim.fn.expand(path, ":t"));
    end
    for path, _ in pairs(to_remove) do
        local filename = vim.fn.fnamemodify(path, ":t:r");
        local newLocation = M.todosDeletedPath .. "/" .. filename .. ".md";
        local _file = io.open(newLocation, "r");
        if _file then
            _file:close();
            local _filename = filename ..
                utils.get_next_id(M.todosDeletedPath, filename) .. ".md";
            newLocation = utils.parse_path_helper(M.todosDeletedPath .. "/" .. _filename):gsub("%./", "");
        end
        M.update_dont_open(path, nil, true, newLocation);
    end
    M.update_todos_md();
end

M.open_new_todo = function()
    local id = utils.get_next_id(M.todosPath, "todo");
    local path = utils.parse_path_helper(M.todosPath "/todo" .. id .. ".md");
    local file = io.open(path, "w");
    if file then
        file:write("!TODO\n\n# ");
        file:close();
    end
    constants.pre[path] = true;
    M.open(path);
end

M.set_Path = function()
    state.closed = {}
    state.opened = {}
    state.path = nil
    save(state)
    M.update_path();
    M.refresh();
end


return M;
