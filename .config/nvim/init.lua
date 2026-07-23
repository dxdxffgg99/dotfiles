vim.loader.enable()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
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
vim.opt.mouse = "a"
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.fileencodings = "utf-8,euc-kr"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
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

local profile_cache = {}

local function apply_profile()
  local profile = get_profile()
  profile_cache[vim.api.nvim_get_current_buf()] = profile
  if profile == "cpp" or profile == "rust" or profile == "python" then
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
  else
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
  end
end

local function cached_profile()
  local buf = vim.api.nvim_get_current_buf()
  if profile_cache[buf] == nil then
    profile_cache[buf] = get_profile()
  end
  return profile_cache[buf]
end

vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
  callback = apply_profile,
})

vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    profile_cache = {}
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
  if vim.g.CBDir and not vim.tbl_contains(build_dirs, vim.g.CBDir) then
    table.insert(build_dirs, 1, vim.g.CBDir)
  end

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

vim.g.CSDir = vim.g.CSDir or "."
vim.g.CBDir = vim.g.CBDir or "build"
vim.g.CArgConf = vim.g.CArgConf or ""
vim.g.CArgBuild = vim.g.CArgBuild or ""
vim.g.CArgTest = vim.g.CArgTest or ""

local task_terminal_id = 100

local function run_in_terminal(cmd, ok_msg, err_prefix)
  ok_msg = ok_msg or cmd
  err_prefix = err_prefix or cmd
  local ok, toggleterm = pcall(require, "toggleterm")
  if ok then
    local Terminal = require("toggleterm.terminal").Terminal
    Terminal:new({
      id = task_terminal_id,
      cmd = cmd,
      direction = "float",
      float_opts = { border = "rounded" },
      on_exit = function(_, _, exit_code)
        if exit_code == 0 then
          vim.notify("✓ " .. ok_msg, vim.log.levels.INFO)
        else
          vim.notify("✗ " .. err_prefix .. " (exit " .. exit_code .. ")", vim.log.levels.ERROR)
        end
      end,
    }):toggle()
  else
    vim.cmd("terminal " .. cmd)
  end
end

