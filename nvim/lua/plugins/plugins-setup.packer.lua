-- auto install packer
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- auto save and install
vim.cmd([[
    augroup packer_user_config
        autocmd!
        autocmd BufWritePost plugins-setup.lua source <afile> | PackerSync
    augroup end
]])

return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'folke/tokyonight.nvim'  -- theme
    use {
        'nvim-lualine/lualine.nvim',  -- status bar
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }  -- icon
    }
    use {
      'nvim-tree/nvim-tree.lua',  -- file explorer
      requires = {
        'nvim-tree/nvim-web-devicons', -- icon
      },
    }
    use("christoomey/vim-tmux-navigator")  -- Use <C>-hjkl to locate panel
    use("nvim-treesitter/nvim-treesitter")  -- syntax highlight
    use("p00f/nvim-ts-rainbow")  -- parenthesis colors
    use {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",  -- bridge between mason.nvim and lspconfig
        "neovim/nvim-lspconfig"
    }
    -- 自动补全
  use "hrsh7th/nvim-cmp"
  use "hrsh7th/cmp-nvim-lsp"
  use "L3MON4D3/LuaSnip" -- snippets引擎，不装这个自动补全会出问题
  use "saadparwaiz1/cmp_luasnip"
  use "rafamadriz/friendly-snippets"
  use "hrsh7th/cmp-path" -- 文件路径

  use "numToStr/Comment.nvim" -- gcc和gc注释
  use "windwp/nvim-autopairs" -- 自动补全括号

    use {
        'akinsho/bufferline.nvim',
        -- tag = "*",
        requires = 'nvim-tree/nvim-web-devicons'
    }
  use "lewis6991/gitsigns.nvim" -- 左则git提示

  use {
    'nvim-telescope/telescope.nvim', tag = '0.1.4',  -- 文件检索
    requires = { {'nvim-lua/plenary.nvim'} }
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)

