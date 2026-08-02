-- Profiling harness for the Lua scripts: measures memory (KB) and time (ns/op).
-- Usage: lua5.4 tests(vibecoded)/lua/bench.lua [--json]
local M = require("tests(vibecoded)/lua/mock")
M.install()

local json = dofile("scripts/libs/json.lua")
local mod = M.load_module("scripts/game.lua", {
  "vn", "g", "prof", "getNode", "loadScript",
  "splitExplicitLines", "wrapParagraph", "wrapText", "paginateLines",
  "buildDialoguePages", "checkIf_script", "textProcess", "syncSound",
  "renderGame", "gameOnKey", "ssave", "sload", "finger",
  "__setScriptData", "__setChoices", "__setCurrentUI",
  "__getScriptData", "__getCurrentUI",
}, [[
  function __setScriptData(t) scriptData = t end
  function __setChoices(t) vn.currentChoices = t end
  function __setCurrentUI(ui) currentUI = ui end
  function __getScriptData() return scriptData end
  function __getCurrentUI() return currentUI end
]])

-- ── timing helpers ────────────────────────────────────────────
mod.prof.flush = function() mod.prof.buf = {}; mod.prof.enabled = false end  -- silent flush

local function mem_kb()
  collectgarbage("collect")
  return collectgarbage("count")
end

local function bench(fn, iters, warmup)
  iters = iters or 10000
  warmup = warmup or 100
  for _ = 1, warmup do fn() end
  local t0 = os.clock()
  for _ = 1, iters do fn() end
  local dt = os.clock() - t0
  return dt / iters * 1e9  -- ns per op
end

local function mem_growth(fn, iters)
  local base = mem_kb()
  for _ = 1, iters do fn() end
  return mem_kb() - base
end

-- ── real workload data ────────────────────────────────────────
local long_text = string.rep("word ", 300) .. "\n" .. string.rep("ВК сиськи ", 50) .. "\nend"
local script_raw = io.open("scripts/script.json"):read("*a")
local big_json = table.concat({
  '{"nodes":{',
  table.concat((function()
    local parts = {}
    for i = 1, 200 do
      parts[i] = string.format('"n%d":{"text":"node number %d","next":"n%d"}', i, i, i + 1)
    end
    return parts
  end)(), ","),
  '},"start":"n1"}'
})

local choice_data = {}
for i = 1, 30 do choice_data[#choice_data + 1] = { node = "6", choice = tostring(i) } end

mod.loadScript()
mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = long_text, next = "2" }, ["2"] = { text = "end" } } })
mod.vn.currentNode = "1"
mod.__setCurrentUI(M.layer("game"))

-- ── benchmark table ───────────────────────────────────────────
local results = {}

local function add(name, fn, iters, warmup)
  local it = iters or 10000
  local ns = bench(fn, it, warmup or 100)
  local kb = mem_growth(fn, math.min(it, 2000))
  results[#results + 1] = { name = name, ns = ns, kb = kb, iters = it }
end

add("buildDialoguePages (long text)", function() mod.buildDialoguePages(long_text) end, 2000)
add("wrapText (long text)", function() mod.wrapText(mod.g.textSmall, long_text, 1728) end, 2000)
add("wrapParagraph (30 words)", function()
  mod.wrapParagraph(mod.g.textSmall, "aa bb cc dd ee ff gg hh ii jj kk ll mm nn oo pp qq rr ss tt uu vv ww xx yy zz", 1728)
end, 20000)
add("splitExplicitLines", function() mod.splitExplicitLines(long_text) end, 20000)
add("paginateLines (40 lines)", function() mod.paginateLines(mod.splitExplicitLines(long_text), 8) end, 5000)
add("checkIf_script (30 choices, miss)", function()
  mod.__setChoices(choice_data)
  mod.checkIf_script("if(6, 999)")
end, 20000)
add("textProcess (if branch)", function()
  mod.__setChoices(choice_data)
  mod.textProcess(mod.getNode("1"))
end, 5000)
add("syncSound (no-op)", function() mod.syncSound({}) end, 50000)
add("json.encode script.json", function() json.encode(mod.__getScriptData()) end, 2000)
add("json.decode script.json", function() json.decode(script_raw) end, 2000)
add("json.decode 200-node doc", function() json.decode(big_json) end, 500)
add("json.encode 200-node table", function() json.encode(json.decode(big_json)) end, 500)
add("renderGame (long text)", function() mod.renderGame(mod.__getCurrentUI()) end, 500, 20)
add("gameOnKey (space, 2 pages)", function() mod.gameOnKey(32) end, 200, 20)

-- ── report ────────────────────────────────────────────────────
collectgarbage("collect")
local baseline_kb = collectgarbage("count")
local fmt = "%3d. %-36s %12.0f ns/op %10.2f KB   (%d iters)"
io.write("\n== Lua benchmark (Lua 5.4) ==\n")
io.write(string.format("%-3s %-36s %12s %10s\n", "#", "operation", "time", "mem/run"))
io.write(string.rep("-", 70) .. "\n")
for i, r in ipairs(results) do
  io.write(string.format(fmt, i, r.name, r.ns, r.kb, r.iters) .. "\n")
end
io.write(string.rep("-", 70) .. "\n")
io.write(string.format("Lua runtime baseline heap: %.0f KB (after full GC)\n", baseline_kb))

-- ── leak detector: is any hot path growing the heap? ─────────
io.write("\n== leak detector (heap growth over N calls, after full GC) ==\n")
local leak_cases = {
  { "buildDialoguePages", function() mod.buildDialoguePages(long_text) end, 5000 },
  { "wrapText", function() mod.wrapText(mod.g.textSmall, long_text, 1728) end, 5000 },
  { "json.decode", function() json.decode(big_json) end, 2000 },
  { "renderGame", function() mod.renderGame(mod.__getCurrentUI()) end, 500 },
}
local leaks = 0
for _, c in ipairs(leak_cases) do
  local before = mem_kb()
  local calls_before = #M.state.calls
  for _ = 1, c[3] do c[2]() end
  local growth = mem_kb() - before
  -- M.log() bookkeeping grows with every engine call; account for it.
  local log_kb = (#M.state.calls - calls_before) * 128 / 1024
  local real_growth = growth - log_kb
  if real_growth > 256 then leaks = leaks + 1 end
  local flag = real_growth > 256 and "  <-- LEAK CANDIDATE" or ""
  io.write(string.format("  %-20s %+10.2f KB after %d calls%s (%.2f KB mock log)\n",
    c[1], real_growth, c[3], flag, log_kb))
end

io.write(string.format("\nLeak gate: %d candidate(s) (fail if > 0)\n", leaks))
if leaks > 0 then os.exit(1) end
