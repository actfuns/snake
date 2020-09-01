local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(oPlayer, target, iCostAmount, mArgs)
    local iRoleType = oPlayer.m_oBaseCtrl:GetRoleType()
    local res = require "base.res"
    local mConfig = res["daobiao"]["huodong"]["zeroyuan"]["config"][1]
    local iShiZhuangDay = mConfig.shizhuang_limit
    local iSZ = mConfig.shizhuang[iRoleType]
    oPlayer:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    oWaiGuan:SetShiZhuangByID(iSZ, { opentime = iShiZhuangDay*24*3600 })
    oWaiGuan:SetCurSZ(iSZ)
    oWaiGuan:GS2CRefreshShiZhuang(iSZ)
    oPlayer:SyncModelInfo()
    return true
end

function CItem:CanUseOnKS()
    return false
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
