local M = {}

local shared_buffs = require("awman.myPlugins.shared_buffer.init");

if M.state == nil then
    M.state, M.save = shared_buffs.setup("notes/state")
    if M.state == nil then
        return
    end
end

return M;
