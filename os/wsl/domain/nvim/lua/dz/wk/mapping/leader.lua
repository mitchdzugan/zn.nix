local paredit = require("nvim-paredit")

local iconReadme = { cat="file", name="README" }
local iconTodo = { cat="file", name="TODO" }

local wk_nvim_configs = {
  {group = "nvim configs" },
  {"d", cmd = "e ~/Projects/dz-nixos/config/domain/nvim/", desc = "open nvim directory" },
  {"v", cmd = "e ~/Projects/dz-nixos/config/domain/nvim/init.vim", desc = "edit `init.vim`" },
  {"l", cmd = "e ~/Projects/dz-nixos/config/domain/nvim/lua", desc = "open nvim lua directory" },
  {"c", cmd = "e ~/Projects/dz-nixos/config/domain/nvim/config.nix", desc = "edit neovim `config.nix`" },
  {"g", cmd = "e ~/Projects/dz-nixos/config/domain/nvim/neovide.nix", desc = "edit `neovide.nix`" },
}

local wk_configs = {
  {group = "configs" },
  {"d", cmd = "e ~/Projects/dz-nixos/config/", desc = "open config directory" },
  {"v", using = wk_nvim_configs},
}

local function do_paredit(fn_name, do_continue)
  return function()
    paredit.api[fn_name]()
    if (do_continue) then
      vim.cmd("execute \"WhichKey <leader>L\"")
    end
  end
end

local function mk_wk_lispk(do_continue_)
  local do_continue = do_continue_ == true
  return {
    {group = "lisp" .. ((do_continue and " - cont.") or "")},
    {"b", do_paredit("barf_forwards", do_continue), desc = "barf" },
    {"s", do_paredit("slurp_forwards", do_continue), desc = "slurp" },
    {"B", do_paredit("barf_backwards", do_continue), desc = "barf back" },
    {"S", do_paredit("slurp_backwards", do_continue), desc = "slurp back" },
    {"d", do_paredit("delete_element", do_continue), desc = "delete element" },
    {"D", do_paredit("delete_form", do_continue), desc = "delete form" },
    {"h", do_paredit("drag_element_forwards", do_continue), desc = "drag element" },
    {"k", do_paredit("raise_element", do_continue), desc = "raise element" },
    {"l", do_paredit("drag_element_backwards", do_continue), desc = "drag element back" },
    {"H", do_paredit("drag_form_forwards", do_continue), desc = "drag form" },
    {"K", do_paredit("raise_form", do_continue), desc = "raise form" },
    {"L", do_paredit("drag_form_backwards", do_continue), desc = "drag form back" },
    {"f", do_paredit("move_to_next_element", do_continue), desc = "move next" },
    {"F", do_paredit("move_to_prev_element", do_continue), desc = "move prev" },
    -- {"<Space>", "!a)zprint<cr>", desc = "format form" },
  }
end

local wk_files = {
  {group = "files" },
  {"p", cmd = "Telescope git_files", desc = "find project file" },
  {"f", cmd = "Telescope find_files", desc = "find file" },
  {"b", cmd = "Telescope buffers", desc = "open buffers" },
  {"r", cmd = "Telescope oldfiles", desc = "recent files" },
  {"g", cmd = "Telescope live_grep grep_current_only=true", desc = "grep current file" },
  {"c", using = wk_configs },
  {"v", using = wk_nvim_configs },
  {"t", cmd = "NvimTreeFindFile", desc = "show file in file tree" },
  {"T", cmd = "NvimTreeToggle", desc = "toggle file tree" },
}

local wk_search = {
  {group = "search" },
  {"p", cmd = "Telescope live_grep", desc = "grep project" },
  {"f", cmd = "Telescope live_grep grep_current_only=true", desc = "grep current file" },
  {"o", cmd = "Telescope live_grep grep_open_files=true", desc = "grep open buffers" },
  {"s", cmd = "Telescope current_buffer_fuzzy_find", desc = "swoop in file" },
}

