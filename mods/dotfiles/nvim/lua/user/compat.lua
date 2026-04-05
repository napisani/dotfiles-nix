-- Neovim 0.11+: builtin vim.tbl_flatten is deprecated (vim.iter is the replacement).
-- Some plugins still call it; shadow before lazy.nvim loads to avoid vim.deprecated noise.
if vim.iter then
	vim.tbl_flatten = function(t)
		return vim.iter(t):flatten():totable()
	end
end

-- Neovim 0.12+: `vim.validate{ key = { val, spec, ... } }` is deprecated (removed in Nvim 1.0).
-- Intercept the table form and forward to the positional API so plugins do not trigger
-- vim.deprecate (see `:checkhealth vim.deprecated`). Type short aliases (`n`, `s`, …) are
-- expanded because the positional form does not accept them.
do
	local type_aliases = {
		n = "number",
		s = "string",
		t = "table",
		b = "boolean",
		f = "function",
		c = "callable",
	}

	---@param validator vim.validate.Validator
	---@return vim.validate.Validator
	local function expand_validator_aliases(validator)
		local t = type(validator)
		if t == "string" then
			return type_aliases[validator] or validator
		elseif t == "table" then
			local out = {}
			for i, v in ipairs(validator) do
				out[i] = expand_validator_aliases(v)
			end
			return out
		end
		return validator
	end

	local orig_validate = vim.validate
	---@diagnostic disable-next-line: duplicate-set-field
	function vim.validate(name, value, validator, optional, message)
		if type(name) ~= "table" then
			return orig_validate(name, value, validator, optional, message)
		end
		local spec = name
		for param_name, sp in vim.spairs(spec) do
			if type(sp) ~= "table" then
				error(string.format("opt[%s]: expected table, got %s", param_name, type(sp)), 2)
			end
			local val, v0 = sp[1], sp[2]
			local v = expand_validator_aliases(v0)
			local msg = type(sp[3]) == "string" and sp[3] or nil
			local opt = sp[3] == true
			if not (opt and val == nil) then
				if opt then
					orig_validate(param_name, val, v, true)
				elseif msg then
					orig_validate(param_name, val, v, msg)
				else
					orig_validate(param_name, val, v)
				end
			end
		end
	end
end

-- NVIM 0.12: Plugins often call `vim.treesitter.start(buf, "markdown")` on nofile/float
-- buffers (Snacks, Agentic, which-key, Trouble, …). That path can still crash inside the
-- decoration provider: "attempt to call method 'range' (a nil value)". FileType-based skips
-- in user/plugins/code/treesitter.lua do not apply to those calls. Intercept markdown TS
-- globally and use regex syntax instead (set g:user_ts_markdown_treesitter = true to allow TS).
do
	local allow_md_ts = vim.g.user_ts_markdown_treesitter
	if not allow_md_ts then
		local orig_start = vim.treesitter.start
		function vim.treesitter.start(bufnr, lang)
			local b = bufnr
			if b == nil or b == 0 then
				b = vim.api.nvim_get_current_buf()
			end
			if not vim.api.nvim_buf_is_valid(b) then
				return false
			end
			local eff = lang
			if eff == nil or eff == "" then
				eff = vim.bo[b].filetype
			end
			local base = (eff or ""):match("^[^.]+") or eff
			if base == "markdown" or base == "markdown_inline" then
				pcall(vim.treesitter.stop, b)
				vim.bo[b].syntax = "markdown"
				return false
			end
			return orig_start(bufnr, lang)
		end
	end
end
