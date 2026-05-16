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

-- =========================
-- diagnostics (Error Lens)
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
  float = { border = "rounded" },
})

-- =========================
-- Workspace profile system
-- =========================
local function get_profile()
  local cwd = vim.fn.getcwd()

  local function exists(file)
    return vim.fn.filereadable(cwd .. "/" .. file) == 1
  end

  if exists("CMakeLists.txt") then return "cpp" end
  if exists("Cargo.toml") then return "rust" end
  if exists("package.json") then return "web" end
  if exists("pyproject.toml") or exists("requirements.txt") then return "python" end

  return "default"
end

local function apply_profile()
  local p = get_profile()

  if p == "cpp" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
  elseif p == "rust" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
  elseif p == "web" then
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
  elseif p == "python" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
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

  -- theme
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup()
      vim.cmd("colorscheme github_dark_high_contrast")
    end,
  },

  "nvim-treesitter/nvim-treesitter",

  -- file tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup()
      vim.keymap.set("n", "<C-n>", ":NvimTreeToggle<CR>")
    end,
  },

  -- =========================
  -- LSP
  -- =========================
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local servers = {
        "ts_ls",
        "clangd",
        "rust_analyzer",
        "pyright",
        "html",
        "cssls",
      }

      for _, lsp in ipairs(servers) do
        vim.lsp.config(lsp, {
          capabilities = capabilities,
        })
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }

          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        end,
      })
    end,
  },

  -- =========================
  -- CMP (FIXED - CRASH SAFE)
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

        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),

        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "buffer" },
          { name = "path" },
        }),

        completion = {
          autocomplete = { cmp.TriggerEvent.InsertEnter },
        },
      })
    end,
  },

  -- =========================
  -- Telescope LSP UI (SAFE)
  -- =========================
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local conf = require("telescope.config").values

      local function registry()
        return require("mason-registry")
      end

      local function get_list()
        local reg = registry()
        local list = {}

        for _, pkg in ipairs(reg.get_all_package_specs()) do
          local p = reg.get_package(pkg.name)
          table.insert(list, {
            name = pkg.name,
            installed = p:is_installed(),
          })
        end

        return list
      end

      vim.api.nvim_create_user_command("LspUI", function()
        pickers.new({}, {
          prompt_title = "LSP Manager",
          finder = finders.new_table({
            results = get_list(),
            entry_maker = function(entry)
              local mark = entry.installed and "✔" or "✖"
              return {
                value = entry,
                display = mark .. " " .. entry.name,
                ordinal = entry.name,
              }
            end,
          }),

          sorter = conf.generic_sorter({}),

          attach_mappings = function(bufnr, map)
            local function toggle()
              local sel = action_state.get_selected_entry().value
              local reg = registry()
              local pkg = reg.get_package(sel.name)

              if pkg:is_installed() then
                pkg:uninstall()
              else
                pkg:install()
              end

              actions.close(bufnr)
            end

            map("i", "<CR>", toggle)
            map("n", "<CR>", toggle)

            return true
          end,
        }):find()
      end, {})

      vim.keymap.set("n", "<leader>li", ":LspUI<CR>")
    end,
  },
})