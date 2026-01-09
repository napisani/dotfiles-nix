local M = {}

local highlight_disable = {
	css = true,
}

local indent_disable = {
	python = true,
	css = true,
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

	ts.setup({
		install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
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
			vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end,
	})

	vim.schedule(function()
		local ignore = {
			phpdoc = true,
			["tree-sitter-phpdoc"] = true,
		}

		local ok_available, available = pcall(ts.get_available)
		if not ok_available then
			vim.notify("Unable to query available tree-sitter parsers: " .. tostring(available), vim.log.levels.WARN)
			return
		end

		local installed = {}
		local ok_installed, installed_list = pcall(ts.get_installed, "parsers")
		if ok_installed then
			for _, lang in ipairs(installed_list) do
				installed[lang] = true
			end
		end

		local missing = {}
		for _, lang in ipairs(available) do
			if not ignore[lang] and not installed[lang] then
				table.insert(missing, lang)
			end
		end

		if #missing > 0 then
			local ok_install, err = pcall(ts.install, missing)
			if not ok_install then
				vim.notify("Failed to install tree-sitter parsers: " .. tostring(err), vim.log.levels.WARN)
			end
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
