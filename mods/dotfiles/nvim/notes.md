:LspInfo  -- show info about currently connected LSP server 
:LspInstallInfo -- show language servers that are installed / install new ones
:messages - show all vim.notify("test")
:NullLsInfo - show info about extra diagnostics and formatters attached to the open file



:Gvsplitdiff! origin/main   - compare in vsplit buffer (Side by side)
:G blame - show blame annoations on the left gutter


:DiffViewOpen %    - shows diff view for current file
:DiffViewOpen     - shows diff view for current workspace
:DiffViewOpen  main..HEAD   - shows diff to main 
:DiffViewClose - closes diff view



-- in vimdiff view
zo - open hidden section
zc - collapse expanded section


-- rust
:RustDebuggables to select a target for debugging

-- update tree sitter
:TSUpdate
