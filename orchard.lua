-- orchard.lua  --  Orchard: the app store for CraftOS (a PineStore client)
--
--   orchard                       open the interactive store
--   orchard search <text>         search the catalog
--   orchard install <id|name>     install into the apps folder
--   orchard info    <id|name>     show a project's details
--   orchard list                  list installed packages
--   orchard update  <id|name|all>
--   orchard remove  <id|name>
--   orchard config  [installdir <path>]
--   orchard help

-- ----- tiny module loader (resolves <home>/lib/*, <home>/screens/*) ---------
local ROOT = fs.getDir(shell.getRunningProgram())
local HOME = "/" .. ROOT:gsub("^/+", "")
local _cache = {}
function _G.ckrequire(name)
  if _cache[name] then return _cache[name] end
  local path = fs.combine(ROOT, (name:gsub("%.", "/")) .. ".lua")
  if not fs.exists(path) then error("Orchard: missing module " .. name .. " (" .. path .. ")", 0) end
  local chunk, e = loadfile(path)
  if not chunk then error("Orchard: load error in " .. name .. ": " .. tostring(e), 0) end
  local mod = chunk()
  _cache[name] = mod
  return mod
end

-- `shell` is injected into the program environment, not _G, so modules loaded
-- via loadfile can't see it by default. Expose it for lib/installer.
_G.shell = shell

local log       = ckrequire("lib.log")
local store     = ckrequire("lib.pinestore")
local registry  = ckrequire("lib.registry")
local installer = ckrequire("lib.installer")
local config    = ckrequire("lib.config")
local ui        = ckrequire("lib.ui")

registry.init(fs.combine(ROOT, "installed.db"))
config.init(fs.combine(ROOT, "config.db"))

-- Make Orchard and the install dir reachable as single commands *this session*
-- too (startup.lua makes it permanent across reboots).
local function ensureOnPath(dir)
  local p = shell.path()
  if not ((":" .. p .. ":"):find(":" .. dir .. ":", 1, true)) then
    shell.setPath(p .. ":" .. dir)
  end
end
ensureOnPath(HOME)
ensureOnPath(config.installDir())
if not fs.exists(config.installDir()) then fs.makeDir(config.installDir()) end

local ctx = {
  ui = ui, store = store, reg = registry, inst = installer, log = log, config = config,
  screens = {
    browse    = ckrequire("screens.browse"),
    details   = ckrequire("screens.details"),
    installed = ckrequire("screens.installed"),
  },
}

-- ----- interactive store ---------------------------------------------------
local function runTUI()
  local parent = term.current()
  local w, h = term.getSize()
  if w < 26 or h < 6 then
    log.error("Screen too small for the store (" .. w .. "x" .. h .. ").")
    log.info("Use a bigger window, or the CLI: orchard search <text>")
    return
  end
  local win = window.create(parent, 1, 1, w, h, true)
  ctx.parent, ctx.win = parent, win

  ctx.suspend = function()
    term.redirect(parent)
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
    term.setCursorBlink(true); term.clear(); term.setCursorPos(1, 1)
  end
  ctx.resume = function()
    term.redirect(win); term.setCursorBlink(false)
  end
  ctx.onResize = function()
    local nw, nh = parent.getSize()
    win.reposition(1, 1, nw, nh)
  end

  term.redirect(win)
  term.setCursorBlink(false)
  local ok, err = pcall(ctx.screens.browse, ctx)
  term.redirect(parent)
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
  term.setCursorBlink(true); term.clear(); term.setCursorPos(1, 1)
  if not ok then log.error(err) else print("Thanks for using Orchard!") end
end

-- ----- CLI -----------------------------------------------------------------
local function resolve(spec)
  if not spec then return nil end
  local id = tonumber(spec)
  if id then return store.get(id) end
  local res = store.search(spec) or {}
  return res[1], res
end

local function printProject(p)
  write(("#%-4d "):format(p.id))
  term.setTextColor(colors.white); write(ui.truncate(p.name or "?", 26))
  term.setTextColor(colors.gray)
  print(("  %s%d  %s%d"):format(ui.G.dl, p.downloads or 0, ui.G.heart, p.likes or 0))
  term.setTextColor(colors.white)
end

local function doInstall(p)
  log.info("Running: " .. (p.install_command or "(none)"))
  local ok, dirOrErr = installer.install(p)
  if ok then
    log.ok("Installed " .. p.name .. " -> " .. (dirOrErr or "?") .. "/" .. (p.target_file or "?"))
    local run = installer.runName(p.target_file)
    if run then log.info("Run it with:  " .. run) end
  else
    log.error(dirOrErr or "install failed")
  end
end

local commands = {}

function commands.search(q)
  if not q then return log.warn("usage: orchard search <text>") end
  local res = store.search(q) or {}
  if #res == 0 then return log.info("No matches for '" .. q .. "'") end
  log.info(#res .. " result(s):")
  for i = 1, math.min(#res, 25) do printProject(res[i]) end
  if #res > 25 then log.info("...and " .. (#res - 25) .. " more") end
end

function commands.info(spec)
  local p = resolve(spec)
  if not p then return log.error("not found: " .. tostring(spec)) end
  printProject(p)
  print("by " .. (p.owner_name or "?"))
  print((p.description or p.description_short or ""):gsub("\n", " "))
  if p.repository and p.repository ~= "" then print("repo: " .. p.repository) end
  print("install: " .. (p.install_command or "(none)"))
  if registry.isInstalled(p.id) then log.ok("installed") end
end

function commands.install(spec)
  local p, many = resolve(spec)
  if not p then return log.error("not found: " .. tostring(spec)) end
  if many and #many > 1 and not tonumber(spec) then
    log.warn("Multiple matches; installing the top one: " .. p.name)
  end
  doInstall(p)
end

function commands.list()
  local all = registry.all()
  if #all == 0 then return log.info("Nothing installed. Try: orchard") end
  store.list()  -- warm the cache so we can flag updates (ignored if offline)
  log.info(#all .. " installed:")
  for _, e in ipairs(all) do
    local outdated = installer.isOutdated(e, store.get(e.id))
    write(("#%-4d %-24s "):format(e.id, ui.truncate(e.name or "?", 24)))
    if outdated then term.setTextColor(colors.yellow); print("update available")
    else term.setTextColor(colors.gray); print(e.path or e.target_file or "") end
    term.setTextColor(colors.white)
  end
end

function commands.update(spec)
  if spec == "all" or not spec then
    local all = registry.all()
    if #all == 0 then return log.info("Nothing installed.") end
    store.list()
    local did = 0
    for _, e in ipairs(all) do
      if installer.isOutdated(e, store.get(e.id)) then
        did = did + 1
        log.info("Updating " .. (e.name or e.id) .. " ...")
        local ok, err = installer.update(e)
        if ok then log.ok("updated " .. (e.name or e.id)) else log.error(err) end
      end
    end
    if did == 0 then log.ok("Everything is up to date.") end
    return
  end
  local p = resolve(spec)
  local e = p and registry.get(p.id)
  if not e then return log.error("not installed: " .. tostring(spec)) end
  log.info("Updating " .. (e.name or e.id) .. " ...")
  local ok, err = installer.update(e)
  if ok then log.ok("updated " .. (e.name or e.id)) else log.error(err) end
end

function commands.remove(spec)
  local p = resolve(spec)
  local e = p and registry.get(p.id) or nil
  if not e and tonumber(spec) then e = registry.get(tonumber(spec)) end
  if not e then return log.error("not installed: " .. tostring(spec)) end
  local ok, deleted = installer.remove(e)
  if ok then log.ok("removed " .. (e.name or e.id) .. (deleted and "" or " (file was already gone)")) end
end

function commands.config(rest)
  if not rest then
    log.info("install dir: " .. config.installDir())
    return
  end
  local key, val = rest:match("^(%S+)%s+(.+)$")
  if key == "installdir" and val then
    config.set("installDir", val)
    log.ok("install dir set to " .. config.installDir())
    log.info("Reboot (or edit /startup.lua) to put it on your shell path.")
  else
    log.warn("usage: orchard config installdir <path>")
  end
end

function commands.help()
  print("Orchard - the app store for CraftOS\n")
  print("  orchard                       open the store (interactive)")
  print("  orchard search <text>")
  print("  orchard info    <id|name>")
  print("  orchard install <id|name>")
  print("  orchard list")
  print("  orchard update  <id|name|all>")
  print("  orchard remove  <id|name>")
  print("  orchard config  installdir <path>")
  print("\nApps install to " .. config.installDir() .. " - catalog: https://pinestore.cc")
end

-- ----- dispatch ------------------------------------------------------------
local args = { ... }
if #args == 0 then
  runTUI()
else
  local cmd = table.remove(args, 1)
  local fn = commands[cmd]
  local rest = table.concat(args, " ")
  if rest == "" then rest = nil end
  if fn then fn(rest)
  else log.error("unknown command '" .. cmd .. "'"); commands.help() end
end
