local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local itemnet = import(service_path("netcmd.item"))
local itemdefines = import(service_path("item.itemdefines"))


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,datactrl.CDataCtrl)

CItem.m_ItemType = "base"

function CItem:New(sid)
    local o = super(CItem).New(self)
    o:Init(sid)
    return o
end

function CItem:Release()
    super(CItem).Release(self)
end

function CItem:Init(sid)
    self.m_ID = self:DispatchItemID()
    self.m_SID = sid
    self.m_iAmount = 1
    self.m_iCreateTime = get_time()
    local mItemData = self:GetItemData()
    self:SetData("quality", mItemData["quality"] or 1)
end

function CItem:Setup()
end

function CItem:OnLogin(oPlayer,bReEnter)
    -- body
end

function CItem:SetValidTime(iSec)
    local iEndTime = get_time() + iSec
    self:SetData("Time",iEndTime)
end

function CItem:Validate()
    local iTime = self:GetData("Time", 0)
    if iTime > 0 and iTime <= get_time() then
        return false
    end
    return true
end

function CItem:DispatchItemID()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:DispatchItemID()
end

function CItem:GetItemData()
    local res = require "base.res"
    local mData = res["daobiao"]["item"]
    local mItemData = mData[self.m_SID]
    assert(mItemData,string.format("itembase GetItemData err:%s %s",self.m_SID,self.m_ItemType))
    return mItemData
end

function CItem:Load(mData)
    if not mData then
        return
    end
    self.m_iAmount = mData["amount"] or self.m_iAmount
    self.m_SID = mData["sid"] or self.m_SID
    self.m_mData = mData["data"] or {}
    self.m_iCreateTime = mData["create_time"] or 0
end

function CItem:Save()
    local mData = {}
    mData["amount"] = self.m_iAmount
    mData["sid"] = self.m_SID
    mData["data"] = self.m_mData or {}
    mData["create_time"] = self.m_iCreateTime
    return mData
end

function CItem:Create(mArgs)
    mArgs = mArgs or {}
    if mArgs.quality then
        self:SetData("quality",mArgs.quality)
    end
end

function CItem:CreateFixedItem(iFix, mArgs)
    self:Create(mArgs)
end

function CItem:ID()
    return self.m_ID
end

function CItem:SID()
    return self.m_SID
end

function CItem:Clone(iToPlayerId)
    local sid = self:SID()
    local oNewItem = global.oItemLoader:ExtCreate(sid)
    oNewItem:SetAmount(self:GetAmount())
    if iToPlayerId then
        if self:IsBind() then
            oNewItem:Bind(iToPlayerId)
        end
    end
    return oNewItem
end

function CItem:TaskSID()
    local iTaskSID = self:GetItemData()["taskid"]
    if iTaskSID == 0 then
        return self.m_SID
    end
    return iTaskSID
end

function CItem:Shape()
    return self.m_SID
end

function CItem:Name()
    return self:GetItemData()["name"]
end

function CItem:SalePrice()
    return self:GetItemData()["salePrice"] or 0
end

function CItem:Quality()
    return self:GetData("quality") or 1
end

function CItem:SetQuality(iQuality)
    iQuality = iQuality or 1
    self:SetData("quality", iQuality)
    self:Dirty()
end

function CItem:ItemColor()
    if self:Quality() > 5 then
        return 0
    end
    return self:Quality()
end

function CItem:Star()
    return self:GetData("star")
end

function CItem:GetMaxAmount()
    return self:GetItemData()["maxOverlay"]
end

function CItem:GetAmount()
    return self.m_iAmount or 1
end

function CItem:ItemType()
    return self.m_ItemType
end

function CItem:GetVirtualItemValue()
    if self:ItemType() == "virtual" then
        return self:GetData("value")
    else
        return 0
    end
end

function CItem:SetVirtualItemValue(iVal)
    self:SetData("value",iVal)
end

