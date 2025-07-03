-- ~/.config/nvim/lua/configs/nvim-dap.lua

local dap = require("dap")
local dotnet = require("configs.nvim-dap-dotnet")
-- lua/configs/nvim-dap.lua
-- ...

local mason_path = vim.fn.stdpath("data") .. "/mason/packages/netcoredbg/netcoredbg"
-- local explicit_path = "$HOME/Documents/debuggers/netcoredbg/netcoredbg"

local netcoredbg_adapter = {
	type = "executable",
	command = mason_path,
	args = { "--interpreter=vscode" },
}

dap.adapters.netcoredbg = netcoredbg_adapter -- needed for normal debugging
dap.adapters.coreclr = netcoredbg_adapter -- needed for unit test debugging

dap.configurations.cs = {
	{
		type = "coreclr",
		name = "launch - netcoredbg",
		request = "launch",
		program = function()
			return dotnet.build_dll_path()
		end,

		-- justMyCode = false,
		-- stopAtEntry = false,
		-- -- program = function()
		-- --   -- todo: request input from ui
		-- --   return "/path/to/your.dll"
		-- -- end,
		-- env = {
		--   ASPNETCORE_ENVIRONMENT = function()
		--     -- todo: request input from ui
		--     return "Development"
		--   end,
		--   ASPNETCORE_URLS = function()
		--     -- todo: request input from ui
		--     return "http://localhost:5050"
		--   end,
		-- },
		-- cwd = function()
		--   -- todo: request input from ui
		--   return vim.fn.getcwd()
		-- end,
	},
}
