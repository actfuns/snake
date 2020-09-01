local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item.other.otherbase"))
local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local HUODONG_TREASURE_NAME = "treasure"


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    o.m_iMapType = itemdefines.TREASUREMAP_TYPE_NORMAL
    o.m_iScene = nil
    o:RandomPos()
    return o
end

function CItem:RandomPos()
    if not self.m_iScene then
        local oHD = global.oHuodongMgr:GetHuodong("treasure")
        self.m_iScene = oHD:RamdomSceneIdForTreasureMap(self.m_iMapType)
    end
    local iPosx,iPosy= global.oSceneMgr:RandomPos2(self.m_iScene)
    self.m_iPosx = iPosx
    self.m_iPosy = iPosy
end

function CItem:Desc()
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:GetTextData(1001, {"huodong", HUODONG_TREASURE_NAME})
    sText = oToolMgr:FormatColorString(sText, {map = tostring(self.m_iSceneId),x = tostring(self.m_iPosX),y = tostring(self.m_iPosY)})
    return sText
end

function CItem:CanUseOnKS()
    return false
end

function CItem:TrueUse(oPlayer)
    if oPlayer:InWar() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(1047, {"itemtext"}))
        return
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<=0 then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(1046, {"itemtext"}))
        return false
    end
    self:RandomPos()
    local itemid = self.m_ID
    local oCbMgr = global.oCbMgr
    local func = function(oPlayer,mData)
        local func2 = function(oPlayer,mData)
            _StartTreasure(oPlayer,mData,itemid)
        end
        oCbMgr:SetCallBack(oPlayer:GetPid(),"GS2CLoadTreasureProgress",{},nil,func2)
    end
    local mData = {map_id = self.m_iScene,pos_x = self.m_iPosx, pos_y = self.m_iPosy, autotype = 1, functype = gamedefines.FIND_PATH_FUNC_TYPE.TREASURE}
    oCbMgr:SetCallBack(oPlayer:GetPid(),"AutoFindPath",mData,nil,func)
    return true
 end

function CItem:AddAmount(iAmount,sReason,mArgs)
    super(CItem).AddAmount(self,iAmount,sReason,mArgs)
    if  sReason and sReason == "itemuse" and mArgs["owner"] then
        self:GS2CConsumeMsg(mArgs["owner"])
    end
end

function  CItem:PackItemInfo()
    local mRet = super(CItem).PackItemInfo(self)
    mRet["treasuremap_info"] = {{treasure_mapid = self.m_iScene}}
    return mRet
end

function CItem:Load(mData)
    super(CItem).Load(self,mData)
    if mData.scene then
        self.m_iScene = mData.scene
    end
end

function CItem:Save()
    local mData = super(CItem).Save(self)
    mData["scene"] = self.m_iScene
    return mData
end

function _StartTreasure(oPlayer,mData,itemid)
    if oPlayer:InWar() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(1047, {"itemtext"}))
        return
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<=0 then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(1046, {"itemtext"}))
        return false
    end
    local itemobj = oPlayer:HasItem(itemid)
    if not itemobj then return end
    local mItemData = {["sid"] = itemobj.m_SID, ["maptype"] = itemobj.m_iMapType, ["mapid"] = itemobj.m_iScene, ["pos_x"] = itemobj.m_iPosx, ["pos_y"] = itemobj.m_iPosy,["itemid"]=itemobj:ID()}
    local  oBuddy =  global.oHuodongMgr:GetHuodong("treasure")
    oBuddy:StartTreasure(oPlayer, mItemData)
    if itemobj:SID() == 11076 and oPlayer.m_oTodayMorning:Query("treasure_energy",0) < 20 then
        oPlayer:AddEnergy(5,"treasure")
        oPlayer.m_oTodayMorning:Add("treasure_energy",1)
    end
end
