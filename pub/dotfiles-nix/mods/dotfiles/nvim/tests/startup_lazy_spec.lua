assert(package.loaded["dadbod-grip"] == nil, "expected dadbod-grip to stay lazy during startup")
assert(vim.fn.exists(":GripConnect") == 2, "expected GripConnect lazy command to be registered")
assert(package.loaded["diffview"] == nil, "expected diffview to stay lazy during startup")
assert(vim.fn.exists(":DiffviewOpen") == 2, "expected DiffviewOpen lazy command to be registered")
assert(package.loaded["neogit"] == nil, "expected neogit to stay lazy during startup")
assert(vim.fn.exists(":Neogit") == 2, "expected Neogit lazy command to be registered")
assert(package.loaded["vantage"] == nil, "expected vantage to stay lazy during startup")
assert(vim.fn.exists(":VantageSetLens") == 2, "expected VantageSetLens lazy command to be registered")
assert(vim.fn.exists(":VantageQuestion") == 2, "expected VantageQuestion lazy command to be registered")
assert(vim.fn.exists(":VantageEdit") == 2, "expected VantageEdit lazy command to be registered")
assert(vim.fn.exists(":VantageAnnotate") == 2, "expected VantageAnnotate lazy command to be registered")

require("lazy").load({ plugins = { "dadbod-grip.nvim" } })
assert(package.loaded["dadbod-grip"] ~= nil, "expected dadbod-grip to load on demand")
assert(vim.g.db_ui_use_nerd_fonts == 1, "expected deferred dadbod-grip config to set database globals")
assert(type(vim.g.dbs) == "table", "expected deferred dadbod-grip config to set database connections")

require("lazy").load({ plugins = { "diffview.nvim" } })
assert(package.loaded["diffview"] ~= nil, "expected diffview to load on demand")

require("lazy").load({ plugins = { "neogit" } })
assert(package.loaded["neogit"] ~= nil, "expected neogit to load on demand")

require("lazy").load({ plugins = { "vantage.nvim" } })
assert(package.loaded["vantage"] ~= nil, "expected vantage to load on demand")

print("startup_lazy_spec: ok")
