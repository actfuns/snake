local skynet = require "skynet"
local global = require "global"
local record = require "public.record"
local extend = require "base.extend"
local res = require "base.res"
local datactrl = import(lualib_path("public.datactrl"))
local loadsummon = import(service_path("summon.loadsummon"))


local ITEM_SIZE  = 30
local SUMMON_SIZE = 10
local ITEM_START = 1
local SUMMON_START = 1
local ACTIVE_TIME = 3*30*24*60*60

CRecoveryCtrl = {}
CRecoveryCtrl.__index = CRecoveryCtrl
inherit(CRecoveryCtrl, datactrl.CDataCtrl)

function CRecoveryCtrl:New(pid)
    local o = super(CRecoveryCtrl).New(self,{pid = pid})
    o:Init(pid)
    return o
end

function CRecoveryCtrl:Init(pid)
    self.m_Owner = pid
    self.m_Item = {}
    self.m_ItemID = {}
    self.m_Summon = {}
    self.m_SummonID = {}
end

function CRecoveryCtrl:Release()
    for _,oItem in pairs(self.m_Item) do
        baseobj_safe_release(oItem)
    end
    for _,oSum in pairs(self.m_Summon) do
        baseobj_safe_release(oSum)
    end
    self.m_Item = {}
    self.m_ItemID = {}
    self.m_Summon = {}
    self.m_SummonID = {}
    super(CRecoveryCtrl).Release(self)      
end

function CRecoveryCtrl:Save()
    local mData = {}
    local itemdata = {}
    local sumdata = {}
    for pos,itemobj in pairs(self.m_Item) do
        itemdata[db_key(pos)] = itemobj:Save()
    end
    for pos,sumobj in pairs(self.m_Summon) do
        sumdata[db_key(pos)] = sumobj:Save()
    end
    mData["itemdata"] = itemdata
    mData["sumdata"] = sumdata
    return mData
end

function CRecoveryCtrl:Load(mData)
    mData = mData or {}
    local itemdata = mData["itemdata"] or {}
    local sumdata = mData["sumdata"] or {}
    local iNowTime = get_time()
    for pos ,data in pairs(itemdata) do
        if not data["sid"] then
            self:Dirty()
            break
        end
        local iCreateTime = data["data"]["cycreate_time"] or 0
        local sid = data["sid"]
        if iNowTime-iCreateTime>ACTIVE_TIME then
            self:Log("delitem3",{createtime = iCreateTime,sid = sid},"item")
        else
            pos = tonumber(pos)
            local itemobj = global.oItemLoader:LoadItem(sid,data)
            assert(itemobj,string.format("item sid error:%s,%s",self.m_Owner,sid))
            self.m_Item[pos] = itemobj
            self.m_ItemID[itemobj:ID()] = itemobj
            itemobj.m_Pos = pos
        end
    end
    for pos,data in pairs(sumdata) do
        if not data["sid"] then
            self:Dirty()
            break
        end
        local iCreateTime = data["cycreate_time"] or 0
        local sid = data["sid"]
        if iNowTime-iCreateTime>ACTIVE_TIME then
            self:Log("delsum3",{createtime = iCreateTime,sid = sid},"sum")
        else
            pos = tonumber(pos)
            local sumobj = loadsummon.LoadSummon(sid, data)
            assert(sumobj, string.format("summon sid error:%s,%s",self.m_Owner,sid))
            self.m_Summon[pos] = sumobj
            self.m_SummonID[sumobj:ID()] = sumobj
            sumobj.m_Pos = pos
        end
    end
end

function CRecoveryCtrl:OnLogin(oPlayer,bReEnter)
end

function CRecoveryCtrl:Log(sSubType,mData,sType)
    local mLogData = {}
    if sType == "item" then
        mLogData.iteminfo = extend.Table.serialize(mData)
    else
         mLogData.suminfo = extend.Table.serialize(mData)
    end
    mLogData.pid = self.m_Owner
    record.user("recovery", sSubType, mLogData)
end

function CRecoveryCtrl:UnDirty()
    super(CRecoveryCtrl).UnDirty(self)
    for _,itemobj in pairs(self.m_Item) do
        if itemobj:IsDirty() then
            itemobj:UnDirty()
        end
    end
    for _,sumobj in pairs(self.m_Summon) do
        if sumobj:IsDirty() then
            sumobj:UnDirty()
        end
    end
end

