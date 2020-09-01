local itembase = import(service_path("item/other/i10075"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function CItem:ValidSend(oPlayer, oTarget)
    if oPlayer:GetSex() == oTarget:GetSex() then
        return true
    end
    return false
end
