vim.loader.enable()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    return
  end
end

vim.opt.rtp:prepend(lazypath)

vim.opt.number = true
vim.opt.mouse = "a"
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.fileencodings = "ucs-bom,utf-8,cp949,latin1"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.shortmess:append("c")
vim.opt.cmdheight = 0
vim.opt.updatetime = 400
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
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
  },
})

if vim.fn.executable("fcitx5-remote") == 1 then
  local ime_group = vim.api.nvim_create_augroup("ImeAutoSwitch", { clear = true })

  local function ime_off()
    local state = vim.system({ "fcitx5-remote" }, { text = true }):wait()
    vim.b.ime_was_active = vim.trim(state.stdout or "") == "2"
    if vim.b.ime_was_active then
      vim.system({ "fcitx5-remote", "-c" }):wait()
    end
  end

  local function ime_restore()
    if vim.b.ime_was_active then
      vim.system({ "fcitx5-remote", "-o" }):wait()
    end
  end

  vim.api.nvim_create_autocmd({ "InsertLeave", "TermLeave" }, { group = ime_group, callback = ime_off })
  vim.api.nvim_create_autocmd({ "InsertEnter", "TermEnter" }, { group = ime_group, callback = ime_restore })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = ime_group,
    pattern = { ":", "/", "?" },
    callback = function()
      vim.system({ "fcitx5-remote", "-c" }):wait()
    end,
  })
end

local profile_by_ext = {
  c = "cpp", h = "cpp", cc = "cpp", cpp = "cpp", cxx = "cpp", hpp = "cpp",
  rs = "rust",
  py = "python",
}
local profile_markers = { "CMakeLists.txt", "Cargo.toml", "package.json", "pyproject.toml", "requirements.txt" }
local profile_by_marker = {
  ["CMakeLists.txt"] = "cpp",
  ["Cargo.toml"] = "rust",
  ["package.json"] = "web",
  ["pyproject.toml"] = "python",
  ["requirements.txt"] = "python",
}

local function get_profile(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local by_ext = profile_by_ext[vim.fn.fnamemodify(name, ":e")]
  if by_ext then return by_ext end

  local start = (name ~= "" and vim.bo[buf].buftype == "") and vim.fs.dirname(name) or vim.fn.getcwd()
  local found = vim.fs.find(profile_markers, { upward = true, path = start, stop = vim.uv.os_homedir(), limit = 1 })[1]
  return found and profile_by_marker[vim.fs.basename(found)] or "default"
end

local profile_cache = {}

local function cached_profile()
  local buf = vim.api.nvim_get_current_buf()
  if profile_cache[buf] == nil then
    profile_cache[buf] = get_profile(buf)
  end
  return profile_cache[buf]
end

local function detect_indent(buf)
  local counts = {}
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(vim.api.nvim_buf_line_count(buf), 500), false)
  for _, line in ipairs(lines) do
    local lead = line:match("^( +)%S")
    if lead and #lead <= 8 then
      counts[#lead] = (counts[#lead] or 0) + 1
    end
  end
  local total = 0
  for _, c in pairs(counts) do total = total + c end
  if total < 3 then return nil end
  if (counts[2] or 0) >= math.max(2, total * 0.05) then return 2 end
  if (counts[4] or 0) > 0 then return 4 end
  if (counts[8] or 0) > 0 then return 8 end
  return nil
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" then return end
    local profile = get_profile(ev.buf)
    profile_cache[ev.buf] = profile
    local width = detect_indent(ev.buf)
      or ((profile == "cpp" or profile == "rust" or profile == "python") and 4 or 2)
    vim.bo[ev.buf].tabstop = width
    vim.bo[ev.buf].shiftwidth = width
  end,
})

vim.api.nvim_create_autocmd({ "DirChanged", "BufFilePost" }, {
  callback = function()
    profile_cache = {}
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(ev)
    profile_cache[ev.buf] = nil
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    for _, s in ipairs({ "Deleted", "Dirty", "Ignored", "Merge", "New", "Renamed", "Staged" }) do
      local legacy = "NvimTreeGit" .. s
      if not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = legacy })) then
        vim.api.nvim_set_hl(0, legacy .. "Icon", { link = legacy })
      end
    end
  end,
})

local in_kitty = vim.env.TERM == "xterm-kitty" or vim.env.KITTY_WINDOW_ID ~= nil

if in_kitty then
  local transparent_groups = {
    "Normal", "NormalNC", "NormalFloat", "FloatBorder",
    "SignColumn", "EndOfBuffer", "LineNr", "CursorLineNr",
    "VertSplit", "WinSeparator", "Pmenu",
    "TabLine", "TabLineSel", "TabLineFill",
  }
  vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
    callback = function()
      for _, group in ipairs(transparent_groups) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        hl.bg = nil
        hl.ctermbg = nil
        hl.default = nil
        vim.api.nvim_set_hl(0, group, hl)
      end
    end,
  })
end

local function setup_cmake_compile_commands()
  local root = vim.fn.getcwd()
  local build_dirs = { "build", "Build", "cmake-build-debug", "cmake-build-release" }
  if vim.g.CBDir and not vim.tbl_contains(build_dirs, vim.g.CBDir) then
    table.insert(build_dirs, 1, vim.g.CBDir)
  end

  for _, dir in ipairs(build_dirs) do
    local cmd_file = root .. "/" .. dir .. "/compile_commands.json"
    if vim.fn.filereadable(cmd_file) == 1 then
      if dir ~= "build" then
        local clangd_config = root .. "/.clangd"
        if vim.fn.filereadable(clangd_config) == 0 then
          local file = io.open(clangd_config, "w")
          if file then
            file:write("CompileFlags:\n  CompilationDatabase: " .. dir .. "\n")
            file:close()
            vim.notify("Wrote .clangd pointing at " .. dir .. "/", vim.log.levels.INFO)
          end
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

local function run_in_terminal(cmd, ok_msg, err_prefix, opts)
  opts = opts or {}
  require("ui").panel.run(cmd, {
    ok_msg = ok_msg or cmd,
    err_msg = err_prefix or cmd,
    quickfix = opts.quickfix,
    efm = opts.efm,
    title = opts.title,
  })
end

