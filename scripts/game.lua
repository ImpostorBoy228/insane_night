local json = dofile("scripts/libs/json.lua")

local vn = {
    currentNode = nil,
    currentBg = nil,
    currentPage = 1,
    history = {}
}

local g = {
    text = getTextGooner(),
    textSmall = getTextGooner("assets/HackRegular-gX84.ttf", 18),
    textOk = getTextGooner("assets/HackRegular-gX84.ttf", 20),
    rect = getRectGooner(),
    image = getImageGooner()
}

local layout = {
    dialogue = {
        panel = { x = 0.04, y = 0.68, w = 0.92, h = 0.28 },
        nameplate = { x = 0.07, y = 0.63, h = 0.055 },
        text = { x = 0.075, y = 0.76, right = 0.915, bottom = 0.92 },
        indicator = { x = 0.90, y = 0.915 }
    }
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
    local textAreaWidth = (layout.dialogue.text.right - layout.dialogue.text.x) * getScreenWidth()
    local textAreaHeight = (layout.dialogue.text.bottom - layout.dialogue.text.y) * getScreenHeight()
    local maxLines = math.floor(textAreaHeight / g.textSmall:getLineHeight())
    local wrappedLines = wrapText(g.textSmall, text or "", textAreaWidth)
    return paginateLines(wrappedLines, maxLines)
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

function renderGame(ui)
    ui:clear()

    local node = getNode(vn.currentNode)
    if not node then
        ui:addTextF(g.text, "Dialogue node not found: " .. tostring(vn.currentNode), 0.1, 0.1, 0xffffffff, 1)
        return
    end

    background(ui, node)

    local panel = layout.dialogue.panel
    local textBox = layout.dialogue.text
    local nameplate = layout.dialogue.nameplate
    local pages = buildDialoguePages(node.text or "")
    local currentPage = math.min(vn.currentPage, #pages)
    local speakerText = node.speaker or ""

    ui:addRectF(g.rect, panel.x, panel.y, panel.w, panel.h, 0xdd101014, 0)
    ui:addRectF(g.rect, panel.x, panel.y, panel.w, 0.004, 0x70ffffff, 1)

    if speakerText ~= "" then
        local speakerWidthPixels = g.text:measureText(speakerText) + 36
        local speakerWidth = math.min(0.28, speakerWidthPixels / getScreenWidth())
        ui:addRectF(g.rect, nameplate.x, nameplate.y, speakerWidth, nameplate.h, 0xffe8e8e8, 2)
        ui:addTextF(g.text, speakerText, nameplate.x + 0.014, nameplate.y + 0.008, 0xff101014, 3)
    end

    ui:addTextF(g.textSmall, pages[currentPage], textBox.x, textBox.y, 0xffffffff, 3)

    if #pages > 1 then
        ui:addTextF(g.textOk, string.format("%d/%d", currentPage, #pages), layout.dialogue.indicator.x,
            layout.dialogue.indicator.y, 0xffd0d0d0, 3)
    elseif node.next then
        ui:addTextF(g.textOk, ">", layout.dialogue.indicator.x, layout.dialogue.indicator.y, 0xffd0d0d0, 3)
    end

    if currentPage < #pages or node.next then
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
    setFont("assets/HackRegular-gX84.ttf", 24)
    script()
    vn.currentBg = nil
    vn.currentPage = 1
    vn.history = {}
    vn.currentNode = script.start
    table.insert(vn.history, vn.currentNode)
    renderGame(ui)
end)
