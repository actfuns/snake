--import module
local skynet = require "skynet"
local global = require "global"
local record = require "public.record"

local tableop = import(lualib_path("base.tableop"))

local datactrl = import(lualib_path("public.datactrl"))
local itemnet = import(service_path("netcmd.item"))
local itemdefines = import(service_path("item.itemdefines"))

local max = math.max
local min = math.min

CWHContainer = {}
CWHContainer.__index = CWHContainer
inherit(CWHContainer, datactrl.CDataCtrl)

function CWHContainer:New(pid)
    local o = super(CWHContainer).New(self, {pid = pid})
    o.m_Owner = pid
    o.m_Item = {}
    o.m_ItemID = {}
    o.m_mShape = {}
    o.m_ID = 0
    o.m_bRefresh = false
    return o
end

function CWHContainer:Release()
    for _,oItem in pairs(self.m_Item) do
        baseobj_safe_release(oItem)
    end
    self.m_ItemID = {}
    self.m_mShape = {}
    super(CWHContainer).Release(self)
end

function CWHContainer:GetOwner()
    return self.m_Owner
end

function CWHContainer:Save()
    local mData = {}

    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemdata[db_key(iPos)] = itemobj:Save()
    end
    mData["itemdata"] = itemdata
    mData["data"] = self.m_mData
    return mData
end

function CWHContainer:Load(mData)
    mData = mData or {}
    local itemdata = mData["itemdata"] or {}
    for iPos,data in pairs(itemdata) do
        iPos = tonumber(iPos)
        local itemobj = global.oItemLoader:LoadItem(data["sid"],data)
        assert(itemobj,string.format("item sid error:%s,%s,%s",self.m_Owner,data["sid"],iPos))
        if itemobj:Validate() then
            self.m_Item[iPos] = itemobj
            self.m_ItemID[itemobj.m_ID] = itemobj
            itemobj.m_Pos = iPos
            itemobj.m_Container = self
            itemobj:OnSetContainer(itemdefines.CONTAINER_MAP.WH_CTRL)
            self:AddShapeItem(itemobj)
        end
    end
    self.m_mData = mData["data"] or {}
end

function CWHContainer:SetName(sName)
    self:SetData("name",sName)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["name"] = sName
    oPlayer:Send("GS2CWareHouseName",mNet)
end

function CWHContainer:Refresh()
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["name"] = self:Name()
    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        table.insert(itemdata,itemobj:PackItemInfo())
    end
    mNet["itemdata"] = itemdata
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CRefreshWareHouse",mNet)
    end
    self.m_bRefresh = true
end

function CWHContainer:Name()
    return self:GetData("name") or string.format("仓库%s",self.m_ID)
end

function CWHContainer:LimitSize()
    return 25
end

function CWHContainer:GetValidPos()
    for iPos = 1,self:LimitSize() do
        if not self.m_Item[iPos] then
            return iPos
        end 
    end
end

function CWHContainer:ItemStartList()
    return self.m_Item
end

function CWHContainer:ValidStore(srcobj)
    if tableop.table_count(self.m_Item) < self:LimitSize() then
        return true
    end
    local iLastAmount = srcobj:GetAmount()
    local iMaxAmount = srcobj:GetMaxAmount()
    local iCanStoreAmount = 0
    local iCombineKey = srcobj:CombineKey()
    for _,itemobj in pairs(self.m_Item) do
        if srcobj:SID() == itemobj:SID() and itemobj:CombineKey() == iCombineKey then
            local iHaveAmount = itemobj:GetAmount()
            iCanStoreAmount = iCanStoreAmount + max(iMaxAmount-iHaveAmount,0)
        end
    end
    if srcobj:GetAmount() <= iCanStoreAmount then
        return true
    end
    return false
end

