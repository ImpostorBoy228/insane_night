local vn = {
    bg = nil,
    characters = {},
    textbox = nil,
    namebox = nil,
    currentDialogue = {},
    currentLine = 1,
    flags = {},
    history = {}
}

local g = {
    text = getTextGooner(),
    rect = getRectGooner(),
    image = getImageGooner()
}

register("gay", function(ui)
    setFont("assets/HackRegular-gX84.ttf", 24)

    local bg = loadTexture("assets/background.png")
    if bg.idx ~= 65535 then
        vn.bg = ui:addImageF(g.image, bg, 0, 0, 1, 1, 0xffffffff, -10)
    end

    ui:addRectF(g.rect, 0.08, 0.75, 0.84, 0.18, 0xcc111111, 0)
    ui:addTextF(g.text, "Game scene works now", 0.12, 0.79, 0xffffffff, 1)
    ui:addTextF(g.text, "Click below to return to menu", 0.12, 0.84, 0xffd0d0d0, 1)

    local back = ui:addRectF(g.rect, 0.08, 0.08, 0.18, 0.07, 0xffffffff, 0)
    back:onClick(function()
        switchTo("menu")
    end)
    ui:addTextF(g.text, "Back", 0.135, 0.10, 0xff000000, 1)
end)
