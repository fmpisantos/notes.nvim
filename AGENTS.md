# Agent Guidelines for notes.nvim

## Build/Lint/Test Commands

This is a Neovim plugin with no build process. Use Neovim's built-in Lua interpreter for testing.

- **Lint**: No dedicated linter configured. Use Neovim's Lua syntax checking
- **Test single file**: `:luafile lua/notes/init.lua` to load the plugin
- **Test functionality**: `:NotesSetup` command to initialize and test core features
- **Manual testing**: Use `:source %` in any Lua file to test syntax

## Code Style Guidelines

### Language & Structure
- **Language**: Lua 5.1+ (Neovim's Lua runtime)
- **Module pattern**: Use `local M = {}` for all modules, return `M` at end
- **File structure**: Keep related functions in separate files under `lua/notes/src/`

### Imports & Dependencies
- **Import style**: `local module = require("path")` at top of file
- **Conditional imports**: Check `package.loaded['module']` before setup calls
- **Local scoping**: Always use `local` for variables and functions

### Naming Conventions
- **Functions**: camelCase (e.g., `getNextId`, `updateTodosMd`)
- **Variables**: camelCase (e.g., `currentPath`, `filePath`)
- **Constants**: PascalCase (e.g., `notesPath`, `todosFilePath`)
- **Modules**: snake_case for file names (e.g., `functions.lua`, `utils.lua`)

### Formatting
- **Indentation**: 4 spaces (no tabs)
- **Line endings**: Semicolons at end of statements
- **String quotes**: Double quotes for consistency
- **Table formatting**: Multi-line tables with proper alignment

### Error Handling
- **Nil checks**: Always check for nil before using variables
- **Error messages**: Use `vim.print()` or `vim.notify()` for user feedback
- **Graceful degradation**: Return early on errors rather than crashing

### File Operations
- **Path handling**: Use `utils.parse_path_helper()` for path normalization
- **File I/O**: Use `io.open()` with proper error checking
- **Vim filesystem**: Prefer `vim.loop` for async operations

### Best Practices
- **Performance**: Minimize file I/O operations, cache when possible
- **State management**: Use the state module for persistent data
- **Autocommands**: Group related autocommands logically
- **Key mappings**: Use buffer-local mappings with `nmap()` helper

### Dependencies
- **Oil.nvim**: Required for file operations (can be replaced with vim functions)
- **Shared_Buffer**: Required for buffer sharing
- **OilAutoCmd**: Required for autocommand integration

### Testing Approach
- **Manual testing**: Test commands like `:NotesSetup`, `:Note`, `:Todo`
- **Integration testing**: Verify file creation, movement, and state updates
- **Edge cases**: Test with missing directories, invalid paths, concurrent operations