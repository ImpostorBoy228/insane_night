-- Structural integrity tests for scripts/script.json
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()
local json = dofile("scripts/libs/json.lua")

local f = assert(io.open("scripts/script.json", "r"))
local content = f:read("*a")
f:close()
local script = assert(json.decode(content), "script.json must be valid JSON")

local function nodeNames()
  local names = {}
  for k in pairs(script.nodes) do names[k] = true end
  return names
end

H.describe("script.json structure")

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

H.test("if() conditional keys are well formed", function()
  for id, node in pairs(script.nodes) do
    for key, sub in pairs(node) do
      if key:match("^if%(") then
        local ok = pcall(function()
          H.eq(type(sub), "table", "if branch must be a table in " .. id)
          H.truthy(sub.text ~= nil or sub.next ~= nil, "if branch needs text or next in " .. id)
        end)
        H.truthy(ok, "malformed if() in node " .. id .. ": " .. key)
      end
    end
  end
end)

H.test("conditional branch references a real choice node", function()
  for id, node in pairs(script.nodes) do
    for key, _ in pairs(node) do
      if key:match("^if%(") then
        local nodePart = key:match("^if%(%s*([^,]+)")
        if nodePart then
          local trimmed = nodePart:match("^%s*(.-)%s*$")
          H.truthy(script.nodes[trimmed] ~= nil, "if() in " .. id .. " refs missing node " .. trimmed)
        end
      end
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
