setFullscreen(false)
local scenes = {}
local currentScene = nil

function register(name, fn)
    scenes[name] = fn
end

function switchTo(name)
    if currentScene then
        currentScene.visible = false
    end

    local layerName = "scene_" .. name
    local ui = getUILayer(layerName)
    if not ui then
        ui = addUILayer(layerName)
    end

    ui:clear()

    ui.visible = true
    currentScene = ui

    local fn = scenes[name]
    if fn then fn(ui) end
end


dofile("scripts/sscreen.lua")
dofile("scripts/settings.lua")

switchTo("menu")
