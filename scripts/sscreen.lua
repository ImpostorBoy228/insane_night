setFullscreen(false)

local start = addUILayer("start")

local bg = loadTexture("assets/background.png")
if bg.idx ~= 65535 then
    start:addImageF(getImageGooner(), bg, 0, 0, 1, 1, 0xffffffff, -1)
end

local r1 = start:addRectF(getRectGooner(), 0.5 - 0.16/2, 0.3 - 0.07/2, 0.4, 0.07, 0xffffffff, 0)
r1:onClick(function()
    print("rect clicked")
end)
local t1 = start:addTextF(getTextGooner(), "Lets fucking go", 0.42, 0.28, 0xff000000, 1)


local r2 = start:addRectF(getRectGooner(), 0.5 - 0.16/2, 0.4 - 0.07/2, 0.4, 0.07, 0xffffffff, 0)
r2:onClick(function()
    print("rect clicked")
end)
local t2 = start:addTextF(getTextGooner(), "Settings idk", 0.42, 0.38, 0xff000000, 1)


local r3 = start:addRectF(getRectGooner(), 0.5 - 0.16/2, 0.5 - 0.07/2, 0.4, 0.07, 0xffffffff, 0)
r3:onClick(function()
    fuckOff()
end)
local t2 = start:addTextF(getTextGooner(), "FUCK GET ME OUT!!11!", 0.42, 0.48, 0xff000000, 1)

print("fuck me pls")
