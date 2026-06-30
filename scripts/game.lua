---@diagnostic disable: undefined-global, undefined-field

local json = dofile("scripts/libs/json.lua")

local vn = {
    currentNode = nil,
    currentBg = nil,
    currentPage = 1,
    currentSound = nil,
    currentSoundId = 0,
    history = {}
}

local Los_Penguinos_me_la_van_a_Mascar = {
    dialogue = {
        Kawasaki = { x = 0, y = 0.7, w = 1, h = 0.3 },
        topLine = { h = 0.004, color = 0x70ffffff }, -- cancer tech
        Cago = { x = 0.05, y = 0.75, right = 0.95, bottom = 1 },
        Krico = { x = 0.07, y = 0.65, h = 0.05, maxWidth = 0.5, paddingPx = 36, textInset = 0.014, textY = 0.65 + (0.05 / 3) },
        Estriper = { x = 0.925, y = 0.905 }
    }
}

-- vn ui
local g = {
    text = getTextGooner(),
    textSmall = getTextGooner("assets/HackRegular-gX84.ttf", 18),
    textOk = getTextGooner("assets/HackRegular-gX84.ttf", 20),
    rect = getRectGooner(),
    image = getImageGooner(),
    audio = getAudioEngine()
}

local script = {
    start = "start",
    nodes = {
        start = {
            text = "script.json not loaded"
        }
    }
}

