-- install.lua  --  Orchard installer.
-- Host this file, then anyone installs Orchard with one line:
--     wget run https://raw.githubusercontent.com/<USER>/orchard/main/orchard/install.lua
--
-- BASE must point at the RAW root of your repo (the folder that contains
-- startup.lua and the orchard/ directory).

local BASE = "https://raw.githubusercontent.com/paolojn/orchard/main"

local FILES = {
  "startup.lua",
  "orchard/orchard.lua",
  "orchard/lib/config.lua",
  "orchard/lib/installer.lua",
  "orchard/lib/log.lua",
  "orchard/lib/pinestore.lua",
  "orchard/lib/registry.lua",
  "orchard/lib/ui.lua",
  "orchard/screens/browse.lua",
  "orchard/screens/details.lua",
  "orchard/screens/installed.lua",
}

if not http then error("HTTP is disabled -- enable it to install Orchard.", 0) end

local function fetch(path)
  local res, err = http.get(BASE .. "/" .. path)
  if not res then return false, err or "request failed" end
  local data = res.readAll(); res.close()
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f = fs.open(path, "w"); f.write(data); f.close()
  return true
end

term.setTextColor(colors.lime); print("Installing Orchard..."); term.setTextColor(colors.white)
for _, path in ipairs(FILES) do
  write("  " .. path .. " ... ")
  local ok, err = fetch(path)
  if ok then
    term.setTextColor(colors.lime); print("ok"); term.setTextColor(colors.white)
  else
    term.setTextColor(colors.red); print(err); term.setTextColor(colors.white)
    error("install failed", 0)
  end
end

if not fs.exists("/apps") then fs.makeDir("/apps") end

-- make `orchard` (and installed apps) runnable this session too
local p = shell.path()
for _, d in ipairs({ "/orchard", "/apps" }) do
  if not ((":" .. p .. ":"):find(":" .. d .. ":", 1, true)) then p = p .. ":" .. d end
end
shell.setPath(p)

term.setTextColor(colors.lime)
print("\nDone! Type  orchard  to open the store.")
print("It also auto-loads on boot via /startup.lua.")
term.setTextColor(colors.white)
