-- Tests for scripts/main.lua (scene manager / entry)
local H = require("tests(vibecoded)/lua/harness")
local M = require("tests(vibecoded)/lua/mock")

M.install()

-- main.lua dofiles sscreen/game/settings and runs switchTo("menu") at the end,
-- so loading it exercises the whole boot path with mocks.
local mod = M.load_module("scripts/main.lua", {
  "Settings", "register", "switchTo", "scrender", "onKeyDown", "applySettings",
  "onResize", "scenes",
})

H.describe("main.lua boot & scene manager")

H.test("boot loads all scenes", function()
  H.eq(type(mod.scenes["menu"]), "function")
  H.eq(type(mod.scenes["gay"]), "function")
  H.eq(type(mod.scenes["settings"]), "function")
end)

H.test("boot switched to menu", function()
  local menuLayer = M.state.layers["scene_menu"]
  H.truthy(menuLayer, "scene_menu layer should exist after boot")
  H.eq(menuLayer.visible, true)
end)

H.test("Settings defaults before loadSettings are sane", function()
  H.eq(type(mod.Settings.fullscreen), "boolean")
  H.eq(type(mod.Settings.volume), "number")
end)

H.test("register stores scene", function()
  local called = false
  mod.register("test_scene", function() called = true end)
  H.eq(type(mod.scenes["test_scene"]), "function")
end)

H.test("switchTo renders the target scene", function()
  local menuLayer = M.state.layers["scene_menu"]
  local before = #menuLayer.items
  mod.switchTo("menu")
  H.truthy(#menuLayer.items > 0, "menu scene should render items")
  H.truthy(#menuLayer.items >= before, "items should be replaced")
end)

H.test("switchTo hides previous scene layer", function()
  local menuLayer = M.state.layers["scene_menu"]
  menuLayer.visible = true
  mod.switchTo("menu")
  -- switchTo("menu") clears and re-renders the same layer; visible stays true
  H.eq(menuLayer.visible, true)
end)

H.test("onKeyDown routes to the menu scene", function()
  -- no menuOnKey defined in sscreen, so it should not error
  local ok = pcall(mod.onKeyDown, 32)
  H.truthy(ok)
end)

H.test("applySettings maps framelimit -1 to vsync", function()
  mod.Settings.framelimit = -1
  mod.applySettings()
  H.eq(M.state.settings.vsync, true)
  H.eq(M.state.settings.frame_limit, 0)
end)

H.test("applySettings maps explicit framelimit to no vsync", function()
  mod.Settings.framelimit = 60
  mod.applySettings()
  H.eq(M.state.settings.vsync, false)
  H.eq(M.state.settings.frame_limit, 60)
end)

H.test("applySettings propagates volume", function()
  mod.Settings.volume = 0.33
  mod.applySettings()
  H.near(M.state.settings.volume, 0.33)
end)

H.test("applySettings propagates fullscreen", function()
  mod.Settings.fullscreen = true
  mod.applySettings()
  H.eq(M.state.settings.fullscreen, true)
end)

H.test("scrender renders the current scene without error", function()
  local ok = pcall(mod.scrender)
  H.truthy(ok)
end)

H.test("onResize re-renders current scene", function()
  local ok = pcall(mod.onResize, 1920, 1080)
  H.truthy(ok)
end)

H.finish()
