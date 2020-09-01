local skynet = require "skynet"
local global = require "global"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local itemnet = import(service_path("netcmd.item"))
local gamedefines = import(lualib_path("public.gamedefines"))
local itemdefines = import(service_path("item.itemdefines"))
local analylog = import(lualib_path("public.analylog"))

local EQUIP_START = 1
local EQUIP_END = 100
local EQUIP_WING_POS = 7
local EQUIP_ARTIFACT_POS = 8

local ITEM_START = 101
local ITEM_END = 2000
local ITEM_SIZE = 50
local MAX_ITEM_SIZE = 250

local max = math.max
local min = math.min

CItemCtrl = {}
CItemCtrl.__index = CItemCtrl
inherit(CItemCtrl, datactrl.CDataCtrl)

function CItemCtrl:New(pid)
    local o = super(CItemCtrl).New(self, {pid = pid})
    o:Init(pid)
    return o
end

function CItemCtrl:Release()
    for _,oItem in pairs(self.m_Item) do
        baseobj_safe_release(oItem)
    end
    self.m_Item = {}
    self.m_ItemID = {}
    self.m_mShape = {}
    super(CItemCtrl).Release(self)
end

function CItemCtrl:Init(pid)
    self.m_Owner = pid
    self.m_Item = {}
    self.m_ItemID = {}
    self.m_mShape = {}
    self.m_TraceNo = 1
    self.m_ExtendSize = 0
    self.m_Size = ITEM_SIZE
end

function CItemCtrl:Save()
    local mData = {}

    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemdata[db_key(iPos)] = itemobj:Save()
    end
    mData["itemdata"] = itemdata
    mData["trace_no"] = self.m_TraceNo
    mData["extendsize"] = self.m_ExtendSize
    return mData
end

function CItemCtrl:Load(mData)
    mData = mData or {}
    self.m_ExtendSize = mData["extendsize"] or self.m_ExtendSize
    self.m_TraceNo = mData["traceno"] or self.m_TraceNo
    local itemdata = mData["itemdata"] or {}
    for iPos,data in pairs(itemdata) do
        local itemobj = global.oItemLoader:LoadItem(data["sid"],data)
        iPos = tonumber(iPos)
        assert(itemobj,string.format("item sid error:%s,%s,%s",self.m_Owner,data["sid"],iPos))
        if itemobj:Validate() then
            self.m_Item[iPos] = itemobj
            self.m_ItemID[itemobj.m_ID] = itemobj
            itemobj.m_Pos = iPos
            itemobj.m_Container = self
            itemobj:OnSetContainer(itemdefines.CONTAINER_MAP.ITEM_CTRL)
            self:AddShapeItem(itemobj)
        else
            --
        end
    end
end

function CItemCtrl:DispatchTraceNo()
    self:Dirty()
    local iTraceNo = self.m_TraceNo
    self.m_TraceNo = self.m_TraceNo + 1
    return iTraceNo
end

function CItemCtrl:UnDirty()
    super(CItemCtrl).UnDirty(self)
    for _,itemobj in pairs(self.m_Item) do
        if itemobj:IsDirty() then
            itemobj:UnDirty()
        end
    end
end

function CItemCtrl:IsDirty()
    local bDirty = super(CItemCtrl).IsDirty(self)
   if bDirty then
        return true
    end
    for _,itemobj in pairs(self.m_Item) do
        if itemobj:IsDirty() then
            return true
        end
    end
    return false
end

function CItemCtrl:GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"itemtext"})
end

function CItemCtrl:GetSize()
    return self.m_Size + self.m_ExtendSize
end

function CItemCtrl:GetExtendSize()
    return self.m_ExtendSize
end

function CItemCtrl:GetStartPos()
    return ITEM_START
end

function CItemCtrl:GetEndPos()
    return ITEM_START + self:GetSize() - 1
end

function CItemCtrl:AddExtendSize(iSize)
    self:Dirty()
    iSize = iSize or 5
    self.m_ExtendSize = self.m_ExtendSize + iSize
    local mNet = {}
    mNet["extsize"] = self.m_ExtendSize
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CItemExtendSize",mNet)
        oPlayer:SendNotification(2005, {amount = iSize})
    end
end

