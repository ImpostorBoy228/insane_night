-- Adversarial tests for scripts/game.lua.
-- Property/fuzz tests AND tests that document real bugs (some are RED on purpose).
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()

local mod = M.load_module("scripts/game.lua", {
  "vn", "g", "getNode",
  "splitExplicitLines", "wrapParagraph", "wrapText", "paginateLines",
  "buildDialoguePages", "checkIf_script", "textProcess", "syncSound",
  "renderGame", "gameOnKey", "nextNode", "finger", "ssave", "sload",
  "__setScriptData", "__setChoices", "__setCurrentUI",
}, [[
  function __setScriptData(t) scriptData = t end
  function __setChoices(t) vn.currentChoices = t end
  function __setCurrentUI(ui) currentUI = ui end
]])

local function words(text)
  local out = {}
  for w in text:gmatch("%S+") do out[#out + 1] = w end
  return out
end

H.describe("game.lua text-wrap properties (fuzz)")

local function rng()
  local seed = 12345
  return function()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
  end
end

H.test("wrapParagraph never loses a word (fuzz, 200 cases)", function()
  local rand = rng()
  local vocab = { "aa", "b", "ccc", "dddd", "supercalifragilistic", "x", "loooongword123" }
  for _ = 1, 200 do
    local n = math.floor(rand() * 8) + 1
    local parts = {}
    for _ = 1, n do parts[#parts + 1] = vocab[math.floor(rand() * #vocab) + 1] end
    local text = table.concat(parts, " ")
    local maxWidth = math.floor(rand() * 40) + 1
    local lines = mod.wrapParagraph(M.custom_gooner(function(t) return #t end), text, maxWidth)
    local outWords = words(table.concat(lines, " "))
    H.eq(table.concat(outWords, " "), text, "words lost for '" .. text .. "' w=" .. maxWidth)
  end
end)

H.test("wrapParagraph word order preserved (fuzz)", function()
  local rand = rng()
  for _ = 1, 100 do
    local n = math.floor(rand() * 10) + 1
    local parts = {}
    for _ = 1, n do parts[#parts + 1] = "w" .. tostring(math.floor(rand() * 1000)) end
    local text = table.concat(parts, " ")
    local lines = mod.wrapParagraph(M.custom_gooner(function(t) return #t end), text, 7)
    local got = {}
    for _, line in ipairs(lines) do
      for w in line:gmatch("%S+") do got[#got + 1] = w end
    end
    H.eq(table.concat(got, " "), text)
  end
end)

H.test("wrapParagraph empty paragraph -> one empty line", function()
  local lines = mod.wrapParagraph(M.gooner(), "", 100)
  H.eq(#lines, 1)
  H.eq(lines[1], "")
end)

H.xfail("blank-only paragraph should yield an empty line (BUG: returns raw spaces)", function()
  local lines = mod.wrapParagraph(M.gooner(), "    ", 100)
  H.eq(#lines, 1)
  H.eq(lines[1], "", "whitespace-only paragraph should become an empty line")
end, "wrapParagraph falls back to the raw paragraph when currentLine is empty")

H.test("wrapText preserves total word count (fuzz)", function()
  local rand = rng()
  for _ = 1, 100 do
    local text = {}
    for _ = 1, 20 do text[#text + 1] = "w" .. math.floor(rand() * 999) end
    local src = table.concat(text, " ")
    local lines = mod.wrapText(M.custom_gooner(function(t) return #t end), src, 5)
    local got = words(table.concat(lines, " "))
    H.eq(table.concat(got, " "), src)
  end
end)

H.test("paginateLines groups and preserves lines", function()
  local lines = { "a", "b", "c", "d", "e" }
  local pages = mod.paginateLines(lines, 2)
  H.eq(#pages, 3)
  H.eq(pages[1], "a\nb")
  H.eq(pages[2], "c\nd")
  H.eq(pages[3], "e")
end)

H.test("paginateLines empty input -> one empty page", function()
  local pages = mod.paginateLines({}, 5)
  H.eq(#pages, 1)
  H.eq(pages[1], "")
end)

H.describe("game.lua wrap edge cases")

H.test("word longer than maxWidth stays on its own line", function()
  local lines = mod.wrapParagraph(M.custom_gooner(function(t) return #t end),
    "aa supercalifragilistic bb", 4)
  H.eq(table.concat(lines, "|"), "aa|supercalifragilistic|bb")
end)

H.test("crlf and bare cr both normalize", function()
  H.tableeq(mod.splitExplicitLines("a\r\nb\rc"), { "a", "b", "c" })
end)

H.test("buildDialoguePages is deterministic for identical input", function()
  local a = mod.buildDialoguePages(string.rep("word ", 50))
  local b = mod.buildDialoguePages(string.rep("word ", 50))
  H.eq(table.concat(a, "\n"), table.concat(b, "\n"))
end)

H.describe("game.lua conditional branches (checkIf_script / textProcess)")

H.test("checkIf_script matches recorded choice", function()
  mod.__setChoices({ { node = "6", choice = "4" } })
  H.eq(mod.checkIf_script("if(6, 4)"), true)
  H.eq(mod.checkIf_script("if(6, 13)"), false)
end)

H.test("else[] branch negates the match", function()
  mod.__setChoices({ { node = "6", choice = "4" } })
  H.eq(mod.checkIf_script("if(6, else[4])"), false)
  H.eq(mod.checkIf_script("if(6, else[13])"), true)
end)

H.test("else[] fires when no choices recorded at all", function()
  mod.__setChoices(nil)
  H.eq(mod.checkIf_script("if(6, else[4])"), true)
end)

H.test("textProcess picks matching branch over default", function()
  mod.__setScriptData({ start = "7", nodes = { ["7"] = { text = "default", next = "8",
    ["if(6, 4)"] = { text = "you picked four" } } } })
  mod.__setChoices({ { node = "6", choice = "4" } })
  H.eq(mod.textProcess(mod.getNode("7")), "you picked four")
end)

H.test("textProcess returns default when no branch matches", function()
  mod.__setScriptData({ start = "7", nodes = { ["7"] = { text = "default", next = "8",
    ["if(6, 4)"] = { text = "you picked four" } } } })
  mod.__setChoices({ { node = "6", choice = "13" } })
  H.eq(mod.textProcess(mod.getNode("7")), "default")
end)

H.test("REAL BUG: multiple matching if() branches are order-dependent (nondeterministic)", function()
  -- Two conditions match simultaneously; textProcess uses pairs() and
  -- last-write-wins, so the result depends on hash iteration order.
  local texts = {}
  for i = 1, 30 do
    mod.__setScriptData({ start = "7", nodes = { ["7"] = { text = "d",
      ["if(6, 4)"] = { text = "A" },
      ["if(6, 13)"] = { text = "B" } } } })
    mod.__setChoices({ { node = "6", choice = "4" }, { node = "6", choice = "13" } })
    texts[mod.textProcess(mod.getNode("7"))] = true
  end
  -- A correct implementation must be deterministic. This is a known bug.
  local keys = {}
  for k in pairs(texts) do keys[#keys + 1] = k end
  H.eq(#keys, 1, "textProcess must be deterministic; got " .. table.concat(keys, ","))
end)

H.test("if() branch with non-table value is silently ignored", function()
  -- textProcess requires value.text; a string branch is dropped without warning.
  mod.__setScriptData({ start = "7", nodes = { ["7"] = { text = "default", next = "8",
    ["if(6, 4)"] = "misformatted branch" } } })
  mod.__setChoices({ { node = "6", choice = "4" } })
  H.eq(mod.textProcess(mod.getNode("7")), "default")
end)

H.describe("game.lua sound")

H.test("empty sound string stops the current sound", function()
  mod.vn.currentSound = "assets/a.mp3"
  mod.vn.currentSoundId = 5
  mod.syncSound({ sound = "" })
  H.isnil(mod.vn.currentSound)
  H.eq(mod.vn.currentSoundId, 0)
end)

H.test("node without sound keeps an already playing sound", function()
  mod.vn.currentSound = "assets/a.mp3"
  mod.vn.currentSoundId = 7
  mod.syncSound({})
  H.eq(mod.vn.currentSound, "assets/a.mp3")
  H.eq(mod.vn.currentSoundId, 7)
end)

H.test("new sound replaces old and returns fresh id", function()
  mod.vn.currentSound = "assets/a.mp3"
  mod.vn.currentSoundId = 7
  mod.syncSound({ sound = "assets/b.mp3" })
  H.eq(mod.vn.currentSound, "assets/b.mp3")
  H.truthy(mod.vn.currentSoundId ~= 0)
end)

H.describe("game.lua renderGame / finger layer routing")

H.xfail("finger() draws choices into currentUI, not the ui passed to renderGame", function()
  -- renderGame(ui) calls finger(node, qu); finger uses the module-global
  -- `currentUI` instead of the `ui` argument. When they differ, the choice
  -- panel lands on the wrong layer.
  mod.__setScriptData({ start = "6", nodes = { ["6"] = { text = "q", qu = "?", choices = { "4", "13" } } } })
  local uiA = M.layer("gameA")
  local uiB = M.layer("gameB")
  mod.__setCurrentUI(uiB)
  mod.vn.currentNode = "6"
  mod.vn.currentPage = 1
  mod.renderGame(uiA)
  local inA = 0
  for _, it in ipairs(uiA.items) do if it.kind == "rect" and it.z == 22 then inA = inA + 1 end end
  H.truthy(inA >= 1, "choice panel should be drawn into the ui passed to renderGame")
end, "finger() uses currentUI global instead of renderGame's ui argument")

H.describe("game.lua save/load roundtrip")

local function backup_state()
  local f = io.open("scripts/state.json", "r")
  local content = f and f:read("*a") or nil
  if f then f:close() end
  return content
end

local function restore_state(content)
  if content then
    local f = io.open("scripts/state.json", "w")
    f:write(content)
    f:close()
  else
    os.remove("scripts/state.json")
  end
end

H.test("ssave -> sload roundtrip restores node and choices", function()
  local backup = backup_state()
  local ok, err = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write('{"node":"3","choices":[{"node":"2","choice":"9"}]}')
    f:close()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a", next = "2" },
      ["2"] = { text = "b" }, ["3"] = { text = "c" } } })
    mod.__setCurrentUI(M.layer("game"))
    mod.sload()
    H.eq(mod.vn.currentNode, "3")
    H.eq(mod.vn.currentChoices[1].choice, "9")
  end)
  restore_state(backup)
  H.truthy(ok, tostring(err))
end)

H.test("sload with unreachable node still restores node id", function()
  local backup = backup_state()
  local ok, err = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write('{"node":"99","choices":[]}')
    f:close()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    mod.__setCurrentUI(M.layer("game"))
    mod.sload()
    H.eq(mod.vn.currentNode, "99")
  end)
  restore_state(backup)
  H.truthy(ok, tostring(err))
end)

H.describe("game.lua g table / renderer wiring")

H.test("all gooners and audio engine are present", function()
  H.truthy(mod.g.text ~= nil)
  H.truthy(mod.g.textSmall ~= nil)
  H.truthy(mod.g.rect ~= nil)
  H.truthy(mod.g.image ~= nil)
  H.truthy(mod.g.audio ~= nil)
end)

H.test("gameOnKey ignores unknown keys without error", function()
  mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
  mod.__setCurrentUI(M.layer("game"))
  mod.vn.currentNode = "1"
  local ok = pcall(mod.gameOnKey, 0x48) -- 'h'
  H.truthy(ok)
end)

H.finish()
