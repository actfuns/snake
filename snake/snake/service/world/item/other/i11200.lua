local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(oPlayer, target, iCostAmount, mArgs)
    if not global.oToolMgr:IsSysOpen("RIDE_SYS", oPlayer, true) then
        local mData = res["daobiao"]["open"]["RIDE_SYS"]
        oPlayer:NotifyMessage(string.format("等级不足#G%s#n级，无法使用", mData["p_level"]))
        return
    end

    local res = require "base.res"
    local mConfig = res["daobiao"]["huodong"]["zeroyuan"]["config"][1]
    local iRide = mConfig.flyfigureid
    local iDay = mConfig.zuoqi_limit
    local oRide = global.oRideMgr:CreateNewRide(iRide, {valid_day=iDay})
    if oRide then
        oPlayer:RemoveOneItemAmount(self, iCostAmount, "itemuse")
        oPlayer.m_oRideCtrl:AddRide(oRide)
    end
    return true
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
