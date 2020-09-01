local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)


-- 九命猫元神 直接获得坐骑
function CItem:New(sid)
    local o = super(CItem).New(self, sid)
    return o
end

function CItem:TrueUse(who,target)
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(who)
    -- TODO 加个物品使用
    if not global.oToolMgr:IsSysOpen("RIDE_SYS", who, true) then
        local res = require "base.res"
        local mData = res["daobiao"]["open"]["RIDE_SYS"]
        who:NotifyMessage(string.format("等级不足#G%s#n级，无法使用", mData["p_level"]))
        return
    end
    who:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    
    who.m_oRideCtrl:ExtendRide(1002, true, "itemuse")
    local oRide = who.m_oRideCtrl:GetRide(1002)
    who:NotifyMessage(string.format("你激活了坐骑：#G%s#n", oRide:GetName()))
    return true
end