function CItemCtrl:MaxSize()
    local res = require "base.res"
    local mData = res["daobiao"]["global"]
    local iMaxSize = tonumber(mData[101]["value"])
    if iMaxSize then
        return iMaxSize
    else
        return MAX_ITEM_SIZE
    end
end

function CItemCtrl:CanAddExtendSize( )
    local iSize = self:GetSize()
    if iSize >= self:MaxSize() then
        return false
    end
    return true
end

function CItemCtrl:GetValidPos()
    local endpos = self:GetEndPos()
    for iPos = ITEM_START,endpos do
        if not self.m_Item[iPos] then
            return iPos
        end
    end
end

function CItemCtrl:GetCanUseSpaceSize()
    local endpos = self:GetEndPos()
    local iSize = 0
    for iPos = ITEM_START,endpos do
        if not self.m_Item[iPos] then
            iSize = iSize + 1
        end
    end
    return iSize
end

function CItemCtrl:ItemList()
    return self.m_Item
end

function CItemCtrl:ItemStartList()
    local mItemList = {}
    local iStartPos = self:GetStartPos()
    local iEndPos = self:GetEndPos()
    for iPos,oItem in pairs(self.m_Item) do
        if iPos >= iStartPos and iPos <= iEndPos then
            mItemList[iPos] = oItem
        end
    end
    return mItemList
end

function CItemCtrl:IsBagPos(iPos)
    local iStartPos = self:GetStartPos()
    local iEndPos = self:GetEndPos()
    if iPos >= iStartPos and iPos <= iEndPos then
        return true
    end
end

function CItemCtrl:GetShapes()
    return self.m_mShape
end

function CItemCtrl:GetShapeItem(sid)
    local mShape = self.m_mShape[sid] or {}
    local lItem = {}
    for iItemid,_ in pairs(mShape) do
        local oItem = self:HasItem(iItemid)
        if oItem then
            table.insert(lItem,oItem)
        end
    end
    return lItem
end

function CItemCtrl:GetItemObj(sid)
    local mShape = self.m_mShape[sid] or {}
    for iItemid,_ in pairs(mShape) do
        local oItem = self:HasItem(iItemid)
        if oItem then
            return oItem
        end
    end
end

function CItemCtrl:HasItem(itemid, bEveryPos)
    local oItem = self.m_ItemID[itemid]
    if bEveryPos then
        -- 任意位置有效（可以为装备区）
        return oItem
    end
    if oItem and self:IsBagPos(oItem:Pos()) then
        return oItem
    end
end

function CItemCtrl:GetItem(iPos)
    return self.m_Item[iPos]
end

function CItemCtrl:AddItem(srcobj,mArgs)
    self:Dirty()
    local iRemain = srcobj:GetAmount()
    local iMaxAmount = srcobj:GetMaxAmount()
    local mSrcSaveData = srcobj:Save()
    if iMaxAmount > 1 then
        local lShape = self:GetShapeItem(srcobj:SID())
        for _,itemobj in pairs(lShape) do
            if srcobj:ValidCombine(itemobj) then
                local iHave = itemobj:GetAmount()
                local iAdd = max(iMaxAmount - iHave,0)
                if iRemain > 0 and iAdd > 0 then
                    iAdd = min(iAdd, iRemain)
                    iRemain = iRemain - iAdd
                    srcobj:AddAmount(-iAdd,"combine",mArgs)
                    itemobj:AddAmount(iAdd,"combine",mArgs)
                    itemobj:AfterCombine(mSrcSaveData)
                    self:GS2CUpdateItem(itemobj)
                    if iRemain <= 0 then
                        break
                    end
                end
            end
        end
    end
    if iRemain <= 0 then
        baseobj_delay_release(srcobj)
        return nil
    end
    local iPos = self:GetValidPos()
    if not iPos then
        return srcobj
    end
    self:AddToPos(srcobj,iPos,mArgs)
end

--能否移入
function CItemCtrl:ValidStorePos(srcobj)
    local iPos = self:GetValidPos()
    if iPos then
        return true
    end
    -- 有格子才能移入
    -- local iMaxAmount = srcobj:GetMaxAmount()
    -- local iCanAddAmount = 0
    -- local iShape = srcobj:SID()
    -- local lShape = self:GetShapeItem(iShape)
    -- for _,itemobj in pairs(lShape) do

    --     local iHaveAmount = itemobj:GetAmount()
    --     iCanAddAmount = iCanAddAmount + max(iMaxAmount-iHaveAmount,0)
    -- end
    -- if srcobj:GetAmount() <= iCanAddAmount then
    --     return true
    -- end
    return false
