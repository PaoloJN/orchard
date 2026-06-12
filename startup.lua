-- Orchard registration (auto-generated). Safe to delete or move into your own
-- startup. Puts Orchard and the installed-apps folder on the shell path so you
-- can run `orchard` -- and any installed program -- by name from any directory.
local dirs = { "/orchard", "/apps" }
if fs.exists("/apps") == false then fs.makeDir("/apps") end
local p = shell.path()
for _, d in ipairs(dirs) do
  if not ((":" .. p .. ":"):find(":" .. d .. ":", 1, true)) then
    p = p .. ":" .. d
  end
end
shell.setPath(p)
