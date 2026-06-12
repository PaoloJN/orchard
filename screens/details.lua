-- screens/details.lua  --  a single project's page: read, then install/remove
return function(ctx, p)
  local ui, reg, inst = ctx.ui, ctx.reg, ctx.inst
  local G = ui.G
  local ESC = keys.escape or 1   -- this ROM doesn't map keys.escape; 1 = raw Esc
  local scroll = 0

  -- Build the scrollable body as {text,color} rows for the given width.
  local function body(w)
    local L = {}
    local function add(s, c) L[#L + 1] = { text = s or "", color = c or colors.white } end
    add(p.name, colors.lime)
    add("by " .. (p.owner_name or "unknown"), colors.lightGray)
    add("")
    add(G.dl .. " " .. (p.downloads or 0) .. " installs     " ..
        G.heart .. " " .. (p.likes or 0) .. " likes", colors.cyan)
    if reg.isInstalled(p.id) then
      add(G.dot .. " installed", colors.lime)
      if inst.isOutdated(reg.get(p.id), p) then add("* update available -- press I *", colors.yellow) end
    end
    add("")
    for _, dl in ipairs(ui.wrap(p.description or p.description_short or "(no description)", w - 2)) do
      add(dl, colors.white)
    end
    add("")
    if p.repository and p.repository ~= "" then add("repo:    " .. p.repository, colors.gray) end
    add("install: " .. (p.install_command or "(none provided)"), colors.gray)
    return L
  end

  while true do
    local w, h = term.getSize()
    local top, bottom = 3, h - 1
    local rows = bottom - top + 1
    local L = body(w)
    local maxScroll = math.max(0, #L - rows)
    if scroll > maxScroll then scroll = maxScroll end
    if scroll < 0 then scroll = 0 end
    local installed = reg.isInstalled(p.id)

    ctx.win.setVisible(false)
    ui.clear(colors.black)
    ui.header(w, G.left .. " back", "Orchard")
    for i = 1, rows do
      local item = L[i + scroll]
      ui.fillLine(top + i - 1, colors.black, w)
      if item then ui.text(2, top + i - 1, ui.truncate(item.text, w - 2), item.color, colors.black) end
    end
    ui.footer(w, h, (installed and "I reinstall   R remove" or "I install") ..
      "   " .. G.up .. G.down .. " scroll   B/Bksp back")
    ctx.win.setVisible(true)

    local ev, p1 = os.pullEvent()
    if ev == "mouse_scroll" then
      scroll = scroll + (p1 > 0 and 1 or -1)
    elseif ev == "term_resize" then
      if ctx.onResize then ctx.onResize() end
    elseif ev == "key" then
      local k = p1
      if k == keys.down then scroll = scroll + 1
      elseif k == keys.up then scroll = scroll - 1
      elseif k == keys.pageDown then scroll = scroll + rows
      elseif k == keys.pageUp then scroll = scroll - rows
      elseif k == keys.i then
        if ui.confirm(ctx.win, w, h, "Install " .. ui.truncate(p.name, 22) .. "?",
            { "Runs this program's install", "command:", "", ui.truncate(p.install_command or "(none)", w - 8) }) then
          ctx.suspend()
          print("Installing " .. p.name .. " ...\n")
          local ok, ierr = inst.install(p)
          print("")
          if ok then
            ctx.log.ok("Installed -> " .. (ierr or "?") .. "/" .. (p.target_file or "?"))
            local run = inst.runName(p.target_file)
            if run then ctx.log.info("Run it any time with:  " .. run) end
          else ctx.log.error(ierr or "install failed") end
          print("\nPress any key to return.")
          os.pullEvent("key")
          ctx.resume()
        end
      elseif k == keys.r and installed then
        if ui.confirm(ctx.win, w, h, "Remove " .. ui.truncate(p.name, 22) .. "?",
            { "Deletes " .. ui.truncate(p.target_file or "?", w - 12), "from this computer." }, true) then
          inst.remove(reg.get(p.id) or { id = p.id, target_file = p.target_file })
        end
      elseif k == keys.b or k == ESC or k == keys.backspace then
        return
      end
    end
  end
end
