local queryBody = [[
  (atx_heading [
      (atx_h1_marker)
      (atx_h2_marker)
      (atx_h3_marker)
      (atx_h4_marker)
      (atx_h5_marker)
      (atx_h6_marker)
  ] @heading)
]]

-- catppuccin
local md_rainbow_map = {2, 6, 3, 5, 2, 6}
-- rose-pine
-- local md_rainbow_map = {1, 6, 4, 2, 5, 3}
local hl_group_fg_lookup = {}
local hl_group_bg_lookup = {}
for ind,target in ipairs(md_rainbow_map) do
    table.insert(hl_group_fg_lookup, 'RenderMarkdownH' .. target)
    table.insert(hl_group_bg_lookup, 'RenderMarkdownH' .. target .. 'Bg')
    vim.cmd ("highlight link markdownH" .. ind .. " rainbow" .. target)
    vim.cmd ("highlight link markdownH" .. ind .. "Delimiter rainbow" .. target)
    vim.cmd ("highlight link @markup.heading." .. ind .. ".markdown rainbow" .. target)
end

local Str = require('render-markdown.lib.str')
local Node = require('render-markdown.lib.node')
local query = vim.treesitter.query.parse('markdown', queryBody)
local function parse_markdown_extended(root, buf)
    local marks = {}
    for id, ts_node in query:iter_captures(root, buf) do
        local capture = query.captures[id]
        local start_row, _, _, end_col = ts_node:range()
        local node = Node.new(buf, ts_node)
        local level = Str.width(node.text)
        local hl_group_bg = hl_group_bg_lookup[level]
        local hl_group_fg = hl_group_fg_lookup[level]
        local line = vim.api.nvim_buf_get_lines(buf, start_row, start_row+1, false)
        local inTodo = false
        local seenMid = false
        local mid = " "
        local seenHash = false
        local seenPostHash = false
        local seenList = false
        local virt_text = ""
        local listDepth = 0
        local listIcons = { [1] = '●', [2] = '○', [3] = '', [0] = '' }
        local mids = { [' '] = '_', ['x'] = '', ['-'] = '󰾞', ['*'] = '✔' }
        local midFgs = {
          [' '] = 'RenderMarkdownUnchecked',
          ['*'] = 'RenderMarkdownSuccess',
          ['-'] = 'RenderMarkdownWarn',
          ['x'] = 'RenderMarkdownError',
        }
        local hasTodo = false
        local todoVirtText1 = nil
        local todoVirtText2 = nil
        local todoVirtText3 = nil
        local underline = '@text.underline'
        for c in line[1]:gmatch"." do
          if (c == "#" and not seenPostHash) then
            seenHash = true
            virt_text = virt_text .. " "
            goto continue
          elseif (c ~= "#" and seenHash) then
            seenPostHash = true
          elseif (not seenPostHash) then
            virt_text = virt_text .. " "
            goto continue
          end
          if (not inTodo and c == "{") then
            inTodo = true
          elseif (inTodo and not seenMid and (c == " " or c == "x" or c == "-" or c == "*")) then
            seenMid = true
            mid = c
          elseif (inTodo and seenMid and c == "}") then
            hasTodo = true
            todoVirtText1 = {"❰", {midFgs[mid], hl_group_bg}}
            todoVirtText2 = {mids[mid], {midFgs[mid], hl_group_bg, underline}}
            todoVirtText2 = {mids[mid], {midFgs[mid], hl_group_bg}}
            todoVirtText3 = {"❱", {midFgs[mid], hl_group_bg}}
            break
          elseif (inTodo) then
            break
          elseif (c == " ") then
            virt_text = virt_text .. " "
            listDepth = listDepth + 1
          elseif (not seenList and (c == "+" or c == "*" or c == "-")) then
            virt_text = virt_text .. listIcons[listDepth % 4]
            seenList = true
          else
            break
          end
          ::continue::
        end
        local fullVirtText = {{virt_text, {hl_group_fg, hl_group_bg}}}
        if hasTodo then
          fullVirtText = {
            {virt_text, {hl_group_fg, hl_group_bg}},
            todoVirtText1,
            todoVirtText2,
            todoVirtText3,
          }
        end
        if capture == 'heading' then
            table.insert(marks, {
                conceal = false,
                start_row = start_row,
                start_col = 0,
                opts = {
                    end_row = start_row + 1,
                    end_col = 0,
                    hl_group = hl_group_bg,
                    hl_eol = true,
                    virt_text = fullVirtText,
                    virt_text_pos = 'overlay',
                },
            })
        end
    end
    return marks
end

require('render-markdown').setup({
    debounce = 0,
    sign = { enabled = false },
    heading = { enabled = false },
    checkbox = { enabled = false },
    render_modes = { "n", "c", 'i' },
    -- file_types = { "markdown" },
    bullet = {
        enabled = true,
        icons = { '●', '○', '', '' },
        ordered_icons = {},
        left_pad = 0,
        right_pad = 0,
        highlight = 'RenderMarkdownBullet',
    },
    custom_handlers = {
        -- markdown = { parse = parse_markdown_extended, extends = true },
    },
})

local function strsplit (inputstr, sep)
    if sep == nil then
      sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
end
local function pretty_date(d)
    return os.date("%Y_%m_%d", d)
end
local function mk_date_str(offset_, from_time_)
    offset = ((offset_ ~= nil) and offset_) or 0
    from_time = ((from_time_ ~= nil) and from_time_) or os.time(os.date("!*t"))
    return pretty_date(from_time + (offset * 60 * 60 * 24) - (6 * 60 * 60))
end
local function mk_todo_filename(offset)
    if (offset == nil) then return mk_date_str() end
    local currfile = vim.api.nvim_buf_get_name(0)
    local steps = strsplit(currfile, "/")
    local fname_parts = strsplit(steps[#steps] or "", ".")
    local date_parts = strsplit(fname_parts[1] or "", "_")
    if (#date_parts ~= 3) then return mk_date_str(offset) end
    local from_time = os.time(
      { year=date_parts[1], month=date_parts[2], day=date_parts[3], hour=12 }
    )
    return mk_date_str(offset, from_time)
end
local function open_todo(offset)
    return function()
      vim.cmd("e ~/.todos/" .. mk_todo_filename(offset) .. ".md")
    end
end

vim.api.nvim_create_user_command('TodoOpenToday',function()
  pcall(open_todo())
end,{})

vim.api.nvim_create_user_command('TodoOpenDayBefore',function()
  pcall(open_todo(-1))
end,{})

vim.api.nvim_create_user_command('TodoOpenDayAfter',function()
  pcall(open_todo(1))
end,{})
