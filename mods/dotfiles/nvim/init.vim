" set runtimepath^=~/.vim
" let &packpath = &runtimepath
" source ~/.config/nvim/primary.viminit

set termguicolors
lua << EOF
require("user.init")
EOF
