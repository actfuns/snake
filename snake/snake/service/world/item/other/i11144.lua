local global = require "global"
local skynet = require "skynet"
local itembase = import(service_path("item/other/otherbase"))

local sKey = "use_11144"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:TrueUse(who, target)
    local iAlreadyUse = who:Query(sKey, 0)
    if iAlreadyUse >= 5 then
        local sText = global.oItemHandler:GetTextData(1049)
        global.oNotifyMgr:Notify(who:GetPid(), sText)
        return
    end

    who:Set(sKey, iAlreadyUse+1)

    local iAmount = self:GetUseCostAmount()
    -- self:AddAmount(-iAmount)
    who:RemoveOneItemAmount(self, iAmount)
    self:GS2CConsumeMsg(who)

    local oFriend = who:GetFriend()
    oFriend:ExtendFriendCnt(10)
    local sText = global.oItemHandler:GetTextData(1050)
    global.oNotifyMgr:Notify(who:GetPid(), sText)
    return true
end

function CItem:CanUseOnKS()
    return false
end


