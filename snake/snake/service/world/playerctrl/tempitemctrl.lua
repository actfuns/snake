local skynet = require "skynet"
local global = require "global"
local record = require "public.record"
local extend = require "base.extend"
local res = require "base.res"
local datactrl = import(lualib_path("public.datactrl"))
local itemdefines = import(service_path("item.itemdefines"))


local ITEM_SIZE = 15
local ITEM_START = 1
local ACTIVE_TIME = 24*60*60

CTempItemCtrl = {}
CTempItemCtrl.__index = CTempItemCtrl
inherit(CTempItemCtrl, datactrl.CDataCtrl)

function CTempItemCtrl:New(pid)
    local o = super(CTempItemCtrl).New(self,{pid = pid})
    o:Init(pid)
    return o
end

function CTempItemCtrl:Release()
    for _,oItem in pairs(self.m_Item) do
        if oItem.Release then
            baseobj_safe_release(oItem)
        end
    end
    self.m_Item = {}
    self.m_ItemID = {}
    self.m_mShape = {}
    super(CTempItemCtrl).Release(self)    
end

function CTempItemCtrl:Init(pid)
    self.m_Owner = pid
    self.m_Item = {}
    self.m_ItemID = {}
    self.m_mShape = {}
end

function CTempItemCtrl:OnLogin(oPlayer,bReEnter)
    local mNet = {}
    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemobj:OnLogin(oPlayer, bReEnter)
        table.insert(itemdata,itemobj:PackItemInfo())
    end
    mNet["itemdata"] = itemdata
    oPlayer:Send("GS2CLoginTempItem",mNet)
end

function CTempItemCtrl:OnLogout()
    self:TranAllToItemBag()
end

function CTempItemCtrl:Save()
    local mData = {}
    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemdata[db_key(iPos)] = itemobj:Save()
    end
    mData["itemdata"] = itemdata
    mData["endtime"] = get_time()
    return mData
end

function CTempItemCtrl:Load(mData)
    mData = mData or {}
    local iEndTime = mData["endtime"] or get_time()
    if get_time() - iEndTime > ACTIVE_TIME then
        local itemdata = mData["itemdata"] or {}
        local mLogData = {}
        local mLog = {}
        for iPos,data in pairs(itemdata) do
            table.insert(mLog,{sid = data["sid"],amount = data["amount"]})
        end
        mLogData.iteminfo=extend.Table.serialize(mLog)
        mLogData.pid = self:GetOwner()
        record.user("tempitem", "delnotactive", mLogData)
        self:Dirty()
    else
        local itemdata = mData["itemdata"] or {}
        for iPos,data in pairs(itemdata) do
            local itemobj = global.oItemLoader:LoadItem(data["sid"],data)
            iPos = tonumber(iPos)
            if itemobj and itemobj:Validate() then
                self.m_Item[iPos] = itemobj
                self.m_ItemID[itemobj.m_ID] = itemobj
                itemobj.m_Pos = iPos
                itemobj.m_Container = self
                itemobj:OnSetContainer(itemdefines.CONTAINER_MAP.ITEM_TMP_CTRL)
                self:AddShapeItem(itemobj)
            else
                record.warning(string.format("tempitem sid error:%s,%s,%s",self.m_Owner,data["sid"],iPos))
            end
        end
    end
end

function CTempItemCtrl:UnDirty()
    super(CTempItemCtrl).UnDirty(self)
    for _,itemobj in pairs(self.m_Item) do
        if itemobj:IsDirty() then
            itemobj:UnDirty()
        end
    end
end

function CTempItemCtrl:IsDirty()
    local bDirty = super(CTempItemCtrl).IsDirty(self)
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

function CTempItemCtrl:GetOwner()
    return self.m_Owner
end

function CTempItemCtrl:GetEndPos()
    return ITEM_START + ITEM_SIZE - 1
end

function CTempItemCtrl:GetStartPos()
    return ITEM_START
end

function CTempItemCtrl:GetValidPos()
    local endpos = self:GetEndPos()
    for iPos = ITEM_START,endpos do
        if not self.m_Item[iPos] then
            return iPos
        end
    end
end

function CTempItemCtrl:ItemList()
    return self.m_Item
end

function CTempItemCtrl:GetItemByPos(iPos)
    return self.m_Item[iPos]
end

function CTempItemCtrl:ClearAllItem()
    for iPos, itemobj in pairs(self:ItemStartList()) do
        self:RemoveItem(itemobj) 
    end
    self:Dirty()
    self.m_Item={}
    self.m_ItemID={}
end

function CTempItemCtrl:PrintAllItem()
    for iPos, itemobj in pairs(self:ItemStartList()) do
        print(itemobj:PackItemInfo())
    end
end

function CTempItemCtrl:HasItem(itemid)
    local oItem = self.m_ItemID[itemid]
    return oItem
end

function CTempItemCtrl:ItemStartList()
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