function CRecoveryCtrl:IsDirty()
    local bDirty = super(CRecoveryCtrl).IsDirty(self)
   if bDirty then
        return true
    end
    for _,itemobj in pairs(self.m_Item) do
        if itemobj:IsDirty() then
            return true
        end
    end
    for _,sumobj in pairs(self.m_Summon) do
        if sumobj:IsDirty() then
            return true
        end
    end
    return false
end

function CRecoveryCtrl:GetOwner()
    return self.m_Owner
end

function CRecoveryCtrl:GetItemEndPos()
    return ITEM_START + ITEM_SIZE - 1
end

function CRecoveryCtrl:GetSumEndPos()
    return SUMMON_START + SUMMON_SIZE - 1
end

function CRecoveryCtrl:GetItemStartPos()
    return ITEM_START
end

function CRecoveryCtrl:GetSumStartPos()
    return SUMMON_START
end

function CRecoveryCtrl:GetValidItemPos()
    local endpos = self:GetItemEndPos()
    local startpos = self:GetItemStartPos()
    for iPos = startpos,endpos do
        if not self.m_Item[iPos] then
            return iPos
        end
    end
end

function CRecoveryCtrl:GetValidSumPos()
    local endpos = self:GetSumEndPos()
    local startpos = self:GetSumStartPos()
    for iPos = startpos,endpos do
        if not self.m_Summon[iPos] then
            return iPos
        end
    end
end

function CRecoveryCtrl:ItemList()
    return self.m_Item
end

function CRecoveryCtrl:SumList()
    return self.m_Summon
end

function CRecoveryCtrl:GetItemByPos(iPos)
    return self.m_Item[iPos]
end

function CRecoveryCtrl:GetSumByPos(iPos)
    return self.m_Summon[iPos]
end

function CRecoveryCtrl:ItemStartList()
    local mItemList = {}
    local iStartPos = self:GetItemStartPos()
    local iEndPos = self:GetItemEndPos()
    for iPos,oItem in pairs(self.m_Item) do
        if iPos >= iStartPos and iPos <= iEndPos then
            mItemList[iPos] = oItem
        end
    end
    return mItemList
end

function CRecoveryCtrl:SumStartList()
    local mSumList = {}
    local iStartPos = self:GetSumStartPos()
    local iEndPos = self:GetSumEndPos()
    for iPos,oSum in pairs(self.m_Summon) do
        if iPos >= iStartPos and iPos <= iEndPos then
            mSumList[iPos] = oSum
        end
    end
    return mSumList
end

function CRecoveryCtrl:PrintAllItem()
    for iPos, itemobj in pairs(self:ItemStartList()) do
        print(itemobj:PackItemInfo())
    end
end

function CRecoveryCtrl:ClearAllItem()
    for iPos, itemobj in pairs(self:ItemStartList()) do
        self:RemoveItem(itemobj) 
    end
    self:Dirty()
    self.m_Item={}
    self.m_ItemID={}
end

function CRecoveryCtrl:PrintAllSum()
    for iPos, sumobj in pairs(self:SumStartList()) do
        print(sumobj:SummonInfo())
    end
end

function CRecoveryCtrl:ClearAllSum()
    for iPos, sumobj in pairs(self:SumStartList()) do
        self:RemoveSum(sumobj) 
    end
    self:Dirty()
    self.m_Summon={}
    self.m_SummonID={}
end

function CRecoveryCtrl:AddItem(data,iAmount)
    --print("AddItem",data,iAmount)
    if not global.oToolMgr:IsSysOpen("RECOVERY",nil,true) then    
        return
    end
    if not res["daobiao"]["recovery"]["item"][data["sid"]] then 
        return
    end
    self:Dirty()
    iAmount = math.abs(iAmount)
    for i = 1,iAmount do 
        local itemobj = global.oItemLoader:LoadItem(data["sid"],data)
        itemobj:SetData("cycreate_time",get_time())
        local iPos = self:GetValidItemPos()
        if not iPos then
            self:ReAddItem(itemobj)
        else
            self:AddItemToPos(itemobj,iPos)
        end
    end
end

function CRecoveryCtrl:AddItemToPos(itemobj,iPos)
    self.m_Item[iPos] = itemobj
    self.m_ItemID[itemobj:ID()] = itemobj
    itemobj.m_Pos = iPos
    self:Log("additem",{sid = itemobj:SID()},"item")
    --print("AddItemToPos",itemobj:SID(),itemobj.m_Pos)
end

