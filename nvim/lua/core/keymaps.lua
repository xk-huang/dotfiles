vim.g.mapleader = " "

local keymap = vim.keymap


-- insert mode
-- keymap.set("i", "jk", "<ESC>")
-- I would prefer <C>-c


-- visual mode
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")


-- normal mode
keymap.set("n", "<leader>sv", "<C-w>v")
keymap.set("n", "<leader>sh", "<C-w>s")


-- unset serach highlight
keymap.set("n", "<leader>nh", ":nohl<CR>")


-- DO NOT CHANGE TOO MUCH KEYS

-- plugins
-- nvim-tree
keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")

-- switch between buffer
keymap.set("n", "<leader>l", ":bnext<CR>")
keymap.set("n", "<leader>h", ":bprevious<CR>")

