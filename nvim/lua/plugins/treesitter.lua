require('nvim-treesitter.configs').setup {
    -- add different languages
    ensure_installed = { "vim", "vimdoc", "bash", "c", "cpp", "javascript", "json", "lua", "python", "typescript", "tsx", "css", "rust", "markdown", "markdown_inline" }, -- one of "all" or a list of languages
    -- What is "help"? It is "vimdoc"

    highlight = { enable = true },
    indent = { enable = true },

    --  parenthesis colors
    rainbow = {
        enable = true,
        extended_mode = true,
        max_file_lines = nil,
    }
}
