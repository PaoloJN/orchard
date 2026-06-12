-- screens/browse.lua  --  the catalog browser with incremental search
return function(ctx)
  local ui, store, reg = ctx.ui, ctx.store, ctx.reg
  local G = ui.G
  local ESC = keys.escape or 1   -- this ROM doesn't map keys.escape; 1 = raw Esc

  local all, err = store.list()
  if not all then
    ui.errorScreen(ctx, "Couldn't reach PineStore",
      { err or "unknown error", "", "Check that HTTP is enabled in CraftOS-PC." })
    return
  end

  local query = ""
  local items = all
  local sel, scroll = 1, 0
  local lTop, lBottom = 3, 0   -- last drawn list region, for mouse mapping

  local function refilter()
    items  = store.search(query) or {}
    sel    = (#items > 0) and 1 or 0
    scroll = 0
  end

  local function draw()
    local w, h = term.getSize()
    local top, bottom = 3, h - 1
    lTop, lBottom = top, bottom
    scroll = ui.clampScroll(sel, scroll, bottom - top + 1, #items)

    ctx.win.setVisible(false)
    ui.clear(colors.black)
    ui.header(w, "Orchard", "the app store for CraftOS")

    ui.fillLine(2, colors.black, w)
    ui.text(2, 2, "Search: ", colors.lightGray, colors.black)
    ui.text(10, 2, query == "" and "(type to filter)" or query,
      query == "" and colors.gray or colors.white, colors.black)

    if #items == 0 then
      ui.center(math.floor((top + bottom) / 2), "No matches", colors.gray, colors.black, w)
    else
      ui.drawList(items, sel, scroll, top, bottom, w, function(p, _, width)
        return ui.projectRow(p, width, reg.isInstalled(p.id))
      end)
    end

    ui.footer(w, h, G.up .. G.down .. " move   Enter open   Tab installed   Bksp " ..
      (query ~= "" and "delete" or "quit") .. "   [" .. #items .. " apps]")
    ctx.win.setVisible(true)
  end

  while true do
    draw()
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "key" then
      if p1 == keys.down then if sel < #items then sel = sel + 1 end
      elseif p1 == keys.up then if sel > 1 then sel = sel - 1 end
      elseif p1 == keys.pageDown then sel = math.min(#items, sel + 10)
      elseif p1 == keys.pageUp then sel = math.max(1, sel - 10)
      elseif p1 == keys.enter then
        if items[sel] then ctx.screens.details(ctx, items[sel]) end
      elseif p1 == keys.tab then
        ctx.screens.installed(ctx)
      elseif p1 == keys.backspace then
        if #query > 0 then query = query:sub(1, -2); refilter() else return end
      elseif p1 == ESC then
        if query ~= "" then query = ""; refilter() else return end
      end
    elseif ev == "char" then
      query = query .. p1
      refilter()
    elseif ev == "mouse_scroll" then
      if p1 > 0 then if sel < #items then sel = sel + 1 end
      elseif sel > 1 then sel = sel - 1 end
    elseif ev == "mouse_click" then
      local idx = scroll + (p3 - lTop) + 1
      if p3 >= lTop and p3 <= lBottom and items[idx] then
        sel = idx
        ctx.screens.details(ctx, items[idx])
      end
    elseif ev == "term_resize" then
      if ctx.onResize then ctx.onResize() end
    end
  end
end