function CRecoveryCtrl:ReAddItem(itemobj)
    self:Dirty()
    local RemoveObj = self.m_Item[self:GetItemStartPos()]
    self.m_ItemID[RemoveObj:ID()] = nil
    baseobj_delay_release(RemoveObj)

    self:Log("delitem2",{sid = RemoveObj:SID()},"item")
    --print("ReAddItem1",RemoveObj:SID(),RemoveObj.m_Pos)

    for pos = self:GetItemStartPos(),self:GetItemEndPos(),1 do
        self.m_Item[pos] = self.m_Item[pos+1]
        if self.m_Item[pos] then
            self.m_Item[pos].m_Pos = pos
        end
    end
    itemobj.m_Pos = self:GetItemEndPos()
    self.m_Item[self:GetItemEndPos()] = itemobj
    self.m_ItemID[itemobj:ID()] = itemobj
    self:Log("additem",{sid = itemobj:SID()},"item")
    --print("ReAddItem2",itemobj:SID(),itemobj.m_Pos)
end

function CRecoveryCtrl:RemoveItem(itemobj)
    self:Dirty()
    local iPos = itemobj.m_Pos
    self.m_Item[iPos] = nil
    self.m_ItemID[itemobj:ID()] = nil
    self:GS2CRemoveItem(itemobj)
    baseobj_delay_release(itemobj)

    for pos = iPos,self:GetItemEndPos(),1 do 
        self.m_Item[pos] = self.m_Item[pos+1]
        if self.m_Item[pos] then
            self.m_Item[pos].m_Pos = pos
        end
    end
end

function CRecoveryCtrl:AddSum(mData,sReason)
    --print("AddSum",mData,sReason)
    if not global.oToolMgr:IsSysOpen("RECOVERY",nil,true) then    
        return
    end
    if not res["daobiao"]["recovery"]["sum"][mData["sid"]] then 
        return
    end
    self:Dirty()
    local oSummon = loadsummon.LoadSummon(mData["sid"], mData)
    oSummon:SetData("cycreate_time",get_time())
    local iPos = self:GetValidSumPos()
    if not iPos then
        self:ReAddSum(oSummon)
    else
        self:AddSumToPos(oSummon,iPos)
    end
end

function CRecoveryCtrl:AddSumToPos(oSummon,iPos)
    self.m_Summon[iPos] = oSummon
    self.m_SummonID[oSummon:ID()] = oSummon
    oSummon.m_Pos = iPos
    self:Log("addsum",{sid = oSummon:TypeID()},"sum")
    --print("AddSumToPos",oSummon:TypeID(),oSummon.m_Pos)
end

function CRecoveryCtrl:ReAddSum(sumobj)
    self:Dirty()
    local RemoveObj = self.m_Summon[self:GetSumStartPos()]
    self.m_Summon[RemoveObj:ID()] = nil
    baseobj_delay_release(RemoveObj)

    self:Log("delsum2",{sid = RemoveObj:TypeID()},"sum")
    --print("ReAddSum1",RemoveObj:TypeID(),RemoveObj.m_Pos)

    for pos = self:GetSumStartPos(),self:GetSumEndPos(),1 do
        self.m_Summon[pos] = self.m_Summon[pos+1]
        if self.m_Summon[pos] then
            self.m_Summon[pos].m_Pos = pos
        end
    end
    sumobj.m_Pos = self:GetSumEndPos()
    self.m_Summon[self:GetSumEndPos()] = sumobj
    self.m_SummonID[sumobj:ID()] = sumobj
    self:Log("addsum",{sid = sumobj:TypeID()},"sum")
    --print("ReAddSum2",sumobj:TypeID(),sumobj.m_Pos)
end

function CRecoveryCtrl:RemoveSum(sumobj)
    self:Dirty()
    local iPos = sumobj.m_Pos
    self.m_Summon[iPos] = nil
    self.m_SummonID[sumobj:ID()] = nil
    self:GS2CRemoveSum(sumobj)
    baseobj_delay_release(sumobj)

    for pos = iPos,self:GetSumEndPos(),1 do 
        self.m_Summon[pos] = self.m_Summon[pos+1]
        if self.m_Summon[pos] then
            self.m_Summon[pos].m_Pos = pos
        end
    end
end

function CRecoveryCtrl:OpenRecoveryItem()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    local lItemList = {}
    for _,itemobj in pairs(self.m_Item) do
        table.insert(lItemList,itemobj:PackItemInfo())
    end
    mNet.itemdata = lItemList
    --print("GS2COpenRecoveryItem",mNet)
    oPlayer:Send("GS2COpenRecoveryItem",mNet)
