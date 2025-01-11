local M = {}

local pre = require("awman.myPlugins.notes.constants").pre;
local utils = require("awman.myPlugins.notes.src.utils");
local state = require("awman.myPlugins.notes.src.state").state;
local functions = require("awman.myPlugins.notes.src.functions");

if state == nil then
    return
end

function M.setup()
    M.notesPath = utils.parse_path_helper(state.path .. "/notes");
    M.notes_inc = M.notesPath .. "/**";
    M.todosPath = utils.parse_path_helper(state.path .. "/todos");
    M.todos_inc = M.todosPath .. "/**";
    M.todosDonePath = utils.parse_path_helper(state.path .. "/todos/done");
    M.todosDeletedPath = utils.parse_path_helper(state.path .. "/todos/deleted");
    M.todosFilePath = utils.parse_path_helper(state.path .. "/todos.md");

    vim.api.nvim_create_user_command("NotesSetup", functions.create_notes_directory, { nargs = 0 })
    vim.api.nvim_create_user_command("Notes", function()
        functions.open(M.notesPath);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("Todos", function()
        functions.open(M.todosPath);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("Note", function()
        local id = functions.get_next_id(M.notesPath, "note");
        local path = M.notesPath .. "/note" .. id .. ".md";
        functions.open(path);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("Todo", functions.open_new_todo, { nargs = 0 })
    vim.api.nvim_create_user_command("GotoNotes", function()
        vim.cmd("e " .. M.notesPath);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("GotoTodos", function()
        vim.cmd("e " .. M.todosFilePath);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("NotesRestart", functions.refresh, { nargs = 0 })
    vim.api.nvim_create_user_command("TodosRestart", functions.refresh, { nargs = 0 })
    vim.api.nvim_create_user_command("TodosRefresh", functions.refresh, { nargs = 0 })
    vim.api.nvim_create_user_command("NotesRefresh", functions.refresh, { nargs = 0 })
    vim.api.nvim_create_user_command("NotesSetPath", functions.set_Path, { nargs = 0 })

    if not functions.is_note_folder() then
        return
    end

    vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = { M.notes_inc, M.todos_inc },
        callback = function()
            local current_path = vim.fn.expand('%:p');
            if pre[current_path] then
                return
            end
            pre[current_path] = vim.fn.filereadable(current_path) == 0
        end,
    });

    vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = { M.notes_inc, M.todos_inc },
        callback = function()
            local current_path = vim.fn.expand('%:p');
            if pre[current_path] then
                functions.new_file(current_path);
            else
                functions.update();
            end
            pre[current_path] = false;
        end,
    });

    vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = { M.todosFilePath },
        callback = function()
            functions.on_todos_md_updated()
            vim.cmd("e " .. M.todosFilePath);
        end,
    });

    vim.api.nvim_create_autocmd('BufDelete', {
        pattern = { M.notes_inc, M.todos_inc },
        callback = function(event)
            local filepath = vim.api.nvim_buf_get_name(event.buf)
            functions.on_file_delete(filepath)
        end,
    });
end

return M;