function CWHContainer:AddItem(srcobj)
    local iLast = srcobj:GetAmount()
    local iMaxAmount = srcobj:GetMaxAmount()
    local iShape = srcobj:SID()
    local lShape = self:GetShapeItem(iShape)
    local mSrcSaveData = srcobj:Save()
    for _,itemobj in pairs(lShape) do
        if srcobj:ValidCombine(itemobj) then
            local iHave = itemobj:GetAmount()
            local iCanAdd = max(iMaxAmount - iHave,0)
            if iLast > 0 and iCanAdd > 0 then
                iCanAdd = min(iCanAdd,iLast)
                iLast = iLast - iCanAdd
                srcobj:AddAmount(-iCanAdd,"combine")
                itemobj:AddAmount(iCanAdd,"combine")
                itemobj:AfterCombine(mSrcSaveData)
                self:GS2CUpdateItem(itemobj)
            end
        end
        if iLast <=0 then
            break
        end
    end
    if iLast <= 0 then
        baseobj_delay_release(srcobj)
        return nil
    end
    local iPos = self:GetValidPos()
    if not iPos then
        return srcobj
    end
    assert(iPos,"CWHContainer AddToPos:%s %s",self.m_Owner,srcobj:Name())
    self:AddToPos(srcobj,iPos)
end

function CWHContainer:GetItem(iPos)
    return self.m_Item[iPos]
end

function CWHContainer:GetStartPos()
    return 1
end

--存入仓库
function CWHContainer:WithStore(oSrcContainer,itemid)
    local oNotifyMgr = global.oNotifyMgr
    local itemobj = oSrcContainer:HasItem(itemid)
    if not itemobj then
        return
    end
    if not itemobj:ValidMoveWH() then
        oNotifyMgr:Notify(self.m_Owner, "该物品不能存入仓库")
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not self:ValidStore(itemobj) then
        if oPlayer then
            oPlayer:SendNotification(2002)
        end
        return
    end
    local iSid, mData = itemobj:SID(), itemobj:Save()
    oSrcContainer:RemoveItem(itemobj)
    local oNewItem = global.oItemLoader:LoadItem(iSid, mData)
    local mItemLog = oNewItem:PackLogInfo()
    local retobj = self:AddItem(oNewItem)

    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData.item = oNewItem:SID()
        mLogData.iteminfo = mItemLog
        record.user("item", "with_store", mLogData)
    end
end

--从仓库取出
function CWHContainer:WithDraw(iPos,oDestContainer)
    local oNotifyMgr = global.oNotifyMgr
    local itemobj = self:GetItem(iPos)
    if not itemobj then
        return
    end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oDestContainer:ValidStorePos(itemobj) then
        if oPlayer then
            oPlayer:SendNotification(2001)
        end
        return
    end

    local iSid, mData = itemobj:SID(), itemobj:Save()
    self:RemoveItem(itemobj)
    local mArgs = {
        from_wh = 1
    }
    local oNewItem = global.oItemLoader:LoadItem(iSid, mData)
    local retobj = oDestContainer:AddItem(oNewItem, mArgs)

    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData.item = oNewItem:SID()
        mLogData.iteminfo = oNewItem:PackLogInfo()
        record.user("item", "with_draw", mLogData)
    end
end

function CWHContainer:ValidArrangeChange(srcobj)
    local srcpos = srcobj.m_Pos
    if srcpos == iPos then
        return false
    end
    return true
end

function CWHContainer:ArrangeChange(srcobj,iPos)
    local destobj = self:GetItem(iPos)
    if not destobj then
        self:ChangeToPos(srcobj,iPos)
    else
        self:ItemChange(srcobj,destobj)
    end
    return destobj
end

function CWHContainer:ChangeToPos(srcobj,iPos)
    self:Dirty()
    local srcpos = srcobj.m_Pos
    self.m_Item[srcpos] = nil
    self.m_Item[iPos] = srcobj
    srcobj.m_Pos = iPos
end

function CWHContainer:ItemChange(srcobj,destobj)
    self:Dirty()
    local srcpos = srcobj.m_Pos
    local destpos = destobj.m_Pos
    self.m_Item[srcpos] = destobj
    self.m_Item[destpos] = srcobj
    srcobj.m_Pos = destpos
    destobj.m_Pos = srcpos
