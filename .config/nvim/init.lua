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

vim.opt.number = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.fileencodings = "utf-8,euc-kr"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.swapfile = false
vim.opt.shortmess:append("I")
vim.opt.shortmess:append("c")
vim.opt.cmdheight = 0
vim.g.mapleader = " "

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

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

local function get_profile()
  local ext = vim.fn.expand("%:e")
  if ext == "cpp" or ext == "hpp" or ext == "cc" or ext == "cxx" or ext == "h" or ext == "c" then
    return "cpp"
  end
  if ext == "rs" then
    return "rust"
  end
  if ext == "py" then
    return "python"
  end

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
  local profile = get_profile()
  if profile == "cpp" or profile == "rust" or profile == "python" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
  else
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
  end
end

vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
  callback = function()
    vim.defer_fn(apply_profile, 50)
  end,
})

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  callback = function()
    local groups = {
      "NvimTreeGitDirty",
      "NvimTreeGitStaged",
      "NvimTreeGitMerge",
      "NvimTreeGitRenamed",
      "NvimTreeGitNew",
      "NvimTreeGitDeleted",
      "NvimTreeDiagnosticError",
      "NvimTreeDiagnosticWarn",
      "NvimTreeDiagnosticInfo",
      "NvimTreeDiagnosticHint",
    }
    for _, group in ipairs(groups) do
      vim.api.nvim_set_hl(0, group, { underline = false })
    end
  end,
})

local function setup_cmake_compile_commands()
  local root = vim.fn.getcwd()
  local build_dirs = { "build", "Build", "cmake-build-debug", "cmake-build-release" }
  
  for _, dir in ipairs(build_dirs) do
    local cmd_file = root .. "/" .. dir .. "/compile_commands.json"
    if vim.fn.filereadable(cmd_file) == 1 then
      local clangd_config = root .. "/.clangd"
      if vim.fn.filereadable(clangd_config) == 0 then
        local file = io.open(clangd_config, "w")
        if file then
          file:write("CompileFlags:\n  CompilationDatabase: " .. dir .. "\n")
          file:close()
        end
      end
      break
    end
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = setup_cmake_compile_commands,
})

local function get_build_command()
  local root = vim.fn.getcwd()
  local ext = vim.fn.expand("%:e")
  
  if ext == "cpp" or ext == "cc" or ext == "cxx" or ext == "c" or ext == "h" or ext == "hpp" then
    if vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 then
      local nproc = tonumber(vim.fn.system("nproc"):gsub("\n", "")) or 4
      local jobs = math.max(1, nproc - 1)
      return "cd " .. root .. " && " ..
             "([ -d build ] || mkdir build) && " ..
             "cd build && cmake .. && make -j" .. jobs
    else
      return nil
    end
  end
  
  if ext == "rs" then
    if vim.fn.filereadable(root .. "/Cargo.toml") == 1 then
      return "cd " .. root .. " && cargo build"
    else
      return nil
    end
  end
  
  if ext == "go" then
    if vim.fn.filereadable(root .. "/go.mod") == 1 then
      return "cd " .. root .. " && go build"
    else
      return nil
    end
  end
  
  return nil
end

local function get_run_command()
  local ext = vim.fn.expand("%:e")
  local filename = vim.fn.expand("%:t:r")
  local filepath = vim.fn.expand("%:p")
  local root = vim.fn.getcwd()
  
  if ext == "cpp" or ext == "cc" or ext == "cxx" or ext == "c" or ext == "h" or ext == "hpp" then
    if vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 then
      local executable = root .. "/build/" .. filename
      if vim.fn.filereadable(executable) == 1 then
        return executable
      else
        vim.notify("Build not found: " .. executable, vim.log.levels.ERROR)
        return nil
      end
    end
  end
  
  if ext == "rs" then
    if vim.fn.filereadable(root .. "/Cargo.toml") == 1 then
      return "cd " .. root .. " && cargo run"
    end
  end
  
  if ext == "go" then
    if vim.fn.filereadable(root .. "/go.mod") == 1 then
      return "cd " .. root .. " && go run ."
    else
      return "go run " .. filepath
    end
  end
  
  if ext == "py" then
    return "python3 " .. filepath
  end
  
  if ext == "js" or ext == "ts" or ext == "jsx" or ext == "tsx" then
    if vim.fn.filereadable(root .. "/package.json") == 1 then
      return "cd " .. root .. " && npm run dev"
    else
      return "node " .. filepath
    end
  end
  
  return nil