end

-- TODO FIXME 分离逻辑与下行协议，增加新的分层，协议放到外面发
function CItemCtrl:AddToPos(itemobj,iPos,mArgs)
    self:Dirty()
    mArgs = mArgs or {}
    self.m_Item[iPos] = itemobj
    self.m_ItemID[itemobj.m_ID] = itemobj
    itemobj.m_Pos = iPos
    itemobj.m_Container = self
    itemobj:OnSetContainer(itemdefines.CONTAINER_MAP.ITEM_CTRL)
    if not itemobj:GetData("TraceNo") then
        local iTraceNo = self:DispatchTraceNo()
        itemobj:SetData("TraceNo",{self.m_Owner,iTraceNo})
    end
    self:GS2CAddItem(itemobj,mArgs)
    itemobj:OnAddToPos(iPos, mArgs)
    self:AddShapeItem(itemobj)
end

function CItemCtrl:RemoveItem(itemobj)
    self:Dirty()
    local iPos = itemobj.m_Pos
    self.m_Item[iPos] = nil
    self.m_ItemID[itemobj.m_ID] = nil
    self:GS2CDelItem(itemobj)
    itemobj:OnDelContainer()
    itemobj.m_Pos = nil
    itemobj.m_Container = nil
    self:RemoveShapeItem(itemobj)
    baseobj_delay_release(itemobj)
end

function CItemCtrl:ItemChange(srcobj,destobj)
    self:Dirty()
    local srcpos = srcobj.m_Pos
    local destpos = destobj.m_Pos
    self.m_Item[srcpos] = destobj
    self.m_Item[destpos] = srcobj
    srcobj.m_Pos = destpos
    destobj.m_Pos = srcpos
    self:ChangeShapeItem(srcobj)
    self:ChangeShapeItem(destobj)
end

function CItemCtrl:ChangeToPos(srcobj,iPos)
    self:Dirty()
    local srcpos = srcobj.m_Pos
    self.m_Item[srcpos] = nil
    self.m_Item[iPos] = srcobj
    srcobj.m_Pos = iPos
    self:ChangeShapeItem(srcobj)
end

function CItemCtrl:ChangeShapeItem(oItem)
    if self:IsBagPos(oItem.m_Pos) then
        self:AddShapeItem(oItem)
    elseif not self:IsBagPos(oItem.m_Pos) and self.m_mShape[oItem:SID()] then
        self:RemoveShapeItem(oItem)
    end
end

function CItemCtrl:AddShapeItem(oItem)
    if not self:IsBagPos(oItem.m_Pos) then
        return
    end
    local iSid = oItem:SID()
    local iItemid = oItem:ID()
    if not self.m_mShape[iSid] then
        self.m_mShape[iSid] = {}
    end
    local mItem = self.m_mShape[iSid] or {}
    mItem[iItemid] = 1
    self.m_mShape[iSid] = mItem
end

function CItemCtrl:RemoveShapeItem(oItem)
    local iSid = oItem:SID()
    local iItemid = oItem:ID()
    local mShape = self.m_mShape[iSid]
    mShape[iItemid] = nil
    if not next(mShape) then
        mShape = nil
    end
    self.m_mShape[iSid] = mShape
end

function CItemCtrl:ValidArrangeChange(srcobj,iPos)
    local srcpos = srcobj.m_Pos
    iPos = iPos + ITEM_START - 1
    if srcpos == iPos then
        return false
    end
    return true
end

function CItemCtrl:ArrangeChange(srcobj,iPos)
    local srcpos = srcobj.m_Pos
    iPos = iPos + ITEM_START - 1
    if srcpos == iPos then
        return
    end
    local destobj = self:GetItem(iPos)
    if not destobj then
        self:ChangeToPos(srcobj,iPos)
    else
        self:ItemChange(srcobj,destobj)
    end
    return destobj
end

