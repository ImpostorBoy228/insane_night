local scenes = {}
local currentScene = nil

Settings = {
    fullscreen = false,
    volume = 1.0,
    framelimit = -1
}

function applySettings()
    setFullscreen(Settings.fullscreen)

    if Settings.framelimit == -1 then
        setVsync(true)
        setFrameLimit(0)
    else
        setVsync(false)
        setFrameLimit(Settings.framelimit)
    end

    setVolume(Settings.volume)
end

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
dofile("scripts/game.lua")
dofile("scripts/settings.lua")

loadSettings()
applySettings()

switchTo("menu")
