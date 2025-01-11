local M = {}

if M.tags then
    return M
end

M.tags = {
    todo = "!TODO",
    done = { "!TODO (DONE)", "!TODO (Done)", "!TODO (done)", "!TODO(DONE)", "!TODO(Done)", "!TODO(done)" }
}

M.pre = {}

return M;
