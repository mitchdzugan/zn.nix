local colors = require('render-markdown.colors')

local function get_hl(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function fg_to_bg(highlight)
  local name = string.format('%s_fgtobg_%s', "", highlight)
  local hl = get_hl(highlight)
  vim.api.nvim_set_hl(0, name, {
    bg = hl.fg,
    ctermbg = hl.ctermfg,
  })
  return name
end

require('tabby.tabline').set(function(line)
  local rsep =  ""
  local lsep =  ""
  local theme = {
    fill = 'TabLineFill',
    head = 'TabLine',
    current_tab = 'TabLineSel',
    tab = 'TabLine',
    win = 'TabLine',
    tail = 'TabLine',
  }
  local win_count = 0
  line.wins_in_tab(line.api.get_current_tab()).foreach(function()
    win_count = win_count + 1
  end)
  local win_printing_count = 0
  local is_first = true
  return {
    line.tabs().foreach(function(tab)
      local hl = tab.is_current() and theme.current_tab or theme.tab
      lside = (is_first and " ") or line.sep(lsep, colors.bg_to_fg(theme.tab), hl)
      is_first = false
      return {
        lside,
        tab.is_current() and '' or '󰆣',
        tab.name(),
        line.sep(rsep, colors.bg_to_fg(theme.tab), hl),
        hl = hl,
        margin = ' ',
      }
    end),
    {
      lsep,
      -- hl = colors.combine(colors.bg_to_fg(theme.tab), fg_to_bg(theme.tab)),
      hl = colors.combine(theme.active_tab, fg_to_bg(theme.tab)),
    },
    line.spacer(),
    {
      rsep,
      -- hl = colors.combine(colors.bg_to_fg(theme.tab), fg_to_bg(theme.tab)),
      hl = colors.combine(theme.active_tab, fg_to_bg(theme.tab)),
    },
    line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
      win_printing_count = win_printing_count + 1
      local is_last = win_count == win_printing_count
      return {
        line.sep(lsep, colors.bg_to_fg(theme.tab), theme.tab),
        win.is_current() and '' or '',
        win.buf_name(),
        ((is_last and " ") or line.sep(rsep, colors.bg_to_fg(theme.tab), theme.fill)),
        hl = theme.tab,
        margin = ' ',
      }
    end),
    hl = colors.combine(theme.tab, fg_to_bg(theme.tab)),
  }
end)