local function mk_add_section_mappings(section_type)
  local opts = ({
    todo = {
      extra = {{group = "add todo"}},
      desc_word = "todo",
      cmd_extra = "Todo",
      icon = iconTodo,
    },
    header = {
      extra = {{group = "add header"}},
      desc_word = "header",
      cmd_extra = "Header",
      icon = iconReadme,
    },
    section = {
      extra = {},
      desc_word = "Section",
      cmd_extra = "",
      icon = iconReadme,
    },
  })[section_type]
  local mk = function(k, cmd_pre, desc_pre, desc_post)
    cmd = cmd_pre .. opts.cmd_extra
    desc = desc_pre .. " " .. opts.desc_word .. " " .. desc_post
    return { k, cmd = cmd, desc = desc, icon = opts.icon }
  end
  return {
    opts.extra,
    mk("c", "ZorgInsertChild", "insert new", "child"),
    mk("C", "ZorgAppendChild", "append new", "child"),
    mk("s", "ZorgInsertSibling", "insert new", "sibling"),
    mk("S", "ZorgAppendSibling", "append new", "sibling"),
  }
end

local wk_organizing = {
  {group = "organizing", icon = iconReadme },
  {"<Enter>", cmd = "TodoOpenToday", desc = "open today's todos", icon=iconTodo },
  {"<S-Left>", cmd = "TodoOpenDayBefore", desc = "back 1 day's todos", icon=iconTodo },
  {"<S-Right>", cmd = "TodoOpenDayAfter", desc = "forward 1 day's todos", icon=iconTodo },
  {"-", cmd = "ZorgAddHr", desc = "add horizontal row line", icon=iconReadme },
  {"b", cmd = "ZorgToggleBullet", desc = "toggle header line bullet", icon=iconReadme },
  {">", cmd = "ZorgIncSectionDepth", desc = "increment section depth", icon=iconReadme },
  {"<", cmd = "ZorgDecSectionDepth", desc = "decrement section depth", icon=iconReadme },
  {"<BS>", cmd = "ZorgRemoveTodoState", desc = "insert root header section", icon=iconReadme },
  {"C", cmd = "ZorgAlterSectionContent", desc = "alter section header content", icon=iconReadme },
  {"H", using = mk_add_section_mappings("header")},
  {"h", cmd = "ZorgAddNewRootHeader", desc = "insert root header section", icon=iconReadme },
  {"T", using = mk_add_section_mappings("todo")},
  {"t", cmd = "ZorgAddNewRootTodo", desc = "insert root todo section", icon=iconTodo },
  {"<tab>", cmd = "ZorgCycleTodoState", desc = "progress todo state", icon=iconTodo },
  {"<Space>", cmd = "ZorgSetTodo", desc = "set todo state to `todo`", icon=iconTodo },
  {",", cmd = "ZorgSetWip", desc = "set todo state to `wip`", icon=iconTodo },
  {".", cmd = "ZorgSetDone", desc = "set todo state to `done`", icon=iconTodo },
  {"/", cmd = "ZorgSetBlocked", desc = "set todo state to `blocked`", icon=iconTodo },
  mk_add_section_mappings("section"),
  {"<Up>", cmd = "ZorgNavSectionUp", desc = "nav to prev section", icon=iconReadme },
  {"<Down>", cmd = "ZorgNavSectionDown", desc = "nav to next section", icon=iconReadme },
}

return {
  {"<tab>", cmd = "TabMRU", desc = "most recent buffer [tab local]" },
  {"<Up>"   , "<C-w><Up>"   , desc = "navigate windows up"    },
  {"<Right>", "<C-w><Right>", desc = "navigate windows right" },
  {"<Down>" , "<C-w><Down>" , desc = "navigate windows down"  },
  {"<Left>" , "<C-w><Left>" , desc = "navigate windows left"  },
  {",", cmd = "WhichKey ;", desc = "filetype specific" },
  {"/", cmd = "noh", desc = "clear search" },
  {"b", cmd = "Telescope buffers", desc = "open buffers" },
  {"h", cmd = "Telescope help_tags", desc = "help" },
  {"T", cmd = "Telescope colorscheme", desc = "themes" },
  {"f", using = wk_files },
  {"o", using = wk_organizing },
  {"s", using = wk_search },
  {"c", using = wk_configs },
  {"v", using = wk_nvim_configs },
  {"l", using = mk_wk_lispk(false)},
  {"L", using = mk_wk_lispk(true)},
  {"[", "%", desc = "goto matching brace" },
}