function CItem:TipsName()
    local res = require "base.res"
    local iColor = self:ItemColor()
    local mItemColor = res["daobiao"]["itemcolor"][iColor]
    assert(iColor, mItemColor, string.format("item color config not exist! id:", iColor))
    return string.format(mItemColor.color, self:Name())
end

function CItem:GetTraceName()
    local iOwner,iTraceNo = table.unpack(self:GetData("TraceNo",{}))
   return string.format("%s %d:<%d,%d>",self:Name(),self:SID(),iOwner,iTraceNo)
end

function CItem:Change2VigorVal()
    local mInfo = self:GetItemData()
    if mInfo.changeToVigorValue and mInfo.changeToVigorValue ~= "" then
        local mEnv = {quality = self:Quality()}
        return math.floor(formula_string(mInfo.changeToVigorValue, mEnv))
    end
    return 0
end

function CItem:SetAmount(iAmount)
    self:Dirty()
    self.m_iAmount = iAmount
    if self.m_iAmount <= 0 then
        if self.m_Container then
            self.m_Container:RemoveItem(self)
            self:OnRemove()
        end
    end
end

function CItem:AddAmount(iAmount,sReason,mArgs)
    assert(iAmount and iAmount ~= 0, string.format("Item:AddAmount amount error: amount:%s", iAmount))
    self:Dirty()
    self.m_iAmount = self.m_iAmount + iAmount

    if self:GetOwner() and global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner()) then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
        if oPlayer.m_oItemCtrl == self.m_Container then
            safe_call(oPlayer.TriggerItemChange,oPlayer,self,iAmount,sReason)
        end
    end

    mArgs = mArgs or {}
    local oOwnCtrller = self.m_Container
    if oOwnCtrller then
        oOwnCtrller:GS2CItemAmount(self, mArgs)
        if self.m_iAmount <= 0 then
            oOwnCtrller:RemoveItem(self)
            self:OnRemove()
        else
            if iAmount > 0 and self:IsQuickUse() and sReason ~= "arrange" then
                if mArgs and mArgs.cancel_quick then return end
                if oOwnCtrller.GS2CItemQuickUse then
                    oOwnCtrller:GS2CItemQuickUse(self)
                end
            end
        end
    end
end

function CItem:OnRemove()
    -- body
end

function CItem:GetOwner()
    if self.m_Container then
        return self.m_Container:GetOwner()
    end
end

function CItem:OnSetContainer(iType)
end

function CItem:OnDelContainer()
end

function CItem:IsTimeItem()
    if self:GetData("Time",0) ~= 0 then
        return true
    end
    return false
end

function CItem:Bind(iOwner)
    self:SetData("Bind",iOwner)
end

function CItem:IsBind()
    if self:GetData("Bind",0) ~= 0 then
        return true
    end
    return false
end

function CItem:CanUseOnKS()
    return true
end

function CItem:ValidUse()
    if self:IsLocked() then
        return false
    end
    if is_ks_server() and not self:CanUseOnKS() then
        return false, global.oToolMgr:GetTextData(1091, {"itemtext"})
    end

    local iAmount = self:GetAmount()
    local iNeedAmount = self:GetUseCostAmount()
    if iAmount < iNeedAmount then
        return false
    end
    return true
end

function CItem:Use(oWho, iTarget, mArgs)
    local bRet, sText = self:ValidUse()
    if not bRet then
        if oWho and sText then
            oWho:NotifyMessage(sText)
        end
        return
    end
    local iCostAmount = self:GetUseCostAmount()
    return self:TrueUse(oWho, iTarget, iCostAmount, mArgs)
end

-- 可否使用扣减
function CItem:CanSubOnWarUse()
    return true
end

-- 需重写
function CItem:TrueUse(oWho, iTarget, iCostAmount, mArgs)
    if oWho then
        oWho:NotifyMessage("该道具无法使用")
    end
end

-- @return: <bool>道具使用是否正常
function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
end

function CItem:GetUseCostAmount()
    local mData = self:GetItemData()
    local iAmount = mData["useCost"] or 1
    return iAmount
end