-- ccmd (https://codeberg.org/dalmurii/ccmd.vim), ported: CMake configure/build/test helpers
vim.api.nvim_create_user_command("Cconf", function(opts)
  run_in_terminal("cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON " .. opts.args)
end, { nargs = "*", desc = "cmake configure with raw args" })

vim.api.nvim_create_user_command("Cbuild", function(opts)
  run_in_terminal("cmake --build " .. opts.args)
end, { nargs = "*", desc = "cmake --build with raw args" })

vim.api.nvim_create_user_command("Ctest", function(opts)
  run_in_terminal("ctest --output-on-failure " .. opts.args)
end, { nargs = "*", desc = "ctest with raw args" })

vim.api.nvim_create_user_command("CConf", function(opts)
  run_in_terminal("cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B " .. vim.g.CBDir .. " -S " .. vim.g.CSDir
    .. " " .. opts.args .. " " .. vim.g.CArgConf)
end, { nargs = "*", desc = "cmake configure using g:CSDir/g:CBDir/g:CArgConf" })

vim.api.nvim_create_user_command("CBuild", function(opts)
  run_in_terminal("cmake --build " .. vim.g.CBDir .. " " .. opts.args .. " " .. vim.g.CArgBuild)
end, { nargs = "*", desc = "cmake build using g:CBDir/g:CArgBuild" })

vim.api.nvim_create_user_command("CTest", function(opts)
  run_in_terminal("ctest --output-on-failure --test-dir " .. vim.g.CBDir .. " " .. opts.args .. " " .. vim.g.CArgTest)
end, { nargs = "*", desc = "ctest using g:CBDir/g:CArgTest" })

-- CLion-style CMake project analysis: discover add_executable() targets,
-- auto-configure on project open / CMakeLists.txt change, and resolve
-- built executables by target name instead of guessing from the filename.

local function find_cmake_files(root)
  local exclude = { [".git"] = true, ["node_modules"] = true, [vim.g.CBDir] = true }
  for _, dir in ipairs({
    "build", "Build", "cmake-build-debug", "cmake-build-release",
    ".venv", "venv", "target", ".cache", "dist", "out", ".next", "vendor",
  }) do
    exclude[dir] = true
  end

  local files = {}
  local max_depth = 8
  local function scan(dir, depth)
    if depth > max_depth then return end
    local handle = vim.uv.fs_scandir(dir)
    if not handle then return end
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if ftype == "directory" then
        if not exclude[name] then
          scan(dir .. "/" .. name, depth + 1)
        end
      elseif name == "CMakeLists.txt" then
        table.insert(files, dir .. "/" .. name)
      end
    end
  end
  scan(root, 0)
  return files
end

local function cmake_targets(root)
  local targets = {}
  local seen = {}
  for _, file in ipairs(find_cmake_files(root)) do
    local f = io.open(file, "r")
    if f then
      local content = f:read("*a")
      f:close()
      for name in content:gmatch("add_executable%s*%(%s*([%w_%-]+)") do
        if not seen[name] then
          seen[name] = true
          table.insert(targets, name)
        end
      end
    end
  end
  return targets
end

local function cmake_state_file()
  return vim.fn.stdpath("state") .. "/cmake_targets.json"
end

local function load_cmake_state()
  local file = cmake_state_file()
  if vim.fn.filereadable(file) == 0 then return {} end
  local f = io.open(file, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return (ok and type(data) == "table") and data or {}
end

local function save_cmake_target(root, target)
  local state = load_cmake_state()
  state[root] = target
  local f = io.open(cmake_state_file(), "w")
  if f then
    f:write(vim.json.encode(state))
    f:close()
  end
end

local cmake_target_cache = {}

local function get_cmake_target(root)
  if cmake_target_cache[root] then
    return cmake_target_cache[root]
  end
  local target = load_cmake_state()[root]
  if target then
    cmake_target_cache[root] = target
  end
  return target
end

local function select_cmake_target(callback)
  local root = vim.fn.getcwd()
  local targets = cmake_targets(root)
  if #targets == 0 then
    vim.notify("No add_executable() targets found in CMakeLists.txt", vim.log.levels.WARN)
    callback(nil)
    return
  end
  if #targets == 1 then
    cmake_target_cache[root] = targets[1]
    save_cmake_target(root, targets[1])
    callback(targets[1])
    return
  end
  vim.ui.select(targets, { prompt = "Select CMake target:" }, function(choice)
    if choice then
      cmake_target_cache[root] = choice
      save_cmake_target(root, choice)
    end
    callback(choice)
  end)
end

local function find_target_executable(build_dir, target)
  if not target then return nil end
  for _, path in ipairs(vim.fn.globpath(build_dir, "**/" .. target, false, true)) do
    if not path:find("CMakeFiles", 1, true) and vim.fn.executable(path) == 1 then
      return path
    end
  end
  return nil
end

local function has_compile_commands(root)
  for _, dir in ipairs({ vim.g.CBDir, "build", "Build", "cmake-build-debug", "cmake-build-release" }) do
    if vim.fn.filereadable(root .. "/" .. dir .. "/compile_commands.json") == 1 then
      return true
    end
  end
  return false
end

local function cmake_configure(root, start_msg)
  if vim.fn.executable("cmake") == 0 then return end
  vim.notify(start_msg or "CMake: configuring project...", vim.log.levels.INFO)
  vim.system(
    { "cmake", "-B", vim.g.CBDir, "-S", vim.g.CSDir, "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON", "-DCMAKE_BUILD_TYPE=Debug" },
    { cwd = root, text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 then
        vim.notify("✓ CMake configured", vim.log.levels.INFO)
        setup_cmake_compile_commands()
        pcall(vim.cmd, "LspRestart clangd")
      else
        vim.notify("✗ CMake configure failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
      end
    end)
  )
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  callback = function()
    local root = vim.fn.getcwd()
    if vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 and not has_compile_commands(root) then
      cmake_configure(root)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "CMakeLists.txt",
  callback = function()
    cmake_configure(vim.fn.getcwd(), "CMake: reconfiguring (CMakeLists.txt changed)...")
  end,
})

vim.api.nvim_create_user_command("CMakeReload", function()
  cmake_configure(vim.fn.getcwd(), "CMake: reloading project...")
end, {})

vim.api.nvim_create_user_command("CMakeTarget", function()
  select_cmake_target(function(target)
    if target then
      vim.notify("CMake target: " .. target, vim.log.levels.INFO)
    end
  end)
end, {})

local function get_build_command()
  local root = vim.fn.getcwd()
  local root_esc = vim.fn.shellescape(root)
  local ext = vim.fn.expand("%:e")

  if ext == "rs" then
    if vim.fn.filereadable(root .. "/Cargo.toml") == 1 then
      return "cd " .. root_esc .. " && cargo build"
    else
      return nil
    end
  end

  if ext == "go" then
    if vim.fn.filereadable(root .. "/go.mod") == 1 then
      return "cd " .. root_esc .. " && go build"
    else
      return nil
    end
  end

  return nil
end

local function get_run_command()
  local ext = vim.fn.expand("%:e")
  local filepath = vim.fn.expand("%:p")
  local filepath_esc = vim.fn.shellescape(filepath)
  local root = vim.fn.getcwd()
  local root_esc = vim.fn.shellescape(root)

  if ext == "rs" then
    if vim.fn.filereadable(root .. "/Cargo.toml") == 1 then
      return "cd " .. root_esc .. " && cargo run"
    end
  end

  if ext == "go" then
    if vim.fn.filereadable(root .. "/go.mod") == 1 then
      return "cd " .. root_esc .. " && go run ."
    else
      return "go run " .. filepath_esc
    end
  end

  if ext == "py" then
    return "python3 " .. filepath_esc
  end

  if ext == "js" or ext == "ts" or ext == "jsx" or ext == "tsx" then
    if vim.fn.filereadable(root .. "/package.json") == 1 then
      return "cd " .. root_esc .. " && npm run dev"
    else
      return "node " .. filepath_esc
    end
  end

  return nil
end

local function is_cpp_ext(ext)
  return ext == "cpp" or ext == "cc" or ext == "cxx" or ext == "c" or ext == "h" or ext == "hpp"
end

local function build_file()
  local ext = vim.fn.expand("%:e")
  local root = vim.fn.getcwd()

  if is_cpp_ext(ext) and vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 then
    local function do_build(target)
      local build_args = target and (vim.g.CBDir .. " --target " .. target) or vim.g.CBDir
      run_in_terminal(
        "cmake --build " .. build_args .. " " .. vim.g.CArgBuild,
        "Build successful",
        "Build failed"
      )
    end

    local existing = get_cmake_target(root)
    if existing then
      do_build(existing)
    else
      select_cmake_target(function(target)
        if target then do_build(target) end
      end)
    end
    return
  end

  local cmd = get_build_command()
  if not cmd then
    vim.notify("Build not supported for: " .. ext, vim.log.levels.WARN)
    return
  end
  run_in_terminal(cmd, "Build successful", "Build failed")
end

local function run_file()
  local ext = vim.fn.expand("%:e")
  local root = vim.fn.getcwd()

  if is_cpp_ext(ext) and vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 then
    local function do_run(target)
      local executable = find_target_executable(root .. "/" .. vim.g.CBDir, target)
      if not executable then
        vim.notify("Build not found for target '" .. target .. "'. Run :Build first", vim.log.levels.ERROR)
        return
      end
      run_in_terminal(vim.fn.shellescape(executable), "Run successful", "Run failed")
    end

    local existing = get_cmake_target(root)
    if existing then
      do_run(existing)
    else
      select_cmake_target(function(target)
        if target then do_run(target) end
      end)
    end
    return
  end

  local cmd = get_run_command()
  if not cmd then
    vim.notify("Run not supported for: " .. ext, vim.log.levels.ERROR)
    return
  end
  run_in_terminal(cmd, "Run successful", "Run failed")
end

vim.api.nvim_create_user_command("Build", build_file, {})
vim.api.nvim_create_user_command("Run", run_file, {})

local function cmake_menu()
  local root = vim.fn.getcwd()
  local target = get_cmake_target(root)
  local items = {
    { label = "Run", action = run_file },
    { label = "Build", action = build_file },
    { label = "Debug", action = function() require("dap").continue() end },
    {
      label = "Select target" .. (target and (" (current: " .. target .. ")") or ""),
      action = function()
        select_cmake_target(function(t)
          if t then vim.notify("CMake target: " .. t, vim.log.levels.INFO) end
        end)
      end,
    },
    { label = "Reload CMake project", action = function() cmake_configure(root, "CMake: reloading project...") end },
  }
  vim.ui.select(items, {
    prompt = "CMake",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then choice.action() end
  end)
end

vim.api.nvim_create_user_command("CMakeMenu", cmake_menu, {})
vim.keymap.set("n", "<leader>cm", cmake_menu, { desc = "CMake menu (build/run/debug/target)" })

require("lazy").setup({

  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup()
    end,
  },

  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },

  {
    "zaldih/themery.nvim",
    lazy = false,
    priority = 900,
    config = function()
      require("themery").setup({
        themes = {
          { name = "GitHub Dark High Contrast", colorscheme = "github_dark_high_contrast" },
          { name = "Tokyo Night",               colorscheme = "tokyonight" },
        },
        livePreview = true,
      })
      if not vim.g.colors_name then
        vim.cmd.colorscheme("github_dark_high_contrast")
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
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
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = { ["]m"] = "@function.outer", ["]]"] = "@class.outer" },
            goto_previous_start = { ["[m"] = "@function.outer", ["[["] = "@class.outer" },
          },
        },
      })
    end,
  },

  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    cmd = { "Mason", "MasonUpdate", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonLog" },
    event = "VeryLazy",
    dependencies = { "WhoIsSethDaniel/mason-tool-installer.nvim" },
    config = function()
      require("mason").setup()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- LSP servers (matches the `servers` list in nvim-lspconfig below)
          "lua-language-server",
          "typescript-language-server",
          "clangd",
          "rust-analyzer",
          "pyright",
          "gopls",
          "html-lsp",
          "css-lsp",
          -- Linters (nvim-lint)
          "ruff",
          -- DAP adapters (nvim-dap)
          "codelldb",
          "delve",
          "debugpy",
        },
        auto_update = false,
        run_on_start = true,
      })
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

      vim.lsp.config("clangd", {
        cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
      })

      -- hyprland.lua files use a runtime-injected `hl` global (Hyprland's lua IPC
      -- table) that lua_ls has no way to know about; suppress just that diagnostic
      -- there instead of whitelisting `hl` as a global for every lua file.
      local orig_publish_diagnostics = vim.lsp.handlers["textDocument/publishDiagnostics"]
      vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
        if result and result.diagnostics and vim.uri_to_fname(result.uri):match("hyprland%.lua$") then
          result.diagnostics = vim.tbl_filter(function(d)
            return not (d.code == "undefined-global" and d.message:match("`hl`"))
          end, result.diagnostics)
        end
        orig_publish_diagnostics(err, result, ctx, config)
      end

      vim.api.nvim_create_user_command("LspDef", vim.lsp.buf.definition, {})
      vim.api.nvim_create_user_command("LspTypeDef", vim.lsp.buf.type_definition, {})
      vim.api.nvim_create_user_command("LspImpl", vim.lsp.buf.implementation, {})
      vim.api.nvim_create_user_command("LspRefs", vim.lsp.buf.references, {})
      vim.api.nvim_create_user_command("LspHover", vim.lsp.buf.hover, {})
      vim.api.nvim_create_user_command("LspRename", vim.lsp.buf.rename, {})
      vim.api.nvim_create_user_command("LspCodeAction", vim.lsp.buf.code_action, {})

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.refresh({ bufnr = ev.buf })
            local group = vim.api.nvim_create_augroup("CodelensRefresh" .. ev.buf, { clear = true })
            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
              group = group,
              buffer = ev.buf,
              callback = function()
                vim.lsp.codelens.refresh({ bufnr = ev.buf })
              end,
            })
          end
        end,
      })

      vim.o.updatetime = 400
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        callback = function()
          vim.diagnostic.open_float(nil, {
            focusable = false,
            close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
            border = "rounded",
            source = "always",
            scope = "cursor",
          })
        end,
      })

      local function rep_pat(old, new, pat, how)
        if not (old and new and pat and how) then
          vim.notify("Usage: RepPat <old> <new> <pattern> <how>", vim.log.levels.ERROR)
          return
        end
        if new:find("\\=", 1, true) then
          local choice = vim.fn.confirm(
            "Replacement contains '\\=' which evaluates a Vim expression for every match. Continue?",
            "&Yes\n&No", 2)
          if choice ~= 1 then
            vim.notify("RepPat cancelled", vim.log.levels.WARN)
            return
          end
        end
        local delim
        for _, d in ipairs({ "/", "#", ",", "@", "|" }) do
          if not old:find(d, 1, true) and not new:find(d, 1, true) then
            delim = d
            break
          end
        end
        if not delim then
          vim.notify("RepPat: couldn't find a delimiter not used in <old>/<new>", vim.log.levels.ERROR)
          return
        end
        vim.cmd("vimgrep " .. delim .. old .. delim .. "g" .. pat)
        vim.cmd("cdo %s" .. delim .. old .. delim .. new .. delim .. how .. " | update")
      end
      vim.api.nvim_create_user_command("RepPat", function(opts)
        rep_pat(unpack(opts.fargs))
      end, { nargs = "*", desc = "RepPat <old> <new> <pattern> <how>: multi-file find & replace" })
    end,
  },

  {
    "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp" },
    opts = {
      inlay_hints = {
        inline = true,
        only_current_line = false,
      },
    },
  },

  {
    "bfrg/vim-c-cpp-modern",
    ft = { "c", "cpp" },
  },

  {
    "pboettch/vim-cmake-syntax",
    ft = { "cmake" },
  },

  {
    "3rd/image.nvim",
    build = "luarocks --local install magick",
    ft = { "markdown", "norg", "typst" },
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
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file explorer" },
    },
    init = function()
      -- cmd/keys lazy-loading means nvim-tree never loads on plain `nvim <dir>`;
      -- open it explicitly when the startup arg is a directory.
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function(data)
          if vim.fn.isdirectory(data.file) == 0 then
            return
          end
          vim.cmd.cd(data.file)
          require("nvim-tree.api").tree.open()
        end,
      })
    end,
    config = function()
      require("nvim-tree").setup()
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
      { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
      { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
      { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
    },
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
      "rafamadriz/friendly-snippets",
      "windwp/nvim-autopairs",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

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
    "andymass/vim-matchup",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  {
    "barrett-ruth/live-server.nvim",
    cmd = { "LiveServerStart", "LiveServerStop", "LiveServerToggle" },
    init = function()
      vim.g.live_server = { port = 5555 }
    end,
  },

  {
    "barrett-ruth/import-cost.nvim",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact", "svelte" },
    init = function()
      vim.g.import_cost = { package_manager = "npm" }
    end,
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "InsertEnter",
    config = function()
      require("lsp_signature").setup({
        bind = true,
        doc_lines = 10,
        hint_enable = true,
        hint_prefix = "🐼 ",
        floating_window = true,
        floating_window_above_cur_line = true,
        hi_parameter = "IncSearch",
        handler_opts = { border = "rounded" },
      })
    end,
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
        html = { "vnu" },
      }

      local timer = vim.uv.new_timer()
      local function debounced_lint()
        if vim.bo.buftype ~= "" then return end
        if not lint.linters_by_ft[vim.bo.filetype] then return end
        timer:stop()
        timer:start(500, 0, vim.schedule_wrap(function() lint.try_lint() end))
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "InsertLeave" }, {
        callback = debounced_lint,
      })

      vim.api.nvim_create_user_command("Lint", lint.try_lint, {})
    end,
  },

  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
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
    event = { "BufReadPre", "BufNewFile" },
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
    cmd = { "AerialToggle", "AerialOpen", "AerialNext", "AerialPrev" },
    keys = {
      { "<leader>a", "<cmd>AerialToggle<cr>", desc = "Toggle symbol outline" },
    },
    config = function()
      require("aerial").setup()
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
    event = "VeryLazy",
    config = function()
      require("lualine").setup({
        options = {
          component_separators = { left = "｜", right = "｜" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_x = {
            {
              function()
                local profile = cached_profile()
                if profile == "cpp" then
                  local target = get_cmake_target(vim.fn.getcwd())
                  if target then return "cpp[" .. target .. "]" end
                end
                return profile
              end,
            },
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
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>du", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "Open REPL" },
      { "<leader>dt", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
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
            local target = get_cmake_target(root)
            if not target then
              vim.notify("No CMake target selected. Run :CMakeTarget first", vim.log.levels.ERROR)
              return nil
            end
            local executable = find_target_executable(root .. "/" .. vim.g.CBDir, target)
            if not executable then
              vim.notify("Build not found for target '" .. target .. "'. Run :Build first", vim.log.levels.ERROR)
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
          command = "codelldb",
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
            local target_dir = root .. "/target"
            local package_name = vim.fn.expand("%:t:r")

            local result = vim
              .system(
                { "cargo", "metadata", "--format-version", "1", "--no-deps", "--manifest-path", root .. "/Cargo.toml" },
                { text = true }
              )
              :wait()

            if result.code == 0 and result.stdout and result.stdout ~= "" then
              local ok, metadata = pcall(vim.json.decode, result.stdout)
              if ok and metadata then
                target_dir = metadata.target_directory or target_dir
                if metadata.packages and metadata.packages[1] and metadata.packages[1].name then
                  package_name = metadata.packages[1].name
                end
              end
            end

            local executable = target_dir .. "/debug/" .. package_name
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

      require("dap-python").setup(
        vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      )

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.api.nvim_create_user_command("DapBreakpoint", dap.toggle_breakpoint, {})
      vim.api.nvim_create_user_command("DapBreakpointCond", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, {})
      vim.api.nvim_create_user_command("DapContinue", dap.continue, {})
      vim.api.nvim_create_user_command("DapStepOver", dap.step_over, {})
      vim.api.nvim_create_user_command("DapStepInto", dap.step_into, {})
      vim.api.nvim_create_user_command("DapStepOut", dap.step_out, {})
      vim.api.nvim_create_user_command("DapRepl", dap.repl.open, {})
      vim.api.nvim_create_user_command("DapUiToggle", dapui.toggle, {})
    end,
  },

  {
    "dalmurii/LspToHtml.nvim",
    cmd = { "LspToHtml" },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add({
        { "<leader>c", group = "cmake" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>t", group = "test" },
        { "<leader>x", group = "diagnostics/trouble" },
      })
    end,
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
      { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "Todo (Trouble)" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix (Trouble)" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list (Trouble)" },
    },
    opts = {},
  },

  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-go",
      "rouge8/neotest-rust",
    },
    keys = {
      { "<leader>tt", function() require("neotest").run.run() end, desc = "Test nearest" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test file" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true }) end, desc = "Test output" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Test stop" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({ dap = { justMyCode = false } }),
          require("neotest-go"),
          require("neotest-rust"),
        },
      })
    end,
  },

  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit commit" },
    },
    opts = { integrations = { diffview = true, telescope = true } },
  },

}, {
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
