local g = { text = getTextGooner(), rect = getRectGooner() }

register("menu", function(ui)
    setFont("assets/HackRegular-gX84.ttf", 24)

    -- menu background
    local bg = loadTexture("assets/background.png")
    if bg.idx ~= 65535 then
        ui:addImageF(getImageGooner(), bg, 0, 0, 1, 1, 0xffffffff, -1)
    end

    -- start button
    local r1 = ui:addRectF(getRectGooner(), 0.5 - 0.4 / 2, 0.3 - 0.07 / 2, 0.4, 0.07, 0xffffffff, 0)
    r1:onClick(function()
        switchTo("gay")
    end)

    -- start label
    local t1 = ui:addTextF(getTextGooner(), "Lets fucking go", 0.5 - 0.4 / 2, 0.29, 0xff000000, 1)

    -- settings button
    local rS = ui:addRectF(getRectGooner(), 0.5 - 0.4 / 2, 0.4 - 0.07 / 2, 0.4, 0.07, 0xffffffff, 0)
    rS:onClick(function()
        switchTo("settings")
    end)

    -- settings label
    local tS = ui:addTextF(getTextGooner(), "Settings", 0.5 - 0.4 / 2, 0.39, 0xff000000, 1)

    -- quit button
    local r3 = ui:addRectF(getRectGooner(), 0.5 - 0.4 / 2, 0.5 - 0.07 / 2, 0.4, 0.07, 0xffffffff, 0)
    r3:onClick(function()
        fuckOff()
    end)

    -- quit label
    local t2 = ui:addTextF(getTextGooner(), "FUCK GET ME OUT!!11!", 0.5 - 0.4 / 2, 0.49, 0xff000000, 1)

    print("fuck me pls")
end)
