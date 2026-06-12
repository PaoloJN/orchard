-- screens/installed.lua  --  manage what's installed: update / remove / inspect
return function(ctx)
  local ui, store, reg, inst = ctx.ui, ctx.store, ctx.reg, ctx.inst
  local ESC = keys.escape or 1   -- this ROM doesn't map keys.escape; 1 = raw Esc
  local sel, scroll = 1, 0
  local lTop, lBottom = 3, 0      -- last drawn list region, for mouse mapping
  store.list()                   -- warm the cache for update detection (ok if offline)

  local function outdated(e) return inst.isOutdated(e, store.get(e.id)) end

  local function doUpdate(e)
    ctx.suspend()
    print("Updating " .. (e.name or e.id) .. " ...\n")
    local ok, uerr = inst.update(e)
    print("")
    if ok then ctx.log.ok("Updated") else ctx.log.error(uerr or "update failed") end
    print("\nPress any key to return.")
    os.pullEvent("key")
    ctx.resume()
  end

  while true do
    local list = reg.all()
    local updates = 0
    for _, e in ipairs(list) do if outdated(e) then updates = updates + 1 end end

    local w, h = term.getSize()
    local top, bottom = 3, h - 1
    lTop, lBottom = top, bottom
    local rows = bottom - top + 1
    if sel > #list then sel = #list end
    if sel < 1 then sel = (#list > 0) and 1 or 0 end
    scroll = ui.clampScroll(sel, scroll, rows, #list)

    ctx.win.setVisible(false)
    ui.clear(colors.black)
    ui.header(w, "Installed apps", #list .. " installed" ..
      (updates > 0 and ("   " .. updates .. " update" .. (updates > 1 and "s" or "")) or ""))
    if #list == 0 then
      ui.center(math.floor((top + bottom) / 2), "Nothing installed yet", colors.gray, colors.black, w)
      ui.center(math.floor((top + bottom) / 2) + 1, "Browse the store and press I to install",
        colors.gray, colors.black, w)
    else
      ui.drawList(list, sel, scroll, top, bottom, w, function(e, _, width)
        local right = outdated(e) and "* update *" or ui.truncate(e.target_file or "", 18)
        local name  = ui.truncate(e.name or ("#" .. tostring(e.id)), math.max(1, width - #right - 1))
        local pad   = math.max(1, width - #name - #right)
        return name .. string.rep(" ", pad) .. right
      end)
    end
    ui.footer(w, h, (#list > 0 and "U update   R remove   Enter details   " or "") .. "B/Bksp back")
    ctx.win.setVisible(true)

    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "key" then
      local k = p1
      if k == keys.down then if sel < #list then sel = sel + 1 end
      elseif k == keys.up then if sel > 1 then sel = sel - 1 end
      elseif k == keys.b or k == ESC or k == keys.tab or k == keys.backspace then
        return
      elseif #list > 0 and list[sel] then
        local e = list[sel]
        if k == keys.u then doUpdate(e)
        elseif k == keys.r then
          if ui.confirm(ctx.win, w, h, "Remove " .. ui.truncate(e.name or "?", 22) .. "?",
              { "Deletes " .. ui.truncate(e.target_file or "?", w - 12), "from this computer." }, true) then
            inst.remove(e)
          end
        elseif k == keys.enter then
          local p = store.get(e.id)
          if p then ctx.screens.details(ctx, p) end
        end
      end
    elseif ev == "mouse_scroll" then
      if p1 > 0 then if sel < #list then sel = sel + 1 end
      elseif sel > 1 then sel = sel - 1 end
    elseif ev == "mouse_click" then
      local idx = scroll + (p3 - lTop) + 1
      if p3 >= lTop and p3 <= lBottom and list[idx] then
        sel = idx
        local p = store.get(list[idx].id)
        if p then ctx.screens.details(ctx, p) end
      end
    elseif ev == "term_resize" then
      if ctx.onResize then ctx.onResize() end
    end
  end
end