end

local function build_file()
  local cmd = get_build_command()
  if not cmd then
    vim.notify("Build not supported for: " .. vim.fn.expand("%:e"), vim.log.levels.WARN)
    return
  end
  
  local ok, toggleterm = pcall(require, "toggleterm")
  if ok then
    local Terminal = require("toggleterm.terminal").Terminal
    local builder = Terminal:new({
      cmd = cmd,
      direction = "float",
      float_opts = { border = "rounded" },
      on_exit = function(terminal, job, exit_code, name)
        if exit_code == 0 then
          vim.notify("✓ Build successful", vim.log.levels.INFO)
        else
          vim.notify("✗ Build failed with exit code " .. exit_code, vim.log.levels.ERROR)
        end
      end,
    })
    builder:toggle()
  else
    vim.cmd("terminal " .. cmd)
  end
end

local function run_file()
  local cmd = get_run_command()
  if not cmd then
    vim.notify("Run not supported for: " .. vim.fn.expand("%:e"), vim.log.levels.ERROR)
    return
  end
  
  local ok, toggleterm = pcall(require, "toggleterm")
  if ok then
    local Terminal = require("toggleterm.terminal").Terminal
    local runner = Terminal:new({
      cmd = cmd,
      direction = "float",
      float_opts = { border = "rounded" },
      on_exit = function(terminal, job, exit_code, name)
        if exit_code == 0 then
          vim.notify("✓ Run successful", vim.log.levels.INFO)
        else
          vim.notify("✗ Run failed with exit code " .. exit_code, vim.log.levels.ERROR)
        end
      end,
    })
    runner:toggle()
  else
    vim.cmd("terminal " .. cmd)
  end
end

vim.api.nvim_create_user_command("Build", build_file, {})
vim.api.nvim_create_user_command("Run", run_file, {})
vim.keymap.set("n", "<leader>b", "<cmd>Build<CR>", { desc = "Build project" })
vim.keymap.set("n", "<leader>r", "<cmd>Run<CR>", { desc = "Run executable" })

