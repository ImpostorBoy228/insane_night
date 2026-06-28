setFullscreen(true)

local ui = addUILayer("ui")

local bg = loadTexture("assets/background.png")
if bg.idx ~= 65535 then
    ui:addImageF(getImageGooner(), bg, 0, 0, 1, 1, 0xffffffff, -1)
end

local r = ui:addRectF(getRectGooner(), 0.5, 0.40, 0.16, 0.07, 0xffffffff, 0)
r:onClick(function()
    print("rect clicked")
end)


print("sscreen ready")
