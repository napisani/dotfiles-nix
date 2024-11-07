-- vim.opt.runtimepath:append("~/code/monoscope")
require("user.options")
require("user.keymaps")
require("user.diff")
require("user.lazy")
require("user.notify")
require("user.colorscheme")
require("user.colorizer")
require("user.cmp")
require("user.lsp")
require("user.neoscopes")
require("user.telescope.init")
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
require("user.alpha")
require("user.whichkey.whichkey")
require("user.autocommands")
require("user.nvim-dap")
require("user.neoscroll")
-- require "user.iron"
require("user.github-search")

require("user.search-rules")
-- require "user.chatgpt"
require("user.gp")
-- require "user.dbee"
require("user.dadbod")
-- require("user.firenvim")
-- require("user.surround")
require("user.tmux-nav")
require("user.oil")
require("user.eyeliner")

-- Enable secure external rc files
vim.opt.exrc = true
-- Also enable secure mode when using exrc for security
vim.opt.secure = true
