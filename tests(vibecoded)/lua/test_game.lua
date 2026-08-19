-- Tests for scripts/game.lua internals (exposed via chunk-scope closures)
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()

local mod = M.load_module("scripts/game.lua", {
  "vn", "g", "prof", "dialogueCfg",
  "getNode", "loadScript", "evalScript", "chosen", "textProcess",
  "splitExplicitLines", "wrapParagraph", "wrapText", "paginateLines",
  "buildDialoguePages", "getSpeakerWidth", "syncSound", "nextNode",
  "image", "background", "character", "finger",
  "renderGame", "gameOnKey", "ssave", "sload", "initSload", "ginit", "onFrame",
  "__getScriptData", "__setScriptData", "__setCurrentUI", "__getRegistered",
}, [[
  function __getScriptData() return scriptData end
  function __setScriptData(t) scriptData = t end
  function __setCurrentUI(ui) currentUI = ui end
  function __getRegistered() return _G.registered["gay"] end
]])

H.describe("game.lua splitExplicitLines")

H.test("empty string -> one empty line", function()
  H.tableeq(mod.splitExplicitLines(""), { "" })
end)

H.test("single line", function()
  H.tableeq(mod.splitExplicitLines("hello"), { "hello" })
end)

H.test("splits on LF", function()
  H.tableeq(mod.splitExplicitLines("a\nb"), { "a", "b" })
end)

H.test("normalizes CRLF", function()
  H.tableeq(mod.splitExplicitLines("a\r\nb"), { "a", "b" })
end)

H.test("normalizes bare CR", function()
  H.tableeq(mod.splitExplicitLines("a\rb"), { "a", "b" })
end)

H.test("handles trailing newline", function()
  H.tableeq(mod.splitExplicitLines("a\n"), { "a", "" })
end)

H.test("handles consecutive newlines", function()
  H.tableeq(mod.splitExplicitLines("a\n\nb"), { "a", "", "b" })
end)

H.describe("game.lua wrapParagraph")

local function W(widest)
  return M.custom_gooner(function(text)
    return #text * widest
  end)
end

H.test("empty paragraph -> one empty line", function()
  H.tableeq(mod.wrapParagraph(W(10), "", 100), { "" })
end)

H.test("single word fits", function()
  H.tableeq(mod.wrapParagraph(W(10), "hello", 100), { "hello" })
end)

H.test("multiple words on one line", function()
  H.tableeq(mod.wrapParagraph(W(10), "a b c", 100), { "a b c" })
end)

