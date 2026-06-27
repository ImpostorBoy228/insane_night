local ui = engine:addUILayer("ui")

ui:addText(engine:getTextGooner(), "Hello from Lua!", 50, 50, 0xffffffff, 0)
ui:addRectangle(engine:getRectGooner(), 50, 50, 150, 30, 0xff0000ff, 0)

local tex = loadTexture("test.png")
if tex.idx ~= 65535 then
    ui:addImage(engine:getImageGooner(), tex, 200, 200, 48, 48, 0xffffffff, 0)
end

print("init.lua done")
