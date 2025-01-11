local M = {};

local functions = require("awman.myPlugins.notes.src.functions");
local tags = require("awman.myPlugins.notes.constants").tags;
local utils = require("awman.myPlugins.notes.src.utils")
local oilAutoCMD = require("awman.myPlugins.oilAutoCmd.init");

local function get_current_line_path()
    local line = vim.fn.getline('.');
    local _, _, path = utils.deserialize_todos_md_line(line);
    return path;
end

local function goto_file_in_todos_md()
    local path = get_current_line_path();
    if path then
        functions.open(path);
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
    local content = tags.todo .. "\n\n# " .. title;
    title = utils.parse_path(title);
    title = makeCamelCase(title, true);
    local file = io.open(utils.parse_path_helper(M.todosPath .. "/" .. title .. ".md"), "w");
    if file then
        file:write(content);
        file:close();
    end
    functions.refresh();
    vim.cmd("/" .. title);
    vim.cmd("normal! 0zz");
end

vim.api.nvim_create_autocmd('CursorMoved', {
    pattern = { M.todosFilePath },
    callback = update_split_content,
});

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { M.todosFilePath },
    callback = function()
        nmap('gf', goto_file_in_todos_md, { noremap = true, silent = true });
        nmap('gd', goto_file_in_todos_md, { noremap = true, silent = true });
        nmap('<Tab>', split_current_file, { noremap = true, silent = true });
        nmap('<leader>n', add_todo, { noremap = true, silent = true });
    end,
});

oilAutoCMD.setup(
    function(path)
        functions.on_file_delete(path)
    end,
    function(src, dest)
        functions.update_dont_open(src, functions.type_of_file_location(dest), true, dest)
        functions.update_todos_md()
    end,
    { M.notes_inc, M.todos_inc }
);
