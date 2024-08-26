local opt = vim.opt


-- line number
opt.relativenumber = true
opt.number = true


-- indention
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true


-- no wrap
opt.wrap = false


-- cursor
opt.cursorline = true


-- mouse
opt.mouse:append("a")


-- clipboard
opt.clipboard:append("unnamedplus")


-- new panel
opt.splitright = true
opt.splitbelow = true


-- search
opt.ignorecase = true
opt.smartcase = true


-- appearance
opt.termguicolors = true
opt.signcolumn = "yes"
vim.cmd[[colorscheme tokyonight-moon]]

