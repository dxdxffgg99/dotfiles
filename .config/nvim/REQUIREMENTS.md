# Requirements 

## tools

- Neovim ≥ 0.11
- git
- gcc / clang / make
- Nerd Font
- truecolor 터미널
- kitty (image.nvim)
- wl-clipboard (Wayland) 또는 xclip / xsel (X11)
- luarocks
- ImageMagick (magick)
- cmake
- gdb
- clangd
- clang-tidy
- cppcheck
- rustc / cargo
- rust-analyzer
- codelldb
- cargo-nextest
- python3
- pyright
- ruff
- debugpy
- pytest
- go
- gopls
- dlv (delve)
- node / npm
- typescript-language-server
- html-lsp / css-lsp
- live-server
- vnu (+ java)
- lua-language-server

## mason auto install

- lua-language-server
- typescript-language-server
- clangd
- rust-analyzer
- pyright
- gopls
- html-lsp
- css-lsp
- ruff
- codelldb
- delve
- debugpy
- vnu
- cppcheck

## plugins

- folke/lazy.nvim
- projekt0n/github-nvim-theme
- folke/tokyonight.nvim
- zaldih/themery.nvim
- nvim-lualine/lualine.nvim
- akinsho/bufferline.nvim
- folke/noice.nvim
- MunifTanjim/nui.nvim
- stevearc/dressing.nvim
- lukas-reineke/indent-blankline.nvim
- catgoose/nvim-colorizer.lua
- nvim-tree/nvim-web-devicons
- neovim/nvim-lspconfig
- williamboman/mason.nvim
- WhoIsSethDaniel/mason-tool-installer.nvim
- hrsh7th/nvim-cmp
- hrsh7th/cmp-nvim-lsp
- hrsh7th/cmp-buffer
- hrsh7th/cmp-path
- L3MON4D3/LuaSnip
- saadparwaiz1/cmp_luasnip
- rafamadriz/friendly-snippets
- ray-x/lsp_signature.nvim
- windwp/nvim-autopairs
- windwp/nvim-ts-autotag
- folke/which-key.nvim
- nvim-treesitter/nvim-treesitter
- nvim-treesitter/nvim-treesitter-textobjects
- p00f/clangd_extensions.nvim
- bfrg/vim-c-cpp-modern
- pboettch/vim-cmake-syntax
- nvim-telescope/telescope.nvim
- nvim-lua/plenary.nvim
- nvim-tree/nvim-tree.lua
- stevearc/aerial.nvim
- numToStr/Comment.nvim
- kylechui/nvim-surround
- ggandor/leap.nvim
- andymass/vim-matchup
- folke/todo-comments.nvim
- folke/trouble.nvim
- lewis6991/gitsigns.nvim
- sindrets/diffview.nvim
- NeogitOrg/neogit
- mfussenegger/nvim-dap
- rcarriga/nvim-dap-ui
- nvim-neotest/nvim-nio
- mfussenegger/nvim-dap-python
- nvim-neotest/neotest
- nvim-neotest/neotest-python
- nvim-neotest/neotest-go
- rouge8/neotest-rust
- akinsho/toggleterm.nvim
- rmagatti/auto-session
- barrett-ruth/live-server.nvim
- barrett-ruth/import-cost.nvim
- 3rd/image.nvim
- mfussenegger/nvim-lint
- dalmurii/LspToHtml.nvim

## install (Arch)

- `sudo pacman -S --needed base-devel git cmake gdb clang cppcheck luarocks imagemagick kitty wl-clipboard go nodejs npm jre-openjdk ttf-firacode-nerd rustup`
- `rustup default stable`
- `cargo install cargo-nextest`
- `pip install --user pytest`
- `npm i -g live-server`
- Neovim 안: `:Lazy sync` → `:MasonInstall gopls delve codelldb debugpy vnu` → `:checkhealth`
