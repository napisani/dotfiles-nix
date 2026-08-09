" set runtimepath^=~/.vim
" let &packpath = &runtimepath
" source ~/.config/nvim/primary.viminit

set termguicolors
lua << EOF
-- vim.g.user_ui2 = false -- uncomment to disable experimental ui2 (cmdline / messages)
require("user.init")
EOF
