local M = {}

local highlight_disable = {
	css = true,
	-- Markdown uses split parsers + injections; on NVIM 0.12 the highlighter can
	-- intermittently error: "attempt to call method 'range' (a nil value)" inside
	-- nvim.treesitter.highlighter during parse (Decoration provider "start").
	-- Classic syntax highlighting is stable for .md; Treesitter adds little here.
	markdown = true,
	markdown_inline = true,
}

local indent_disable = {
	python = true,
	css = true,
	-- tree-sitter indents for markdown are noisy; vim's default is more predictable
	markdown = true,
}

function M.setup()
	local lazy_ok, lazy = pcall(require, "lazy")
	if lazy_ok then
		lazy.load({ plugins = { "nvim-treesitter" }, wait = true })
	end

	local ts_ok, ts = pcall(require, "nvim-treesitter")
	if not ts_ok then
		vim.notify("nvim-treesitter not found: " .. tostring(ts), vim.log.levels.ERROR)
		return
	end

	-- parser_install_dir (not install_dir) — wrong key was ignored and polluted modules table
	ts.setup({
		parser_install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
	})

	local highlight_group = vim.api.nvim_create_augroup("UserTreesitterHighlight", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = highlight_group,
		callback = function(event)
			local ft = vim.bo[event.buf].filetype
			if ft == "" or highlight_disable[ft] then
				return
			end
			pcall(vim.treesitter.start, event.buf)
		end,
	})

	local indent_group = vim.api.nvim_create_augroup("UserTreesitterIndent", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = indent_group,
		callback = function(event)
			local ft = vim.bo[event.buf].filetype
			if ft == "" or indent_disable[ft] then
				return
			end
			vim.bo[event.buf].indentexpr = "nvim_treesitter#indent()"
		end,
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

		-- ensure_installed is install { exclude_configured_parsers = true }; installs given langs
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