function CItemCtrl:RemoveItemAmount(sid,iAmount,sReason, mArgs)
    assert(iAmount and iAmount ~= 0, string.format("RemoveItemAmount amount error: shape:%d amount:%d", sid, iAmount))
    mArgs = mArgs or {}
    local mResult = {}
    local iHaveAmount = self:GetItemAmount(sid)
    local iRecord = iAmount
    if iHaveAmount < iAmount then
        return false
    end
    local mItemList = self:GetShapeItem(sid)
    local SortFunc = function (oItem1,oItem2)
        if oItem1:IsBind() ~= oItem2:IsBind() then
            if oItem1:IsBind() then
                return true
            elseif oItem2:IsBind() then
                return false
            end
        else
            if oItem1:GetAmount() ~= oItem2:GetAmount() then
                return oItem1:GetAmount() < oItem2:GetAmount()
            else
                return oItem1.m_ID > oItem2.m_ID
            end
        end
    end
    table.sort(mItemList,SortFunc)

    for _,itemobj in pairs(mItemList) do
        if itemobj:IsLocked() then
            goto continue
        end
        if itemobj:IsBind() then
            mResult.bind = true
        end

        local iSubAmount = itemobj:GetAmount()
        iSubAmount = min(iSubAmount,iAmount)
        iAmount = iAmount - iSubAmount
        itemobj:AddAmount(-iSubAmount,sReason)

        if iAmount <= 0 then
            break
        end
        ::continue::
    end
    if iAmount > 0 then
        record.error("remove ctrl item less pid:%s, item:%s, Amount:%s, sReason:%s", 
            self:GetPid(), itemobj:SID(), iAmount, sReason or "")
        return false
    end
    local oItem = global.oItemLoader:GetItem(sid)
    
    if oItem then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
        if oPlayer then
            local sMsg = global.oToolMgr:FormatColorString("消耗#amount个#item", {amount = iRecord, item = oItem:TipsName()})
            if not mArgs.cancel_tip then
                global.oNotifyMgr:ItemNotify(self.m_Owner, {sid=oItem:SID(), amount=-iRecord})
            end
            if not mArgs.cancel_chat then
                global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
            end
        end
    end
    return mResult
end

function CItemCtrl:GetOneItem(sid, bNoCheck)
    local lShape = self:GetShapeItem(sid)
    for _,oItemobj in pairs(lShape) do
        if bNoCheck or not oItemobj:IsLocked() then
            return oItemobj
        end
    end
end

function CItemCtrl:GetItemAmount(sid, bNoCheck)
    local iAmount = 0
    local lShape = self:GetShapeItem(sid)
    for _,itemobj in pairs(lShape) do
        if bNoCheck or not itemobj:IsLocked() then
            iAmount = iAmount + itemobj:GetAmount()
        end
    end
    return iAmount
end

function CItemCtrl:GetUnBindItemAmount(iSid)
    local iAmount = 0
    for _,oItem in pairs(self:GetShapeItem(iSid)) do
        if not oItem:IsBind() and not oItem:IsLocked() then
            iAmount = iAmount + oItem:GetAmount()
        end
    end
    return iAmount
end

