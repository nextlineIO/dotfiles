-- OPTIONS
local set = vim.opt

--line nums
set.relativenumber = true
set.number = true

-- indentation and tabs
set.tabstop = 4
set.shiftwidth = 4
set.autoindent = true
set.expandtab = true

-- search settings
set.ignorecase = true
set.smartcase = true

-- appearance
set.termguicolors = true
set.background = "dark"
set.signcolumn = "yes"

-- cursor line
set.cursorline = true

-- Color Column size
set.colorcolumn =

-- clipboard
set.clipboard:append("unnamedplus")

-- backspace
set.backspace = "indent,eol,start"

-- split windows
set.splitbelow = true
set.splitright = true

-- dw/diw/ciw works on full-word
set.iskeyword:append("-")

-- keep cursor at least 8 rows from top/bot
set.scrolloff = 8

-- ensure undo dir exists (XDG-correct location), then enable persistent undo
local undo_dir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undo_dir) == 0 then
  vim.fn.mkdir(undo_dir, "p", 0700)
end

-- normalize permissions to rwx------ if they drift
if vim.fn.getfperm(undo_dir) ~= "rwx------" then
  vim.fn.setfperm(undo_dir, "rwx------")
end

-- normalize permissions to rwx------ if they drift
if vim.fn.getfperm(undo_dir) ~= "rwx------" then
  vim.fn.setfperm(undo_dir, "rwx------")
end

-- undo dir settings
set.swapfile = false
set.backup = false
set.undodir = undo_dir
set.undofile = true

-- incremental search
set.incsearch = true

-- faster cursor hold
set.updatetime = 50
