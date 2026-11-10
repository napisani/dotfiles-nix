local M = {}

local unpack = table.unpack or unpack

local function with_vantage(method, ...)
	local args = { ... }
	return function()
		local ok, vantage = pcall(require, "vantage")
		if not ok then
			vim.notify("vantage.nvim not found", vim.log.levels.WARN)
			return
		end

		local fn = vantage[method]
		if type(fn) ~= "function" then
			vim.notify("vantage.nvim has no public function " .. method, vim.log.levels.WARN)
			return
		end

		fn(unpack(args))
	end
end

local function command_opts(args)
	args = args or ""
	local fargs = {}
	for part in args:gmatch("%S+") do
		table.insert(fargs, part)
	end
	return {
		args = args,
		fargs = fargs,
		range = 0,
	}
end

-- Visual keymaps deliberately pass no range. These are plain Lua-function
-- keymaps, which never commit the '< / '> marks -- reading them here would
-- capture the *previous* selection. Leaving range = 0 lets Vantage resolve the
-- scope itself from the live visual selection (see vantage.visual.live_range),
-- which is still active when the callback runs.
local function visual_opts(args)
	return command_opts(args)
end

-- Threads in a snacks picker instead of vim.ui.select; Vantage itself stays
-- picker-agnostic and exposes the entries through vantage.threads().
local function pick_threads()
	local ok_vantage, vantage = pcall(require, "vantage")
	local ok_snacks, snacks = pcall(require, "snacks")
	if not ok_vantage then
		vim.notify("vantage.nvim not found", vim.log.levels.WARN)
		return
	end
	if not ok_snacks then
		return vantage.pick_thread()
	end
	local review = require("vantage.review")
	local root = review.connection().root
	local items = {}
	for _, entry in ipairs(vantage.threads()) do
		table.insert(items, {
			text = table.concat({ entry.id, entry.status, entry.path or "workspace", entry.title }, " "),
			id = entry.id,
			status = entry.status,
			title = entry.title,
			where = entry.path and (entry.path .. ":" .. entry.line) or "workspace",
			file = entry.path and root and (root .. "/" .. entry.path) or nil,
			pos = entry.line and { entry.line, 0 } or nil,
		})
	end
	if #items == 0 then
		vim.notify("Vantage: no threads yet", vim.log.levels.INFO)
		return
	end
	snacks.picker.pick({
		title = "Vantage threads",
		items = items,
		format = function(item)
			return {
				{ string.format("%-4s ", item.id), "Identifier" },
				{ string.format("%-11s ", item.status), "Comment" },
				{ item.where .. "  ", "Directory" },
				{ item.title },
			}
		end,
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					require("vantage.review.ui.thread").open(item.id)
					require("vantage.review.ui.thread").jump_to_anchor(item.id)
				end)
			end
		end,
	})
end

-- The review base follows Diffview: opening a comparison sets it, closing it
-- clears it. A local convenience; Vantage only provides the explicit commands.
local function follow_diffview()
	local group = vim.api.nvim_create_augroup("user_vantage_diffview_base", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "DiffviewViewEnter",
		callback = function()
			local ok, lib = pcall(require, "diffview.lib")
			local view = ok and lib.get_current_view() or nil
			-- Only while connected, so opening Diffview never starts agent discovery.
			if
				not view
				or not view.left
				or not view.left.commit
				or require("vantage.review").connection().status ~= "connected"
			then
				return
			end
			local target = view.right and view.right.commit or nil
			local vantage = require("vantage")
			vantage.set_review_base({ ref = view.left.commit, target = target })
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "DiffviewViewClosed",
		callback = function()
			local review = require("vantage.review")
			local current = review.state()
			if current and current.base then
				require("vantage").clear_review_base()
			end
		end,
	})
end

M.opts = {
	input = {
		provider = "ui2",
	},
}

function M.setup()
	-- Vantage is configured lazily by the plugin spec when require("vantage")
	-- first loads vantage.nvim.
end

function M.configure(opts)
	local ok, vantage = pcall(require, "vantage")
	if not ok then
		vim.notify("vantage.nvim not found", vim.log.levels.WARN)
		return
	end

	vantage.setup(opts or M.opts)
	follow_diffview()
