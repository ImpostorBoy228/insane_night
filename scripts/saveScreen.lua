register("saveScreen", function()
    setFont("assets/HackRegular-gX84.ttf", 24)
    local bg = loadTexture("assets/bal.png")
    if bg.idx ~= 65535 then
        ui:addImageF(getImageGooner(), bg, 0, 0, 1, 1, 0xffffffff, -1)
    end
end)
