local wk = require("which-key")
local wk_leader = require("dz.wk.mapping.leader")

wk.setup({ win = { no_overlap = false }, triggers = {}, sort = { "manual" } })

local function flattenUntilWkLine(t, res)
  local res = res or {}
  local is_opts = t[1] == nil and next(t) ~= nil
  if (type(t[1]) ~= 'string') and (not is_opts) then
    for k, v in pairs(t) do
      flattenUntilWkLine(v, res)
    end
  else
    if type(t.using) == 'table' then
      local prefix = t[1]
      local tmp = flattenUntilWkLine(t.using)
      for k, v in ipairs(tmp) do
        v[1] = prefix .. (v[1] or "")
        res[#res + 1] = v
      end
      return res
    end
    if type(t.cmd) == 'string' then
      local cmd = t.cmd
      t[2] = function() vim.cmd(cmd) end
      t.cmd = nil
    end
    local cloned = {}
    for k, v in pairs(t) do
      cloned[k] = v
    end
    res[#res + 1] = cloned
  end
  return res
end
  
local function wk_wrap(t) return flattenUntilWkLine(t) end

wk.add(wk_wrap({{"<leader>", using = wk_leader }}))

vim.keymap.set('n', '<space>', ':WhichKey <leader><cr>')