function CItemCtrl:RemoveUnBindItemAmount(iSid, iAmount, sReason, mArgs)
    assert(iAmount and iAmount ~= 0, string.format("RemoveUnBindItemAmount amount error: pid:%s, item:%s, Amount:%s", self.m_Owner, iSid, iAmount))
    local iHasAmount = self:GetUnBindItemAmount(iSid)
    if iHasAmount < iAmount then
        record.error("RemoveUnBindItemAmount item less pid:%s, item:%s, Amount:%s, sReason:%s", 
            self.m_Owner, iSid, iAmount, sReason or "")
        return false
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    oPlayer:LogItemOnChange("sub_item", iSid, iAmount, sReason)

    -- 数据中心log
    analylog.LogBackpackChange(oPlayer, 2, iSid, iAmount, sReason)

    mArgs = mArgs or {}
    local mItemList = self:GetShapeItem(iSid)
    local SortFunc = function (oItem1,oItem2)
        if oItem1:IsBind() ~= oItem2:IsBind() then
            return oItem2:IsBind()
        else
            if oItem1:GetAmount() ~= oItem2:GetAmount() then
                return oItem1:GetAmount() < oItem2:GetAmount()
            else
                return oItem1.m_ID > oItem2.m_ID
            end
        end
    end
    table.sort(mItemList, SortFunc)

    local mResult = {}
    local iRecord = iAmount
    for _,oItem in pairs(mItemList) do
        if oItem:IsBind() or oItem:IsLocked() then
            goto continue
        end
        local iSubAmount = oItem:GetAmount()
        iSubAmount = min(iSubAmount, iAmount)
        iAmount = iAmount - iSubAmount
        oItem:AddAmount(-iSubAmount, sReason)
        if iAmount <= 0 then
            break
        end
        ::continue::
    end
    if iAmount > 0 then
        record.error("RemoveUnBindItemAmount item less pid:%s, item:%s, Amount:%s, sReason:%s", 
            self.m_Owner, iSid, iAmount, sReason or "")
        return false
    end
    local oItem = global.oItemLoader:GetItem(iSid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oItem and oPlayer then
        local sMsg = global.oToolMgr:FormatColorString("消耗#amount个#item", {amount = iRecord, item = oItem:TipsName()})
        if not mArgs.cancel_tip then
            global.oNotifyMgr:ItemNotify(self.m_Owner, {sid=oItem:SID(), amount=-iRecord})
        end
        if not mArgs.cancel_chat then
            global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
    end
    return mResult
end

--ItemList:{sid:amount}
-- function CItemCtrl:ValidGive(ItemList, mArgs)
--     mArgs = mArgs or {}
--     local iNeedSpace = 0
--     for sid,iAmount in pairs(ItemList) do
--         local ItemList = self:GetShapeItem(sid)
--         local iCanAddAmount = 0
--         local itemobj = global.oItemLoader:GetItem(sid)
--         local iMaxAmount = itemobj:GetMaxAmount()
--         for _,itemobj in pairs(ItemList) do
--             local func = mArgs[sid]
--             if func and type(func)=="function" and not func(itemobj) then
--                 goto continue
--             end
--             local iAddAmount = max(iMaxAmount-itemobj:GetAmount(),0)
--             if iAddAmount > 0 then
--                 iCanAddAmount = iCanAddAmount + iAddAmount
--             end
--             ::continue::
--         end
--         local iItemAmount = max(iAmount - iCanAddAmount,0)
--         if iItemAmount > 0 then
--             local iSize = iItemAmount // iMaxAmount + 1
--             if iItemAmount % iMaxAmount == 0 then
--                 iSize = iItemAmount // iMaxAmount
--             end
--             iNeedSpace = iNeedSpace + iSize
--         end
--     end
--     local iHaveSpace = self:GetCanUseSpaceSize()
--     if iHaveSpace < iNeedSpace then
--         return false
--     end
--     return true
-- end

--ItemList:{sid:amount} 不和自身的堆叠的判断
function CItemCtrl:ValidGive(ItemList, mArgs)
    local iNeedSpace = 0
    for sid,iAmount in pairs(ItemList) do
        if sid < 10000 then
            goto continue
        end
        local itemobj = global.oItemLoader:GetItem(sid)
        local iMaxAmount = itemobj:GetMaxAmount()
        if iAmount % iMaxAmount == 0 then
            iNeedSpace = iAmount // iMaxAmount
        else
            iNeedSpace = iAmount // iMaxAmount + 1
        end
        ::continue::
    end
    local iHaveSpace = self:GetCanUseSpaceSize()
    if iHaveSpace < iNeedSpace then
        return false
    end
    return true
end

function CItemCtrl:GiveItem(ItemList,sReason,mArgs)
    mArgs = mArgs or {}
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)

    local lItemObjs = {}
    for sid,iAmount in pairs(ItemList) do
        local iRecord = iAmount
        while(iAmount > 0) do
            local itemobj = global.oItemLoader:ExtCreate(sid)
            local iAddAmount = min(itemobj:GetMaxAmount(),iAmount)
            iAmount = iAmount - iAddAmount
            itemobj:SetAmount(iAddAmount)
            if mArgs.bind then 
                itemobj:Bind(self.m_Owner) 
            end
            self:AddItem(itemobj)
            table.insert(lItemObjs, itemobj)
            if iAmount <= 0 then
                break
            end
        end
        if tonumber(sid) then
            sid = tonumber(sid)
        else
            local sOther
            sid, sOther = string.match(sid,"(%d+)(.*)")
            sid = tonumber(sid)
        end
        local oItem = global.oItemLoader:GetItem(sid)
        if oItem then
            local oNotifyMgr = global.oNotifyMgr
            local oChatMgr = global.oChatMgr
            local oToolMgr = global.oToolMgr
            if oPlayer then
                local sMsg = oToolMgr:FormatColorString("获得#amount个#item", {amount = iRecord, item = oItem:TipsName()})
                oChatMgr:HandleMsgChat(oPlayer, sMsg)
                if not mArgs.cancel_tip then
                    oNotifyMgr:ItemNotify(self.m_Owner, {sid=oItem:SID(), amount=iRecord})
                end
            end
        end

        if oPlayer then
            -- 数据中心log
            analylog.LogBackpackChange(oPlayer, 1, sid, iRecord, sReason)
            oPlayer:LogItemOnChange("add_item", sid, iRecord, sReason)
        end
    end
    return lItemObjs
