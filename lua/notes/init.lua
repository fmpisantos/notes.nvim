local M = {}

local state = require("notes.src.state").state;
local functions = require("notes.src.functions");
local constants = require("notes.constants");

if state == nil then
    return
end

function M.setup()
    vim.api.nvim_create_user_command("NotesSetup", functions.create_notes_directory, { nargs = 0 })
    vim.api.nvim_create_user_command("NotesSetPath", functions.set_Path, { nargs = 0 })

    if constants.update_paths() then
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
    end
end

return M;
