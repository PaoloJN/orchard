-- lib/config.lua  --  persisted settings (currently just the install directory)
local M = {}
local PATH
local data = { installDir = "/apps" }

function M.init(path)
  PATH = path
  if fs.exists(PATH) then
    local f = fs.open(PATH, "r"); local s = f.readAll(); f.close()
    local t = textutils.unserialize(s)
    if type(t) == "table" then
      for k, v in pairs(t) do data[k] = v end
    end
  end
end

function M.save()
  if not PATH then return end
  local f = fs.open(PATH, "w"); f.write(textutils.serialize(data)); f.close()
end

function M.get(k) return data[k] end

function M.set(k, v) data[k] = v; M.save() end

-- Normalized absolute install directory (always leading slash, no trailing).
function M.installDir()
  local d = data.installDir or "/apps"
  d = "/" .. d:gsub("^/+", ""):gsub("/+$", "")
  return d
end

return M
