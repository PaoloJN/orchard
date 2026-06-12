-- lib/log.lua  --  small colored status output (used by the CLI + install flow)
local log = {}

local function out(tag, color, msg)
  local prev = term.getTextColor and term.getTextColor() or colors.white
  term.setTextColor(color); write("[" .. tag .. "] ")
  term.setTextColor(colors.white); print(tostring(msg))
  term.setTextColor(prev)
end

function log.info(m)  out("info", colors.lightBlue, m) end
function log.ok(m)    out(" ok ", colors.lime, m)      end
function log.warn(m)  out("warn", colors.yellow, m)    end
function log.error(m) out("err ", colors.red, m)       end

return log