end

function CItemCtrl:ValidGiveitemlist(itemlist,mArgs)
    local iHaveSpace = self:GetCanUseSpaceSize()
    local iNeedSpace = 0
    for _,srcobj in pairs(itemlist) do
        local iSrcSid = srcobj:SID()
        if srcobj:ItemType() == "virtual" then
            goto continue2
        end
        local lSrcShape = self:GetShapeItem(iSrcSid)
        local iCurAmount = srcobj:GetAmount()
        local iMaxAmount = srcobj:GetMaxAmount()
        for _,itemobj in pairs(lSrcShape) do
            if iCurAmount<=0 then
                break
            end
            if not srcobj:ValidCombine(itemobj) then
                goto continue1
            end

            local iHave = itemobj:GetAmount()
            local iAdd = math.min(iCurAmount ,math.max(iMaxAmount - iHave,0))
            iCurAmount = iCurAmount - iAdd
            ::continue1::
        end
        if iCurAmount>0 then
            iNeedSpace = iNeedSpace + math.floor(iCurAmount/iMaxAmount)
            if iCurAmount%iMaxAmount~=0 then
                iNeedSpace = iNeedSpace+1
            end
        end
        ::continue2::
    end
    if iHaveSpace>=iNeedSpace then
        return true
    else
        return false 
    end
end

function CItemCtrl:GiveItemobj(oPlayer,ItemList,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local oWorldMgr = global.oWorldMgr
    local lLogItemlist = {}
    for _,itemobj in pairs(ItemList) do
        if itemobj:ItemType() == "virtual" then
            itemobj:Reward(oPlayer, sReason, mArgs)
            goto continue
        end
        local itemsid = itemobj:SID()
        local iAmount = itemobj:GetAmount()
        local iCurAmount = iAmount
        lLogItemlist[itemsid] = iAmount
        while iCurAmount >0 do
            local iAddAmount = math.min(iCurAmount,itemobj:GetMaxAmount())
            iCurAmount = iCurAmount-iAddAmount
            local data = itemobj:Save()
            local oRewardObj = global.oItemLoader:LoadItem(data["sid"],data)
            oRewardObj:SetAmount(iAddAmount)
            self:AddItem(oRewardObj,mArgs)
        end
        
        local sMsg = oToolMgr:FormatColorString("获得#amount个#item", {amount = iAmount, item = itemobj:TipsName()})
        if not mArgs.cancel_chat then
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        if not mArgs.cancel_tip then
            oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=itemsid, amount=iAmount})
        end

        analylog.LogBackpackChange(oPlayer, 1, itemsid, iAmount, sReason)
        oPlayer:LogItemOnChange("add_item", itemsid, iAmount, sReason, itemobj:PackLogInfo())
        ::continue::
    end
end

function CItemCtrl:OnLogin(oPlayer,bReEnter)
    local mNet = {}
    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemobj:OnLogin(oPlayer,bReEnter)
        table.insert(itemdata,itemobj:PackItemInfo())
    end
    mNet["itemdata"] = itemdata
    mNet["extsize"] = self:GetExtendSize()
    if oPlayer then
        oPlayer:Send("GS2CLoginItem",mNet)
    end

    if self:IsEquipsNeedTipsFix(oPlayer, true) then
        self:ToTipsFixEquips(oPlayer)
    end
end

function CItemCtrl:CalcFixAllEquipPrice(oPlayer)
    local iSilver = 0
    for iPos = 1,6 do
        local oItem = self:GetItem(iPos)
        if oItem and oItem:GetLast() < oItem:GetMaxLast() then
            iSilver = iSilver + oItem:GetFixPrice()
        end
    end
    return iSilver
