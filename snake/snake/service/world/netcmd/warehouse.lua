local global = require "global"
local skynet = require "skynet"
local extend = require "base/extend"

local gamedefines = import(lualib_path("public/gamedefines"))
local analylog = import(lualib_path("public.analylog"))

local max = math.max
local min = math.min

function GetGlobalData(idx)
    local res = require "base.res"
    local mData = res["daobiao"]["global"][idx]
    local value = mData["value"]
    value = tonumber(value) or 1000000
    return value
end

function C2GSSwitchWareHouse(oPlayer,mData)
    local wid = mData["wid"]
    local oWareHouse = oPlayer.m_oWHCtrl:GetWareHouse(wid)
    if not oWareHouse then
        return
    end
    oWareHouse:Refresh()
end

function C2GSBuyWareHouse(oPlayer,mData)
    local iSilver = GetGlobalData(104)
    if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver,"购买仓库") then
        return
    end
    local oWHCtrl = oPlayer.m_oWHCtrl
    if not oWHCtrl:ValidBuyWareHouse() then
        oPlayer:SendNotification(2008)
        return
    end
    oPlayer.m_oActiveCtrl:ResumeSilver(iSilver,"购买仓库")
    oPlayer.m_oWHCtrl:BuyWareHouse()
    oPlayer:SendNotification(2004)
    analylog.LogSystemInfo(oPlayer, "buy_ware_house", nil, {[gamedefines.MONEY_TYPE.SILVER]=iSilver})
end

function C2GSRenameWareHouse(oPlayer,mData)
    local wid = mData["wid"]
    local sName = mData["name"]
    local oWHCtrl = oPlayer.m_oWHCtrl
    local oWareHouse = oPlayer.m_oWHCtrl:GetWareHouse(wid)
    if not oWareHouse then
        return
    end
    oWareHouse:SetName(sName)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oPlayer.m_iPid,"改名成功")
end

function C2GSWareHouseWithStore(oPlayer,mData)
    local wid = mData["wid"]
    local itemid = mData["itemid"]
    local oWareHouse = oPlayer.m_oWHCtrl:GetWareHouse(wid)
    if not oWareHouse then
        return
    end
    oWareHouse:WithStore(oPlayer.m_oItemCtrl,itemid)
end

function C2GSWareHouseWithDraw(oPlayer,mData)
    local wid = mData["wid"]
    local iPos = mData["pos"]
    local oWareHouse = oPlayer.m_oWHCtrl:GetWareHouse(wid)
    if not oWareHouse then
        return
    end
    oWareHouse:WithDraw(iPos,oPlayer.m_oItemCtrl)
end

function C2GSWareHouseArrange(oPlayer,mData)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    local wid = mData["wid"]
    local oWareHouse = oPlayer.m_oWHCtrl:GetWareHouse(wid)
    if not oWareHouse then
        return
    end
    local oPubMgr = global.oPubMgr
    local sKey = string.format("wharrange%d",wid)
    if oPlayer.m_oThisTemp:Query(sKey) then
        oNotifyMgr:Notify(pid,"道友~淡定淡定~稍等几秒")
        return
    end
    oPlayer.m_oThisTemp:Set(sKey,1,3)
    oPubMgr:Arrange(oPlayer.m_iPid,oWareHouse)
end