end

function CRecoveryCtrl:GS2CRemoveItem(itemobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet["id"] = itemobj:ID()
    oPlayer:Send("GS2CDelRecoveryItem",mNet)
end

function CRecoveryCtrl:GS2CRemoveSum(sumobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet["id"] = sumobj:ID()
    oPlayer:Send("GS2CDelRecoverSum",mNet)
end

function CRecoveryCtrl:OpenRecoverySum()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local mNet = {}
    local lSumList = {}
    for _,sumobj in pairs(self.m_Summon) do
        table.insert(lSumList,sumobj:SummonInfo())
    end
    mNet.sumdata = lSumList
    --print("GS2COpenRecoverySum",mNet)
    oPlayer:Send("GS2COpenRecoverySum",mNet)
end

function CRecoveryCtrl:ValidRecoveryItem(oPlayer,itemobj)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not global.oToolMgr:IsSysOpen("RECOVERY",oPlayer,false) then    
        return false
    end
    local mRes = res["daobiao"]["recovery"]["item"][itemobj:SID()]
    if not mRes then
        oNotifyMgr:Notify(pid,"此道具不能回收")
        return false
    end
    local sFormula = mRes["cost"]
    local iGoldCoin = formula_string(sFormula, {lv = itemobj:Quality()})
    iGoldCoin = math.floor(iGoldCoin)
    if not oPlayer:ValidGoldCoin(iGoldCoin) then
        return false
    end
    oPlayer:ResumeGoldCoin(iGoldCoin,"recoveryitem")
    return true
end

function CRecoveryCtrl:RecoveryItem(oPlayer,itemid)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local itemobj = self.m_ItemID[itemid]
    if not itemobj then return end
    if not self:ValidRecoveryItem(oPlayer,itemobj) then return end
    local mRes = res["daobiao"]["recovery"]["item"][itemobj:SID()]
    local sFormula = mRes["cost"]
    local iGoldCoin = formula_string(sFormula, {lv = itemobj:Quality()})
    iGoldCoin = math.floor(iGoldCoin)
    self:Log("delitem1",{sid = itemobj:SID()},"item")
    local itemobj2 = global.oItemLoader:LoadItem(itemobj:SID(),itemobj:Save())
    self:RemoveItem(itemobj)
    oPlayer:RewardItem(itemobj2,"物品找回",{cancel_tip = true,cancel_chat = true})
    oNotifyMgr:Notify(pid,string.format("消耗了%s元宝，你找回了%s",iGoldCoin,itemobj:Name()))
end

function CRecoveryCtrl:ValidRecoverySum(oPlayer,sumobj)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not global.oToolMgr:IsSysOpen("RECOVERY",oPlayer,false) then    
        return false
    end
    if oPlayer.m_oSummonCtrl:IsFull() then
        oNotifyMgr:Notify(pid,"你的宠物栏已满，无法找回")
        return false
    end
    local mRes = res["daobiao"]["recovery"]["sum"][sumobj:TypeID()]
    if not mRes then
        oNotifyMgr:Notify(pid,"此宠物不能回收")
        return false
    end
    local sFormula = mRes["cost"]
    local iGoldCoin = formula_string(sFormula, {lv = sumobj:CarryGrade()})
    iGoldCoin = math.floor(iGoldCoin)
    if not oPlayer:ValidGoldCoin(iGoldCoin) then
        return false
    end
    oPlayer:ResumeGoldCoin(iGoldCoin,"recoveryitem")
    return true
end

function CRecoveryCtrl:RecoverySum(oPlayer,sumid)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local sumobj = self.m_SummonID[sumid]
    if not sumobj then return end 
    if not self:ValidRecoverySum(oPlayer,sumobj) then return end
    local mRes = res["daobiao"]["recovery"]["sum"][sumobj:TypeID()]
    local sFormula = mRes["cost"]
    local iGoldCoin = formula_string(sFormula, {lv = sumobj:CarryGrade()})
    iGoldCoin = math.floor(iGoldCoin)
    self:Log("delsum1",{sid = sumobj:TypeID()},"sum")
    local sumobj2 = loadsummon.LoadSummon(sumobj:TypeID(), sumobj:Save())
    self:RemoveSum(sumobj)
    oPlayer.m_oSummonCtrl:AddSummon(sumobj2, "recovery")
    oNotifyMgr:Notify(pid,string.format("消耗了%s元宝，你找回了%s",iGoldCoin,sumobj:Name()))
end