function CTempItemCtrl:AddItem(srcobj)
    self:Dirty()
    local iRemain = srcobj:GetAmount()
    local iMaxAmount = srcobj:GetMaxAmount()
    local mSrcSaveData = srcobj:Save()
    local iShape = srcobj:SID()
    if iMaxAmount > 1 then
        local lShape = self:GetShapeItem(iShape)
        for _,itemobj in pairs(lShape) do
            if srcobj:ValidCombine(itemobj) then
                local iHave = itemobj:GetAmount()
                local iAdd = math.max(iMaxAmount - iHave,0)
                if iRemain > 0 and iAdd > 0 then
                    iAdd = math.min(iAdd, iRemain)
                    iRemain = iRemain - iAdd
                    srcobj:AddAmount(-iAdd)
                    itemobj:AddAmount(iAdd)
                    itemobj:AfterCombine(mSrcSaveData)
                end
            end
        end
    end
    if iRemain <= 0 then
        global.oNotifyMgr:Notify(self:GetOwner(), string.format("#G%s#n进入临时背包", srcobj:TipsName()))
        return nil
    end
    local iPos = self:GetValidPos()
    if not iPos then
        srcobj = self:ReAddItem(srcobj)
        return srcobj
    else
        if self:CheckSort(iPos) then
            iPos = self:GetValidPos()
        end
        global.oNotifyMgr:Notify(self:GetOwner(), string.format("#G%s#n进入临时背包", srcobj:TipsName()))
        self:AddToPos(srcobj,iPos)
    end
end

function CTempItemCtrl:AddToPos(itemobj,iPos)
    if self.m_ItemID[itemobj.m_ID] then
        print(debug.traceback("repeat add tempitem"))
    end
    self:Dirty()
    self.m_Item[iPos] = itemobj
    self.m_ItemID[itemobj.m_ID] = itemobj
    itemobj.m_Pos = iPos
    itemobj.m_Container = self
    itemobj:OnSetContainer(itemdefines.CONTAINER_MAP.ITEM_TMP_CTRL)
    self:GS2CAddTempItem(itemobj)
    self:AddShapeItem(itemobj)
end

function CTempItemCtrl:ReAddItem(srcobj)
    local iSortPos
    for iPos,itemobj in pairs(self.m_Item) do
        if itemobj:Quality()<3 and srcobj:Quality()>=3 then
            self.m_Item[iPos] = nil
            self.m_ItemID[itemobj.m_ID] = nil
            itemobj.m_Pos = nil
            itemobj.m_Container = nil
            baseobj_delay_release(itemobj)
            iSortPos = iPos
            local sText = GetText(1006)
            sText = global.oToolMgr:FormatColorString(sText, {item = srcobj:TipsName(),olditem = itemobj:TipsName()})
            global.oNotifyMgr:Notify(self:GetOwner(),sText)
            break
        end
    end

    if not iSortPos and  srcobj:Quality()>=3  then
        return srcobj
    end
    if iSortPos then
        self:CheckSort(iSortPos)
        iSortPos = self:GetValidPos()
        self:AddToPos(srcobj,iSortPos)
        return
    end
    local mLogData = {}
    mLogData.iteminfo = extend.Table.serialize({sid = srcobj:SID(),amount = srcobj:GetAmount()})
    mLogData.pid = self:GetOwner()
    record.user("tempitem", "failadd", mLogData)
    global.oNotifyMgr:Notify(self:GetOwner(),GetText(1010))
end

function CTempItemCtrl:CheckSort(iPos)
    local bSort = false
    local endpos = self:GetEndPos()
    for pos = iPos +1 , endpos  do
        if self.m_Item[pos] then
            bSort = true 
            break
        end
    end
    if bSort then
        local lItem =  {}
        for pos = ITEM_START , endpos  do
            if self.m_Item[pos] then
                table.insert(lItem,self.m_Item[pos])
            end
        end
        if #lItem>0 then
            self.m_Item  = {}
            for iPos ,itemobj in pairs(lItem) do
                itemobj.m_Pos = iPos
                self.m_Item[iPos] = itemobj
            end
            self:GS2CRefreshAll()
            return true
        end
    end
end

function CTempItemCtrl:RemoveItem(itemobj)
    self:Dirty()
    local iPos = itemobj.m_Pos
    self.m_Item[iPos] = nil
    self.m_ItemID[itemobj.m_ID] = nil
    self:GS2CDelTempItem(itemobj)
    itemobj:OnDelContainer()
    itemobj.m_Pos = nil
    itemobj.m_Container = nil
    self:RemoveShapeItem(itemobj)
    baseobj_delay_release(itemobj)
end

function CTempItemCtrl:AddShapeItem(oItem)
    local iSid = oItem:SID()
    local iItemid = oItem:ID()
    if not self.m_mShape[iSid] then
        self.m_mShape[iSid] = {}
    end
    local mItem = self.m_mShape[iSid] or {}
    mItem[iItemid] = 1
    self.m_mShape[iSid] = mItem
end

