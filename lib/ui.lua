-- lib/ui.lua  --  terminal UI toolkit for Orchard's screens
-- Pure drawing helpers + a couple of reusable widgets (scrolling list, confirm
-- modal). All drawing targets the currently-redirected term; screens wrap their
-- frames in win.setVisible(false/true) for flicker-free updates.

local M = {}

-- CP437 glyphs that CraftOS's font renders nicely.
M.G = {
  up    = string.char(24), -- ^
  down  = string.char(25), -- v
  left  = string.char(27), -- <
  dl    = string.char(31), -- down triangle  (downloads)
  heart = string.char(3),  -- heart          (likes)
  dot   = string.char(7),  -- bullet         (installed marker)
}

function M.clear(bg)
  term.setBackgroundColor(bg or colors.black)
  term.clear()
end

function M.text(x, y, s, fg, bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(x, y)
  term.write(s)
end

function M.fillLine(y, bg, w)
  term.setBackgroundColor(bg)
  term.setCursorPos(1, y)
  term.write(string.rep(" ", w))
end

function M.center(y, s, fg, bg, w)
  M.text(math.max(1, math.floor((w - #s) / 2) + 1), math.floor(y), s, fg, bg)
end

function M.truncate(s, n)
  s = tostring(s == nil and "" or s)
  if #s <= n then return s end
  if n <= 3 then return s:sub(1, n) end
  return s:sub(1, n - 3) .. "..."
end

-- Word-wrap text (respecting existing newlines) into an array of lines.
function M.wrap(text, width)
  local out = {}
  text = tostring(text or ""):gsub("\r", "")
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line == "" then
      out[#out + 1] = ""
    else
      local cur = ""
      for word in line:gmatch("%S+") do
        if cur == "" then cur = word
        elseif #cur + 1 + #word <= width then cur = cur .. " " .. word
        else out[#out + 1] = cur; cur = word end
        while #cur > width do
          out[#out + 1] = cur:sub(1, width)
          cur = cur:sub(width + 1)
        end
      end
      out[#out + 1] = cur
    end
  end
  return out
end

function M.header(w, title, right)
  M.fillLine(1, colors.gray, w)
  M.text(2, 1, M.truncate(title, w - 2), colors.lime, colors.gray)
  if right and right ~= "" then
    M.text(math.max(2, w - #right), 1, M.truncate(right, w - 4), colors.lightGray, colors.gray)
  end
end

function M.footer(w, h, hints)
  M.fillLine(h, colors.gray, w)
  M.text(2, h, M.truncate(hints, w - 3), colors.lightGray, colors.gray)
end

-- Keep `sel` visible inside a window of `rows` rows; returns adjusted scroll.
function M.clampScroll(sel, scroll, rows, total)
  if sel < 1 then return 0 end
  if sel < scroll + 1 then scroll = sel - 1 end
  if sel > scroll + rows then scroll = sel - rows end
  if scroll < 0 then scroll = 0 end
  local maxScroll = math.max(0, total - rows)
  if scroll > maxScroll then scroll = maxScroll end
  return scroll
end

-- Draw a scrollable, selectable list between rows `top`..`bottom`.
-- renderRow(item, isSel, innerWidth) -> string.
function M.drawList(items, sel, scroll, top, bottom, w, renderRow)
  local rows   = bottom - top + 1
  local total  = #items
  local hasBar = total > rows
  local innerW = w - 2 - (hasBar and 1 or 0)
  for i = 1, rows do
    local idx = i + scroll
    local y   = top + i - 1
    local isSel = (idx == sel)
    local bg  = isSel and colors.blue or colors.black
    M.fillLine(y, bg, w)
    local item = items[idx]
    if item then
      M.text(2, y, renderRow(item, isSel, innerW), isSel and colors.white or colors.lightGray, bg)
    end
    if hasBar then
      local thumbTop = top + math.floor(scroll / total * rows)
      local thumbBot = top + math.ceil((scroll + rows) / total * rows) - 1
      local isThumb  = (y >= thumbTop and y <= thumbBot)
      M.text(w, y, " ", nil, isThumb and colors.lightGray or colors.gray)
    end
  end
end

-- One catalog row: "[*] Name ........... v1100  <3 12"
function M.projectRow(p, width, installed)
  local right  = M.G.dl .. tostring(p.downloads or 0) .. "  " .. M.G.heart .. tostring(p.likes or 0)
  local marker = installed and (M.G.dot .. " ") or "  "
  local name   = M.truncate(p.name or "?", math.max(1, width - #right - #marker - 1))
  local left   = marker .. name
  local pad    = math.max(1, width - #left - #right)
  return left .. string.rep(" ", pad) .. right
end

-- Centered yes/no modal drawn over the current frame. Returns boolean.
function M.confirm(win, w, h, title, lines, danger)
  local bw = math.min(w - 4, 46)
  local bh = #lines + 4
  local bx = math.floor((w - bw) / 2) + 1
  local by = math.floor((h - bh) / 2) + 1
  win.setVisible(false)
  for y = by, by + bh - 1 do M.text(bx, y, string.rep(" ", bw), nil, colors.gray) end
  M.text(bx + 1, by + 1, M.truncate(title, bw - 2), danger and colors.red or colors.yellow, colors.gray)
  for i, l in ipairs(lines) do
    M.text(bx + 1, by + 1 + i, M.truncate(l, bw - 2), colors.white, colors.gray)
  end
  M.text(bx + 1, by + bh - 1, "[Y] yes     [N] no", colors.lightGray, colors.gray)
  win.setVisible(true)
  while true do
    local _, k = os.pullEvent("key")
    if k == keys.y then return true
    elseif k == keys.n or k == (keys.escape or 1) then return false end
  end
end

-- Full-screen error/message, waits for a keypress.
function M.errorScreen(ctx, title, lines)
  local w, h = term.getSize()
  ctx.win.setVisible(false)
  M.clear(colors.black)
  M.header(w, "Orchard", "")
  local startY = math.floor(h / 2 - #lines / 2)
  M.center(startY, title, colors.red, colors.black, w)
  for i, l in ipairs(lines) do
    M.center(startY + i, l, colors.lightGray, colors.black, w)
  end
  M.center(h - 1, "press any key", colors.gray, colors.black, w)
  ctx.win.setVisible(true)
  os.pullEvent("key")
end

return M