--同种类型道具数目
function CItem:GetItemAmount()
    if self.m_Container then
        return self.m_Container:GetItemAmount(self:Shape())
    end
end

--是否回收
function CItem:ValidRecycle()
    return (self:SalePrice() > 0 and not self:IsLocked())
end

function CItem:SortNo()
    local iNo = self:GetItemData()["sort"] or 100
    return iNo
end

--key值
function CItem:Key()
    local iKey = 0
    if self:IsBind() then
        iKey = iKey | itemdefines.ITEM_KEY_BIND
    end
    if self:IsTimeItem() then
        iKey = iKey | itemdefines.ITEM_KEY_TIME
    end
    return iKey
end

function CItem:CustomCombineKey()
    return self:Quality() or 0
end

function CItem:CombineKey()
    local iKey = self:CustomCombineKey()
    local iBase = 16
    iKey = self:IsBind() and (iKey + 1<<(iBase)) or iKey
    iKey = self:IsTimeItem() and (iKey + 1<<(iBase+1)) or iKey
    iKey = self:IsGuildItem() and (iKey + 1<<(iBase+2)) or iKey
    --19-21 bit for lock key
    iKey = self:IsLocked() and (iKey + self:GetLockKey() << (iBase+3)) or iKey
    iKey = iKey + 1<<(iBase+6)
    iKey = math.floor(iKey)
    return iKey
end

function CItem:ValidCombine(oSrcItem)
    if self:IsLocked() or oSrcItem:IsLocked() then
        return false
    end
    if self:IsBind() ~= oSrcItem:IsBind() then
        return false
    end
    if self:IsTimeItem() or oSrcItem:IsTimeItem() then
        return false
    end
    if self:IsGuildItem() ~= oSrcItem:IsGuildItem() then
        return false
    end
    if self:Quality() ~= oSrcItem:Quality() then
        return false
    end
    return true
end

function CItem:AfterCombine(mSrcItemSaveData)
    local iGuildBuyPrice = table_get_depth(mSrcItemSaveData, {"data", "guild_buy_price"})
    if iGuildBuyPrice then
        self:SetData("guild_buy_price", math.min(self:GetData("guild_buy_price", iGuildBuyPrice), iGuildBuyPrice))
    end
    local iStallBuyPrice = table_get_depth(mSrcItemSaveData, {"data", "stall_buy_price"})
    if iStallBuyPrice then
        self:SetData("stall_buy_price", math.min(self:GetData("stall_buy_price", iStallBuyPrice), iStallBuyPrice))
    end
end

function CItem:IsGuildItem()
    return self:GetData("guild_buy_price", 0) > 0
end

function CItem:IsStallItem()
    return self:GetData("stall_buy_price", 0) > 0
end

function CItem:ApplyInfo()
    local mData = {}
    return mData
end

function CItem:Desc()
    return ""
end

function CItem:Refresh()
    local mArgs = {refresh = 1} -- refresh前端处理不显示落袋动画
    local oOwnCtrller = self.m_Container
    if oOwnCtrller then
        oOwnCtrller:GS2CAddItem(self, mArgs)
    end
end

function CItem:IsHunShi()
    return false
end

--快捷使用
function CItem:IsQuickUse( ... )
    local iQuickUse = self:GetItemData()["quickable"] or 0
    if iQuickUse == 1 then
        return true
    end
    return false
end

--能否给予
function CItem:IsGive()
    if self:IsLocked() then
        return false
    end
    local iGive = self:GetItemData()["giftable"] or 0
    if iGive == 1 then
        return true
    end
    return false
end

--能否摆摊
function CItem:IsStore()
    if self:IsLocked() then
        return false
    end
    return true
end

function CItem:ValidMoveWH()
    if self:IsLocked() then
        return false
    end
    local iCanStore = self:GetItemData()["canStore"] or 1
    if iCanStore == 1 then
        return true
    end
    return false
end

function CItem:ValidCompose()
    if self:IsLocked() then
        return false
    end
    return true
end

function CItem:ValidDeCompose()
    if self:IsLocked() then
        return false
    end
    return true
end

