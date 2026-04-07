local M = {}

-- Parser names (what `parsers.get_buf_lang` returns), not always equal to 'filetype'.
local function highlight_disabled(lang)
	local off = {
		css = true,
		-- Markdown + markdown_inline + injections: Neovim highlighter can throw
		-- "attempt to call method 'range' (a nil value)" (see neovim#27591-adjacent,
		-- nvim-treesitter#8618). Regex syntax is fine for .md.
		markdown = true,
		markdown_inline = true,
	}
	return off[lang] or false
end

local function indent_disabled(lang)
	local off = {
		python = true,
		css = true,
		markdown = true,
	}
	return off[lang] or false
end

function M.setup()
	local lazy_ok, lazy = pcall(require, "lazy")
	if lazy_ok then
		lazy.load({ plugins = { "nvim-treesitter" }, wait = true })
	end

	local ts_ok, ts_top = pcall(require, "nvim-treesitter")
	if not ts_ok then
		vim.notify("nvim-treesitter not found: " .. tostring(ts_top), vim.log.levels.ERROR)
		return
	end

	local configs = require("nvim-treesitter.configs")

	-- Registers :TS* commands and calls configs.init() (defines builtin modules).
	-- Important: this function takes no arguments; options go through configs.setup only.
	ts_top.setup()

	local parser_install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")

	configs.setup({
		parser_install_dir = parser_install_dir,
		highlight = {
			enable = true,
			disable = highlight_disabled,
		},
		indent = {
			enable = true,
			disable = indent_disabled,
		},
	})

	vim.schedule(function()
		local parsers_mod = require("nvim-treesitter.parsers")
		local install_mod = require("nvim-treesitter.install")

		local ignore = {
			phpdoc = true,
			["tree-sitter-phpdoc"] = true,
		}

		local available = parsers_mod.available_parsers()
		local missing = {}
		for _, lang in ipairs(available) do
			if not ignore[lang] and not parsers_mod.has_parser(lang) then
				table.insert(missing, lang)
			end
		end

		if #missing == 0 then
			return
		end

		local ok_install, err = pcall(function()
			install_mod.ensure_installed(unpack(missing))
		end)
		if not ok_install then
			vim.notify("Failed to install tree-sitter parsers: " .. tostring(err), vim.log.levels.WARN)
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