require("lazy").setup({

  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup()
      vim.cmd("colorscheme github_dark_high_contrast")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter.configs")
      if not ok then return end
      ts.setup({
        ensure_installed = {
          "lua", "vim", "javascript", "typescript", "tsx",
          "html", "css", "json", "c", "cpp", "rust", "python", "go",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
      vim.keymap.set("n", "<leader>lm", ":Mason<CR>")
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local servers = { "lua_ls", "ts_ls", "clangd", "rust_analyzer", "pyright", "gopls", "html", "cssls" }

      for _, server in ipairs(servers) do
        vim.lsp.config(server, { 
          capabilities = capabilities,
          flags = {
            debounce_text_changes = 300,
          }
        })
        vim.lsp.enable(server)
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        end,
      })
    end,
  },

  {
    "3rd/image.nvim",
    build = "luarocks --local install magick",
    opts = {
      backend = "kitty",
      integrations = {
        markdown = { enabled = true },
      },
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup()
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "Toggle file tree" })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
    end,
  },

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
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })

      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function() require("nvim-autopairs").setup() end,
  },

  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },

  {
    "catgoose/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    config = function() require("colorizer").setup() end,
  },

  {
    "folke/noice.nvim",
    lazy = false,
    priority = 900,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "InsertLeave" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        python = { "ruff" },
        cpp = { "cppcheck" },
        c = { "cppcheck" },
      }

      local timer = vim.uv.new_timer()
      local function debounced_lint()
        if vim.bo.buftype ~= "" then return end
        timer:stop()
        timer:start(500, 0, vim.schedule_wrap(function() lint.try_lint() end))
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "InsertLeave" }, {
        callback = debounced_lint,
      })

      vim.keymap.set("n", "<leader>ll", lint.try_lint, { desc = "Run linter" })
    end,
  },

  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          always_show_bufferline = true,
        },
      })
    end,
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 15,
        open_mapping = [[<c-\>]],
        direction = "horizontal",
      })
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("aerial").setup({
        on_attach = function(bufnr)
          vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>", { buffer = bufnr })
        end,
      })
    end,
  },

  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("Comment").setup()
    end,
  },

  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },

  {
    "ggandor/leap.nvim",
    keys = {
      { "s", "<Plug>(leap-forward-to)", mode = { "n", "x", "o" }, desc = "Leap forward to" },
      { "S", "<Plug>(leap-backward-to)", mode = { "n", "x", "o" }, desc = "Leap backward to" },
    },
    config = function()
      require("leap").opts.safe_labels = {}
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          component_separators = { left = "｜", right = "｜" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_x = { 
            { function() return get_profile() end },
            "encoding", 
            "fileformat", 
            "filetype" 
          },
        },
      })
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local colors = {
        "#12151c",
        "#171b24",
        "#1d212c",
        "#222734",
        "#282e3d",
        "#2d3445",
        "#333b4e",
      }

      local hl_groups = {}
      for i, color in ipairs(colors) do
        local name = "IndentColorizer" .. i
        vim.api.nvim_set_hl(0, name, { bg = color })
        table.insert(hl_groups, name)
      end

      require("ibl").setup({
        indent = {
          char = "",
          highlight = hl_groups,
        },
        whitespace = {
          highlight = hl_groups,
        },
        scope = { enabled = false },
      })
    end,
  },

  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {},
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    config = function()
      require("diffview").setup()
    end,
  },

  { 
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("todo-comments").setup()
      vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { desc = "Find TODOs" })
    end,
  },

  {
    "rmagatti/auto-session",
    lazy = false,
    opts = {
      log_level = "error",
      auto_session_suppress_dirs = { "~/", "~/Downloads", "/" },
    },
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸" },
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.25 },
              { id = "breakpoints", size = 0.25 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl", size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size = 10,
            position = "bottom",
          },
        },
      })

      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        args = { "--interpreter=mi" },
      }

      dap.configurations.cpp = {
        {
          name = "Launch (gdb)",
          type = "gdb",
          request = "launch",
          program = function()
            local root = vim.fn.getcwd()
            local filename = vim.fn.expand("%:t:r")
            local executable = root .. "/build/" .. filename
            
            if vim.fn.filereadable(executable) == 0 then
              vim.notify("Build not found. Run :Build first", vim.log.levels.ERROR)
              return nil
            end
            return executable
          end,
          cwd = vim.fn.getcwd(),
          stopOnEntry = false,
          args = function()
            local input = vim.fn.input("Arguments: ")
            return vim.split(input, " ")
          end,
        },
      }

      dap.configurations.c = dap.configurations.cpp

      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = { "dap", "--listen=127.0.0.1:${port}" },
        },
      }

      dap.configurations.go = {
        {
          name = "Launch (go)",
          type = "delve",
          request = "launch",
          program = "${fileDirname}",
          cwd = vim.fn.getcwd(),
          mode = "debug",
          dlvToolPath = "dlv",
        },
      }

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = "lldb-vscode",
          args = { "--port", "${port}" },
        },
      }

      dap.configurations.rust = {
        {
          name = "Launch (rust)",
          type = "codelldb",
          request = "launch",
          program = function()
            local root = vim.fn.getcwd()
            local manifest = vim.fn.system("cargo metadata --format-version 1 --manifest-path " .. root .. "/Cargo.toml 2>/dev/null | jq -r '.target_directory' 2>/dev/null"):gsub("\n", "")
            
            if manifest == "" then
              manifest = root .. "/target"
            end
            
            local package_name = vim.fn.system("grep -m 1 'name' " .. root .. "/Cargo.toml | head -1 | sed 's/.*name = \"\\([^\"]*\\)\".*/\\1/'"):gsub("\n", "")
            
            if package_name == "" then
              package_name = vim.fn.expand("%:t:r")
            end
            
            local executable = manifest .. "/debug/" .. package_name
            if vim.fn.filereadable(executable) == 0 then
              vim.notify("Build not found. Run cargo build first", vim.log.levels.ERROR)
              return nil
            end
            return executable
          end,
          cwd = vim.fn.getcwd(),
          stopOnEntry = false,
        },
      }

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
      vim.keymap.set("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Set conditional breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue" })
      vim.keymap.set("n", "<leader>dn", dap.step_over, { desc = "Step over" })
      vim.keymap.set("n", "<leader>ds", dap.step_into, { desc = "Step into" })
      vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Step out" })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Open REPL" })
      vim.keymap.set("n", "<leader>dd", dapui.toggle, { desc = "Toggle DAP UI" })
    end,
  },

})