--合成分解信息
function CItem:DeComposeInfo()
    local mData = self:GetItemData()
    return mData["deCompose"]
end

function CItem:DeComposeItems()
    local mGiveItem = {}
    for _, mData in pairs(self:DeComposeInfo() or {}) do
        mGiveItem[mData["sid"]] = mData["amount"]
    end
    return mGiveItem
end

function CItem:ComposeAmount()
    local mData = self:GetItemData()
    return mData["ComposeAmount"]
end

function CItem:ComposeItemInfo(iSize)
    local mData = self:GetItemData()
    if not iSize or iSize <= 1 then
        return mData["ComposeItem"]
    end

    local mResult = {}
    for idx, mInfo in pairs(mData["ComposeItem"]) do
        local mTmp = {}
        mTmp.sid = mInfo.sid
        mTmp.amount = mInfo.amount*iSize
        table.insert(mResult, mTmp)
    end
    return mResult
end

function CItem:ValidSubmit()
    if self:IsLocked() then
        return false
    end
    if self.m_Pos <= 100 then
        return false
    end
    if self:GetData("wield") then
        return false
    end
    return true
end

function CItem:Pos()
    return self.m_Pos
end

function CItem:IsLocked()
    if self:HasWarLock() then
        return true
    end
    return false
end

function CItem:GetLockKey()
    return self.m_iWarLock or 0
end

function CItem:SetWarLock(iMask)
    self:Dirty()
    self.m_iWarLock = iMask
end

function CItem:HasWarLock()
    return self.m_iWarLock and true or false
end

function CItem:ClearWarLock()
    self:Dirty()
    self.m_iWarLock = nil
end

function CItem:ValidUseInWar()
    return false
end

function CItem:PackWarUseInfo()
    return {}
end

function CItem:CanUse2SummonLife()
    return false
end

function CItem:PackItemInfo()
     local mNet = {}
    mNet["id"] = self.m_ID
    mNet["sid"] = self:SID()
    mNet["pos"] = self.m_Pos
    mNet["name"] = self:Name()
    mNet["itemlevel"] = self:Quality()
    mNet["amount"] = self:GetAmount()
    mNet["key"] = self:Key()
    if self:IsTimeItem() then
        mNet["time"] = math.max(0, self:GetData("Time", 0) - get_time())
    end
    mNet["apply_info"] = self:ApplyInfo()
    mNet["desc"] = self:Desc()
    mNet["guild_buy_price"] = self:GetData("guild_buy_price")
    mNet["cycreate_time"] = self:GetData("cycreate_time",0)
    mNet["stall_buy_price"] = self:GetData("stall_buy_price")
    return mNet
end

function CItem:PackShowItemInfo(oPlayer)
    local mNet = self:PackItemInfo()
    mNet.guild_buy_price = 0
    mNet.stall_buy_price = 0
    return mNet
end

function CItem:PackLogInfo()
    local mData = {}
    mData["amount"] = self.m_iAmount
    mData["sid"] = self.m_SID
    mData["data"] = self.m_mData or {}
    mData["create_time"] = self.m_iCreateTime
    return mData
end

function CItem:PackBackendInfo()
    return {
        amount = self.m_iAmount,
        sid = self.m_SID,
        data = self.m_mData or {},
    }
end

function CItem:OnAddToPos(iPos, mArgs)
    if self:IsQuickUse() and not mArgs.cancel_quick then
        local oOwnCtrller = self.m_Container
        if oOwnCtrller then
            oOwnCtrller:GS2CItemQuickUse(self)
        end
    end
end

function CItem:GS2CConsumeMsg(oPlayer, iTrueUse)
    if oPlayer then
        local oChatMgr = global.oChatMgr
        local oToolMgr = global.oToolMgr
        -- local iColor = self:Quality()
        local iAmount = iTrueUse or self:GetUseCostAmount()
        local sTipsName = self:TipsName()
        local sMsg = oToolMgr:FormatColorString("使用#amount个#item", {amount=iAmount, item = sTipsName})
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
end
