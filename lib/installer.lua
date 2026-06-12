-- lib/installer.lua  --  install / update / remove orchestration
-- Everything installs into one place (config.installDir, default /apps): we run
-- the project's own install command with the shell's working directory pointed
-- there, so single files, `pastebin get`, and multi-file `wget run` installers
-- all land in the same folder.

local registry  = ckrequire("lib.registry")
local pinestore = ckrequire("lib.pinestore")
local config    = ckrequire("lib.config")

local M = {}

-- A package manager wants a saved, launchable file -- not a one-shot run.
-- "pastebin run CODE" only *executes* the paste (and can surface the program's
-- own crash, which looks like an install failure), so rewrite it to *save*
-- instead. "wget run URL" is left alone: those are real installer scripts that
-- must execute to fetch their files.
local function effectiveCommand(cmd, target)
  local code = cmd:match("^%s*pastebin%s+run%s+(%S+)")
  if code and target and target ~= "" then
    return "pastebin get " .. code .. " " .. target
  end
  return cmd
end

-- Is the installed `entry` older than the current PineStore `project`?
-- PineStore timestamps are epoch-ms; date_updated == 0 means "unknown", so we
-- only flag a real, newer update.
function M.isOutdated(entry, project)
  if not entry or not project then return false end
  local updated = project.date_updated or 0
  local since   = entry.installed_at or 0
  return updated > 0 and since > 0 and updated > since
end

-- The launchable name a user types to run the program (drops a .lua suffix).
function M.runName(target)
  if not target or target == "" then return nil end
  return (fs.getName(target):gsub("%.lua$", ""))
end

-- Run a shell command with the working dir temporarily set to `dir`, restoring
-- it (and surviving errors) afterwards. Returns shell.run's boolean result.
local function runIn(dir, command)
  if not fs.exists(dir) then fs.makeDir(dir) end
  local old = shell.dir()
  shell.setDir(dir)
  local pcok, ran = pcall(shell.run, command)
  shell.setDir(old)
  return pcok and ran
end

-- Install a PineStore project into the configured install directory.
function M.install(project)
  local raw = project.install_command
  if not raw or raw == "" then
    return false, "this project has no install command on PineStore"
  end
  local dir  = config.installDir()
  local cmd  = effectiveCommand(raw, project.target_file)
  local full = (project.target_file and project.target_file ~= "")
    and fs.combine(dir, project.target_file) or nil
  if full and fs.exists(full) then fs.delete(full) end   -- clean reinstall

  if not runIn(dir, cmd) then
    return false, "the install command failed (see output above)"
  end

  registry.add({
    id              = project.id,
    name            = project.name,
    target_file     = project.target_file,
    path            = full,
    install_dir     = dir,
    install_command = cmd,            -- store normalized command for updates
    installed_at    = os.epoch and os.epoch("utc") or 0,
  })
  pinestore.logDownload(project.id)
  return true, dir
end

-- Re-run the stored install command to pull the latest version.
function M.update(entry)
  if not entry.install_command or entry.install_command == "" then
    return false, "no stored install command for this package"
  end
  local dir = entry.install_dir or config.installDir()
  if entry.path and fs.exists(entry.path) then fs.delete(entry.path) end
  if not runIn(dir, entry.install_command) then
    return false, "the update command failed"
  end
  entry.installed_at = os.epoch and os.epoch("utc") or entry.installed_at
  registry.add(entry)
  return true
end

-- Delete the installed file (if we know it) and drop it from the manifest.
function M.remove(entry)
  local p = entry.path or entry.target_file
  local deletedFile = false
  if p and p ~= "" and fs.exists(p) then
    fs.delete(p)
    deletedFile = true
  end
  registry.remove(entry.id)
  return true, deletedFile
end

return M