end

function CItemCtrl:CheckNeedFixEquips(oPlayer)
    local bNeedFix = self:IsEquipsNeedFix(oPlayer)
    self:NeedFixEquips(oPlayer, bNeedFix)
end

function CItemCtrl:IsEquipsNeedFix(oPlayer)
    for iPos = 1, 6 do
        local oItem = self:GetItem(iPos)
        if oItem and oItem:IsNeedFix() then
            return true
        end
    end
    return false
end

function CItemCtrl:IsEquipsNeedTipsFix(oPlayer, bCheckBroken)
    local bTips = false
    if bCheckBroken then
        -- 仅为检查损坏
        for iPos = 1, 6 do
            local oItem = self:GetItem(iPos)
            if oItem and not oItem:IsValid() then
                bTips = true
                break
            end
        end
    else
        for iPos = 1, 6 do
            local oItem = self:GetItem(iPos)
            -- 所有装备检查一遍，以加上首次标记
            if oItem and oItem:TouchIsFirstNeedFix() then
                bTips = true
            end
        end
    end
    return bTips
end

function CItemCtrl:HasNeedFixBuff(oPlayer)
    local iState = 1001
    local oState = oPlayer.m_oStateCtrl:GetState(iState)
    return oState ~= nil
end

function CItemCtrl:NeedFixEquips(oPlayer, bNeedFix)
    local iState = 1001
    local oState = oPlayer.m_oStateCtrl:GetState(iState)
    if bNeedFix and not oState then
        oPlayer.m_oStateCtrl:AddState(iState)
    elseif not bNeedFix and oState then
        oPlayer.m_oStateCtrl:RemoveState(iState)
    end
end