end

function CWHContainer:AddToPos(itemobj,iPos)
    self:Dirty()
    self.m_Item[iPos] = itemobj
    self.m_ItemID[itemobj.m_ID] = itemobj
    itemobj.m_Pos = iPos
    itemobj.m_Container = self
    itemobj:OnSetContainer(itemdefines.CONTAINER_MAP.WH_CTRL)
    self:GS2CAddItem(itemobj)
    self:AddShapeItem(itemobj)
end

function CWHContainer:RemoveItem(itemobj)
    self:Dirty()
    self:GS2CDelItem(itemobj)
    local iPos = itemobj.m_Pos
    itemobj:OnDelContainer()
    self.m_Item[iPos] = nil
    self.m_ItemID[itemobj.m_ID] = nil
    itemobj.m_Container = nil
    itemobj.m_Pos = nil
    self:RemoveShapeItem(itemobj)
    baseobj_delay_release(itemobj)
end

function CWHContainer:AddShapeItem(oItem)
    local iSid = oItem:SID()
    local iItemid = oItem:ID()
    if not self.m_mShape[iSid] then
        self.m_mShape[iSid] = {}
    end
    local mItem = self.m_mShape[iSid] or {}
    mItem[iItemid] = 1
    self.m_mShape[iSid] = mItem
end

function CWHContainer:RemoveShapeItem(oItem)
    local iSid = oItem:SID()
    local iItemid = oItem:ID()
    local mShape = self.m_mShape[iSid]
    mShape[iItemid] = nil
    if not next(mShape) then
        mShape = nil
    end
    self.m_mShape[iSid] = mShape
end

function CWHContainer:GetShapes()
    return self.m_mShape
end

function CWHContainer:GetShapeItem(sid)
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

function CWHContainer:GetItemObj(sid)
    local mShape = self.m_mShape[sid] or {}
    for iItemid,_ in pairs(mShape) do
        local oItem = self:HasItem(iItemid)
        if oItem then
            return oItem
        end
    end
end

function CWHContainer:HasItem(itemid)
    return self.m_ItemID[itemid]
end

function CWHContainer:GS2CAddItem(itemobj)
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["itemdata"] = itemobj:PackItemInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CAddWareHouseItem",mNet)
    end
end

function CWHContainer:GS2CDelItem(itemobj)
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["itemid"] = itemobj.m_ID
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CDelWareHouseItem",mNet)
    end
end

function CWHContainer:GS2CUpdateItem(itemobj)
    if not self.m_bRefresh then return end
    
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["itemdata"] = itemobj:PackItemInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CUpdateWHItem",mNet)
    end
end

function CWHContainer:GS2CItemArrange(pid,mChange)
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["pos_info"] = mChange
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CWHItemArrange",mNet)
    end
end

function CWHContainer:GS2CItemAmount(itemobj, mArgs)
    local mNet = {}
    mNet["wid"] = self.m_ID
    mNet["itemid"] = itemobj.m_ID
    mNet["amount"] = itemobj:GetAmount()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CWHItemAmount",mNet)
    end
end

function CWHContainer:PackBackendInfo()
    local mData = {}

    local itemdata = {}
    for iPos,itemobj in pairs(self.m_Item) do
        itemdata[db_key(iPos)] = itemobj:PackBackendInfo()
    end
    mData["itemdata"] = itemdata
    return mData
end

function CWHContainer:UnDirty()
    super(CWHContainer).UnDirty(self)
    for _,itemobj in pairs(self.m_Item) do
        if itemobj:IsDirty() then
            itemobj:UnDirty()
        end
    end
end

function CWHContainer:IsDirty()
    local bDirty = super(CWHContainer).IsDirty(self)
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

function CWHContainer:OnLogin(oPlayer, bReEnter)
    for _,itemobj in pairs(self.m_Item) do
        itemobj:OnLogin(oPlayer, bReEnter)
    end
end


CWareHouseCtrl = {}
CWareHouseCtrl.__index = CWareHouseCtrl
inherit(CWareHouseCtrl,datactrl.CDataCtrl)