local function readlike_book(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function script()
    local raw = readlike_book("scripts/script.json")
    if not raw then
        print("Could not read scripts/script.json")
        return false
    end

    local ok, data = pcall(json.decode, raw)
    if not ok then
        print("Fuck your scripts/script.json: " .. tostring(data))
        return false
    end

    if type(data) ~= "table" or type(data.nodes) ~= "table" or type(data.start) ~= "string" then
        print("scripts/script.json has invalid format")
        return false
    end

    if type(data.nodes[data.start]) ~= "table" then
        print("Forgot to define start node: " .. tostring(data.start))
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

local function background(ui, node, x, y, w, h)
    local bgPath = node.bg or vn.currentBg
    if not bgPath then
        return
    end

    vn.currentBg = bgPath

    local bg = loadTexture(bgPath)
    if bg.idx ~= 65535 then
        ui:addImageF(g.image, bg, x, y, w, h, 0xffffffff, -10)
    else
        ui:addRectF(g.rect, x, y, w, h, 0xff111111, -10)
    end
end

local function image(ui, node, x, y, w, h)
    local bgPath = node.bg
    if not bgPath then
        return
    end

    local tex = loadTexture(bgPath)
    if tex.idx ~= 65535 then
        ui:addImageF(g.image, tex, x, y, w, h, 0xffffffff, -10)
    else
        ui:addRectF(g.rect, x, y, w, h, 0xff111111, -10)
    end
end

local function splitExplicitLines(text)
    local normalized = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}

    for line in (normalized .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end

    if #lines == 0 then
        return { "" }
    end

    return lines
end

local function wrapParagraph(gooner, paragraph, maxWidth)
    if paragraph == "" then
        return { "" }
    end

    local lines = {}
    local currentLine = ""

    for word in paragraph:gmatch("%S+") do
        local candidate = currentLine == "" and word or (currentLine .. " " .. word)
        if currentLine == "" or gooner:measureText(candidate) <= maxWidth then
            currentLine = candidate
        else
            table.insert(lines, currentLine)
            currentLine = word
        end
    end

    if currentLine == "" then
        currentLine = paragraph
    end

    table.insert(lines, currentLine)
    return lines
end

local function wrapText(gooner, text, maxWidth)
    local wrappedLines = {}

    for _, paragraph in ipairs(splitExplicitLines(text)) do
        local lines = wrapParagraph(gooner, paragraph, maxWidth)
        for _, line in ipairs(lines) do
            table.insert(wrappedLines, line)
        end
    end

    if #wrappedLines == 0 then
        table.insert(wrappedLines, "")
    end

    return wrappedLines
end

local function paginateLines(lines, maxLines)
    local pages = {}
    local safeMaxLines = math.max(1, maxLines)
    local index = 1

    while index <= #lines do
        local pageLines = {}
        for _ = 1, safeMaxLines do
            if index > #lines then
                break
            end

            table.insert(pageLines, lines[index])
            index = index + 1
        end
        table.insert(pages, table.concat(pageLines, "\n"))
    end

    if #pages == 0 then
        pages[1] = ""
    end

    return pages
end

local function buildDialoguePages(text)
    local textBox = Los_Penguinos_me_la_van_a_Mascar.dialogue.Cago
    local textAreaWidth = (textBox.right - textBox.x) * getScreenWidth()
    local textAreaHeight = (textBox.bottom - textBox.y) * getScreenHeight()
    local maxLines = math.floor(textAreaHeight / g.textSmall:getLineHeight())
    local wrappedLines = wrapText(g.textSmall, text or "", textAreaWidth)
    return paginateLines(wrappedLines, maxLines)
end

local function getSpeakerWidth(text)
    local speaker = Los_Penguinos_me_la_van_a_Mascar.dialogue.Krico
    local speakerWidthPixels = g.text:measureText(text) + speaker.paddingPx
    return math.min(speaker.maxWidth, speakerWidthPixels / getScreenWidth())
end

local function syncSound(node)
    if node.sound == nil then
        return
    end

    local nextSound = node.sound
    if nextSound == "" then
        nextSound = nil
    end

    if vn.currentSound == nextSound then
        return
    end

    if vn.currentSoundId and vn.currentSoundId ~= 0 then
        g.audio:stopSound(vn.currentSoundId)
        vn.currentSoundId = 0
    end

    vn.currentSound = nextSound
    if nextSound then
        vn.currentSoundId = g.audio:playSound(nextSound, true)
        if vn.currentSoundId == 0 then
            print("Could not play sound: " .. tostring(nextSound))
            vn.currentSound = nil
        end
    end
end

local function nextNode(ui, nextId)
    if not nextId then
        return
    end

    vn.currentNode = nextId
    vn.currentPage = 1
    table.insert(vn.history, vn.currentNode)
    renderGame(ui)
end

function ginit()
    setFont("assets/HackRegular-gX84.ttf", 24)
    script()
    g.audio:stopAllSounds()
    vn.currentBg = nil
    vn.currentPage = 1
    vn.currentSound = nil
    vn.currentSoundId = 0
    vn.history = {}
    vn.currentNode = script.start
    table.insert(vn.history, vn.currentNode)
end

function renderGame(ui)
    ui:clear()

    local node = getNode(vn.currentNode)
    if not node then
        -- error text
        ui:addTextF(g.text, "missing node: " .. tostring(vn.currentNode), 0.1, 0.1, 0xffffffff, 1)
        return
    end

    background(ui, node, 0, 0, 1, 0.7)
    syncSound(node)

    local dialogue = Los_Penguinos_me_la_van_a_Mascar.dialogue
    local panel = dialogue.Kawasaki
    local textBox = dialogue.Cago
    local speaker = dialogue.Krico
    local nextHint = dialogue.Estriper
    local pages = buildDialoguePages(node.text or "")
    local currentPage = math.min(vn.currentPage, #pages)
    local speakerText = node.speaker or node.speaker_name or ""

    -- dialogue panel
    ui:addRectF(g.rect, panel.x, panel.y, panel.w, panel.h, 0xdd101014, 0)

    -- panel top line
    -- ui:addRectF(g.rect, panel.x, panel.y, panel.w, dialogue.topLine.h, dialogue.topLine.color, 1)

    if speakerText ~= "" then
        local speakerWidth = getSpeakerWidth(speakerText)

        -- speaker plate
        ui:addRectF(g.rect, speaker.x, speaker.y, speakerWidth, speaker.h, 0xffe8e8e8, 2)

        -- speaker label
        ui:addTextF(g.text, speakerText, speaker.x + speaker.textInset, speaker.textY, 0xff101014, 3)
    end

    -- dialogue text
    ui:addTextF(g.textSmall, pages[currentPage], textBox.x, textBox.y, 0xffffffff, 3)

    if currentPage < #pages or node.next then
        -- next hitbox
        local nextBtn = ui:addRectF(g.rect, panel.x, panel.y, panel.w, panel.h, 0x00000000, 10)
        nextBtn:onClick(function()
            if currentPage < #pages then
                vn.currentPage = currentPage + 1
                renderGame(ui)
            else
                nextNode(ui, node.next)
            end
        end)
    end
end

register("gay", function(ui)
    if not vn.currentNode then
        ginit()
    end
    renderGame(ui)
end)
--
