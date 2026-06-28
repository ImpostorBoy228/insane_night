local g = { text = getTextGooner(), rect = getRectGooner() }

register("settings", function(ui)
    ui:addTextF(g.text, "SETTINGS", 0.42, 0.2, 0xff000000, 0)
    local back = ui:addRectF(g.rect, 0.42, 0.5, 0.16, 0.07, 0xffffffff, 0)
    back:onClick(function() switchTo("menu") end)
end)
