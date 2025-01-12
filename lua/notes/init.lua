local M = {}

local pre = require("notes.constants").pre;
local utils = require("notes.src.utils");
local state = require("notes.src.state").state;
local functions = require("notes.src.functions");
local constants = require("notes.constants");

if state == nil then
    return
end

function M.setup()
    vim.api.nvim_create_user_command("NotesSetup", functions.create_notes_directory, { nargs = 0 })
    vim.api.nvim_create_user_command("NotesSetPath", functions.set_Path, { nargs = 0 })

    constants.update_paths();

    vim.api.nvim_create_user_command("Notes", function()
        functions.open(constants.notesPath);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("Todos", function()
        functions.open(constants.todosPath);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("Note", function()
        local id = functions.get_next_id(constants.notesPath, "note");
        local path = constants.notesPath .. "/note" .. id .. ".md";
        functions.open(path);
    end, { nargs = 0 })
    vim.api.nvim_create_user_command("Todo", functions.open_new_todo, { nargs = 0 })

    if not functions.is_note_folder() then
        return
    end

    vim.api.nvim_create_user_command("TodosRefresh", functions.refresh, { nargs = 0 })

    vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = { constants.notes_inc, constants.todos_inc },
        callback = function()
            local current_path = vim.fn.expand('%:p');
            if pre[current_path] then
                return
            end
            pre[current_path] = vim.fn.filereadable(current_path) == 0
        end,
    });

    vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = { constants.notes_inc, constants.todos_inc },
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
        pattern = { constants.todosFilePath },
        callback = function()
            functions.on_todos_md_updated()
            vim.cmd("e " .. constants.todosFilePath);
        end,
    });

    vim.api.nvim_create_autocmd('BufDelete', {
        pattern = { constants.notes_inc, constants.todos_inc },
        callback = function(event)
            local filepath = vim.api.nvim_buf_get_name(event.buf)
            functions.on_file_delete(filepath)
        end,
    });
end

return M;
