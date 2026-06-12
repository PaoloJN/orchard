-- lib/registry.lua  --  local manifest of installed packages
-- Stored as a serialized Lua table next to the program (set via init()).

local M = {}
local PATH = "orchard/installed.db"

function M.init(path) PATH = path end

local function read()
  if not fs.exists(PATH) then return {} end
  local f = fs.open(PATH, "r"); local s = f.readAll(); f.close()
  local t = textutils.unserialize(s)
  return type(t) == "table" and t or {}
end

local function persist(t)
  local f = fs.open(PATH, "w"); f.write(textutils.serialize(t)); f.close()
end

function M.all() return read() end

function M.get(id)
  for _, e in ipairs(read()) do if e.id == id then return e end end
  return nil
end

function M.isInstalled(id) return M.get(id) ~= nil end

-- Insert or replace by id.
function M.add(entry)
  local t = read()
  for i, e in ipairs(t) do
    if e.id == entry.id then t[i] = entry; persist(t); return end
  end
  t[#t + 1] = entry
  persist(t)
end

function M.remove(id)
  local t = read()
  for i, e in ipairs(t) do
    if e.id == id then table.remove(t, i); persist(t); return true end
  end
  return false
end

return M
