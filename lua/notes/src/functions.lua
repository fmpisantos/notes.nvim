local M = {}

local oil = require("oil");
local constants = require("notes.constants");
local utils = require("notes.src.utils");
local _state = require("notes.src.state");
local state, save = _state.state, _state.save;

if not state then
    return
end

M.get_location_from_type = function(type)
    if type == "todo" then
        return constants.todosPath;
    else
        if type == "done" then
            return constants.todosDonePath;
        end
    end
    return constants.notesPath
end

M.open = function(path)
    utils.open_floating_window();
    vim.cmd("edit " .. path);
    vim.cmd("normal! G$");
end

M.update_path = function(path)
    if (path == nil) then
        path = vim.fn.expand('%:p');
    end
    if (save == nil) then
        return
    end
    path = utils.parse_path_helper(path);
    state.path = path
    state.opened = {}
    state.closed = {}
    save(state)
end

M.update_todos_md = function()
    local todo_file = io.open(constants.todosFilePath, "w")
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
    state.opened = utils.get_files(constants.todosPath, "todo") or {};
    state.closed = utils.get_files(constants.todosDonePath, "done") or {};
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

M.update_file_move = function(oldPath, newPath)
    local oldType = utils.type_of_file_location(oldPath);
    local newType = utils.type_of_file_location(newPath);
    if oldType == newType then
        return
    end
    utils.update_first_line(newPath, newType);
    local title = utils.get_title(newPath) or newPath;

    utils.update_state(oldType, newType, oldPath, newPath, title);
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
    newPath = newPath or M.get_location_from_type(newType) .. "/" .. vim.fn.fnamemodify(_oldPath, ":t");

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

M.delete_todo = function(filepath)
    local filename = vim.fn.fnamemodify(filepath, ":t:r");
    local newLocation = constants.todosDeletedPath .. "/" .. filename .. ".md";
    local _file = io.open(newLocation, "r");
    if _file then
        _file:close();
        local newFileName = filename .. ".1"
        newLocation = constants.todosDeletePath .. "/" .. newFileName .. ".md";
        _file = io.open(newLocation, "r");
        if _file then
            _file:close();
            newFileName = filename .. utils.get_next_id(constants.todosDeletedPath, filename) .. ".md";
            newLocation = constants.todosDeletedPath .. "/" .. newFileName;
        end
        newLocation = utils.parse_path_helper(newLocation):gsub("%./", "");
    end
    M.update_dont_open(filepath, nil, true, newLocation);
end

M.on_todos_md_updated = function()
    local file = io.open(constants.todosFilePath, "r");
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
        M.update_dont_open(path, title.type, true,
            M.get_location_from_type(title.type) .. "/" .. vim.fn.fnamemodify(path, ":t"):gsub("%./", ""));
    end
    for path, _ in pairs(to_remove) do
        M.delete_todo(path);
    end
    M.update_todos_md();
end

M.open_new_todo = function()
    local id = utils.get_next_id(constants.todosPath, "todo");
    local path = utils.parse_path_helper(constants.todosPath .. "/todo" .. id .. ".md");
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
    if (constants.update_paths()) then
        require("notes.src.autocmds");
    end
    M.refresh();
end

M.create_notes_directory = function()
    local projectName = vim.fn.input("Enter project name: ")
    if projectName == nil or projectName == "" then
        return
    end

    local path = oil.get_current_dir()
    local notes_path = utils.parse_path_helper(path .. "/" .. projectName)


    utils.create_dir(notes_path)

    utils.create_dir(notes_path .. "/notes")
    utils.create_dir(notes_path .. "/todos")
    utils.create_dir(notes_path .. "/todos/done")
    utils.create_dir(notes_path .. "/todos/deleted")

    io.open(utils.parse_path(notes_path .. "/notes/.gitkeep"), "w"):close()
    io.open(utils.parse_path(notes_path .. "/todos/.gitkeep"), "w"):close()
    io.open(utils.parse_path(notes_path .. "/todos/deleted/.gitkeep"), "w"):close()
    io.open(utils.parse_path(notes_path .. "/todos/done/.gitkeep"), "w"):close()

    local todo_file = io.open(utils.parse_path(notes_path .. "/todos.md"), "w")
    if todo_file then
        todo_file:write("# TODOS:\n\n## Open:\n\n## Closed:")
        todo_file:close()
    end

    vim.cmd(":edit!");
    oil.open(projectName);
    vim.cmd(":edit!");
    M.update_path(notes_path);
    constants.update_paths();
end

return M;