H.test("wraps long text onto multiple lines", function()
  local lines = mod.wrapParagraph(W(10), "aa bb cc dd ee ff", 60)
  H.truthy(#lines >= 2)
  H.eq(table.concat(lines, "|"), "aa bb|cc dd|ee ff")
end)

H.test("word longer than maxWidth stays whole", function()
  local lines = mod.wrapParagraph(W(10), "aaaaaaaaaa", 40)
  H.tableeq(lines, { "aaaaaaaaaa" })
end)

H.test("wraps in the middle of a sentence at word boundaries", function()
  local lines = mod.wrapParagraph(W(1), "one two three four", 4)
  H.eq(lines[1], "one")
  H.eq(lines[2], "two")
  H.eq(lines[3], "three")
  H.eq(lines[4], "four")
end)

H.describe("game.lua wrapText")

H.test("wrapText joins paragraphs by line", function()
  local lines = mod.wrapText(W(10), "aa bb\ncc dd", 60)
  H.eq(#lines, 2)
  H.eq(lines[1], "aa bb")
  H.eq(lines[2], "cc dd")
end)

H.test("wrapText handles empty input", function()
  local lines = mod.wrapText(W(10), "", 100)
  H.eq(#lines, 1)
  H.eq(lines[1], "")
end)

H.test("wrapText respects explicit blank lines", function()
  local lines = mod.wrapText(W(10), "a\n\nb", 100)
  H.eq(#lines, 3)
  H.eq(lines[2], "")
end)

H.describe("game.lua paginateLines")

H.test("paginate groups lines by maxLines", function()
  local pages = mod.paginateLines({ "1", "2", "3", "4", "5" }, 2)
  H.eq(#pages, 3)
  H.eq(pages[1], "1\n2")
  H.eq(pages[2], "3\n4")
  H.eq(pages[3], "5")
end)

H.test("paginate handles exact multiple", function()
  local pages = mod.paginateLines({ "1", "2", "3", "4" }, 2)
  H.eq(#pages, 2)
end)

H.test("paginate with maxLines 0 -> at least 1 line per page", function()
  local pages = mod.paginateLines({ "a", "b" }, 0)
  H.eq(#pages, 2)
  H.eq(pages[1], "a")
end)

H.test("paginate empty input -> one empty page", function()
  local pages = mod.paginateLines({}, 2)
  H.eq(#pages, 1)
  H.eq(pages[1], "")
end)

H.test("paginate single line", function()
  local pages = mod.paginateLines({ "solo" }, 5)
  H.eq(#pages, 1)
  H.eq(pages[1], "solo")
end)

H.describe("game.lua buildDialoguePages")

H.test("short text produces single page", function()
  local pages = mod.buildDialoguePages("hi there")
  H.eq(#pages, 1)
  H.matches(pages[1], "hi there")
end)

H.test("long text produces multiple pages", function()
  local long = string.rep("word ", 400)
  local pages = mod.buildDialoguePages(long)
  H.truthy(#pages >= 2, "got " .. #pages .. " pages")
end)

H.test("empty text produces one empty page", function()
  local pages = mod.buildDialoguePages("")
  H.eq(#pages, 1)
end)

H.describe("game.lua getSpeakerWidth")

H.test("short speaker name stays under max width", function()
  local w = mod.getSpeakerWidth("Санс")
  H.truthy(w > 0 and w <= 0.5, "width was " .. tostring(w))
end)

H.test("long speaker name is clamped to maxWidth", function()
  local w = mod.getSpeakerWidth(string.rep("A", 500))
  H.eq(w, 0.5)
end)

H.test("empty speaker is a small positive width", function()
  local w = mod.getSpeakerWidth("")
  H.truthy(w > 0 and w <= 0.5)
end)

H.describe("game.lua loadScript / getNode")

H.test("loadScript succeeds on real script.son", function()
  H.eq(mod.loadScript(), true)
end)

H.test("getNode returns start node", function()
  mod.loadScript()
  local node = mod.getNode(mod.__getScriptData().start)
  H.eq(type(node), "table")
end)

H.test("getNode returns nil for unknown id", function()
  mod.loadScript()
  H.isnil(mod.getNode("no_such_node"))
end)

H.test("getNode returns nil for nil id", function()
  H.isnil(mod.getNode(nil))
end)

H.test("start node has text", function()
  mod.loadScript()
  local start = mod.getNode(mod.__getScriptData().start)
  H.eq(type(start.text), "string")
end)

H.describe("game.lua conditional branches (SON chosen())")

local function eval_choices(choices)
  mod.vn.currentChoices = choices
  mod.loadScript()
end

H.test("chosen() is true when a matching choice was made", function()
  eval_choices({ { node = "6", choice = "4" } })
  H.eq(mod.chosen("6", "4"), true)
end)

H.test("chosen() is false when choice not made", function()
  eval_choices({ { node = "6", choice = "8" } })
  H.eq(mod.chosen("6", "4"), false)
end)

H.test("chosen() is false when no choices recorded", function()
  eval_choices({})
  H.eq(mod.chosen("6", "4"), false)
end)

H.test("chosen() is false when currentChoices is nil", function()
  mod.vn.currentChoices = nil
  H.eq(mod.chosen("6", "4"), false)
end)

H.test("chosen() compares node and choice as strings", function()
  eval_choices({ { node = 6, choice = 4 } })
  H.eq(mod.chosen("6", "4"), true)
end)

H.test("chosen() ignores choices for other nodes", function()
  eval_choices({ { node = "2", choice = "4" } })
  H.eq(mod.chosen("6", "4"), false)
end)

H.test("evalScript resolves if(chosen()) branch in the real script", function()
  eval_choices({ { node = "6", choice = "4" } })
  H.matches(mod.getNode("7").text, "неудачное число")
end)

H.test("evalScript resolves the not-chosen branch", function()
  eval_choices({ { node = "6", choice = "13" } })
  H.matches(mod.getNode("7").text, "3 буквы")
end)

H.test("evalScript resolves not-chosen branch when no choices", function()
  eval_choices({})
  H.matches(mod.getNode("7").text, "3 буквы")
end)

H.test("evalScript is deterministic for identical choices", function()
  local texts = {}
  for _ = 1, 30 do
    eval_choices({ { node = "6", choice = "4" } })
    texts[mod.getNode("7").text] = true
  end
  local keys = {}
  for k in pairs(texts) do keys[#keys + 1] = k end
  H.eq(#keys, 1, "evalScript must be deterministic; got " .. table.concat(keys, ","))
end)

H.describe("game.lua textProcess")

H.test("returns node.text by default", function()
  H.eq(mod.textProcess({ text = "hello" }), "hello")
end)

H.test("returns empty string for missing text", function()
  H.eq(mod.textProcess({}), "")
end)

H.test("empty text and nil node both yield a string", function()
  H.eq(mod.textProcess({ text = "" }), "")
end)

H.describe("game.lua syncSound")

H.test("plays new sound when node has one", function()
  mod.vn.currentSound = nil
  mod.vn.currentSoundId = 0
  mod.syncSound({ sound = "assets/megalovania.mp3" })
  H.eq(mod.vn.currentSound, "assets/megalovania.mp3")
  H.truthy(mod.vn.currentSoundId ~= 0)
end)

H.test("treats empty sound string as stop", function()
  mod.vn.currentSound = "assets/x.mp3"
  mod.vn.currentSoundId = 5
  mod.syncSound({ sound = "" })
  H.isnil(mod.vn.currentSound)
  H.eq(mod.vn.currentSoundId, 0)
end)

H.test("stops old sound when switching", function()
  mod.vn.currentSound = "assets/a.mp3"
  mod.vn.currentSoundId = 7
  mod.syncSound({ sound = "assets/b.mp3" })
  H.eq(mod.vn.currentSound, "assets/b.mp3")
  H.truthy(mod.vn.currentSoundId ~= 7)
end)

H.test("keeps current sound when node has none and already playing", function()
  mod.vn.currentSound = "assets/a.mp3"
  mod.vn.currentSoundId = 7
  mod.syncSound({})
  H.eq(mod.vn.currentSound, "assets/a.mp3")
  H.eq(mod.vn.currentSoundId, 7)
end)

H.test("does not restart identical sound", function()
  mod.vn.currentSound = "assets/a.mp3"
  mod.vn.currentSoundId = 7
  mod.syncSound({ sound = "assets/a.mp3" })
  H.eq(mod.vn.currentSoundId, 7)
end)

H.describe("game.lua image / background / character")

H.test("image adds image element when texture loads", function()
  local ui = M.layer("game")
  mod.image(ui, "assets/sans.png", 0, 0, 0.5, 0.5, 1)
  local hasImage = false
  for _, it in ipairs(ui.items) do
    if it.kind == "image" then hasImage = true end
  end
  H.truthy(hasImage)
end)

H.test("image falls back to rect when texture missing", function()
  local ui = M.layer("game")
  mod.image(ui, "assets/missing_tex.png", 0, 0, 0.5, 0.5, 1)
  local hasRect = false
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" then hasRect = true end
  end
  H.truthy(hasRect)
end)

H.test("image with nil path adds nothing", function()
  local ui = M.layer("game")
  mod.image(ui, nil, 0, 0, 0.5, 0.5, 1)
  H.eq(#ui.items, 0)
end)

H.test("background stores currentBg", function()
  local ui = M.layer("game")
  mod.background(ui, { bg = "assets/bg.png" }, 0, 0, 1, 1)
  H.eq(mod.vn.currentBg, "assets/bg.png")
end)

H.test("background reuses currentBg when node has none", function()
  mod.vn.currentBg = "assets/old.png"
  local ui = M.layer("game")
  mod.background(ui, {}, 0, 0, 1, 1)
  H.eq(mod.vn.currentBg, "assets/old.png")
end)

H.test("character computes width from aspect ratio", function()
  M.state.image_dims["assets/sans.png"] = { 200, 100 }
  local ui = M.layer("game")
  mod.vn.currentChar = nil
  mod.character(ui, { character = "assets/sans.png", character_place = "left" }, -5)
  local img = nil
  for _, it in ipairs(ui.items) do
    if it.kind == "image" then img = it end
  end
  H.truthy(img, "character should add an image")
  H.truthy(img.w > 0 and img.h > 0)
end)

H.test("character skips when image dims unknown", function()
  M.state.image_dims["assets/unknown.png"] = { 0, 0 }
  local ui = M.layer("game")
  mod.character(ui, { character = "assets/unknown.png", character_place = "right" }, -5)
  H.eq(#ui.items, 0)
end)

H.describe("game.lua renderGame")

H.test("renderGame shows missing node message", function()
  local ui = M.layer("game")
  mod.vn.currentNode = "does_not_exist"
  mod.renderGame(ui)
  local texts = {}
  for _, it in ipairs(ui.items) do
    if it.kind == "text" then table.insert(texts, it.text) end
  end
  H.matches(table.concat(texts, "|"), "missing node")
end)

H.test("renderGame renders text with reveal", function()
  mod.loadScript()
  mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "hello" } } })
  mod.vn.currentNode = "1"
  mod.vn.currentPage = 1
  local ui = M.layer("game")
  mod.renderGame(ui)
  H.truthy(mod.vn.textEl, "textEl should be set")
  H.eq(mod.vn.textEl.revealing, true, "text should start revealing")
end)

H.test("renderGame handles qu node by opening choices", function()
  mod.__setScriptData({
    start = "6",
    nodes = {
      ["6"] = { text = "q", qu = "Сколько букв?", choices = { "4", "13", "9", "8" } },
    },
  })
  mod.vn.currentNode = "6"
  mod.vn.currentPage = 1
  local ui = M.layer("game")
  mod.__setCurrentUI(ui)
  mod.renderGame(ui)
  local choiceLayer = M.state.layers["choice"]
  H.falsy(choiceLayer, "choice layer should not open while text is revealing")
  mod.vn.textEl:showAll()
  mod.onFrame(0.016)
  choiceLayer = M.state.layers["choice"]
  H.truthy(choiceLayer, "choice layer should open after reveal finishes")
end)

H.describe("game.lua finger (choices) — fresh module instance")

-- A second module load keeps scriptTree == nil so renderGame's evalScript()
-- does not clobber synthetic __setScriptData payloads.
local fresh = M.load_module("scripts/game.lua", {
  "vn", "getNode", "finger", "renderGame", "onFrame",
  "__setScriptData", "__setCurrentUI",
}, [[
  function __setScriptData(t) scriptData = t end
  function __setCurrentUI(ui) currentUI = ui end
]])

local function qu_setup()
  fresh.__setScriptData({
    start = "6",
    nodes = {
      ["6"] = { text = "q", qu = "Сколько букв?", choices = { "4", "13" }, next = "7" },
      ["7"] = { text = "end" },
    },
  })
  local ui = M.layer("game")
  fresh.__setCurrentUI(ui)
  fresh.vn.currentNode = "6"
  fresh.vn.currentPage = 1
  fresh.vn.currentChoices = {}
  return ui
end

H.test("finger draws the question and one button per choice", function()
  local ui = qu_setup()
  fresh.finger(fresh.getNode("6"), "Сколько букв?")
  local texts = {}
  for _, it in ipairs(ui.items) do
    if it.kind == "text" then table.insert(texts, it.text) end
  end
  H.matches(table.concat(texts, "|"), "Сколько букв%?")
  H.matches(table.concat(texts, "|"), "4")
  H.matches(table.concat(texts, "|"), "13")
  local buttons = 0
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" and it.z == 22 then buttons = buttons + 1 end
  end
  H.eq(buttons, 2)
end)

H.test("clicking a choice records it and advances the node", function()
  local ui = qu_setup()
  fresh.finger(fresh.getNode("6"), "?")
  local buttons = {}
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" and it.z == 22 then table.insert(buttons, it) end
  end
  buttons[1].click()
  H.eq(fresh.vn.currentNode, "7")
  H.eq(#fresh.vn.currentChoices, 1)
  H.eq(fresh.vn.currentChoices[1].node, "6")
  H.eq(fresh.vn.currentChoices[1].choice, "4")
end)

H.test("clicking a different choice replaces the old one for the same node", function()
  local ui = qu_setup()
  fresh.vn.currentChoices = { { node = "6", choice = "4" } }
  fresh.finger(fresh.getNode("6"), "?")
  local buttons = {}
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" and it.z == 22 then table.insert(buttons, it) end
  end
  buttons[2].click()
  H.eq(#fresh.vn.currentChoices, 1)
  H.eq(fresh.vn.currentChoices[1].choice, "13")
end)

H.test("clicking a choice keeps choices recorded for other nodes", function()
  local ui = qu_setup()
  fresh.vn.currentChoices = { { node = "2", choice = "x" } }
  fresh.finger(fresh.getNode("6"), "?")
  local buttons = {}
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" and it.z == 22 then table.insert(buttons, it) end
  end
  buttons[1].click()
  H.eq(#fresh.vn.currentChoices, 2)
end)

H.test("onFrame opens choices only after the text reveal finishes", function()
  local ui = qu_setup()
  fresh.renderGame(ui)
  local before = 0
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" and it.z == 22 then before = before + 1 end
  end
  H.eq(before, 0, "no choice buttons while the question is revealing")
  fresh.vn.textEl:showAll()
  fresh.onFrame(0.016)
  local after = 0
  for _, it in ipairs(ui.items) do
    if it.kind == "rect" and it.z == 22 then after = after + 1 end
  end
  H.eq(after, 2, "choice buttons appear once the reveal finishes")
end)

H.describe("game.lua nextNode")

H.test("nextNode advances currentNode and resets page", function()
  mod.__setScriptData({
    start = "1",
    nodes = { ["1"] = { text = "a", next = "2" }, ["2"] = { text = "b" } },
  })
  mod.vn.currentNode = "1"
  mod.vn.currentPage = 3
  local ui = M.layer("game")
  mod.nextNode(ui, "2")
  H.eq(mod.vn.currentNode, "2")
  H.eq(mod.vn.currentPage, 1)
end)

H.test("nextNode with nil next does nothing", function()
  mod.vn.currentNode = "1"
  mod.nextNode(M.layer("game"), nil)
  H.eq(mod.vn.currentNode, "1")
end)

H.describe("game.lua gameOnKey")

local function backup_file(path)
  local f = io.open(path, "r")
  local content = f and f:read("*a") or nil
  if f then f:close() end
  return content
end

local function restore_file(path, content)
  if content then
    local f = io.open(path, "w")
    f:write(content)
    f:close()
  else
    os.remove(path)
  end
end

local function reset_vn()
  mod.vn.currentNode = nil
  mod.vn.currentPage = 1
  mod.vn.currentSound = nil
  mod.vn.currentSoundId = 0
  mod.vn.textEl = nil
  mod.vn.currentChoices = nil
  mod.__setCurrentUI(M.layer("game"))
end

H.test("space advances page within a multi-page node", function()
  mod.__setScriptData({
    start = "1",
    nodes = {
      ["1"] = { text = string.rep("word ", 400), next = "2" },
      ["2"] = { text = "end" },
    },
  })
  reset_vn()
  mod.vn.currentNode = "1"
  mod.vn.currentPage = 1
  mod.gameOnKey(32)
  H.eq(mod.vn.currentPage, 2, "should advance a page")
end)

H.test("space on final page advances to next node", function()
  mod.__setScriptData({
    start = "1",
    nodes = {
      ["1"] = { text = "short", next = "2" },
      ["2"] = { text = "end" },
    },
  })
  reset_vn()
  mod.vn.currentNode = "1"
  mod.vn.currentPage = 1
  mod.gameOnKey(32)
  H.eq(mod.vn.currentNode, "2")
end)

H.test("space does not advance on qu node", function()
  mod.__setScriptData({
    start = "1",
    nodes = { ["1"] = { text = "q", qu = "?", next = "2" } },
  })
  reset_vn()
  mod.vn.currentNode = "1"
  mod.vn.currentPage = 1
  mod.gameOnKey(32)
  H.eq(mod.vn.currentNode, "1")
end)

H.test("F3 triggers save", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    reset_vn()
    mod.vn.currentNode = "1"
    mod.gameOnKey(1073741884)
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("F2 triggers load", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write('{"node":"1","choices":[]}')
    f:close()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    reset_vn()
    mod.vn.currentNode = "1"
    mod.gameOnKey(1073741883)
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.describe("game.lua save / load")

H.test("ssave writes state.json", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    mod.vn.currentNode = "1"
    mod.vn.currentChoices = { { node = "6", choice = "4" } }
    mod.ssave()
    local f = io.open("scripts/state.json", "r")
    H.truthy(f, "state.json should exist")
    local content = f:read("*a")
    f:close()
    H.matches(content, '"node"')
    H.matches(content, '"4"')
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("sload restores currentNode and choices", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    mod.__setScriptData({
      start = "1",
      nodes = {
        ["1"] = { text = "a" },
        ["6"] = { text = "b", character = "assets/cirno.png", bg = "assets/background.png" },
      },
    })
    local f = io.open("scripts/state.json", "w")
    f:write('{"node":"6","choices":[{"node":"6","choice":"13"}]}')
    f:close()
    mod.vn.currentNode = "1"
    mod.sload()
    H.eq(mod.vn.currentNode, "6")
    H.eq(mod.vn.currentChoices[1].choice, "13")
    H.eq(mod.vn.currentBg, "assets/background.png")
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("initSload returns true when state exists", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write('{"node":"1","choices":[]}')
    f:close()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    H.eq(mod.initSload(), true)
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("initSload returns false when no state", function()
  local backup = backup_file("scripts/state.json")
  os.remove("scripts/state.json")
  local ok, result = pcall(mod.initSload)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
  H.eq(result, false)
end)

H.test("sload with corrupt state.json does not error", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write("not json {{{")
    f:close()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    mod.sload()
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("sload with missing state.json does not error", function()
  local backup = backup_file("scripts/state.json")
  os.remove("scripts/state.json")
  local ok = pcall(mod.sload)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("sload with empty state object does not error", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write("{}")
    f:close()
    mod.__setScriptData({ start = "1", nodes = { ["1"] = { text = "a" } } })
    mod.__setCurrentUI(M.layer("game"))
    mod.vn.currentNode = "1"
    mod.sload()
    H.eq(#mod.vn.currentChoices, 0)
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.test("initSload returns false for corrupt state", function()
  local backup = backup_file("scripts/state.json")
  local ok = pcall(function()
    local f = io.open("scripts/state.json", "w")
    f:write("garbage{{")
    f:close()
    H.eq(mod.initSload(), false)
  end)
  restore_file("scripts/state.json", backup)
  H.truthy(ok)
end)

H.describe("game.lua prof")

H.test("prof is disabled by default", function()
  H.eq(mod.prof.enabled, false)
end)

H.test("prof.start enables and mark records entries", function()
  mod.prof.buf = {}
  mod.prof.start()
  H.eq(mod.prof.enabled, true)
  mod.prof.mark("a")
  mod.prof.mark("b")
  H.eq(#mod.prof.buf, 2)
end)

H.test("prof.flush clears buffer", function()
  mod.prof.buf = {}
  mod.prof.enabled = true
  mod.prof.mark("a")
  mod.prof.mark("b")
  mod.prof.flush()
  H.eq(#mod.prof.buf, 0)
  H.eq(mod.prof.enabled, false)
end)

H.test("prof.mark no-op when disabled", function()
  mod.prof.enabled = false
  mod.prof.buf = {}
  mod.prof.mark("x")
  H.eq(#mod.prof.buf, 0)
end)

H.describe("game.lua onFrame")

H.test("onFrame runs without error", function()
  local ok = pcall(mod.onFrame, 0.016)
  H.truthy(ok)
end)

H.finish()
