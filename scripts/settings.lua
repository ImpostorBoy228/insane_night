local g = {
    text = getTextGooner(),
    rect = getRectGooner()
}

local json = dofile("scripts/libs/json.lua")
local SETTINGS_PATH = "scripts/settings.json"

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function writeJsonFile(path, data)
    local file = io.open(path, "w")
    if not file then
        print("Could not open settings file for writing: " .. tostring(path))
        return false
    end

    local encoded = json.encode(data)
    if not encoded then
        file:close()
        print("Could not encode settings json")
        return false
    end

    file:write(encoded)
    file:close()
    return true
end

local function parseSettingsFile(path)
    local content = readFile(path)
    if not content or content == "" then
        return {}
    end

    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" then
        print("Invalid settings json in " .. tostring(path))
        return {}
    end

    return data
end

function jsonWriteFile(path, key, value)
    local data = parseSettingsFile(path)
    data[key] = value
    return writeJsonFile(path, data)
end

function loadSettings()
    local data = parseSettingsFile(SETTINGS_PATH)

    if type(data.fullscreen) == "boolean" then
        Settings.fullscreen = data.fullscreen
    end

    if type(data.volume) == "number" then
        Settings.volume = data.volume
    end

    if type(data.framelimit) == "number" then
        Settings.framelimit = data.framelimit
    end
end

function saveSettings()
    return writeJsonFile(SETTINGS_PATH, Settings)
end

local function boolLabel(value)
    if value then
        return "On"
    end

    return "Off"
end

local function frameLimitLabel(value)
    if value == -1 then
        return "VSync"
    end

    if value == 0 then
        return "Unlimited"
    end

    return tostring(value)
end

local function nextFrameLimit(value)
    if value == -1 then
        return 0
    end

    if value == 0 then
        return 30
    end

    if value == 30 then
        return 60
    end

    if value == 60 then
        return 120
    end

    return -1
end

local function addButton(ui, x, y, w, h, label, onClick)
    local button = ui:addRectF(g.rect, x, y, w, h, 0xffffffff, 0)
    button:onClick(onClick)
    ui:addTextF(g.text, label, x + 0.02, y + 0.02, 0xff000000, 1)
    return button
end

local function applyAndSaveSettings()
    applySettings()
    saveSettings()
end

register("settings", function(ui)
    setFont("assets/HackRegular-gX84.ttf", 24)

    local bg = loadTexture("assets/background.png")
    if bg.idx ~= 65535 then
        ui:addImageF(getImageGooner(), bg, 0, 0, 1, 1, 0xffffffff, -1)
    end

    ui:addTextF(g.text, "Settings", 0.38, 0.12, 0xffffffff, 1)

    addButton(ui, 0.28, 0.26, 0.44, 0.07, "Fullscreen: " .. boolLabel(Settings.fullscreen), function()
        Settings.fullscreen = not Settings.fullscreen
        applyAndSaveSettings()
        switchTo("settings")
    end)

    addButton(ui, 0.28, 0.37, 0.44, 0.07, "Frame limit: " .. frameLimitLabel(Settings.framelimit), function()
        Settings.framelimit = nextFrameLimit(Settings.framelimit)
        applyAndSaveSettings()
        switchTo("settings")
    end)

    addButton(ui, 0.28, 0.48, 0.44, 0.07, string.format("Volume: %.1f", Settings.volume), function()
        local nextVolume = Settings.volume + 0.1
        if nextVolume > 1.0 then
            nextVolume = 0.0
        end

        Settings.volume = math.floor(nextVolume * 10 + 0.5) / 10
        applyAndSaveSettings()
        switchTo("settings")
    end)

    addButton(ui, 0.28, 0.62, 0.44, 0.07, "Back", function()
        switchTo("menu")
    end)
end)
