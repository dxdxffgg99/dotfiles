-- =========================
-- lazy.nvim bootstrap
-- =========================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- =========================
-- basic options
-- =========================
vim.opt.number = true
vim.opt.signcolumn = "yes"

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

-- =========================
-- diagnostics
-- =========================
vim.diagnostic.config({
  virtual_text = {
    spacing = 4,
    prefix = "●",
  },

  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,

  float = {
    border = "rounded",
  },
})

-- =========================
-- workspace profiles
-- =========================
local function get_profile()
  local cwd = vim.fn.getcwd()

  local function exists(file)
    return vim.fn.filereadable(cwd .. "/" .. file) == 1
  end

  if exists("CMakeLists.txt") then
    return "cpp"
  end

  if exists("Cargo.toml") then
    return "rust"
  end

  if exists("package.json") then
    return "web"
  end

  if exists("pyproject.toml")
    or exists("requirements.txt")
  then
    return "python"
  end

  return "default"
end

local function apply_profile()
  local profile = get_profile()

  if profile == "cpp" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4

  elseif profile == "rust" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4

  elseif profile == "python" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4

  else
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(apply_profile, 50)
  end,
})

-- =========================
-- plugins
-- =========================
require("lazy").setup({

  -- =========================
  -- theme
  -- =========================
  {
    "projekt0n/github-nvim-theme",

    lazy = false,
    priority = 1000,

    config = function()
      require("github-theme").setup()

      vim.cmd(
        "colorscheme github_dark_high_contrast"
      )
    end,
  },

  -- =========================
  -- treesitter
  -- =========================
  {
    "nvim-treesitter/nvim-treesitter",

    build = ":TSUpdate",

    config = function()
      local ok, ts = pcall(
        require,
        "nvim-treesitter.configs"
      )

      if not ok then
        return
      end

      ts.setup({
        highlight = {
          enable = true,
        },

        indent = {
          enable = true,
        },
      })
    end,
  },

  -- =========================
  -- mason
  -- =========================
  {
    "williamboman/mason.nvim",

    build = ":MasonUpdate",

    config = function()
      require("mason").setup()

      vim.keymap.set(
        "n",
        "<leader>lm",
        ":Mason<CR>"
      )
    end,
  },

  -- =========================
  -- file tree
  -- =========================
  {
    "nvim-tree/nvim-tree.lua",

    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    config = function()
      require("nvim-tree").setup()

      vim.keymap.set(
        "n",
        "<C-n>",
        ":NvimTreeToggle<CR>"
      )
    end,
  },

  -- =========================
  -- LSP
  -- =========================
  {
    "neovim/nvim-lspconfig",

    event = {
      "BufReadPre",
      "BufNewFile",
    },

    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },

    config = function()
      local capabilities =
        require("cmp_nvim_lsp")
        .default_capabilities()

      local servers = {
        "ts_ls",
        "clangd",
        "rust_analyzer",
        "pyright",
        "html",
        "cssls",
      }

      for _, server in ipairs(servers) do
        vim.lsp.config(server, {
          capabilities = capabilities,
        })

        vim.lsp.enable(server)
      end

      vim.api.nvim_create_autocmd(
        "LspAttach",
        {
          callback = function(ev)
            local opts = {
              buffer = ev.buf,
            }

            vim.keymap.set(
              "n",
              "gd",
              vim.lsp.buf.definition,
              opts
            )

            vim.keymap.set(
              "n",
              "K",
              vim.lsp.buf.hover,
              opts
            )

            vim.keymap.set(
              "n",
              "<leader>rn",
              vim.lsp.buf.rename,
              opts
            )

            vim.keymap.set(
              "n",
              "<leader>ca",
              vim.lsp.buf.code_action,
              opts
            )

            vim.keymap.set(
              "n",
              "gr",
              vim.lsp.buf.references,
              opts
            )
          end,
        }
      )
    end,
  },

  -- =========================
  -- completion
  -- =========================
  {
    "hrsh7th/nvim-cmp",

    event = "InsertEnter",

    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },

    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },

        mapping =
          cmp.mapping.preset.insert({

            ["<Tab>"] =
              cmp.mapping.select_next_item(),

            ["<S-Tab>"] =
              cmp.mapping.select_prev_item(),

            ["<CR>"] =
              cmp.mapping.confirm({
                select = true,
              }),
          }),

        sources = cmp.config.sources({
          {
            name = "nvim_lsp",
          },

          {
            name = "buffer",
          },

          {
            name = "path",
          },
        }),

        completion = {
          autocomplete = {
            cmp.TriggerEvent.InsertEnter,
          },
        },
      })
    end,
  },

  -- =========================
  -- telescope
  -- =========================
  {
    "nvim-telescope/telescope.nvim",

    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    config = function()
      local builtin =
        require("telescope.builtin")

      vim.keymap.set(
        "n",
        "<leader>ff",
        builtin.find_files
      )

      vim.keymap.set(
        "n",
        "<leader>fg",
        builtin.live_grep
      )

      vim.keymap.set(
        "n",
        "<leader>fb",
        builtin.buffers
      )

      vim.keymap.set(
        "n",
        "<leader>fh",
        builtin.help_tags
      )
    end,
  },

})