vim.api.nvim_create_user_command("Term", function(opts)
  require("ui").panel.new_terminal(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", desc = "Open a terminal in the bottom panel" })

vim.cmd([[
  cnoreabbrev <expr> term     (getcmdtype() ==# ':' && getcmdline() ==# 'term')     ? 'Term' : 'term'
  cnoreabbrev <expr> terminal (getcmdtype() ==# ':' && getcmdline() ==# 'terminal') ? 'Term' : 'terminal'
]])

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})

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

local cmake_target_cache = {}

local function save_cmake_target(root, target)
  local state = load_cmake_state()
  state[root] = target
  cmake_target_cache[root] = target
  local f = io.open(cmake_state_file(), "w")
  if f then
    f:write(vim.json.encode(state))
    f:close()
  end
end

local function get_cmake_target(root)
  local cached = cmake_target_cache[root]
  if cached ~= nil then
    return cached or nil
  end
  local target = load_cmake_state()[root]
  cmake_target_cache[root] = target or false
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
        pcall(vim.cmd, "lsp restart clangd")
      else
        vim.notify("✗ CMake configure failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
      end
    end)
  )
end

local function is_cmake_root(dir)
  if vim.fn.filereadable(dir .. "/CMakeLists.txt") == 0 then return false end
  local parent = vim.fs.dirname(dir)
  return parent == dir or vim.fn.filereadable(parent .. "/CMakeLists.txt") == 0
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  callback = function()
    local root = vim.fn.getcwd()
    if vim.bo.filetype:match("^git") then return end
    if is_cmake_root(root) and not has_compile_commands(root) then
      cmake_configure(root)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "CMakeLists.txt",
  callback = function(ev)
    local root = vim.fn.getcwd()
    local file = vim.fn.fnamemodify(ev.file, ":p")
    if not is_cmake_root(root) or not vim.startswith(file, root .. "/") then return end
    cmake_configure(root, "CMake: reconfiguring (CMakeLists.txt changed)...")
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
    for _, venv in ipairs({ ".venv", "venv" }) do
      local python = root .. "/" .. venv .. "/bin/python"
      if vim.fn.executable(python) == 1 then
        return vim.fn.shellescape(python) .. " " .. filepath_esc
      end
    end
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
      local build_args = vim.fn.shellescape(vim.g.CBDir)
        .. (target and (" --target " .. vim.fn.shellescape(target)) or "")
      run_in_terminal(
        "cmake --build " .. build_args .. " " .. vim.g.CArgBuild,
        "Build successful",
        "Build failed",
        { quickfix = true, title = "cmake --build" .. (target and (" " .. target) or "") }
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
  run_in_terminal(cmd, "Build successful", "Build failed", { quickfix = true })
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

vim.api.nvim_create_user_command("Build", function() build_file() end, {})
vim.api.nvim_create_user_command("Run", function() run_file() end, {})

local colorscheme_owner = {
  tokyonight = "tokyonight.nvim",
  catppuccin = "catppuccin",
  github = "github-nvim-theme",
}

vim.api.nvim_create_autocmd("ColorSchemePre", {
  callback = function(ev)
    for prefix, plugin in pairs(colorscheme_owner) do
      if vim.startswith(ev.match, prefix) then
        pcall(require("lazy").load, { plugins = { plugin } })
        return
      end
    end
  end,
})

require("lazy").setup({

  {
    "projekt0n/github-nvim-theme",
    lazy = true,
    config = function()
      require("github-theme").setup()
    end,
  },

  { "folke/tokyonight.nvim", lazy = true },

  { "catppuccin/nvim", name = "catppuccin", lazy = true },

  {
    "zaldih/themery.nvim",
    lazy = false,
    priority = 900,
    config = function()
      require("themery").setup({
        themes = {
          { name = "Tokyo Night Darker",        colorscheme = "tokyonight-night" },
          { name = "GitHub Dark High Contrast", colorscheme = "github_dark_high_contrast" },
          { name = "Tokyo Night",               colorscheme = "tokyonight" },
          { name = "Catppuccin Latte",          colorscheme = "catppuccin-latte" },
          { name = "Catppuccin Frappe",         colorscheme = "catppuccin-frappe" },
          { name = "Catppuccin Macchiato",      colorscheme = "catppuccin-macchiato" },
          { name = "Catppuccin Mocha",          colorscheme = "catppuccin-mocha" },
        },
        livePreview = true,
      })
      if not vim.g.colors_name then
        vim.cmd.colorscheme("tokyonight-night")
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      local nts = require("nvim-treesitter")
      nts.setup()

      local ensure_installed = {
        "lua", "vim", "vimdoc", "query", "javascript", "typescript", "tsx",
        "html", "css", "json", "c", "cpp", "rust", "python", "go",
        "markdown", "markdown_inline", "regex", "bash",
      }

      local warned = false
      local function can_build()
        if vim.fn.executable("tree-sitter") == 1 then return true end
        if not warned then
          warned = true
          vim.notify(
            "tree-sitter CLI not found -- parsers can't be built.\n" ..
            "Install it with: pacman -S tree-sitter-cli",
            vim.log.levels.WARN
          )
        end
        return false
      end

      local installed = {}
      for _, lang in ipairs(nts.get_installed()) do
        installed[lang] = true
      end

      local missing = vim.tbl_filter(function(lang) return not installed[lang] end, ensure_installed)
      if #missing > 0 and can_build() then
        nts.install(missing)
      end

      local function start(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if not pcall(vim.treesitter.start, buf, lang) then return end
        if #vim.api.nvim_get_runtime_file("queries/" .. lang .. "/indents.scm", false) > 0 then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      local pending, failed = {}, {}
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang then return end

          if vim.treesitter.language.add(lang) then
            start(ev.buf, lang)
            return
          end

          if pending[lang] or failed[lang] or not vim.list_contains(nts.get_available(), lang) then return end
          if not can_build() then return end
          pending[lang] = true
          nts.install(lang):await(function(err, ok)
            pending[lang] = nil
            if err or not ok then
              failed[lang] = true
              return
            end
            vim.schedule(function()
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) and vim.treesitter.language.get_lang(vim.bo[buf].filetype) == lang then
                  start(buf, lang)
                end
              end
            end)
          end)
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    lazy = true,
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      local select = require("nvim-treesitter-textobjects.select")
      for lhs, query in pairs({
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
      }) do
        vim.keymap.set({ "x", "o" }, lhs, function()
          select.select_textobject(query, "textobjects")
        end, { desc = "Select " .. query })
      end

      local move = require("nvim-treesitter-textobjects.move")
      for lhs, spec in pairs({
        ["]m"] = { "goto_next_start", "@function.outer" },
        ["]]"] = { "goto_next_start", "@class.outer" },
        ["[m"] = { "goto_previous_start", "@function.outer" },
        ["[["] = { "goto_previous_start", "@class.outer" },
      }) do
        vim.keymap.set({ "n", "x", "o" }, lhs, function()
          move[spec[1]](spec[2], "textobjects")
        end, { desc = spec[1] .. " " .. spec[2] })
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPre", "BufNewFile" },
    keys = {
      {
        "[x",
        function() require("treesitter-context").go_to_context(vim.v.count1) end,
        mode = "n",
        desc = "Jump to context start",
      },
    },
    opts = {
      max_lines = 3,
      multiline_threshold = 1,
      trim_scope = "outer",
      separator = "─",
    },
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
          "lua-language-server",
          "typescript-language-server",
          "clangd",
          "rust-analyzer",
          "pyright",
          "gopls",
          "html-lsp",
          "css-lsp",
          "ruff",
          "stylua",
          "clang-format",
          "prettier",
          "goimports",
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
    "folke/lazydev.nvim",
    ft = "lua",
    cmd = "LazyDev",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "lazy.nvim", words = { "LazySpec" } },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp", "williamboman/mason.nvim" },
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
        cmd = {
          "clangd",
          "--background-index",
          "--background-index-priority=low",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--pch-storage=disk",
          "-j=2",
        },
      })

      vim.lsp.config("gopls", {
        settings = {
          gopls = {
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
          },
        },
      })

      local ts_hints = {
        inlayHints = {
          includeInlayParameterNameHints = "literals",
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
      }
      vim.lsp.config("ts_ls", { settings = { typescript = ts_hints, javascript = ts_hints } })

      vim.lsp.config("pyright", {
        before_init = function(_, config)
          local root = config.root_dir or vim.fn.getcwd()
          for _, venv in ipairs({ ".venv", "venv" }) do
            local python = root .. "/" .. venv .. "/bin/python"
            if vim.fn.executable(python) == 1 then
              config.settings.python = vim.tbl_deep_extend("force", config.settings.python or {}, { pythonPath = python })
              return
            end
          end
        end,
      })

      vim.api.nvim_create_user_command("LspDef", function() vim.lsp.buf.definition() end, {})
      vim.api.nvim_create_user_command("LspTypeDef", function() vim.lsp.buf.type_definition() end, {})
      vim.api.nvim_create_user_command("LspImpl", function() vim.lsp.buf.implementation() end, {})
      vim.api.nvim_create_user_command("LspRefs", function() vim.lsp.buf.references() end, {})
      vim.api.nvim_create_user_command("LspHover", function() vim.lsp.buf.hover() end, {})
      vim.api.nvim_create_user_command("LspRename", function(opts)
        vim.lsp.buf.rename(opts.args ~= "" and opts.args or nil)
      end, { nargs = "?", desc = "LspRename [new_name]" })
      vim.api.nvim_create_user_command("LspCodeAction", function() vim.lsp.buf.code_action() end, {})

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if not client then return end
          if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
          end
          if client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.enable(true, { bufnr = ev.buf })
          end
          if client:supports_method("textDocument/definition") then
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "Go to definition" })
          end
          if client:supports_method("textDocument/declaration") then
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf, desc = "Go to declaration" })
          end
        end,
      })

      vim.api.nvim_create_autocmd("CursorHold", {
        group = vim.api.nvim_create_augroup("user_diag_float", { clear = true }),
        callback = function()
          if vim.bo.buftype ~= "" then return end
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local cfg = vim.api.nvim_win_get_config(win)
            if cfg.relative ~= "" and cfg.focusable then return end
          end
          vim.diagnostic.open_float(nil, {
            focusable = false,
            close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
            border = "rounded",
            source = true,
            scope = "line",
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
        for _, d in ipairs({ "/", "#", ",", "@", ";", "!" }) do
          if not old:find(d, 1, true) and not new:find(d, 1, true) then
            delim = d
            break
          end
        end
        if not delim then
          vim.notify("RepPat: couldn't find a delimiter not used in <old>/<new>", vim.log.levels.ERROR)
          return
        end
        local ok, err = pcall(vim.cmd, "vimgrep " .. delim .. old .. delim .. "gj " .. pat)
        if not ok then
          vim.notify("RepPat: " .. (tostring(err):match("E%d+:.*") or tostring(err)), vim.log.levels.WARN)
          return
        end
        vim.cmd("cfdo %s" .. delim .. old .. delim .. new .. delim .. how .. " | update")
      end
      vim.api.nvim_create_user_command("RepPat", function(opts)
        rep_pat(unpack(opts.fargs))
      end, { nargs = "*", desc = "RepPat <old> <new> <pattern> <how>: multi-file find & replace" })
    end,
  },

  {
    "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp" },
    opts = {},
  },

  {
    "bfrg/vim-c-cpp-modern",
    ft = { "c", "cpp" },
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>ur", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle markdown render" },
    },
    opts = {
      completions = { lsp = { enabled = true } },
      heading = { width = "block", left_pad = 1, right_pad = 2 },
      code = { width = "block", left_pad = 1, right_pad = 2, border = "thin" },
      pipe_table = { style = "full" },
    },
  },

  {
    "3rd/image.nvim",
    build = false,
    ft = { "markdown", "norg", "typst" },
    event = {
      "BufReadPre *.png",
      "BufReadPre *.jpg",
      "BufReadPre *.jpeg",
      "BufReadPre *.gif",
      "BufReadPre *.webp",
      "BufReadPre *.avif",
    },
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
      require("nvim-tree").setup({
        on_attach = function(buf)
          local api = require("nvim-tree.api")
          api.config.mappings.default_on_attach(buf)
          vim.keymap.set("n", "<LeftRelease>", function()
            local node = api.tree.get_node_under_cursor()
            if not node or node.name == ".." then return end
            api.node.open.edit()
          end, { buffer = buf, desc = "Open (single click)" })
          for _, key in ipairs({ "<2-LeftMouse>", "<2-LeftRelease>", "<3-LeftMouse>", "<3-LeftRelease>", "<4-LeftMouse>", "<4-LeftRelease>" }) do
            vim.keymap.set("n", key, "<Nop>", { buffer = buf })
          end
        end,
        sync_root_with_cwd = true,
        update_focused_file = { enable = true },
        view = { width = 32, side = "left", preserve_window_proportions = true },
        renderer = {
          root_folder_label = function(path)
            return "󰉋 " .. vim.fn.fnamemodify(path, ":t"):upper()
          end,
          group_empty = true,
          indent_markers = { enable = true },
          highlight_git = "name",
          highlight_diagnostics = "name",
          highlight_opened_files = "name",
          highlight_modified = "name",
          icons = {
            git_placement = "after",
            diagnostics_placement = "after",
            modified_placement = "after",
            glyphs = {
              git = {
                unstaged = "M", staged = "A", unmerged = "!", renamed = "R",
                untracked = "U", deleted = "D", ignored = "◌",
              },
            },
          },
        },
        diagnostics = { enable = true, show_on_dirs = true },
        modified = { enable = true },
        git = { ignore = false },
        filters = { custom = { "^.git$" } },
      })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function() return vim.fn.executable("make") == 1 end,
      },
    },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
      { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
      { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
      { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
      { "<leader>fr", function() require("telescope.builtin").resume() end, desc = "Resume last picker" },
      { "<leader>fo", function() require("telescope.builtin").oldfiles({ only_cwd = true }) end, desc = "Recent files (cwd)" },
      { "<leader>fw", function() require("telescope.builtin").grep_string() end, mode = { "n", "x" }, desc = "Grep word/selection" },
      { "<leader>fs", function() require("telescope.builtin").lsp_document_symbols() end, desc = "Document symbols" },
      { "<leader>fS", function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end, desc = "Workspace symbols" },
      { "<leader>fd", function() require("telescope.builtin").diagnostics({ bufnr = 0 }) end, desc = "Buffer diagnostics" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        },
      })
      pcall(telescope.load_extension, "fzf")
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
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "lazydev", group_index = 0 },
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
    config = function()
      require("colorizer").setup({
        filetypes = {
          "*",
          css = { parsers = { css = true, css_fn = true } },
          scss = { parsers = { css = true, css_fn = true } },
          less = { parsers = { css = true, css_fn = true } },
          html = {
            parsers = { css = true, css_fn = true, tailwind = { enable = true } },
          },
          javascript = { parsers = { css_fn = true, tailwind = { enable = true } } },
          javascriptreact = { parsers = { css_fn = true, tailwind = { enable = true } } },
          typescript = { parsers = { css_fn = true, tailwind = { enable = true } } },
          typescriptreact = { parsers = { css_fn = true, tailwind = { enable = true } } },
        },
        options = {
          parsers = {
            hex = { default = true, rrggbbaa = true },
          },
          display = { mode = "background" },
        },
      })
    end,
  },

  {
    "folke/noice.nvim",
    lazy = false,
    priority = 900,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      lsp = {
        signature = { enabled = false },
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
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo", "Format", "FormatEnable", "FormatDisable" },
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "x" },
        desc = "Format buffer/selection",
      },
    },
    config = function()
      local conform = require("conform")

      conform.setup({
        formatters_by_ft = {
          lua = { "stylua" },
          python = { "ruff_organize_imports", "ruff_format" },
          c = { "clang_format" },
          cpp = { "clang_format" },
          rust = { "rustfmt" },
          go = { "goimports", "gofmt" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          html = { "prettier" },
          css = { "prettier" },
          json = { "prettier" },
          jsonc = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
        },
        default_format_opts = { lsp_format = "fallback" },
        format_on_save = function(buf)
          if vim.g.disable_autoformat or vim.b[buf].disable_autoformat then
            return nil
          end
          return { timeout_ms = 1000, lsp_format = "fallback" }
        end,
      })

      vim.api.nvim_create_user_command("Format", function(opts)
        local range = nil
        if opts.count ~= -1 then
          local end_line = vim.api.nvim_buf_get_lines(0, opts.line2 - 1, opts.line2, true)[1]
          range = {
            start = { opts.line1, 0 },
            ["end"] = { opts.line2, end_line:len() },
          }
        end
        conform.format({ async = true, lsp_format = "fallback", range = range })
      end, { range = true, desc = "Format buffer or [range]" })

      vim.api.nvim_create_user_command("FormatDisable", function(opts)
        if opts.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, { bang = true, desc = "Disable format-on-save (! = this buffer only)" })

      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = "Re-enable format-on-save" })
    end,
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

      local function available_linters(ft)
        local names = lint.linters_by_ft[ft]
        if not names then return nil end
        local out = {}
        for _, name in ipairs(names) do
          local linter = lint.linters[name]
          if type(linter) == "function" then linter = linter() end
          if type(linter) == "table" then
            local cmd = linter.cmd
            if type(cmd) == "function" then cmd = cmd() end
            if vim.fn.executable(cmd) == 1 then
              table.insert(out, name)
            end
          end
        end
        return #out > 0 and out or nil
      end

      local lint_timers = {}
      local function debounced_lint()
        if vim.bo.buftype ~= "" then return end
        local names = available_linters(vim.bo.filetype)
        if not names then return end

        local buf = vim.api.nvim_get_current_buf()
        local timer = lint_timers[buf]
        if not timer then
          timer = vim.uv.new_timer()
          lint_timers[buf] = timer
        end
        timer:stop()
        timer:start(500, 0, vim.schedule_wrap(function()
          if vim.api.nvim_get_current_buf() == buf then
            lint.try_lint(names)
          end
        end))
      end

      local group = vim.api.nvim_create_augroup("user_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "InsertLeave" }, {
        group = group,
        callback = debounced_lint,
      })

      vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        callback = function(ev)
          local timer = lint_timers[ev.buf]
          if timer then
            timer:stop()
            timer:close()
            lint_timers[ev.buf] = nil
          end
        end,
      })

      vim.api.nvim_create_user_command("Lint", function()
        local names = available_linters(vim.bo.filetype)
        if not names then
          vim.notify("No available linter for filetype '" .. vim.bo.filetype .. "'", vim.log.levels.WARN)
          return
        end
        lint.try_lint(names)
      end, {})
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        on_attach = function(buf)
          local gs = require("gitsigns")
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
          end
          map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
          map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
          map("n", "<leader>gs", gs.stage_hunk, "Stage/unstage hunk")
          map("x", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
          map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
          map("n", "<leader>gp", gs.preview_hunk_inline, "Preview hunk")
          map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
          map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
        end,
      })
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
    url = "https://codeberg.org/andyg/leap.nvim",
    name = "leap.nvim",
    keys = {
      { "s", "<Plug>(leap-forward)", mode = { "n", "x", "o" }, desc = "Leap forward" },
      { "S", "<Plug>(leap-backward)", mode = { "n", "x", "o" }, desc = "Leap backward" },
    },
    config = function()
      require("leap").opts.safe_labels = ""
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local function hex_to_rgb(hex)
        hex = hex:gsub("#", "")
        return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
      end

      local function blend(fg, bg, alpha)
        local fr, fg_, fb = hex_to_rgb(fg)
        local br, bgg, bb = hex_to_rgb(bg)
        local r = math.floor(fr * alpha + br * (1 - alpha))
        local g = math.floor(fg_ * alpha + bgg * (1 - alpha))
        local b = math.floor(fb * alpha + bb * (1 - alpha))
        return string.format("#%02x%02x%02x", r, g, b)
      end

      local alphas = { 0.0, 0.15, 0.30, 0.45, 0.60, 0.75, 0.90 }

      local hl_groups = {}
      for i = 1, #alphas do
        table.insert(hl_groups, "IndentColorizer" .. i)
      end

      local function setup_colors()
        local function hl_fg(name, fallback)
          local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
          return hl.fg and string.format("#%06x", hl.fg) or fallback
        end

        local base = hl_fg("Comment", "#565f89")
        local top = hl_fg("Normal", "#c0caf5")

        for i, name in ipairs(hl_groups) do
          vim.api.nvim_set_hl(0, name, { fg = blend(top, base, alphas[i]) })
        end
      end

      setup_colors()
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = setup_colors,
      })

      require("ibl").setup({
        indent = {
          char = "▏",
          highlight = hl_groups,
        },
        whitespace = {
          highlight = hl_groups,
          remove_blankline_trail = true,
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
      session_lens = { load_on_setup = false },
    },
  },

  { "mfussenegger/nvim-dap-python", lazy = true },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
      "theHamsta/nvim-dap-virtual-text",
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

      require("nvim-dap-virtual-text").setup({
        virt_text_pos = "eol",
        commented = true,
        highlight_changed_variables = true,
      })

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
        args = { "--interpreter=dap" },
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
          cwd = function() return vim.fn.getcwd() end,
          stopOnEntry = false,
          args = function()
            local input = vim.fn.input("Arguments: ")
            return vim.split(input, "%s+", { trimempty = true })
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
          cwd = function() return vim.fn.getcwd() end,
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
          cwd = function() return vim.fn.getcwd() end,
          stopOnEntry = false,
        },
      }

      local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      if vim.fn.executable(debugpy) == 1 then
        require("dap-python").setup(debugpy)
      else
        require("dap-python").setup("python3")
      end

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.api.nvim_create_user_command("DapBreakpoint", function() dap.toggle_breakpoint() end, {})
      vim.api.nvim_create_user_command("DapBreakpointCond", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, {})
      vim.api.nvim_create_user_command("DapContinue", function() dap.continue() end, {})
      vim.api.nvim_create_user_command("DapStepOver", function() dap.step_over() end, {})
      vim.api.nvim_create_user_command("DapStepInto", function() dap.step_into() end, {})
      vim.api.nvim_create_user_command("DapStepOut", function() dap.step_out() end, {})
      vim.api.nvim_create_user_command("DapRepl", function() dap.repl.open() end, {})
      vim.api.nvim_create_user_command("DapUiToggle", function() dapui.toggle() end, {})
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
        { "<leader>b", group = "buffer/tab" },
        { "<leader>c", group = "code/claude" },
        { "<leader>p", group = "panel" },
        { "<leader>u", group = "ui" },
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

  {
    "coder/claudecode.nvim",
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend", "ClaudeCodeAdd", "ClaudeCodeTreeAdd",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeSelectModel", "ClaudeCodeStatus",
    },
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Claude Code toggle" },
      { "<C-,>", "<cmd>ClaudeCodeFocus<cr>", mode = { "n", "t" }, desc = "Claude Code focus" },
      { "<leader>cC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude Code (continue)" },
      { "<leader>cr", "<cmd>ClaudeCode --resume<cr>", desc = "Claude Code (resume)" },
      { "<leader>cm", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Claude: select model" },
      { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add buffer" },
      { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "x", desc = "Claude: send selection" },
      { "<leader>cs", "<cmd>ClaudeCodeTreeAdd<cr>", ft = "NvimTree", desc = "Claude: add file" },
      { "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>cn", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: deny diff" },
    },
    opts = {
      terminal = {
        provider = "native",
        split_side = "right",
        split_width_percentage = 0.35,
      },
      diff_opts = { layout = "vertical" },
    },
  },

  {
    "vyfor/cord.nvim",
    build = ":Cord update",
    event = "VeryLazy",
    opts = {},
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

package.preload["ui.util"] = function()
  local M = {}

  local function hl(name)
    local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    return ok and h or {}
  end

  function M.fg(name, fallback)
    local h = hl(name)
    return h.fg and string.format("#%06x", h.fg) or fallback
  end

  function M.bg(name, fallback)
    local h = hl(name)
    return h.bg and string.format("#%06x", h.bg) or fallback
  end

  function M.blend(a, b, alpha)
    if not a or not b then return a or b end
    local function rgb(hex)
      hex = hex:gsub("#", "")
      return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    end
    local ar, ag, ab = rgb(a)
    local br, bg_, bb = rgb(b)
    return string.format(
      "#%02x%02x%02x",
      math.floor(ar * alpha + br * (1 - alpha)),
      math.floor(ag * alpha + bg_ * (1 - alpha)),
      math.floor(ab * alpha + bb * (1 - alpha))
    )
  end

  function M.base_bg()
    return M.bg("Normal") or (vim.o.background == "light" and "#ffffff" or "#1e1e1e")
  end

  function M.palette()
    local normal = M.fg("Normal", "#cccccc")
    local base = M.base_bg()
    return {
      fg = normal,
      dim = M.fg("Comment", "#808080"),
      base = base,
      bar = M.bg("StatusLine") or M.blend(normal, base, 0.08),
      accent = M.fg("Function", "#569cd6"),
      blue = M.fg("Directory", "#569cd6"),
      green = M.fg("String", "#6a9955"),
      purple = M.fg("Statement", "#c586c0"),
      orange = M.fg("Constant", "#ce9178"),
      red = M.fg("DiagnosticError", "#f14c4c"),
      yellow = M.fg("DiagnosticWarn", "#cca700"),
      info = M.fg("DiagnosticInfo", "#3794ff"),
      hint = M.fg("DiagnosticHint", "#75beff"),
      add = M.fg("GitSignsAdd", M.fg("Added", "#587c0c")),
      change = M.fg("GitSignsChange", M.fg("Changed", "#0c7d9d")),
      delete = M.fg("GitSignsDelete", M.fg("Removed", "#94151b")),
    }
  end

  function M.icon(path, ft)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if not ok then return "", nil end
    local name = vim.fn.fnamemodify(path, ":t")
    local icon, group = devicons.get_icon(name, vim.fn.fnamemodify(name, ":e"), { default = false })
    if not icon and ft and ft ~= "" then
      icon, group = devicons.get_icon_by_filetype(ft, { default = false })
    end
    if not icon then
      icon, group = devicons.get_icon(name, nil, { default = true })
    end
    return icon or "", group
  end

  function M.esc(s)
    return (tostring(s):gsub("%%", "%%%%"))
  end

  local special_ft = {
    NvimTree = true, ["neo-tree"] = true, aerial = true, Trouble = true, trouble = true,
    qf = true, help = false, lazy = true, mason = true, TelescopePrompt = true,
    ["dapui_scopes"] = true, ["dapui_breakpoints"] = true, ["dapui_stacks"] = true,
    ["dapui_watches"] = true, ["dapui_console"] = true, ["dap-repl"] = true,
    noice = true, notify = true, Themery = true, vspanel = true,
  }

  function M.is_editor_win(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    if vim.api.nvim_win_get_config(win).relative ~= "" then return false end
    local buf = vim.api.nvim_win_get_buf(win)
    local bt = vim.bo[buf].buftype
    if bt ~= "" and bt ~= "help" then return false end
    return not special_ft[vim.bo[buf].filetype]
  end

  M.special_ft = special_ft

  function M.is_empty_noname(buf)
    return vim.api.nvim_buf_get_name(buf) == "" and vim.bo[buf].buftype == "" and not vim.bo[buf].modified
      and vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
  end

  return M
end

package.preload["ui.statusline"] = function()
  local util = require("ui.util")

  local M = {}

  M.extra = nil

  local modes = {
    n = { "NORMAL", "N" }, no = { "O-PENDING", "N" }, nov = { "O-PENDING", "N" }, noV = { "O-PENDING", "N" },
    i = { "INSERT", "I" }, ic = { "INSERT", "I" }, ix = { "INSERT", "I" },
    v = { "VISUAL", "V" }, vs = { "VISUAL", "V" }, V = { "V-LINE", "V" }, Vs = { "V-LINE", "V" },
    ["\22"] = { "V-BLOCK", "V" }, ["\22s"] = { "V-BLOCK", "V" },
    s = { "SELECT", "V" }, S = { "S-LINE", "V" }, ["\19"] = { "S-BLOCK", "V" },
    R = { "REPLACE", "R" }, Rc = { "REPLACE", "R" }, Rv = { "V-REPLACE", "R" },
    c = { "COMMAND", "C" }, cv = { "EX", "C" }, r = { "PROMPT", "C" }, rm = { "MORE", "C" },
    ["r?"] = { "CONFIRM", "C" }, ["!"] = { "SHELL", "T" }, t = { "TERMINAL", "T" }, nt = { "NORMAL", "N" },
  }

  function M.setup_hl()
    local p = util.palette()
    local set = vim.api.nvim_set_hl
    local mode_bg = { N = p.accent, I = p.green, V = p.purple, R = p.red, C = p.orange, T = p.green }
    for key, color in pairs(mode_bg) do
      set(0, "VsStMode" .. key, { fg = p.base, bg = color, bold = true })
    end

    local bars = { [""] = p.bar, D = p.orange }
    for suffix, bar in pairs(bars) do
      local on_debug = suffix == "D"
      local fg = on_debug and p.base or p.fg
      set(0, "VsSt" .. suffix, { fg = fg, bg = bar })
      set(0, "VsStDim" .. suffix, { fg = on_debug and p.base or p.dim, bg = bar })
      set(0, "VsStErr" .. suffix, { fg = on_debug and p.base or p.red, bg = bar, bold = on_debug })
      set(0, "VsStWarn" .. suffix, { fg = on_debug and p.base or p.yellow, bg = bar })
      set(0, "VsStAdd" .. suffix, { fg = on_debug and p.base or p.add, bg = bar })
      set(0, "VsStChg" .. suffix, { fg = on_debug and p.base or p.change, bg = bar })
      set(0, "VsStDel" .. suffix, { fg = on_debug and p.base or p.delete, bg = bar })
      set(0, "VsStRec" .. suffix, { fg = on_debug and p.base or p.red, bg = bar, bold = true })
      set(0, "VsStAccent" .. suffix, { fg = on_debug and p.base or p.accent, bg = bar, bold = true })
    end
  end

  local function debugging()
    if not package.loaded["dap"] then return nil end
    local session = require("dap").session()
    return session and (session.config and session.config.name or "debug") or nil
  end

  local function item(group, text, click)
    if not text or text == "" then return "" end
    local s = "%#" .. group .. "#" .. text
    if click then
      s = "%@v:lua.VsUi.click_" .. click .. "@" .. s .. "%T"
    end
    return s
  end

  function M.render()
    local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(win) then return "" end
    local buf = vim.api.nvim_win_get_buf(win)
    local dbg = debugging()
    local x = dbg and "D" or ""
    local g = function(name) return name .. x end

    local mode = vim.api.nvim_get_mode().mode
    local m = modes[mode] or modes[mode:sub(1, 1)] or { mode, "N" }
    local left = {}

    left[#left + 1] = "%#VsStMode" .. m[2] .. "# " .. m[1] .. " "

    local head = vim.b[buf].gitsigns_head
    if head and head ~= "" then
      left[#left + 1] = item(g("VsSt"), "  " .. util.esc(head) .. " ", "git")
      local st = vim.b[buf].gitsigns_status_dict
      if st then
        local diff = {}
        if (st.added or 0) > 0 then diff[#diff + 1] = "%#" .. g("VsStAdd") .. "#+" .. st.added end
        if (st.changed or 0) > 0 then diff[#diff + 1] = "%#" .. g("VsStChg") .. "#~" .. st.changed end
        if (st.removed or 0) > 0 then diff[#diff + 1] = "%#" .. g("VsStDel") .. "#-" .. st.removed end
        if #diff > 0 then left[#left + 1] = table.concat(diff, " ") .. " " end
      end
    end

    local counts = vim.diagnostic.count(nil)
    local errs = counts[vim.diagnostic.severity.ERROR] or 0
    local warns = counts[vim.diagnostic.severity.WARN] or 0
    left[#left + 1] = "%@v:lua.VsUi.click_problems@"
      .. "%#" .. g(errs > 0 and "VsStErr" or "VsStDim") .. "#  " .. errs
      .. " %#" .. g(warns > 0 and "VsStWarn" or "VsStDim") .. "# " .. warns .. " %T"

    local reg = vim.fn.reg_recording()
    if reg ~= "" then
      left[#left + 1] = item(g("VsStRec"), " 󰑋 recording @" .. reg .. " ")
    end

    if dbg then
      left[#left + 1] = item(g("VsSt"), "  " .. util.esc(dbg) .. " ", "debug")
    end

    local right = {}
    local progress = vim.lsp.status()
    if progress ~= "" then
      right[#right + 1] = item(g("VsStDim"), " " .. util.esc(progress:sub(1, 40)) .. " ")
    end

    local clients = {}
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      clients[#clients + 1] = c.name
    end
    if #clients > 0 then
      right[#right + 1] = item(g("VsStDim"), "  " .. util.esc(table.concat(clients, ", ")) .. " ", "lsp")
    end

    local cur = vim.api.nvim_win_get_cursor(win)
    right[#right + 1] = item(g("VsSt"), " Ln " .. cur[1] .. ", Col " .. (vim.fn.virtcol(".") or cur[2] + 1) .. " ")

    local bo = vim.bo[buf]
    if bo.buftype == "" then
      local sw = bo.shiftwidth == 0 and bo.tabstop or bo.shiftwidth
      right[#right + 1] = item(g("VsSt"), bo.expandtab and (" Spaces: " .. sw .. " ") or (" Tab Size: " .. bo.tabstop .. " "))
      local enc = (bo.fileencoding ~= "" and bo.fileencoding or vim.o.encoding):upper()
      right[#right + 1] = item(g("VsSt"), " " .. enc .. (bo.bomb and " BOM" or "") .. " ")
      right[#right + 1] = item(g("VsSt"), " " .. ({ unix = "LF", dos = "CRLF", mac = "CR" })[bo.fileformat] .. " ")
    end

    local ft = bo.filetype
    if ft ~= "" and not util.special_ft[ft] then
      local icon = util.icon(vim.api.nvim_buf_get_name(buf), ft)
      right[#right + 1] = item(g("VsSt"), " " .. icon .. " " .. ft .. " ")
    end

    if M.extra then
      local ok, extra = pcall(M.extra, buf)
      if ok and extra and extra ~= "" and extra ~= ft then
        right[#right + 1] = item(g("VsStAccent"), " " .. util.esc(extra) .. " ")
      end
    end

    right[#right + 1] = item(g("VsStDim"), " 󰂚 ", "notifications")

    return table.concat(left) .. "%#" .. g("VsSt") .. "#%=" .. table.concat(right)
  end

  function M.setup()
    vim.o.laststatus = 3
    vim.o.showmode = false
    vim.o.statusline = "%!v:lua.VsUi.statusline()"

    local group = vim.api.nvim_create_augroup("VsUiStatusline", { clear = true })
    vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave", "DiagnosticChanged", "LspProgress", "LspAttach", "LspDetach" }, {
      group = group,
      callback = function() vim.schedule(function() vim.cmd.redrawstatus() end) end,
    })
  end

  return M
end

package.preload["ui.tabline"] = function()
  local util = require("ui.util")

  local M = {}

  M.last_editor_win = nil

  local icon_hl_cache = {}

  function M.setup_hl()
    icon_hl_cache = {}
    local p = util.palette()
    local set = vim.api.nvim_set_hl
    local inactive_bg = p.bar
    set(0, "VsTab", { fg = p.dim, bg = inactive_bg })
    set(0, "VsTabSel", { fg = p.fg, bold = true, underline = true, sp = p.accent })
    set(0, "VsTabSelErr", { fg = p.red, bold = true, underline = true, sp = p.accent })
    set(0, "VsTabSelWarn", { fg = p.yellow, bold = true, underline = true, sp = p.accent })
    set(0, "VsTabErr", { fg = p.red, bg = inactive_bg })
    set(0, "VsTabWarn", { fg = p.yellow, bg = inactive_bg })
    set(0, "VsTabDir", { fg = p.dim, bg = inactive_bg, italic = true })
    set(0, "VsTabSelDir", { fg = p.dim, italic = true, underline = true, sp = p.accent })
    set(0, "VsTabFill", { bg = inactive_bg })
    set(0, "VsTabExplorer", { fg = p.dim, bg = inactive_bg, bold = true })
    set(0, "VsTabMore", { fg = p.accent, bg = inactive_bg, bold = true })
  end

  function M.buffers()
    local out = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_is_loaded(buf)
        and not util.is_empty_noname(buf) then
        out[#out + 1] = buf
      end
    end
    return out
  end

  local function display_names(bufs)
    local names, tails = {}, {}
    for _, buf in ipairs(bufs) do
      local full = vim.api.nvim_buf_get_name(buf)
      local tail = full == "" and "Untitled-" .. buf or vim.fn.fnamemodify(full, ":t")
      names[buf] = { tail = tail, full = full }
      tails[tail] = (tails[tail] or 0) + 1
    end
    for _, buf in ipairs(bufs) do
      local n = names[buf]
      if tails[n.tail] > 1 and n.full ~= "" then
        n.dir = vim.fn.fnamemodify(n.full, ":h:t")
      end
    end
    return names
  end

  local function sidebar_width()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "NvimTree" and vim.api.nvim_win_get_position(win)[2] == 0 then
        return vim.api.nvim_win_get_width(win)
      end
    end
    return 0
  end

  local function current_editor_buf()
    local win = vim.api.nvim_get_current_win()
    if not util.is_editor_win(win) and M.last_editor_win and vim.api.nvim_win_is_valid(M.last_editor_win) then
      win = M.last_editor_win
    end
    return vim.api.nvim_win_get_buf(win)
  end

  function M.render()
    local bufs = M.buffers()
    local names = display_names(bufs)
    local current = current_editor_buf()
    local cols = vim.o.columns
    local parts = {}

    local sw = sidebar_width()
    local used = 0
    if sw > 0 then
      local title = " EXPLORER"
      parts[#parts + 1] = "%#VsTabExplorer#" .. title .. string.rep(" ", math.max(0, sw - #title)) .. "%#VsTabFill#│"
      used = sw + 1
    end
    parts[#parts + 1] = "%<"

    local tabs = {}
    local current_idx = 1
    for i, buf in ipairs(bufs) do
      local n = names[buf]
      local sel = buf == current
      if sel then current_idx = i end
      local counts = vim.diagnostic.count(buf)
      local state = (counts[vim.diagnostic.severity.ERROR] or 0) > 0 and "Err"
        or (counts[vim.diagnostic.severity.WARN] or 0) > 0 and "Warn" or ""
      local base = sel and "VsTabSel" or "VsTab"
      local icon, icon_group = util.icon(n.full ~= "" and n.full or n.tail, vim.bo[buf].filetype)
      local modified = vim.bo[buf].modified

      local icon_hl = base
      if icon_group then
        local name = "VsTabIcon" .. (sel and "Sel" or "") .. icon_group
        if not icon_hl_cache[name] then
          icon_hl_cache[name] = true
          local p = util.palette()
          vim.api.nvim_set_hl(0, name, sel
            and { fg = util.fg(icon_group), underline = true, sp = p.accent }
            or { fg = util.fg(icon_group), bg = p.bar })
        end
        icon_hl = name
      end

      local text = "%" .. buf .. "@v:lua.VsUi.tab_click@"
        .. "%#" .. base .. "#  "
        .. "%#" .. icon_hl .. "#" .. icon .. " "
        .. "%#" .. base .. state .. "#" .. util.esc(n.tail)
        .. (n.dir and ("%#" .. (sel and "VsTabSelDir" or "VsTabDir") .. "# " .. util.esc(n.dir)) or "")
        .. "%#" .. base .. "# %T"
        .. "%" .. buf .. "@v:lua.VsUi.tab_close@" .. (modified and "● " or "󰅖 ") .. "%T"
      local width = vim.api.nvim_eval_statusline(text:gsub("%%%d*@[^@]*@", ""):gsub("%%T", ""), { use_tabline = true }).width
      tabs[i] = { text = text, width = width }
    end

    local avail = cols - used - 4
    local first, last = current_idx, current_idx
    local total = tabs[current_idx] and tabs[current_idx].width or 0
    while true do
      local grew = false
      if last < #tabs and total + tabs[last + 1].width <= avail then
        last = last + 1; total = total + tabs[last].width; grew = true
      end
      if first > 1 and total + tabs[first - 1].width <= avail then
        first = first - 1; total = total + tabs[first].width; grew = true
      end
      if not grew then break end
    end

    if first > 1 then parts[#parts + 1] = "%#VsTabMore#‹ " end
    for i = first, last do
      if tabs[i] then parts[#parts + 1] = tabs[i].text end
    end
    if last < #tabs then parts[#parts + 1] = "%#VsTabMore# ›" end

    parts[#parts + 1] = "%#VsTabFill#%="
    if #vim.api.nvim_list_tabpages() > 1 then
      parts[#parts + 1] = "%#VsTabMore# " .. vim.fn.tabpagenr() .. "/" .. vim.fn.tabpagenr("$") .. " "
    end
    return table.concat(parts)
  end

  local function target_win()
    local win = vim.api.nvim_get_current_win()
    if util.is_editor_win(win) then return win end
    if M.last_editor_win and vim.api.nvim_win_is_valid(M.last_editor_win)
      and vim.api.nvim_win_get_tabpage(M.last_editor_win) == vim.api.nvim_get_current_tabpage() then
      return M.last_editor_win
    end
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if util.is_editor_win(w) then return w end
    end
    return win
  end

  function M.goto_buf(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local win = target_win()
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_buf(win, buf)
  end

  function M.close_buf(buf, force)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.bo[buf].modified and not force then
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
      local choice = vim.fn.confirm(("Save changes to %s?"):format(name ~= "" and name or "Untitled"), "&Save\n&Don't Save\n&Cancel", 3)
      if choice == 1 then
        vim.api.nvim_buf_call(buf, function() vim.cmd.write() end)
      elseif choice ~= 2 then
        return
      end
    end

    local bufs = M.buffers()
    local idx = 1
    for i, b in ipairs(bufs) do
      if b == buf then idx = i end
    end
    local replacement = bufs[idx + 1] or bufs[idx - 1]
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf and vim.api.nvim_win_get_config(win).relative == "" then
        if replacement and replacement ~= buf then
          vim.api.nvim_win_set_buf(win, replacement)
        else
          vim.api.nvim_win_call(win, function() vim.cmd.enew() end)
        end
      end
    end
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  function M.cycle(step)
    local bufs = M.buffers()
    if #bufs == 0 then return end
    local cur = current_editor_buf()
    local idx = 1
    for i, b in ipairs(bufs) do
      if b == cur then idx = i end
    end
    M.goto_buf(bufs[(idx - 1 + step) % #bufs + 1])
  end

  function M.setup()
    vim.o.showtabline = 2
    vim.o.tabline = "%!v:lua.VsUi.tabline()"

    local group = vim.api.nvim_create_augroup("VsUiTabline", { clear = true })
    vim.api.nvim_create_autocmd("WinEnter", {
      group = group,
      callback = function()
        local win = vim.api.nvim_get_current_win()
        if util.is_editor_win(win) then M.last_editor_win = win end
      end,
    })
    vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufModifiedSet" }, {
      group = group,
      callback = function() vim.schedule(function() vim.cmd.redrawtabline() end) end,
    })

    local map = vim.keymap.set
    map("n", "<C-PageDown>", function() M.cycle(1) end, { desc = "Next tab" })
    map("n", "<C-PageUp>", function() M.cycle(-1) end, { desc = "Previous tab" })
    map("n", "<A-l>", function() M.cycle(1) end, { desc = "Next tab" })
    map("n", "<A-h>", function() M.cycle(-1) end, { desc = "Previous tab" })
    for i = 1, 9 do
      map("n", "<A-" .. i .. ">", function()
        local b = M.buffers()[i]
        if b then M.goto_buf(b) end
      end, { desc = "Go to tab " .. i })
    end
    map("n", "<leader>bd", function() M.close_buf(0) end, { desc = "Close tab" })
    map("n", "<leader>bD", function() M.close_buf(0, true) end, { desc = "Close tab (discard changes)" })
    map("n", "<leader>bo", function()
      local cur = current_editor_buf()
      for _, b in ipairs(M.buffers()) do
        if b ~= cur and not vim.bo[b].modified then M.close_buf(b) end
      end
    end, { desc = "Close other tabs" })
  end

  return M
end

package.preload["ui.winbar"] = function()
  local util = require("ui.util")

  local M = {}

  local kind_icons = {
    [1] = "󰈙", [2] = "", [3] = "󰅩", [4] = "󰏗", [5] = "󰠱", [6] = "󰆧", [7] = "", [8] = "",
    [9] = "", [10] = "", [11] = "", [12] = "󰊕", [13] = "󰀫", [14] = "󰏿", [15] = "󰀬",
    [16] = "󰎠", [17] = "◩", [18] = "󰅪", [19] = "󰅩", [20] = "󰌋", [21] = "󰟢", [22] = "",
    [23] = "󰙅", [24] = "", [25] = "󰆕", [26] = "󰊄",
  }
  local kind_hl = {
    [5] = "Type", [10] = "Type", [11] = "Type", [23] = "Type", [26] = "Type",
    [6] = "Function", [9] = "Function", [12] = "Function",
    [7] = "Identifier", [8] = "Identifier", [13] = "Identifier", [14] = "Constant", [22] = "Constant",
    [2] = "Include", [3] = "Include", [4] = "Include",
  }

  local cache = {}
  local pending = {}
  local chains = {}

  function M.setup_hl()
    local p = util.palette()
    local set = vim.api.nvim_set_hl
    set(0, "WinBar", { fg = p.dim })
    set(0, "WinBarNC", { fg = p.dim })
    set(0, "VsCrumb", { fg = p.dim })
    set(0, "VsCrumbSep", { fg = util.blend(p.dim, p.base, 0.6) })
    set(0, "VsCrumbFile", { fg = util.blend(p.fg, p.dim, 0.5) })
    for kind, group in pairs(kind_hl) do
      set(0, "VsCrumbKind" .. kind, { fg = util.fg(group, p.accent) })
    end
  end

  local function contains(range, line, col)
    local s, e = range.start, range["end"]
    if line < s.line or line > e.line then return false end
    if line == s.line and col < s.character then return false end
    if line == e.line and col > e.character then return false end
    return true
  end

  local function chain_at(buf, line, col)
    local entry = cache[buf]
    if not entry or not entry.symbols then return {} end
    local out = {}
    local nodes = entry.symbols
    if entry.flat then
      for _, s in ipairs(nodes) do
        local r = s.location and s.location.range
        if r and contains(r, line, col) then out[#out + 1] = { s = s, r = r } end
      end
      table.sort(out, function(a, b)
        return (a.r["end"].line - a.r.start.line) > (b.r["end"].line - b.r.start.line)
      end)
      for i, o in ipairs(out) do out[i] = { name = o.s.name, kind = o.s.kind, pos = o.r.start } end
      return out
    end
    while nodes do
      local found
      for _, s in ipairs(nodes) do
        if s.range and contains(s.range, line, col) then
          found = s
          break
        end
      end
      if not found then break end
      local pos = (found.selectionRange or found.range).start
      out[#out + 1] = { name = found.name, kind = found.kind, pos = pos }
      nodes = found.children
    end
    return out
  end

  function M.request(buf)
    if pending[buf] or not vim.api.nvim_buf_is_valid(buf) then return end
    local tick = vim.b[buf].changedtick
    if cache[buf] and cache[buf].tick == tick then return end
    local client = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })[1]
    if not client then return end
    pending[buf] = true
    local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
    client:request("textDocument/documentSymbol", params, function(err, result)
      pending[buf] = nil
      if err or not result or not vim.api.nvim_buf_is_valid(buf) then return end
      cache[buf] = { tick = tick, symbols = result, flat = result[1] ~= nil and result[1].location ~= nil }
      vim.schedule(function() pcall(vim.cmd.redrawstatus, { bang = true }) end)
    end, buf)
  end

  local function path_parts(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return {}, "Untitled" end
    local rel = vim.fn.fnamemodify(name, ":~:.")
    local parts = vim.split(rel, "/", { plain = true, trimempty = true })
    local file = table.remove(parts)
    if not rel:match("^[~/]") then
      table.insert(parts, 1, vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
    end
    if #parts > 4 then
      parts = { "…", parts[#parts - 2], parts[#parts - 1], parts[#parts] }
    end
    return parts, file
  end

  function M.render()
    local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(win) then return "" end
    local buf = vim.api.nvim_win_get_buf(win)
    local sep = "%#VsCrumbSep# › "
    local out = { " " }

    local parts, file = path_parts(buf)
    for _, p in ipairs(parts) do
      out[#out + 1] = "%#VsCrumb#" .. util.esc(p) .. sep
    end
    local icon, icon_group = util.icon(vim.api.nvim_buf_get_name(buf), vim.bo[buf].filetype)
    out[#out + 1] = "%#" .. (icon_group or "VsCrumbFile") .. "#" .. icon .. " %#VsCrumbFile#" .. util.esc(file)

    local cur = vim.api.nvim_win_get_cursor(win)
    local chain = chain_at(buf, cur[1] - 1, cur[2])
    chains[win] = {}
    for i, s in ipairs(chain) do
      chains[win][i] = s.pos
      local group = kind_hl[s.kind] and ("VsCrumbKind" .. s.kind) or "VsCrumb"
      out[#out + 1] = sep .. "%" .. i .. "@v:lua.VsUi.crumb_click@"
        .. "%#" .. group .. "#" .. (kind_icons[s.kind] or "•") .. " %#VsCrumb#" .. util.esc(s.name) .. "%T"
    end
    return table.concat(out)
  end

  function M.click(idx)
    local win = vim.fn.getmousepos().winid
    local pos = chains[win] and chains[win][idx]
    if not pos or not vim.api.nvim_win_is_valid(win) then return end
    vim.api.nvim_set_current_win(win)
    pcall(vim.api.nvim_win_set_cursor, win, { pos.line + 1, pos.character })
  end

  local WINBAR = "%{%v:lua.VsUi.winbar()%}"

  local function attach(win)
    if not vim.api.nvim_win_is_valid(win) then return end
    local buf = vim.api.nvim_win_get_buf(win)
    if util.is_editor_win(win) and vim.bo[buf].buftype == "" and not util.is_empty_noname(buf) then
      if vim.wo[win].winbar ~= WINBAR then vim.wo[win].winbar = WINBAR end
    elseif vim.wo[win].winbar == WINBAR then
      vim.wo[win].winbar = ""
    end
  end

  function M.setup()
    local group = vim.api.nvim_create_augroup("VsUiWinbar", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "FileType", "TermOpen", "BufModifiedSet", "BufFilePost" }, {
      group = group,
      callback = function() attach(vim.api.nvim_get_current_win()) end,
    })

    local timers = {}
    local function debounced(buf, ms)
      local t = timers[buf]
      if not t then
        t = vim.uv.new_timer()
        timers[buf] = t
      end
      t:stop()
      t:start(ms, 0, vim.schedule_wrap(function() M.request(buf) end))
    end

    vim.api.nvim_create_autocmd("LspAttach", {
      group = group,
      callback = function(ev) debounced(ev.buf, 100) end,
    })
    vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
      group = group,
      callback = function(ev) debounced(ev.buf, 100) end,
    })
    vim.api.nvim_create_autocmd("TextChanged", {
      group = group,
      callback = function(ev) debounced(ev.buf, 500) end,
    })
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
      group = group,
      callback = function(ev)
        cache[ev.buf] = nil
        pending[ev.buf] = nil
        local t = timers[ev.buf]
        if t then
          t:stop()
          t:close()
          timers[ev.buf] = nil
        end
      end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      callback = function(ev) chains[tonumber(ev.match)] = nil end,
    })

    for _, win in ipairs(vim.api.nvim_list_wins()) do attach(win) end
  end

  return M
end

package.preload["ui.panel"] = function()
  local util = require("ui.util")

  local M = {}

  M.height = 12

  local state = {
    win = nil,
    tab = "terminal",
    problems_buf = nil,
    output_buf = nil,
    output_job = nil,
    output_title = nil,
    terms = {},
    term_idx = 0,
    rows = {},
  }

  local ns = vim.api.nvim_create_namespace("vs_panel")

  function M.setup_hl()
    local p = util.palette()
    local set = vim.api.nvim_set_hl
    set(0, "VsPanelTab", { fg = p.dim })
    set(0, "VsPanelTabSel", { fg = p.fg, bold = true, underline = true, sp = p.accent })
    set(0, "VsPanelBadge", { fg = p.base, bg = p.accent, bold = true })
    set(0, "VsPanelBadgeErr", { fg = p.base, bg = p.red, bold = true })
    set(0, "VsPanelFile", { fg = p.fg, bold = true })
    set(0, "VsPanelDir", { fg = p.dim, italic = true })
    set(0, "VsPanelPos", { fg = p.dim })
    set(0, "VsPanelSource", { fg = p.dim, italic = true })
    set(0, "VsPanelBtn", { fg = p.dim })
  end

  local function is_open()
    return state.win and vim.api.nvim_win_is_valid(state.win)
  end

  function M.is_panel_win(win)
    return is_open() and win == state.win
  end

  local sev_icon = { "", "", "", "󰌶" }
  local sev_hl = { "DiagnosticError", "DiagnosticWarn", "DiagnosticInfo", "DiagnosticHint" }

  local function build_items()
    local qf = vim.fn.getqflist({ title = 0, items = 0 })
    local items = {}
    if qf.title and qf.title:match("^Build") then
      for _, it in ipairs(qf.items) do
        if it.valid == 1 and it.bufnr > 0 then
          local t = (it.type or ""):upper()
          items[#items + 1] = {
            bufnr = it.bufnr, lnum = it.lnum - 1, col = math.max(it.col - 1, 0),
            severity = (t == "W") and 2 or (t == "I" or t == "N") and 3 or 1,
            message = it.text, source = "build",
          }
        end
      end
    end
    return items
  end

  local function problem_counts()
    local c = vim.diagnostic.count(nil)
    local n = (c[1] or 0) + (c[2] or 0) + (c[3] or 0) + (c[4] or 0)
    return n + #build_items(), c[1] or 0
  end

  local function render_problems()
    local buf = state.problems_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

    local by_file = {}
    local order = {}
    local function add(d)
      local key = d.bufnr
      if not by_file[key] then
        by_file[key] = {}
        order[#order + 1] = key
      end
      table.insert(by_file[key], d)
    end
    for _, d in ipairs(vim.diagnostic.get(nil)) do add(d) end
    for _, d in ipairs(build_items()) do add(d) end

    local function worst(list)
      local w = 9
      for _, d in ipairs(list) do w = math.min(w, d.severity) end
      return w
    end
    table.sort(order, function(a, b)
      local wa, wb = worst(by_file[a]), worst(by_file[b])
      if wa ~= wb then return wa < wb end
      return vim.api.nvim_buf_get_name(a) < vim.api.nvim_buf_get_name(b)
    end)

    local lines, marks, rows = {}, {}, {}
    if #order == 0 then
      lines[1] = "  No problems have been detected in the workspace."
      marks[1] = { { 0, #lines[1], "VsPanelPos" } }
    end
    for _, b in ipairs(order) do
      local list = by_file[b]
      table.sort(list, function(x, y)
        if x.severity ~= y.severity then return x.severity < y.severity end
        return x.lnum < y.lnum
      end)
      local name = vim.api.nvim_buf_get_name(b)
      local tail = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
      local dir = name ~= "" and vim.fn.fnamemodify(name, ":~:.:h") or ""
      local icon = util.icon(name, vim.bo[b].filetype)
      local header = " " .. icon .. " " .. tail .. "  " .. (dir ~= "." and dir or "") .. "  " .. #list
      lines[#lines + 1] = header
      local s1 = #(" " .. icon .. " ")
      marks[#lines] = {
        { s1, s1 + #tail, "VsPanelFile" },
        { s1 + #tail, #header - #tostring(#list), "VsPanelDir" },
        { #header - #tostring(#list), #header, "VsPanelBadge" },
      }
      rows[#lines] = { bufnr = b, lnum = list[1].lnum, col = list[1].col }
      for _, d in ipairs(list) do
        local msg = (d.message or ""):gsub("\n.*", "")
        local src = d.source and ("  " .. d.source) or ""
        local pos = ("  [Ln %d, Col %d]"):format(d.lnum + 1, d.col + 1)
        local prefix = "    " .. sev_icon[d.severity] .. " "
        local line = prefix .. msg .. src .. pos
        lines[#lines + 1] = line
        marks[#lines] = {
          { 4, #prefix, sev_hl[d.severity] },
          { #prefix + #msg, #prefix + #msg + #src, "VsPanelSource" },
          { #line - #pos, #line, "VsPanelPos" },
        }
        rows[#lines] = { bufnr = b, lnum = d.lnum, col = d.col }
      end
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for row, list in pairs(marks) do
      for _, mk in ipairs(list) do
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, mk[1], { end_col = mk[2], hl_group = mk[3] })
      end
    end
    state.rows = rows
  end

  local function jump_to_problem()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local target = state.rows[row]
    if not target or not vim.api.nvim_buf_is_valid(target.bufnr) then return end
    local tl = require("ui.tabline")
    tl.goto_buf(target.bufnr)
    pcall(vim.api.nvim_win_set_cursor, 0, { target.lnum + 1, target.col })
    vim.cmd("normal! zv")
  end

  local function problems_buf()
    if state.problems_buf and vim.api.nvim_buf_is_valid(state.problems_buf) then return state.problems_buf end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "vspanel"
    vim.bo[buf].bufhidden = "hide"
    vim.api.nvim_buf_set_name(buf, "vs://problems")
    vim.keymap.set("n", "<CR>", jump_to_problem, { buffer = buf, desc = "Go to problem" })
    vim.keymap.set("n", "<2-LeftMouse>", jump_to_problem, { buffer = buf })
    vim.keymap.set("n", "q", function() M.close() end, { buffer = buf })
    state.problems_buf = buf
    return buf
  end

  local function placeholder(text)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "vspanel"
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  " .. text })
    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "q", function() M.close() end, { buffer = buf })
    return buf
  end

  local function live_terms()
    local out = {}
    for _, b in ipairs(state.terms) do
      if vim.api.nvim_buf_is_valid(b) then out[#out + 1] = b end
    end
    state.terms = out
    state.term_idx = math.max(1, math.min(state.term_idx, #out))
    return out
  end

  local function style_win(win)
    local wo = vim.wo[win]
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.foldcolumn = "0"
    wo.winfixheight = true
    wo.cursorline = false
    wo.winbar = "%{%v:lua.VsUi.panel_header()%}"
  end

  local function buf_for(tab)
    if tab == "problems" then
      return problems_buf()
    elseif tab == "output" then
      if state.output_buf and vim.api.nvim_buf_is_valid(state.output_buf) then return state.output_buf end
      return placeholder("No task output yet. Run :Build or :Run.")
    else
      local terms = live_terms()
      return terms[state.term_idx]
    end
  end

  local function ensure_win()
    if is_open() then return state.win end
    local cur = vim.api.nvim_get_current_win()
    local tree = package.loaded["nvim-tree"] and require("nvim-tree.api").tree
    local tree_open = tree and tree.is_visible()
    if tree_open then tree.close() end
    vim.cmd("botright " .. M.height .. "split")
    state.win = vim.api.nvim_get_current_win()
    style_win(state.win)
    if tree_open then
      pcall(tree.toggle, { focus = false, find_file = false })
    end
    if vim.api.nvim_win_is_valid(cur) then vim.api.nvim_set_current_win(cur) end
    return state.win
  end

  local function new_term_buf(cmd)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.bo[buf].buflisted = false
    local win = ensure_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_call(win, function()
      vim.fn.jobstart(cmd or vim.o.shell, { term = true, cwd = vim.fn.getcwd() })
    end)
    vim.bo[buf].buflisted = false
    return buf
  end

  function M.show(tab, opts)
    opts = opts or {}
    state.tab = tab or state.tab
    local win = ensure_win()
    if state.tab == "terminal" and #live_terms() == 0 then
      state.terms = { new_term_buf() }
      state.term_idx = 1
    end
    local buf = buf_for(state.tab)
    if vim.api.nvim_win_get_buf(win) ~= buf then vim.api.nvim_win_set_buf(win, buf) end
    style_win(win)
    if state.tab == "problems" then render_problems() end
    if opts.focus then
      vim.api.nvim_set_current_win(win)
      if state.tab == "terminal" then vim.cmd.startinsert() end
    end
    vim.cmd.redrawstatus({ bang = true })
  end

  function M.close()
    if not is_open() then return end
    M.height = vim.api.nvim_win_get_height(state.win)
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then
      pcall(vim.api.nvim_win_close, state.win, true)
    end
    state.win = nil
  end

  function M.toggle(tab)
    if is_open() and (tab == nil or tab == state.tab) then
      M.close()
    else
      M.show(tab, { focus = true })
    end
  end

  function M.new_terminal(cmd)
    state.tab = "terminal"
    live_terms()
    local buf = new_term_buf(cmd)
    table.insert(state.terms, buf)
    state.term_idx = #state.terms
    M.show("terminal", { focus = true })
  end

  function M.run(cmd, opts)
    opts = opts or {}
    if state.output_job then pcall(vim.fn.jobstop, state.output_job) end
    local old = state.output_buf

    state.tab = "output"
    local win = ensure_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    style_win(win)
    state.output_buf = buf
    state.output_title = opts.title or cmd

    local job
    vim.api.nvim_win_call(win, function()
      job = vim.fn.jobstart(cmd, {
        term = true,
        cwd = opts.cwd,
        on_exit = function(_, code)
          vim.schedule(function()
            if state.output_job == job then state.output_job = nil end
            if code == 143 or code == 129 then return end
            if code == 0 then
              vim.notify("✓ " .. (opts.ok_msg or cmd), vim.log.levels.INFO)
            else
              vim.notify("✗ " .. (opts.err_msg or cmd) .. " (exit " .. code .. ")", vim.log.levels.ERROR)
            end
            if opts.quickfix and vim.api.nvim_buf_is_valid(buf) then
              local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
              vim.fn.setqflist({}, "r", { title = "Build: " .. state.output_title, lines = lines, efm = opts.efm or vim.o.errorformat })
              local n = #vim.tbl_filter(function(i) return i.valid == 1 end, vim.fn.getqflist())
              if code ~= 0 and n > 0 then
                vim.notify(("%d problem(s) from build → PROBLEMS 탭 / ]q"):format(n), vim.log.levels.WARN)
              end
            end
            if opts.on_exit then opts.on_exit(code) end
            vim.cmd.redrawstatus({ bang = true })
          end)
        end,
      })
      vim.cmd("normal! G")
    end)
    state.output_job = job
    if old and old ~= buf and vim.api.nvim_buf_is_valid(old) then
      pcall(vim.api.nvim_buf_delete, old, { force = true })
    end
    vim.cmd.redrawstatus({ bang = true })
    return job
  end

  local function term_name(buf)
    local title = vim.b[buf].term_title or ""
    if title == "" or title:match("^term://") then
      return vim.fn.fnamemodify(vim.o.shell, ":t")
    end
    return title:sub(1, 18)
  end

  function M.header()
    local total, errs = problem_counts()
    local function tab(id, label, key)
      local sel = state.tab == key
      return "%" .. id .. "@v:lua.VsUi.panel_click@%#" .. (sel and "VsPanelTabSel" or "VsPanelTab") .. "# " .. label .. " %T"
    end
    local parts = { " " }
    parts[#parts + 1] = tab(1, "PROBLEMS", "problems")
    if total > 0 then
      parts[#parts + 1] = "%#" .. (errs > 0 and "VsPanelBadgeErr" or "VsPanelBadge") .. "# " .. total .. " "
    end
    parts[#parts + 1] = "%#VsPanelTab#  "
    parts[#parts + 1] = tab(2, "OUTPUT", "output")
    if state.output_job then parts[#parts + 1] = "%#VsPanelBadge# ● " end
    parts[#parts + 1] = "%#VsPanelTab#  "
    parts[#parts + 1] = tab(3, "TERMINAL", "terminal")

    local right = {}
    if state.tab == "terminal" then
      local terms = live_terms()
      for i = 1, #terms do
        local sel = i == state.term_idx
        right[#right + 1] = "%" .. (10 + i) .. "@v:lua.VsUi.panel_click@%#"
          .. (sel and "VsPanelTabSel" or "VsPanelTab") .. "# " .. i .. ": " .. util.esc(term_name(terms[i])) .. " %T"
      end
      right[#right + 1] = "%99@v:lua.VsUi.panel_click@%#VsPanelBtn#  %T"
    elseif state.tab == "output" and state.output_title then
      right[#right + 1] = "%#VsPanelTab#" .. util.esc(state.output_title:sub(1, 50)) .. " "
    end
    right[#right + 1] = "%98@v:lua.VsUi.panel_click@%#VsPanelBtn#  %T"
    return table.concat(parts) .. "%#VsPanelTab#%=" .. table.concat(right)
  end

  function M.click(id)
    if id == 1 then M.show("problems", { focus = true })
    elseif id == 2 then M.show("output", { focus = true })
    elseif id == 3 then M.show("terminal", { focus = true })
    elseif id == 98 then M.close()
    elseif id == 99 then M.new_terminal()
    elseif id > 10 then
      state.term_idx = id - 10
      M.show("terminal", { focus = true })
    end
  end

  function M.setup()
    local group = vim.api.nvim_create_augroup("VsUiPanel", { clear = true })
    local timer = vim.uv.new_timer()
    vim.api.nvim_create_autocmd({ "DiagnosticChanged", "QuickFixCmdPost" }, {
      group = group,
      callback = function()
        timer:stop()
        timer:start(150, 0, vim.schedule_wrap(function()
          if is_open() and state.tab == "problems" then render_problems() end
          pcall(vim.cmd.redrawstatus, { bang = true })
        end))
      end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      callback = function(ev)
        if state.win and tonumber(ev.match) == state.win then
          M.height = vim.api.nvim_win_get_height(state.win)
          state.win = nil
        end
      end,
    })
    vim.api.nvim_create_autocmd("TermClose", {
      group = group,
      callback = function(ev)
        if vim.tbl_contains(state.terms, ev.buf) then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
              local was_shown = is_open() and vim.api.nvim_win_get_buf(state.win) == ev.buf
              if was_shown and #live_terms() > 1 then
                state.term_idx = math.max(1, state.term_idx - 1)
              end
              pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
              if was_shown then
                if #live_terms() > 0 then M.show("terminal") else M.close() end
              end
            end
          end)
        end
      end,
    })

    local map = vim.keymap.set
    local function toggle_term()
      if vim.fn.mode() == "i" then vim.cmd.stopinsert() end
      M.toggle("terminal")
    end
    map({ "n", "i", "t" }, "<C-`>", toggle_term, { desc = "Toggle terminal panel" })
    map({ "n", "t" }, "<C-Space>", toggle_term, { desc = "Toggle terminal panel" })
    map({ "n", "t" }, "<C-@>", toggle_term, { desc = "Toggle terminal panel" })
    map("n", "<leader>pp", function()
      if is_open() then M.close() else M.show(nil, { focus = true }) end
    end, { desc = "Toggle panel" })
    map("n", "<leader>pe", function() M.show("problems", { focus = true }) end, { desc = "Problems" })
    map("n", "<leader>po", function() M.show("output", { focus = true }) end, { desc = "Output" })
    map("n", "<leader>pt", function() M.show("terminal", { focus = true }) end, { desc = "Terminal" })
    map("n", "<leader>pn", function() M.new_terminal() end, { desc = "New terminal" })
    map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
  end

  return M
end

package.preload["ui"] = function()
  local util = require("ui.util")
  local statusline = require("ui.statusline")
  local tabline = require("ui.tabline")
  local winbar = require("ui.winbar")
  local panel = require("ui.panel")

  local M = {}

  _G.VsUi = {
    statusline = statusline.render,
    tabline = tabline.render,
    winbar = winbar.render,
    panel_header = panel.header,

    tab_click = function(buf, _, button)
      if button == "m" then
        tabline.close_buf(buf)
      else
        tabline.goto_buf(buf)
      end
    end,
    tab_close = function(buf) tabline.close_buf(buf) end,
    crumb_click = function(idx) winbar.click(idx) end,
    panel_click = function(id) panel.click(id) end,

    click_problems = function() panel.show("problems", { focus = true }) end,
    click_git = function() vim.cmd("Neogit") end,
    click_lsp = function() vim.cmd("checkhealth vim.lsp") end,
    click_debug = function() pcall(function() require("dapui").toggle() end) end,
    click_notifications = function() pcall(vim.cmd, "Noice history") end,
  }

  local function setup_hl()
    statusline.setup_hl()
    tabline.setup_hl()
    winbar.setup_hl()
    panel.setup_hl()
  end

  local function is_aux(w)
    local buf = vim.api.nvim_win_get_buf(w)
    return panel.is_panel_win(w) or vim.bo[buf].buftype == "terminal" or util.special_ft[vim.bo[buf].filetype]
  end

  local function quit_if_only_aux(closed)
    if not util.is_editor_win(closed) then return end
    local tab = vim.api.nvim_win_get_tabpage(closed)
    vim.schedule(function()
      if not vim.api.nvim_tabpage_is_valid(tab) then return end
      local aux = 0
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_get_config(w).relative == "" then
          if util.is_editor_win(w) then return end
          if is_aux(w) then aux = aux + 1 end
        end
      end
      if aux == 0 then return end
      if #vim.api.nvim_list_tabpages() > 1 then
        pcall(vim.cmd, "tabclose")
      else
        pcall(vim.cmd, "confirm qa")
      end
    end)
  end

  function M.setup(opts)
    opts = opts or {}
    statusline.extra = opts.statusline_extra

    setup_hl()
    local group = vim.api.nvim_create_augroup("VsUi", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = setup_hl,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      callback = function(ev)
        local win = tonumber(ev.match)
        if win and vim.api.nvim_win_is_valid(win) then quit_if_only_aux(win) end
      end,
    })

    statusline.setup()
    tabline.setup()
    winbar.setup()
    panel.setup()

    vim.opt.fillchars:append({ eob = " ", vert = "│", horiz = "─" })
  end

  M.panel = panel
  M.tabline = tabline

  return M
end

require("ui").setup({
  statusline_extra = function()
    local profile = cached_profile()
    if profile == "cpp" then
      local target = get_cmake_target(vim.fn.getcwd())
      if target then return "cpp[" .. target .. "]" end
    end
    return profile ~= "default" and profile or nil
  end,
})