end

function M.get_keymaps()
	return {
		shared = {
			{ "<leader>v", group = "Vantage" },
			{ "<leader>vb", group = "Vantage agent" },
			{ "<leader>vd", group = "Vantage tours" },
		},
		normal = {
			{ "<leader>v?", with_vantage("ask", command_opts()), desc = "ask about line" },
			{ "<leader>vE", with_vantage("explain", command_opts()), desc = "explain line" },
			{ "<leader>vr", with_vantage("request", command_opts()), desc = "queue change request" },
			{ "<leader>ve", with_vantage("request_now", command_opts()), desc = "request change now" },
			{ "<leader>vS", with_vantage("send_round"), desc = "send change round" },
			{ "<leader>vR", with_vantage("reply", {}), desc = "reply to thread" },
			{ "<leader>vX", with_vantage("resolve", {}), desc = "resolve thread" },
			{ "<leader>vp", with_vantage("thread_peek"), desc = "peek thread" },
			{ "<leader>vo", with_vantage("thread_open"), desc = "open thread" },
			-- Under find with the other pickers: (T)hreads.
			{ "<leader>fT", pick_threads, desc = "Vantage (T)hreads" },
			{ "<leader>vt", with_vantage("sidebar"), desc = "toggle thread sidebar" },
			{ "<leader>va", with_vantage("annotate", command_opts()), desc = "annotate line" },
			{ "<leader>vA", with_vantage("annotate", command_opts("visible")), desc = "annotate visible" },
			{ "<leader>vx", with_vantage("clear_annotations"), desc = "clear annotations" },
			{ "<leader>vl", with_vantage("prompt_lens", "learning"), desc = "set lens" },
			{ "<leader>vL", with_vantage("clear_lens"), desc = "clear lens" },
			{ "<leader>vw", with_vantage("walkthrough", command_opts()), desc = "request walkthrough" },
			{ "<leader>vC", with_vantage("diff_tour", {}), desc = "request diff tour" },
			{ "<leader>vdc", with_vantage("tour_clear"), desc = "clear tours" },
			{ "<leader>vB", with_vantage("set_review_base", {}), desc = "set review base" },
			{ "<leader>vF", with_vantage("review_files"), desc = "changed files vs base" },
			{ "]c", with_vantage("tour_next"), desc = "next tour stop" },
			{ "[c", with_vantage("tour_prev"), desc = "previous tour stop" },
			{ "]t", with_vantage("thread_next"), desc = "next Vantage thread" },
			{ "[t", with_vantage("thread_prev"), desc = "previous Vantage thread" },
			-- Monitor mode binds nothing itself: each changed file opens as an
			-- ordinary buffer, so <C-o>/<C-i> walk recent edits natively.
			{ "<leader>vm", with_vantage("monitor"), desc = "listen for changes" },
			{ "<leader>vs", with_vantage("status"), desc = "status" },
			{ "<leader>vbc", with_vantage("cancel", {}), desc = "cancel request" },
			{ "<leader>vbr", with_vantage("recall_round"), desc = "recall change round" },
			{ "<leader>vbC", with_vantage("connect"), desc = "connect to agent" },
		},
		visual = {
			{
				"<leader>v?",
				function()
					with_vantage("ask", visual_opts())()
				end,
				desc = "ask about selection",
			},
			{
				"<leader>vE",
				function()
					with_vantage("explain", visual_opts())()
				end,
				desc = "explain selection",
			},
			{
				"<leader>vr",
				function()
					with_vantage("request", visual_opts())()
				end,
				desc = "queue change for selection",
			},
			{
				"<leader>ve",
				function()
					with_vantage("request_now", visual_opts())()
				end,
				desc = "request change for selection now",
			},
			{
				"<leader>va",
				function()
					with_vantage("annotate", visual_opts())()
				end,
				desc = "annotate selection",
			},
			{
				"<leader>vw",
				function()
					with_vantage("walkthrough", visual_opts())()
				end,
				desc = "request walkthrough from selection",
			},
		},
	}
end

return M
