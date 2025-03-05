local constants = require("notes.constants");
local functions = require("notes.src.functions");
local tags = require("notes.constants").tags;
local utils = require("notes.src.utils")
local oilAutoCMD = require("oilAutoCmd.init");

local function get_current_line_path()
    local line = vim.fn.getline('.');
    local _, _, path = utils.deserialize_todos_md_line(line);
    return path;
end

local function goto_file_in_todos_md()
    local path = get_current_line_path();
    if path then
        functions.open(utils.make_full_path(path));
    end
end

local function nmap(key, cmd, opts)
    opts.buffer = vim.api.nvim_get_current_buf()
    vim.keymap.set('n', key, cmd, opts);
end

local split_window = nil;

local function split_current_file()
    local current_win = vim.api.nvim_get_current_win();
    local path = get_current_line_path();
    if path then
        if split_window and vim.api.nvim_win_is_valid(split_window) then
            vim.api.nvim_set_current_win(split_window);
            vim.cmd('e ' .. path);
        else
            vim.cmd('vsplit ' .. path);
        end
        split_window = vim.api.nvim_get_current_win();
        vim.api.nvim_set_current_win(current_win);
    end
end

local function update_split_content()
    local current_win = vim.api.nvim_get_current_win();
    local filepath = get_current_line_path();
    if filepath and split_window then
        if vim.api.nvim_win_is_valid(split_window) then
            vim.api.nvim_set_current_win(split_window);
            vim.cmd('e ' .. filepath);
            vim.api.nvim_set_current_win(current_win);
        else
            split_window = nil;
        end
    end
end

local function makeCamelCase(title, firstCap)
    local ret = "";
    local i = 0;
    for words in string.gmatch(title, "%S+") do
        local first = string.lower(words)
        if i == 0 and firstCap then
            first = string.sub(words, 1, 1):upper();
        end
        local rest = string.sub(words, 2, #words);
        ret = ret .. first .. rest;
    end
    return ret;
end

local function add_todo()
    local title = vim.fn.input("Enter title: ");
    if title == nil or title == "" then
        return
    end
    local content  = tags.todo .. "\n\n# " .. title;
    local filePath = utils.parse_path(title);
    filePath       = makeCamelCase(title, true);
    local file     = io.open(utils.parse_path_helper(constants.todosPath .. "/" .. filePath .. ".md"), "w");
    if file then
        file:write(content);
        file:close();
    end
    functions.refresh();
    vim.cmd("/" .. title);
    vim.cmd("normal! 0zz");
end

vim.api.nvim_create_autocmd('CursorMoved', {
    pattern = { constants.todosFilePath },
    callback = update_split_content,
});

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { constants.todosFilePath },
    callback = function()
        functions.refresh();
        nmap('<CR>', goto_file_in_todos_md, { noremap = true, silent = true });
        nmap('gf', goto_file_in_todos_md, { noremap = true, silent = true });
        nmap('gd', goto_file_in_todos_md, { noremap = true, silent = true });
        nmap('<Tab>', split_current_file, { noremap = true, silent = true });
        nmap('<leader>n', add_todo, { noremap = true, silent = true });
    end,
});

if not functions.is_note_folder() then
    return
end

vim.api.nvim_create_user_command("TodosRefresh", functions.refresh, { nargs = 0 })

vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { constants.notes_inc, constants.todos_inc },
    callback = function()
        vim.print("BufWritePre");
        local current_path = vim.fn.expand('%:p');
        if constants.pre[current_path] then
            return
        end
        constants.pre[current_path] = vim.fn.filereadable(current_path) == 0
    end,
});

vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = { constants.notes_inc, constants.todos_inc },
    callback = function()
        vim.print("BufWritePost");
        local current_path = vim.fn.expand('%:p');
        if constants.pre[current_path] then
            functions.new_file(current_path);
        else
            functions.update();
        end
        constants.pre[current_path] = false;
    end,
});

vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = { constants.todosFilePath },
    callback = function()
        vim.print("BufWritePost");
        functions.on_todos_md_updated()
        vim.cmd("e " .. constants.todosFilePath);
    end,
});

vim.api.nvim_create_autocmd('BufDelete', {
    pattern = { constants.notes_inc, constants.todos_inc },
    callback = function(event)
        vim.print("BufDelete");
        local filepath = vim.api.nvim_buf_get_name(event.buf)
        functions.on_file_delete(filepath)
    end,
});

oilAutoCMD.setup(
    {
        func = function(path)
            functions.on_file_delete(path)
        end,
        pattern = { constants.todos_inc }
    },
    {
        func = function(src, dest)
            functions.update_file_move(src, utils.type_of_file_location(dest))
        end,
        pattern = { constants.notes_inc, constants.todos_inc },
        on_end = function()
            functions.update_todos_md()
        end
    }
);
