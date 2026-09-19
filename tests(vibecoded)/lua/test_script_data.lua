-- Structural integrity tests for scripts/script.son (SON format)
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()
local son = dofile("external/son/src/son.lua")
local json = dofile("scripts/libs/json.lua")

local tree, parseOk = son.parse_file("scripts/script.son")
assert(parseOk, "cannot read scripts/script.son")

-- convert an evaluated SON tree to a plain table (mirrors scripts/game.lua sonToTable)
local function toTable(obj)
  local t = {}
  for _, c in ipairs(obj.children or {}) do
    if c.type == son.CSON_STRING then
      t[c.key] = c.value
    elseif c.type == son.CSON_OBJECT then
      t[c.key] = toTable(c)
    end
  end
  if type(t.choices) == "string" then
    local list = {}
    for s in (t.choices .. ","):gmatch("([^,]*),") do
      list[#list + 1] = s:match("^%s*(.-)%s*$")
    end
    t.choices = list
  end
  return t
end

-- eval with every conditional branch taken so all node bodies are present
local script = assert(toTable(son.eval(tree, { chosen = function() return true end })))

local function nodeNames()
  local names = {}
  for k in pairs(script.nodes) do names[k] = true end
  return names
end

-- walk the raw (pre-eval) tree and collect every CSON_IF condition
local function collectIFs(obj, out)
  for _, c in ipairs(obj.children or {}) do
    if c.type == son.CSON_IF then
      out[#out + 1] = c.value
    end
    collectIFs(c, out)
  end
  return out
end

H.describe("script.son structure")

H.test("has start node", function()
  H.eq(type(script.start), "string")
  H.truthy(script.nodes[script.start], "start node must exist")
end)

H.test("has nodes table", function()
  H.eq(type(script.nodes), "table")
  H.truthy(next(script.nodes) ~= nil, "should have at least one node")
end)

H.test("every node is a table", function()
  for id, node in pairs(script.nodes) do
    H.eq(type(node), "table", "node " .. id)
  end
end)

H.test("every next references existing node", function()
  local names = nodeNames()
  for id, node in pairs(script.nodes) do
    if node.next ~= nil then
      H.truthy(names[node.next], "node " .. id .. " next -> " .. node.next)
    end
  end
end)

H.test("no infinite single-node loops", function()
  for startId, node in pairs(script.nodes) do
    if node.next then
      local visited = {}
      local id = startId
      while id and not visited[id] do
        visited[id] = true
        id = script.nodes[id] and script.nodes[id].next
      end
      H.truthy(visited[script.start] ~= nil or #script.nodes == 1 or visited[id] == nil,
        "node " .. startId .. " leads back to start")
    end
  end
end)

H.test("speakers are strings", function()
  for id, node in pairs(script.nodes) do
    if node.speaker ~= nil then
      H.eq(type(node.speaker), "string", "node " .. id)
    end
  end
end)

H.test("choice nodes have non-empty choices", function()
  for id, node in pairs(script.nodes) do
    if node.qu then
      H.eq(type(node.choices), "table", "qu node " .. id .. " needs choices")
      H.truthy(#node.choices > 0, "qu node " .. id .. " needs non-empty choices")
    end
  end
end)

H.test("conditional branches are well formed", function()
  local conds = collectIFs(tree, {})
  H.truthy(#conds > 0, "script should contain at least one conditional branch")
  for _, cond in ipairs(conds) do
    local inner = cond:match("^if%s*%((.*)%)%s*$")
    H.truthy(inner ~= nil, "malformed if() in: " .. cond)
    local ok = inner:match("^not%s+chosen%s*%(%s*\"[^\"]+\"%s*,%s*\"[^\"]+\"%s*%)$")
      or inner:match("^chosen%s*%(%s*\"[^\"]+\"%s*,%s*\"[^\"]+\"%s*%)$")
    H.truthy(ok ~= nil, "unsupported conditional expression: " .. cond)
  end
end)

H.test("conditional branches reference a real choice node", function()
  local names = nodeNames()
  for _, cond in ipairs(collectIFs(tree, {})) do
    local refNode = cond:match('chosen%s*%(%s*"([^"]+)"')
    if refNode then
      H.truthy(names[refNode], "conditional " .. cond .. " refs missing node " .. refNode)
    end
  end
end)

H.test("background/character assets referenced", function()
  for id, node in pairs(script.nodes) do
    if node.bg then H.eq(type(node.bg), "string", "bg " .. id) end
    if node.character then H.eq(type(node.character), "string", "char " .. id) end
    if node.character_place then
      H.truthy(node.character_place == "left" or node.character_place == "right" or node.character_place == "mid",
        "bad character_place in " .. id)
    end
  end
end)

H.test("asset files exist", function()
  local seen = {}
  for id, node in pairs(script.nodes) do
    for _, field in ipairs({ "bg", "character", "sound" }) do
      local path = node[field]
      if path and path ~= "" and not seen[path] then
        seen[path] = true
        local fh = io.open(path, "r")
        H.truthy(fh ~= nil, "asset missing: " .. path .. " (node " .. id .. ")")
        if fh then fh:close() end
      end
    end
  end
end)

H.test("settings.json is valid", function()
  local sf = io.open("scripts/settings.json", "r")
  if sf then
    local sc = sf:read("*a")
    sf:close()
    local ok, data = pcall(json.decode, sc)
    H.truthy(ok)
    H.eq(type(data), "table")
  end
end)

H.finish()