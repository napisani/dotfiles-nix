-- Enable secure external rc files
vim.opt.exrc = true
-- Also enable secure mode when using exrc for security
vim.opt.secure = true

local exrc_manager = require("user.exrc_manager")
exrc_manager.source_local_config()
-- vim.opt.runtimepath:append("~/code/monoscope")
require("user.options")
require("user.keymaps")
require("user.diff")
require("user.lazy")
require("user.notify")
require("user.colorscheme")
require("user.colorizer")
-- require("user.cmp")
require("user.lsp")
-- require("user.neoscopes")
-- require("user.telescope.init")
require("user.gitsigns")
require("user.neogit")
require("user.hop")
require("user.treesitter")
require("user.autopairs")
require("user.comment")
require("user.nvim-tree")
require("user.bufferline")
require("user.lualine")
require("user.outline")
require("user.indentline")
-- require("user.alpha")
require("user.whichkey.whichkey")
require("user.autocommands")
require("user.nvim-dap")
-- require("user.neoscroll")
-- require("user.iron")
require("user.github-search")

-- require("user.search-rules")
-- require("user.gp")
require("user.codecompanion")
-- require "user.dbee"
require("user.dadbod")
-- require("user.firenvim")
-- require("user.surround")
require("user.tmux-nav")
require("user.oil")
require("user.eyeliner")
require("user.overseer")
require("user.context_nvim")

exrc_manager.setup()