function CWareHouseCtrl:New(pid)
    local o = super(CWareHouseCtrl).New(self,pid)
    o.m_Owner = pid
    o.m_List = {}
    return o
end

function CWareHouseCtrl:Release()
    for _,oWH in pairs(self.m_List) do
        baseobj_safe_release(oWH)
    end
    self.m_List = {}
    super(CWareHouseCtrl).Release(self)
end

function CWareHouseCtrl:Save()
    local mData = {}
    local mWHData = {}
    for iNo,oWH in ipairs(self.m_List) do
        mWHData[iNo] = oWH:Save()
    end
    mData["warehouse"] = mWHData
    mData["data"] = self.m_mData
    return mData
end

function CWareHouseCtrl:Load(mData)
    mData = mData or {}
    local mWHData = mData["warehouse"] or {}
    for iNo,data in pairs(mWHData) do
        local oWareHouse = CWHContainer:New(self.m_Owner)
        oWareHouse.m_ID = iNo
        oWareHouse:Load(data)
        self.m_List[iNo] = oWareHouse
    end
    local iSize = self:DefaultSize()
    if tableop.table_count(self.m_List) < iSize then
        for iNo=1,iSize do
            local oWareHouse = CWHContainer:New(self.m_Owner)
            oWareHouse.m_ID = iNo
            self.m_List[#self.m_List+1] = oWareHouse
            if tableop.table_count(self.m_List) >= iSize then
                break
            end
        end
    end
    self.m_mData = mData["data"] or {}
end

function CWareHouseCtrl:DefaultSize()
    return 2
end

function CWareHouseCtrl:LimitSize()
    local res = require "base.res"
    local mData = res["daobiao"]["global"]
    local iSize = tonumber(mData[102]["value"])
    if iSize then
        return iSize
    else
        return 9
    end
end

function CWareHouseCtrl:GetWareHouse(id)
    return self.m_List[id]
end

function CWareHouseCtrl:OnLogin(oPlayer,bReEnter)
    for _,oWareHouse  in ipairs(self.m_List) do
        oWareHouse:OnLogin(oPlayer, bReEnter)
    end
    self:RefreshWareHouseInfo()
end

function CWareHouseCtrl:ValidBuyWareHouse()
    if #self.m_List >= self:LimitSize() then
        return false
    end
    return true
end

function CWareHouseCtrl:BuyWareHouse()
    if not self:ValidBuyWareHouse() then
        return
    end
    self:Dirty()
    local iNo = #self.m_List + 1
    local oWareHouse = CWHContainer:New(self.m_Owner)
    oWareHouse.m_ID = iNo
    self.m_List[iNo] = oWareHouse
    oWareHouse:Refresh()
    self:RefreshWareHouseInfo()
end

function CWareHouseCtrl:RefreshWareHouseInfo()
    local mNet = {}
    mNet["size"] = #self.m_List
    local mName = {}
    for _,oWareHouse  in ipairs(self.m_List) do
        table.insert(mName,oWareHouse:Name())
    end
    mNet["namelist"] = mName
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CWareHouseInfo",mNet)
end

function CWareHouseCtrl:PackBackendInfo()
    local mNet = {}
    local mWHData = {}
    for iNo,oWH in ipairs(self.m_List) do
        mWHData[iNo] = oWH:PackBackendInfo()
    end
    mNet["warehouse"] = mWHData
    return mNet
end

function CWareHouseCtrl:UnDirty()
    super(CWareHouseCtrl).UnDirty(self)
    for _,oWareHouse in pairs(self.m_List) do
        if oWareHouse:IsDirty() then
            oWareHouse:UnDirty()
        end
    end
end

function CWareHouseCtrl:IsDirty()
    local bDirty = super(CWareHouseCtrl).IsDirty(self)
   if bDirty then
        return true
    end
    for _,oWareHouse in pairs(self.m_List) do
        if oWareHouse:IsDirty() then
            return true
        end
    end
    return false
end
