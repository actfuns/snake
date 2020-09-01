local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local itembase = import(service_path("item/equip/equipbase"))
local itemdefines = import(service_path("item.itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines")) 


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

local MAX_GROW_LEVEL = 50

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    o.m_iGrowLevel = 30
    o.m_iContainerType = nil
    return o
end

function CItem:Load(mData)
    super(CItem).Load(self, mData)
    self.m_iGrowLevel = mData.growlevel or 30
end

function CItem:Save()
    local mData = super(CItem).Save(self)
    mData.growlevel = self.m_iGrowLevel
    return mData
end

function CItem:OnLogin(oPlayer, bReEnter)
    local iType = self.m_iContainerType
    if iType then
        self:OnSetContainer(iType)
    end
end

function CItem:OnSetContainer(iType)
    self.m_iContainerType = iType
    if not self:CanLevelUp() then return end

    self:_CheckGrowLevel(iType)
end

function CItem:_CheckGrowLevel(iType)
    local oContainer = self.m_Container
    if not oContainer then return end

    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
        
    local iID = self:ID()
    local iWh = oContainer.m_ID 

    self:CheckGrowLevel(oPlayer, {type=iType, wh=iWh, cancel_tip=true})
    local func 
    func = function ()
        local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oOwner then return end

        local oItem
        if iType == itemdefines.CONTAINER_MAP.ITEM_CTRL then
            oItem = oOwner.m_oItemCtrl:HasItem(iID, true)
        elseif iType == itemdefines.CONTAINER_MAP.ITEM_TMP_CTRL  then
            oItem = oOwner.m_mTempItemCtrl:HasItem(iID)
        elseif iType == itemdefines.CONTAINER_MAP.WH_CTRL then
            local oWh = oOwner.m_oWHCtrl:GetWareHouse(iWh)
            if not oWh then return end

            oItem = oWh:HasItem(iID)
        end         

        if oItem then
            if oItem:CanLevelUp() then
                oItem:CheckGrowLevel(oOwner, {type=iType, wh=iWh})
            else
                oOwner:DelEvent(oItem, gamedefines.EVENT.ON_UPGRADE)
            end
        end
    end
    if self:CanLevelUp() then
        oPlayer:AddEvent(self, gamedefines.EVENT.ON_UPGRADE, func)
    end
end

function CItem:CanLevelUp()
    if self:GrowLevel() >= self:MaxGrowLevel() then
        return false
    end
    return true
end

function CItem:CanWield(oPlayer)
    return true
end

function CItem:CheckGrowLevel(oPlayer, mArgs)
    local iMaxLv = self:MaxGrowLevel()
    local iCurrLv = self:GrowLevel()
    local iGrade = oPlayer:GetGrade()
    if iMaxLv <= iCurrLv or iCurrLv >= iGrade then return end

    local iCheckLv = math.min(iGrade, iMaxLv)
    self.m_iGrowLevel = iCheckLv
    global.oItemHandler.m_oEquipMakeMgr:CalLevelUpApply(self, iCurrLv, self:GrowLevel())
    if self:IsWield() then
        self:UnCalApply(oPlayer) 
        self:CalApply(oPlayer)
    end   

    if not mArgs.cancel_tip then
        local sMsg = global.oToolMgr:GetSystemText({"itemtext"}, 1051, {item=self:TipsName()})
        oPlayer:NotifyMessage(sMsg)
    end
    self:RefreshItem(oPlayer, mArgs)
end


function CItem:RefreshItem(oPlayer, mArgs)
    local iType = mArgs.type
    local iWh = mArgs.wh

    if iType == itemdefines.CONTAINER_MAP.ITEM_CTRL then
        oPlayer.m_oItemCtrl:GS2CAddItem(self, {refresh=1})
    elseif iType == itemdefines.CONTAINER_MAP.ITEM_TMP_CTRL  then
        oPlayer.m_mTempItemCtrl:GS2CItemAmount(self)
    elseif iType == itemdefines.CONTAINER_MAP.WH_CTRL then
        local oWh = oPlayer.m_oWHCtrl:GetWareHouse(iWh)
        if oWh then
            oWh:GS2CUpdateItem(self)
        end
    end         
end

function CItem:GrowLevel()
    return self.m_iGrowLevel
end

function CItem:EquipLevel()
    return self:GrowLevel() // 10 * 10
end

function CItem:MaxGrowLevel()
    return MAX_GROW_LEVEL
end

function CItem:OnDelContainer()
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    
    oPlayer:DelEvent(self, gamedefines.EVENT.ON_UPGRADE)    
end

function CItem:PackEquipInfo()
    local mNet = super(CItem).PackEquipInfo(self)
    mNet.grow_level = self:GrowLevel()
    -- mNet.left_minute = 0
    return mNet
end