function CItemCtrl:ToTipsFixEquips(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oCbMgr = global.oCbMgr
    local iPid = oPlayer.m_iPid
    local iSilver = self:CalcFixAllEquipPrice(oPlayer)
    if iSilver > 0 then
        local mData = oCbMgr:PackConfirmData(iPid,{sContent = string.format("是否花费%d银币修理所有装备",iSilver)})
        local fCallBack = function (oPlayer, mData)
            oPlayer.m_oItemCtrl:OnConfirmFixEquips(oPlayer, mData)
        end
        oCbMgr:SetCallBack(iPid,"GS2CConfirmUI",mData,nil,fCallBack)
        -- oPlayer:Send("GS2CEquipNeedFix", {silver = iSilver})
    end
end

function CItemCtrl:OnConfirmFixEquips(oPlayer, mData)
    if mData["answer"] ~= 1 then
        return
    end
    local iPid = oPlayer:GetPid()
    local iSilver = self:CalcFixAllEquipPrice(oPlayer)
    assert(iSilver > 0, string.format("equip fix cost silver error: %d", iSilver))
    if not oPlayer:ValidSilver(iSilver, { cancel_tip = true}) then
        local iHasSilver = oPlayer:GetSilver()
        local mExchange, mCopyExchange = global.oToolMgr:PackExchangeData(gamedefines.MONEY_TYPE.SILVER, iSilver - iHasSilver, {})
        global.oCbMgr:SetCallBack(iPid, "GS2CExecAfterExchange", mCopyExchange,
        function(oPlayer, mData)
            local bResult = global.oToolMgr:TryExchange(oPlayer, mExchange, mData)
            return bResult
        end,
        function(oPlayer, mData)
            global.oItemHandler:FixAllEquips(oPlayer)
        end)
    else
        global.oItemHandler:FixAllEquips(oPlayer)
    end
end

function CItemCtrl:CalApply(oPlayer,bReEnter)
    if not bReEnter then
        for iPos = 1,6 do
            local itemobj = self:GetItem(iPos)
            if itemobj and itemobj:GetLast() > 0 then
                itemobj:CalApply(oPlayer)
            end
        end
    end
end

function CItemCtrl:GetOwner()
    return self.m_Owner
end

function CItemCtrl:GS2CAddItem(itemobj, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mArgs = mArgs or {}
    local mNet = {}
    local itemdata = itemobj:PackItemInfo()
    mNet["itemdata"] = itemdata
    mNet["from_wh"] =  mArgs.from_wh
    mNet["refresh"] =  mArgs.refresh
    oPlayer:Send("GS2CAddItem", mNet)
end

function CItemCtrl:GS2CItemAmount(itemobj, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    mArgs = mArgs or {}
    local mNet = {}
    mNet["id"] = itemobj:ID()
    mNet["amount"] = itemobj:GetAmount()
    mNet["from_wh"] = mArgs.from_wh
    mNet["refresh"] =  mArgs.refresh
    oPlayer:Send("GS2CItemAmount", mNet)
end

function CItemCtrl:GS2CItemQuickUse(itemobj)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet["id"] = itemobj:ID()
    oPlayer:Send("GS2CItemQuickUse", mNet)
end

function CItemCtrl:GS2CUpdateItem(itemobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CUpdateItemInfo", {itemdata=itemobj:PackItemInfo()})
    end
end

function CItemCtrl:GS2CDelItem(itemobj)
    local mNet = {}
    mNet["id"] = itemobj.m_ID
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CDelItem",mNet)
    end
end

function CItemCtrl:GS2CItemArrange(pid,mChange)
    local mNet = {}
    mNet["pos_info"] = mChange
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CItemArrange",mNet)
    end
end

function CItemCtrl:QuickBuyItem(iSid, iNeedAmount)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    if not iNeedAmount or iNeedAmount <= 0 then
        oPlayer:NotifyMessage("数量不正确")
        return
    end
    local mItemInfo = global.oItemLoader:GetItemData(iSid)
    if not mItemInfo then
        oPlayer:NotifyMessage(self:GetTextData(1025))
        return
    end
    local iBuyPrice = mItemInfo.buyPrice
    if not iBuyPrice or iBuyPrice <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1026))
        return
    end
    local iNeedGoldcoin = iBuyPrice * iNeedAmount
    local iMoneyType = gamedefines.MONEY_TYPE.GOLDCOIN
    if not oPlayer:ValidMoneyByType(iMoneyType, iNeedGoldcoin) then
        -- Valid有tips
        -- local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(1027), {money = gamedefines.MONEY_NAME[iMoneyType]})
        -- oPlayer:NotifyMessage(sMsg)
        return
    end
    oPlayer:ResumeMoneyByType(iMoneyType, iNeedGoldcoin, "quickbuy", {})
    oPlayer:RewardItems(iSid, iNeedAmount, "quickbuy", {})
    oPlayer:Send("GS2CQuickBuyItemSucc", {})
    local mLogData = oPlayer:LogData()
    mLogData.sid = iSid
    mLogData.amount = iNeedAmount
    mLogData.goldcoin = iNeedGoldcoin
    record.user("economic", "quick_buy_item", mLogData)
end

function CItemCtrl:GetArtifact()
    local oEquip = self:GetItem(EQUIP_ARTIFACT_POS)
    return oEquip
end

function CItemCtrl:AddArtifact(oEquip)
    self:Dirty()
    self:AddToPos(oEquip, EQUIP_ARTIFACT_POS, {})
end

function CItemCtrl:GetWing()
    local oEquip = self:GetItem(EQUIP_WING_POS)
    return oEquip
end

function CItemCtrl:AddWing(oEquip)
    self:Dirty()
    self:ChangeToPos(oEquip, EQUIP_WING_POS)

    local mChangePos = {}
    table.insert(mChangePos,{itemid=oEquip.m_ID, pos=oEquip.m_Pos})
    self:GS2CItemArrange(self.m_Owner, mChangePos)
end

function CItemCtrl:PackBackendInfo()
    local mData = {}

    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemdata[db_key(iPos)] = itemobj:PackBackendInfo()
    end
    mData["itemdata"] = itemdata
    return mData
end

function CItemCtrl:FireEquipStrengthen(oEquip, bSucc)
    self:TriggerEvent(gamedefines.EVENT.EQUIP_STRENGTHEN, {succ = bSucc, equip = oEquip})
end

function CItemCtrl:FireEquipWash(oEquip)
    self:TriggerEvent(gamedefines.EVENT.EQUIP_WASH, {equip = oEquip})
end

function CItemCtrl:FireEquipDazao(oEquip)
    self:TriggerEvent(gamedefines.EVENT.EQUIP_DAZAO, {equip = oEquip})
end

function CItemCtrl:FireEquipFuhun(oEquip)
    self:TriggerEvent(gamedefines.EVENT.EQUIP_FUHUN, {equip = oEquip})
end
