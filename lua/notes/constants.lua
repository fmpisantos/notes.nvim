local M = {}

if M.tags then
    return M
end

local utils = require("notes.src.utils")
local oil = require("oil")

if package.loaded['oil'] == nil then
  oil.setup()
end

local _state = require("notes.src.state")
local state = _state.state

M.tags = {
    todo = "!TODO",
    done = { "!TODO (DONE)", "!TODO (Done)", "!TODO (done)", "!TODO(DONE)", "!TODO(Done)", "!TODO(done)" }
}

M.pre = {}

M.update_paths = function()
    if not state then
        return false
    end
    M.notesPath = utils.parse_path_helper(state.path .. "/notes");
    M.notes_inc = M.notesPath .. "/**";
    M.todosPath = utils.parse_path_helper(state.path .. "/todos");
    M.todos_inc = M.todosPath .. "/**";
    M.todosDonePath = utils.parse_path_helper(state.path .. "/todos/done");
    M.todosDeletedPath = utils.parse_path_helper(state.path .. "/todos/deleted");
    M.todosFilePath = utils.parse_path_helper(state.path .. "/todos.md");
    require("notes.src.autocmds");
    return true;
end

return M;
