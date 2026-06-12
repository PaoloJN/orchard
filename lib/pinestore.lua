-- lib/pinestore.lua  --  client for the PineStore API (https://pinestore.cc)
-- Docs: https://pinestore.cc/documentation
--
-- The whole catalog is small (~150 projects) and every record already carries
-- install_command / target_file, so we fetch it once, cache it, and filter
-- locally. That keeps search instant and the server happy.

local API  = "https://pinestore.cc/api"

local json = textutils.unserialiseJSON or textutils.unserializeJSON

local M = {}
local cache

local function getJSON(url)
  if not http then return nil, "HTTP is disabled -- enable it in CraftOS-PC settings" end
  if not json then return nil, "this CC build has no JSON support" end
  -- table form gives us a timeout so a dead network can't hang the UI
  local res, err, errRes = http.get({ url = url, timeout = 10 })
  if not res then
    if errRes and errRes.close then errRes.close() end
    return nil, err or "could not reach pinestore.cc"
  end
  local body = res.readAll()
  res.close()
  local okParse, data = pcall(json, body)
  if not okParse or type(data) ~= "table" then return nil, "could not parse server response" end
  if data.success == false then return nil, data.error or "API error" end
  return data
end

-- Fetch every visible project, sorted by downloads (desc). Cached after first call.
function M.list(force)
  if cache and not force then return cache end
  local data, err = getJSON(API .. "/projects")
  if not data then return nil, err end
  local ps = data.projects or {}
  table.sort(ps, function(a, b) return (a.downloads or 0) > (b.downloads or 0) end)
  cache = ps
  return ps
end

-- Look up a single project by id (cache first, then network).
function M.get(id)
  if cache then
    for _, p in ipairs(cache) do if p.id == id then return p end end
  end
  local data, err = getJSON(API .. "/project/" .. tostring(id))
  if not data then return nil, err end
  return data.project
end

-- Case-insensitive substring search over name / description / author / keywords.
function M.search(query)
  local ps, err = M.list()
  if not ps then return nil, err end
  query = tostring(query or ""):lower()
  if query == "" then return ps end
  local out = {}
  for _, p in ipairs(ps) do
    local hay = ((p.name or "") .. " " .. (p.description or "") .. " " ..
                 (p.owner_name or "") .. " " ..
                 table.concat(p.keywords or {}, " ")):lower()
    if hay:find(query, 1, true) then out[#out + 1] = p end
  end
  return out
end

-- Best-effort: tell PineStore an install happened so download counts stay honest.
function M.logDownload(id)
  if not http then return end
  pcall(function()
    local body = textutils.serialiseJSON({ id = id, projectId = id })
    local r = http.post(API .. "/log/download", body, { ["Content-Type"] = "application/json" })
    if r then r.close() end
  end)
end

return M
