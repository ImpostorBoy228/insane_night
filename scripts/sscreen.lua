local ui = addUILayer("ui")

-- фон на весь экран (zindex = -1 — позади всего)
local bg = loadTexture("assets/background.png")
if bg.idx ~= 65535 then
    ui:addImage(getImageGooner(), bg, 0, 0, 1280, 720, 0xffffffff, -1)
end

local btn = ui:addRectangle(getRectGooner(), 540, 360, 200, 50, 0x4444ffff, 0)
ui:addText(getTextGooner(), "go", 590, 370, 0xffffffff, 1)
ui:addClickable(540, 360, 200, 50, function()
    print("go clicked")
end)

print("sscreen ready")
