local ui = addUILayer("ui")

ui:addText(getTextGooner(), "Hello from Lua!", 50, 50, 0xffffffff, 0)
ui:addRectangle(getRectGooner(), 50, 50, 150, 30, 0xff0000ff, 0)

local tex = loadTexture("test.png")
if tex.idx ~= 65535 then
    ui:addImage(getImageGooner(), tex, 200, 200, 48, 48, 0xffffffff, 0)
end

-- inline click on a Rect (auto-hitbox from dimensions)
local r = ui:addRectangle(getRectGooner(), 100, 300, 200, 50, 0x4444ffff, 0)
r:onClick(function()
    print("rect clicked")
end)

-- click on Text (hitbox must be set manually)
local t = ui:addText(getTextGooner(), "Click me", 110, 310, 0xffffffff, 1)
t:setHitbox(100, 300, 200, 50)
t:onClick(function()
    print("text clicked")
end)

-- old addClickable still works
ui:addClickable(400, 300, 100, 50, function()
    print("clickable clicked")
end)

print("init.lua done")
