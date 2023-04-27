" set runtimepath^=~/.vim
" let &packpath = &runtimepath
" source ~/.config/nvim/primary.viminit
set termguicolors
lua << EOF
-- vim.opt.runtimepath:append("~/code/monoscope")
require("user.init")
EOF
