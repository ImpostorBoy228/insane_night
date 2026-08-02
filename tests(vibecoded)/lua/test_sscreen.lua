-- Tests for scripts/sscreen.lua (main menu)
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()
M.load_module("scripts/sscreen.lua", {})

local function build_menu()
  local ui = M.layer("menu")
  M.state.registered["menu"](ui)
  return ui
end

local function rects_in(ui)
  local out = {}
  for _, item in ipairs(ui.items) do
    if item.kind == "rect" then table.insert(out, item) end
  end
  return out
end

H.describe("sscreen.lua (menu)")

H.test("registers a menu scene", function()
  H.eq(type(M.state.registered["menu"]), "function")
end)

H.test("menu scene builds a background image", function()
  local ui = build_menu()
  local imgs = 0
  for _, item in ipairs(ui.items) do
    if item.kind == "image" then imgs = imgs + 1 end
  end
  H.eq(imgs, 1)
end)

H.test("menu scene builds three buttons", function()
  local ui = build_menu()
  H.eq(#rects_in(ui), 3)
end)

H.test("start button switches to gay", function()
  local ui = build_menu()
  local r = rects_in(ui)[1]
  H.truthy(r.click, "start button should have a click handler")
  r.click()
  H.eq(M.state.switches[#M.state.switches], "gay")
end)

H.test("settings button switches to settings", function()
  local ui = build_menu()
  local r = rects_in(ui)[2]
  H.truthy(r.click, "settings button should have a click handler")
  r.click()
  H.eq(M.state.switches[#M.state.switches], "settings")
end)

H.test("quit button calls fuckOff", function()
  local ui = build_menu()
  local r = rects_in(ui)[3]
  H.truthy(r.click, "quit button should have a click handler")
  r.click()
  H.eq(M.state.fucked, true)
end)

H.test("menu has a start label", function()
  local ui = build_menu()
  local found = false
  for _, item in ipairs(ui.items) do
    if item.kind == "text" and item.text == "Lets fucking go" then found = true end
  end
  H.truthy(found)
end)

H.test("menu has settings and quit labels", function()
  local ui = build_menu()
  local texts = {}
  for _, item in ipairs(ui.items) do
    if item.kind == "text" then table.insert(texts, item.text) end
  end
  H.truthy(texts[2] == "Settings" or texts[3] == "Settings", "has Settings label")
  H.truthy(texts[3] == "FUCK GET ME OUT!!11!" or texts[4] == "FUCK GET ME OUT!!11!", "has quit label")
end)

H.finish()