function CTempItemCtrl:RemoveShapeItem(oItem)
    local iSid = oItem:SID()
    local iItemid = oItem:ID()
    local mShape = self.m_mShape[iSid]
    mShape[iItemid] = nil
    if not next(mShape) then
        mShape = nil
    end
    self.m_mShape[iSid] = mShape
end

function CTempItemCtrl:GetShapes()
    return self.m_mShape
end

function CTempItemCtrl:GetShapeItem(sid)
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

function CTempItemCtrl:GS2CAddTempItem(itemobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    local itemdata = itemobj:PackItemInfo()
    mNet["itemdata"] = itemdata
    oPlayer:Send("GS2CAddTempItem", mNet)
end

--刷新道具协议 兼容itembase
function CTempItemCtrl:GS2CItemAmount(itemobj)
     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    local itemdata = itemobj:PackItemInfo()
    mNet["itemdata"] = itemdata
    oPlayer:Send("GS2CRefreshTempItem", mNet)   
end

function CTempItemCtrl:GS2CDelTempItem(itemobj)
     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet["id"] = itemobj.m_ID
    oPlayer:Send("GS2CDelTempItem",mNet)
end

function CTempItemCtrl:GS2CRefreshAll()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        table.insert(itemdata,itemobj:PackItemInfo())
    end
    mNet["itemdata"] = itemdata
    oPlayer:Send("GS2CRefreshAllTemItem",mNet)
end

function CTempItemCtrl:ValidTransItembag(oPlayer,itemobj)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local iShape = itemobj:SID()
    if oPlayer.m_oItemCtrl:GetValidPos() then
        return true
    end
    if itemobj:GetMaxAmount()<=1 then
        local sText = global.oToolMgr:FormatColorString(GetText(1002), {item = itemobj:TipsName()})
        oNotifyMgr:Notify(pid,sText)
        return false
    end
    if itemobj:GetAmount()<=0 then
        return false
    end
    local mShape = oPlayer.m_oItemCtrl:GetShapes()
    for iItem, _ in pairs(mShape[iShape] or {}) do
        local obj = oPlayer.m_oItemCtrl:HasItem(iItem)
        if obj and obj:GetAmount() < obj:GetMaxAmount() and obj:ValidCombine(itemobj) then
            return true
        end
    end
    return false
end

function CTempItemCtrl:TranToItemBag(itemid,bAll)
    if not self:HasItem(itemid) then
        return false
    end

    local oNotifyMgr = global.oNotifyMgr
    local pid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local itemobj1 = self:HasItem(itemid)

    if not self:ValidTransItembag(oPlayer,itemobj1) then
        return  false
    end

    local mData = itemobj1:Save()
    local itemobj2 = global.oItemLoader:LoadItem(itemobj1:SID(),mData)
    local iAmount2 = itemobj2:GetAmount()
    local itemobj3 = oPlayer.m_oItemCtrl:AddItem(itemobj2)
    
    if not itemobj3 then 
        self:RemoveItem(itemobj1)
        if not bAll then
            local sText = GetText(1001)
            sText = global.oToolMgr:FormatColorString(sText, {item = itemobj1:TipsName()})
            oNotifyMgr:Notify(pid,sText)
        end
        return true
    end

    local iAmount3 = itemobj3:GetAmount()
    if iAmount3 == iAmount2 then
        if not bAll then
            local sText = GetText(1002)
            sText = global.oToolMgr:FormatColorString(sText, {item = itemobj1:TipsName()})
            oNotifyMgr:Notify(pid,sText)
        end
        return false
    end

    if iAmount2 > iAmount3 then
        local iTransAmount = iAmount2 - iAmount3
        itemobj1:AddAmount(-iTransAmount)
        if not bAll then
            local sText = GetText(1003)
            sText = global.oToolMgr:FormatColorString(sText, {item = itemobj1:TipsName(),amount = iTransAmount})
            oNotifyMgr:Notify(pid,sText)
        end
        return true
    end
end

function CTempItemCtrl:TranAllToItemBag(bFailSilent)
    local pid = self:GetOwner()
    local oNotifyMgr = global.oNotifyMgr
    local bNotifyFail = true
    local itemlist = self:ItemStartList()
    if table_count(itemlist)<=0 then
        return
    end
    for iPos, itemobj in pairs(itemlist) do
        if self:TranToItemBag(itemobj:ID(),true) then
            bNotifyFail = false
        end
    end
    if bNotifyFail then
        if not bFailSilent then
            oNotifyMgr:Notify(pid,GetText(1005))
        end
    else
        oNotifyMgr:Notify(pid,GetText(1004))
    end
end

function CTempItemCtrl:ReSort()
    local iSortPos = self:GetValidPos()
    if iSortPos then
        self:CheckSort(iSortPos)
    end
end

function GetText(iText)
    local mRes = res["daobiao"]["tempitem"]["text"][iText]
    if  not mRes then
        return  "没有配表"
    end
    return mRes["text"] 
end
