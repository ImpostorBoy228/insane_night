local json = dofile("scripts/libs/json.lua")

local vn = {
    currentNode = nil,
    currentBg = nil,
    history = {}
}

local g = {
    text = getTextGooner(),
    textSmall = getTextGooner("assets/HackRegular-gX84.ttf", 18),
    textOk = getTextGooner("assets/HackRegular-gX84.ttf", 20),
    rect = getRectGooner(),
    image = getImageGooner()
}

local script = {
    start = "start",
    nodes = {
        start = {
            text = "script.json not loaded"
        }
    }
}

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function script()
    local raw = readFile("scripts/script.json")
    if not raw then
        print("Could not read scripts/script.json")
        return false
    end

    local ok, data = pcall(json.decode, raw)
    if not ok then
        print("Invalid scripts/script.json: " .. tostring(data))
        return false
    end

    if type(data) ~= "table" or type(data.nodes) ~= "table" or type(data.start) ~= "string" then
        print("scripts/script.json has invalid format")
        return false
    end

    if type(data.nodes[data.start]) ~= "table" then
        print("Start node does not exist: " .. tostring(data.start))
        return false
    end

    script = data
    return true
end

local function getNode(id)
    if not id then
        return nil
    end

    return script.nodes[id]
end

local function background(ui, node)
    local bgPath = node.bg or vn.currentBg
    if not bgPath then
        return
    end

    vn.currentBg = bgPath

    local bg = loadTexture(bgPath)
    if bg.idx ~= 65535 then
        ui:addImageF(g.image, bg, 0, 0, 1, 1, 0xffffffff, -10)
    else
        ui:addRectF(g.rect, 0, 0, 1, 1, 0xff111111, -10)
    end
end

local function renderGame(ui)
    ui:clear()

    local node = getNode(vn.currentNode)
    if not node then
        ui:addTextF(g.text, "Dialogue node not found: " .. tostring(vn.currentNode), 0.1, 0.1, 0xffffffff, 1)
        return
    end

    background(ui, node)

    -- bottom dialogue panel
    ui:addRectF(g.rect, 0, 0.8, 1, 0.20, 0xcc111111, 0)

    if node.speaker and node.speaker ~= "" then
        -- speaker nameplate background
        ui:addRectF(g.rect, 0.06, 0.76, 0.22, 0.04, 0xffe0e0e0, 1)
        -- speaker name text
        ui:addTextF(g.text, node.speaker, 0.07, 0.77, 0xff000000, 2)
    end

    -- main dialogue text
    ui:addTextF(g.textSmall, node.text or "", 0.06, 0.85, 0xffffffff, 2)

    -- -- button background for returning to the main menu
    -- local back = ui:addRectF(g.rect, 0.08, 0.08, 0.18, 0.07, 0xffffffff, 0)
    -- back:onClick(function()
    --     switchTo("menu")
    -- end)
    -- back button label
    -- ui:addTextF(g.text, "Fuck", 0.135, 0.10, 0xff000000, 1)

    if node.next then
        -- ui:addTextF(g.text, ">", 0.885, 0.86, 0xffd0d0d0, 2)

        -- invisible clickable area to advance the dialogue
        local nextBtn = ui:addRectF(g.rect, 0, 0.8, 1, 0.20, 0x00000000, 3)
        nextBtn:onClick(function()
            vn.currentNode = node.next
            table.insert(vn.history, vn.currentNode)
            renderGame(ui)
        end)
    else
        -- ui:addTextF(g.text, "End", 0.84, 0.86, 0xffd0d0d0, 2)
    end
end

register("gay", function(ui)
    setFont("assets/HackRegular-gX84.ttf", 24)
    script()
    vn.currentBg = nil
    vn.history = {}
    vn.currentNode = script.start
    table.insert(vn.history, vn.currentNode)
    renderGame(ui)
end)
