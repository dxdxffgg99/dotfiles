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
vim.opt.swapfile = false
vim.opt.shortmess:append("I")
vim.opt.shortmess:append("c")
vim.opt.cmdheight = 0
vim.g.mapleader = " "

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
  update_in_insert = true,
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

  if profile == "cpp"
    or profile == "rust"
    or profile == "python"
  then
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
        ensure_installed = {
          "lua",
          "vim",
          "javascript",
          "typescript",
          "tsx",
          "html",
          "css",
          "json",
          "c",
          "cpp",
          "rust",
          "python",
        },

        auto_install = true,

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
  -- mason lspconfig
  -- =========================
  {
    "williamboman/mason-lspconfig.nvim",

    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },

    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "ts_ls",
          "clangd",
          "rust_analyzer",
          "pyright",
          "html",
          "cssls",
        },

        automatic_installation = true,
      })
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
    end,
  },

  -- =========================
  -- error lens
  -- =========================
  {
    "chikko80/error-lens.nvim",

    event = "BufRead",

    dependencies = {
      "nvim-telescope/telescope.nvim",
    },

    config = function()
      require("error-lens").setup({
        enabled = true,

        auto_adjust = {
          enable = false,
        },
      })
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
        "lua_ls",
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
      "windwp/nvim-autopairs",
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

      local cmp_autopairs =
        require(
          "nvim-autopairs.completion.cmp"
        )

      cmp.event:on(
        "confirm_done",
        cmp_autopairs.on_confirm_done()
      )
    end,
  },

  -- =========================
  -- autopairs
  -- =========================
  {
    "windwp/nvim-autopairs",

    event = "InsertEnter",

    config = function()
      require("nvim-autopairs").setup()
    end,
  },

  -- =========================
  -- auto tag
  -- =========================
  {
    "windwp/nvim-ts-autotag",

    event = {
      "BufReadPre",
      "BufNewFile",
    },

    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },

  -- =========================
  -- colorizer
  -- =========================
  {
    "catgoose/nvim-colorizer.lua",

    event = {
      "BufReadPre",
      "BufNewFile",
    },

    config = function()
      require("colorizer").setup()
    end,
  },

  -- =========================
  -- lint
  -- =========================
  {
    "mfussenegger/nvim-lint",

    event = {
      "BufEnter",
      "BufWritePost",
      "TextChanged",
      "TextChangedI",
      "InsertLeave",
    },

    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        python          = { "ruff" },
        cpp             = { "cppcheck" },
        c               = { "cppcheck" },
      }

      local timer = vim.uv.new_timer()

      local function debounced_lint()
        if vim.bo.buftype ~= "" then
          return
        end

        timer:stop()

        timer:start(
          500,
          0,
          vim.schedule_wrap(function()
            lint.try_lint()
          end)
        )
      end

      vim.api.nvim_create_autocmd({
        "BufEnter",
        "BufWritePost",
        "TextChanged",
        "TextChangedI",
        "InsertLeave",
      }, {
        callback = debounced_lint,
      })

      vim.keymap.set(
        "n",
        "<leader>ll",
        lint.try_lint,
        { desc = "Run linter" }
      )
    end,
  },
  {
    "3rd/image.nvim",

    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    config = function()
      require("image").setup({
        backend = "kitty",

        integrations = {
          markdown = {
            enabled = true,
            clear_in_insert_mode = false,
            download_remote_images = true,
          },
        },

        max_width = 100,
        max_height = 30,

        kitty_method = "normal",
      })
    end,
  },
  {
  "akinsho/bufferline.nvim",

  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },

  config = function()
    require("bufferline").setup({
      options = {
        diagnostics = "nvim_lsp",
        separator_style = "slant",
        always_show_bufferline = true,
      },
    })

    vim.opt.termguicolors = true
  end,
  },
})