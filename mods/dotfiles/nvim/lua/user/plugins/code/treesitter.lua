local M = {}

-- Vim filetype (event.match), aligned with previous parser-name disables where they overlap.
local function highlight_disabled_ft(ft)
	local base = (ft or ""):match("^[^.]+") or ft
	local off = {
		css = true,
		-- Markdown + markdown_inline + injections: Neovim highlighter can throw
		-- "attempt to call method 'range' (a nil value)" (see neovim#27591-adjacent,
		-- nvim-treesitter#8618). Regex syntax is fine for .md.
		markdown = true,
		markdown_inline = true,
	}
	return off[base] or false
end

local function indent_disabled_ft(ft)
	local base = (ft or ""):match("^[^.]+") or ft
	local off = {
		python = true,
		css = true,
		markdown = true,
	}
	return off[base] or false
end

function M.setup()
	local lazy_ok, lazy = pcall(require, "lazy")
	if lazy_ok then
		lazy.load({ plugins = { "nvim-treesitter" }, wait = true })
	end

	local ts_ok, ts_err = pcall(require, "nvim-treesitter")
	if not ts_ok then
		vim.notify("nvim-treesitter not found: " .. tostring(ts_err), vim.log.levels.ERROR)
		return
	end

	-- nvim-treesitter `main` (0.12+): no `nvim-treesitter.configs`; see plugin README.
	local parser_install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
	require("nvim-treesitter").setup({
		install_dir = parser_install_dir,
	})

	local aug = vim.api.nvim_create_augroup("user_nvim_treesitter", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = aug,
		callback = function(args)
			local ft = args.match
			if not highlight_disabled_ft(ft) then
				pcall(vim.treesitter.start, 0)
			end
			if not indent_disabled_ft(ft) then
				-- Quotes must match `:h nvim-treesitter` indent section on main.
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end,
	})

	vim.schedule(function()
		local ts_config = require("nvim-treesitter.config")
		local parsers_mod = require("nvim-treesitter.parsers")
		local installed = ts_config.get_installed("parsers")
		local have = {}
		for _, lang in ipairs(installed) do
			have[lang] = true
		end

		local ignore = {
			phpdoc = true,
			["tree-sitter-phpdoc"] = true,
		}

		local missing = {}
		for _, lang in ipairs(vim.tbl_keys(parsers_mod)) do
			if not ignore[lang] and not have[lang] then
				missing[#missing + 1] = lang
			end
		end

		if #missing == 0 then
			return
		end

		-- Async install (do not `:wait()` — that blocks UI for hundreds of parsers on first run).
		local ok_install, install_err = pcall(function()
			require("nvim-treesitter").install(missing)
		end)
		if not ok_install then
			vim.notify("Failed to install tree-sitter parsers: " .. tostring(install_err), vim.log.levels.WARN)
		end
	end)
end

function M.get_keymaps()
	return {
		shared = {},
		normal = {},
		visual = {},
	}
end

return M
