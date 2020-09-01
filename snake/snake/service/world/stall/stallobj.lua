local global = require "global"
local res = require "base.res"
local record = require "public.record"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local stallcatalog = import(service_path("stall.stallcatalog"))
local defines = import(service_path("stall.defines"))
local proxy = import(service_path("stall.itemobj"))
local servicesave = import(lualib_path("base.servicesave"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))
local gamedb = import(lualib_path("public.gamedb"))
local analylog = import(lualib_path("public.analylog"))


function NewStallObj(iPid, ...)
    local o = CStall:New(iPid, ...)
    return o
end

CStall = {}
CStall.__index = CStall
inherit(CStall, datactrl.CDataCtrl)

function CStall:New(iPid, ...)
    local o = super(CStall).New(self)
    o.m_iPid = iPid
    o:Init()
    return o
end

function CStall:Init()
    self.m_mItemInfo = {}
    self.m_mCashInfo = {}
    self.m_iSizeLimit = 6
    self.m_iProxyId = 0
    self.m_iMorningDayNo = 0
    self.m_iSellCnt = 0
    self.m_iSellPrice = 0
end

function CStall:Save()
    local mData = {}
    mData.size_limit = self.m_iSizeLimit
    mData.item_info = self:SaveItemInfo()
    mData.cash_info = self:SaveCashInfo()
    mData.morningdayno = self.m_iMorningDayNo
    mData.sell_cnt = self.m_iSellCnt
    mData.sell_price = self.m_iSellPrice
    return mData
end

function CStall:SaveItemInfo()
    local mResult = {}
    for iPos, oItem in pairs(self.m_mItemInfo) do
        local sPos = db_key(iPos)
        mResult[sPos] = oItem:Save()
    end
    return mResult
end

function CStall:SaveCashInfo()
    local mResult = {}
    for iPos, iCash in pairs(self.m_mCashInfo) do
        local sPos = db_key(iPos)
        mResult[sPos] = iCash
    end
    return mResult
end

function CStall:LoadItemInfo(mInfo)
    mInfo = mInfo or {}
    for sPos, mItem in pairs(mInfo) do
        local iPos = tonumber(sPos)
        local oItem = self:CreateItem(mItem.datactrl.sid, mItem)
        self.m_mItemInfo[iPos] = oItem
        self:BuildCatalogIndex(iPos, oItem)
    end
end

function CStall:LoadCashInfo(mInfo)
    mInfo = mInfo or {}
    for sPos, iPrice in pairs(mInfo) do
        local iPos = tonumber(sPos)
        self.m_mCashInfo[iPos] = iPrice
    end
end

function CStall:Load(m)
    self.m_iSizeLimit = m.size_limit or 6
    self:LoadItemInfo(m.item_info)
    self:LoadCashInfo(m.cash_info)
    self.m_iMorningDayNo = m.morningdayno or get_morningdayno()
    self.m_iSellCnt = m.sell_cnt or 0
    self.m_iSellPrice = m.sell_price or 0
end

function CStall:Dirty(iMergeId)
    super(CStall).Dirty(self)

    if not iMergeId then return end
    local oMerge = self:GetPlayer(iMergeId)
    if oMerge then
        self:AddSaveMerge(oMerge)
    end
end

function CStall:DispatchProxyId()
    self.m_iProxyId = self.m_iProxyId + 1
    return self.m_iProxyId
end

function CStall:GetSellItem(iPos)
    return self.m_mItemInfo[iPos]
end

function CStall:GetEmptyPosList()
    local lEmptyPos = {}
    for iPos = 1, self.m_iSizeLimit do
        local iCash = self.m_mCashInfo[iPos]
        if iCash and iCash > 0 then
            goto continue
        end
        if self.m_mItemInfo[iPos] then
            goto continue
        end
        table.insert(lEmptyPos, iPos)
        ::continue::
    end
    return lEmptyPos
end

function CStall:AddSizeLimit(iAdd)
    if self.m_iSizeLimit + iAdd > defines.ITEM_SIZE_LIMIT then
        return false
    else
        self.m_iSizeLimit = self.m_iSizeLimit + iAdd
        self:Dirty(self.m_iPid)
        return true
    end
end

function CStall:ValidSell(iPos, iItem, iAmount, iPrice)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return false end

    local iPid = self:GetOwner()
    local iSilver = self.m_mCashInfo[iPos]
    if iSilver and iSilver > 0 then
        self:Notify(iPid, 1001)
        return false
    end
   
    if self:GetSellSize() >= self.m_iSizeLimit then
        self:Notify(iPid, 1002)
        return false
    end
   
    local oItem = oPlayer:HasItem(iItem)
    if not oItem then
        self:Notify(iPid, 1003)
        return false
    end
    
    if oItem:GetAmount() < iAmount then
        self:Notify(iPid, 1004)
        return false
    end
    
    if oItem:IsBind() then
        self:Notify(iPid, 1023)
        return false
    end

    if oItem:IsStallItem() then
        self:Notify(iPid, 1028)
        return false
    end

    local iSid = oItem:SID()
    local iQuery = defines.EncodeSid(iSid)
    if (10046<=iSid and iSid<=10050) or (10058<=iSid and iSid<=10064) then
        iQuery = defines.EncodeSid(iSid, oItem:Quality())
    end
    if defines.FUZHUAN[iSid] then
        iQuery = defines.EncodeSid(iSid, oItem:GetData("skill_level", 1) * 10)
    end
    local mInfo = self:GetItemTable(iQuery)
    if not mInfo or mInfo.stallable == 0 then
        self:Notify(iPid, 1005)
        return false
    end

    if not oItem:IsStore() then
        self:Notify(iPid, 1005)
        return false
    end

    if oItem:ItemType() == "equip" and oItem:Quality() >= 3 then
        self:Notify(iPid, 1005)
        return false
    end
    if oItem:ItemType() == "equip" and (oItem:HasSE() or oItem:HasSK()) then
        self:Notify(iPid, 1024)
        return false
    end

    if iPrice < mInfo.min_price or iPrice > mInfo.max_price then
        self:Notify(iPid, 1006)
        return false
    end
   
    local iDefault = self:GetDefaultPrice(iQuery) 
    if math.abs(iPrice-iDefault) / iDefault * 100 >  50 then
        self:Notify(iPid, 1006)
        return false
    end
    
    local iTax = mInfo.tax or 0
    local iTaxFee = math.floor(iPrice * iAmount * iTax / 100)
    if iTaxFee > 0 and not oPlayer:ValidSilver(iTaxFee, {cancel_tip=1}) then
        self:Notify(iPid, 1007)
        return false
    end

    return true
end

function CStall:AddSellItem(iPos, iItem, iAmount, iPrice,bSilent)
    if not self:ValidSell(iPos, iItem, iAmount, iPrice) then
        return false
    end
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    --self:ReturnItem2Owner(iPos)
    if self.m_mItemInfo[iPos] then return false end
    
    local oPlayer = self:GetPlayer()
    local oItem = oPlayer:HasItem(iItem)
    local iSid = oItem:SID()
    local mData = oItem:Save()
    oPlayer:RemoveOneItemAmount(oItem, iAmount, "stall_upitem", {cancel_tip=1, cancel_chat=1})
    local oSell = self:CreateItem(iSid, {datactrl=mData})

    local iTax = oSell:GetTableAttr("tax") or 0
    local iTaxFee = math.floor(iPrice * iAmount * iTax / 100)
    if iTaxFee > 0 then
        oPlayer:ResumeSilver(iTaxFee, "摆摊上架")
    end
    if not bSilent then
        local sMsg = "上架成功"
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
    end
    
    oSell:SetAmount(iAmount)
    oSell:SetPrice(iPrice)
    oSell:SetOwner(self:GetOwner())
    oSell:SetPos(iPos)
    self.m_mItemInfo[iPos] = oSell
    self:Dirty(self.m_iPid)
    local iTime = defines.InitTimeByGrade(oPlayer:GetGrade())
    oSell:SetSellStart(iTime)
    self:BuildCatalogIndex(iPos, oSell)
    self:SendOneGridInfo(iPos)
    self:RecordWarning(oPlayer, true)

    local mLogData = oPlayer:LogData()
    mLogData["sid"] = iSid
    mLogData["pos"] = iPos
    mLogData["amount"] = iAmount
    mLogData["price"] = iPrice
    mLogData["taxfee"] = iTaxFee
    record.log_db("economic", "stall_upitem", mLogData)

    -- 数据中心log
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["operation"] = 1
    mAnalyLog["currency_type"] = gamedefines.MONEY_TYPE.SILVER
    mAnalyLog["item_id"] = iSid
    mAnalyLog["num"] = iAmount
    mAnalyLog["consume_count"] = iTaxFee
    mAnalyLog["remain_currency"] = oPlayer:GetSilver()
    analy.log_data("ItemSale", mAnalyLog)
    return true
end

function CStall:AddSellItemList(lItemList)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr

    if not lItemList then return end

    local lEmptyPosList = self:GetEmptyPosList()
    local iLen = math.min(#lEmptyPosList, #lItemList)
    local bSell = false
    for iIdx = 1, iLen do
        local iPos = lEmptyPosList[iIdx]
        local mInfo = lItemList[iIdx]
        local iItem = mInfo.item_id
        local iPrice = mInfo.price
        local iAmount = mInfo.amount
        local bRet = self:AddSellItem(iPos, iItem, iAmount, iPrice,true)
        if bRet then bSell = true end
        if not bRet then break end
    end
    if bSell then
        local sMsg = "上架成功"
        local oPlayer = self:GetPlayer()
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
    end
    self:Dirty(self.m_iPid)
end

function CStall:AddOverTimeItem(oPlayer)
    local bNeedRefresh = false
    local iCurrTime = get_time()
    for iPos, oItem in pairs(self.m_mItemInfo) do
        if oItem:GetSellTime() + defines.GetKeepTime() < iCurrTime then
            oItem:SetSellTime(iCurrTime)
            local iTime = defines.InitTimeByGrade(oPlayer:GetGrade())
            oItem:SetSellStart(iTime)
            bNeedRefresh = true
        end
    end
    if bNeedRefresh then
        self:SendAllGridInfo()
        self:Notify(self.m_iPid, 1027)
    else
        self:Notify(self.m_iPid, 1021)
    end
end

function CStall:RecordWarning(oPlayer, bSell, iPrice)
    self:Dirty()
    if get_morningdayno() ~= self.m_iMorningDayNo then
        self.m_iSellCnt = 0
        self.m_iSellPrice = 0
        self.m_iMorningDayNo = get_morningdayno()
    end

    local iPid = self.m_iPid 
    local mData = res["daobiao"]["stall"]["stall_config"][1]
    if bSell then
        self.m_iSellCnt = self.m_iSellCnt + 1
        if self.m_iSellCnt > mData.sell_cnt_limit then
            record.warning("%d stall sell over %d", iPid, self.m_iSellCnt)
            local sMsg = string.format("玩家%d, 摆摊次数为:%d, 超过设定:%d", iPid, self.m_iSellCnt, mData.sell_cnt_limit)
            self:DebugMsg(iPid, sMsg)
        end
    end
    if iPrice and iPrice > 0 then
        self.m_iSellPrice = self.m_iSellPrice + iPrice
        if self.m_iSellPrice > mData.sell_price_limit then
            record.warning("%d stall sell price over %d", iPid, self.m_iSellPrice)
            local sMsg = string.format("玩家%d, 摆摊获利为:%d, 超过设定:%d", iPid, self.m_iSellPrice, mData.sell_price_limit)
            self:DebugMsg(iPid, sMsg)
        end
    end
end

function CStall:ReturnItem2Owner(iPos, iAmount)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local oSell = self.m_mItemInfo[iPos]
    if not oSell then
        self:Notify(oPlayer:GetPid(), 1008)
        return
    end

    iAmount = iAmount and iAmount or oSell:GetAmount()
    iAmount = math.min(iAmount, oSell:GetAmount())
    local mItem = {[oSell:SID()] = iAmount}
    --TODO 叠加是否有问题
    if not oPlayer:ValidGive(mItem) then
        self:Notify(oPlayer:GetPid(), 1009)
        return
    end

    local mData = oSell:ItemBaseData()
    local oItem = global.oItemLoader:LoadItem(oSell:SID(), mData)
    oItem:SetAmount(iAmount)
    oPlayer:RewardItem(oItem, "stall_return", {cancel_tip=1, cancel_chat=1})
    oPlayer:NotifyMessage("下架成功")
    global.oChatMgr:HandleMsgChat(oPlayer, "下架成功")
    oSell:AddAmount(-iAmount)
    self:TryRemoveItem(iPos)
    self:Dirty(self.m_iPid)
    
    local mNet = {pos_id = iPos}
    self:Send("GS2CStallOneGrid", {grid_unit= mNet})

    local mLogData = oPlayer:LogData()
    mLogData["sid"] = oItem:SID()
    mLogData["amount"] = iAmount
    mLogData["pos"] = iPos
    record.log_db("economic", "stall_downitem", mLogData)

    -- 数据中心log
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["operation"] = 2
    mAnalyLog["currency_type"] = gamedefines.MONEY_TYPE.SILVER
    mAnalyLog["item_id"] = oItem:SID()
    mAnalyLog["num"] = iAmount
    mAnalyLog["consume_count"] = 0
    mAnalyLog["remain_currency"] = oPlayer:GetSilver()
    analy.log_data("ItemSale", mAnalyLog)
end

function CStall:ResetItemPrice(iPos, iPrice)
    local oSell = self:GetSellItem(iPos)
    if not oSell then return end
   
    local iCurrTime = get_time() 
    if oSell:GetSellTime() + defines.GetKeepTime() >= iCurrTime then
        self:Notify(self:GetOwner(), 1018)
        return
    end
    local iDefault = self:GetDefaultPrice(oSell:QueryIdx()) 
    if math.abs(iPrice-iDefault) / iDefault * 100 >  50 then
        self:Notify(self:GetOwner(), 1006)
        return
    end

    oSell:SetSellTime(iCurrTime)
    oSell:SetPrice(iPrice)
    self:SendOneGridInfo(iPos)
end

function CStall:ResetItemListPrice(lItemList)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local iCurrTime = get_time()
    local bSuccess = false
    local iKeepTime = defines.GetKeepTime()
    for _, mItem in pairs(lItemList or {}) do
        local iPos = mItem.pos_id
        local iPrice = mItem.price
        local oSell = self:GetSellItem(iPos)
        if not oSell then goto continue end

        local iOldPrice = oSell:GetPrice()
        local iAmount = oSell:GetAmount()
        local iTaxFee = 0
        if iPrice ~= iOldPrice or oSell:GetSellTime() + iKeepTime < get_time() then
            local iDefault = self:GetDefaultPrice(oSell:QueryIdx()) 
            if math.abs(iPrice-iDefault) / iDefault * 100 >  50 then
                goto continue
            end

            local iTax = oSell:GetTableAttr("tax") or 0
            iTaxFee = math.floor(iPrice * iAmount * iTax / 100)
            if iTaxFee > 0 then
                if oPlayer:ValidSilver(iTaxFee, {cancel_tip=1}) then
                    oPlayer:ResumeSilver(iTaxFee, "摆摊上架")
                else
                    goto continue
                end
            end
        end
        oSell:SetSellTime(iCurrTime)
        oSell:SetPrice(iPrice)
        self:SendOneGridInfo(iPos)
        bSuccess = true
        ::continue::
    end
    
    if bSuccess then
        local sMsg = "上架成功"
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
        global.oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
    end
end

function CStall:TryRemoveItem(iPos)
    local oSell = self:GetSellItem(iPos)
    if not oSell then return end
    if oSell:GetAmount() > 0 then return end

    if self.m_mCashInfo[iPos] and self.m_mCashInfo[iPos] > 0 then
        return
    end

    self:RemoveCatalogIndex(oSell)
    self:ClearItemByPos(iPos)
end

function CStall:WithdrawOneGrid(iPos)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local iCash = self.m_mCashInfo[iPos]
    if not iCash or iCash <= 0 then return end

    self:Dirty(self.m_iPid)
    self.m_mCashInfo[iPos] = nil
    self:SendOneGridInfo(iPos)
    self:TryRemoveItem(iPos)
    if iCash > 0 then
        oPlayer:RewardSilver(iCash, "stall_withdraw")

        local mLogData = oPlayer:LogData()
        mLogData["pos_list"] = {iPos}
        mLogData["total"] = iCash
        record.log_db("economic", "stall_withdraw", mLogData)
    end
end

function CStall:WithdrawAllCash()
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local iTotal, lPos = 0, {}
    for iPos = 1, self.m_iSizeLimit do
        local iCash = self.m_mCashInfo[iPos]
        self.m_mCashInfo[iPos] = 0
        if iCash and iCash > 0 then
            iTotal = iTotal + iCash
            table.insert(lPos, iPos)
        end
        self:TryRemoveItem(iPos)
    end
    if iTotal > 0 then
        self:Dirty(self.m_iPid)
        self:SendAllGridCash()
        self.m_mCashInfo = {}
        oPlayer:RewardSilver(iTotal, "stall_withdraw")

        local mLogData = oPlayer:LogData()
        mLogData["pos_list"] = lPos
        mLogData["total"] = iTotal
        record.log_db("economic", "stall_withdraw", mLogData)
    else
        self:Notify(self.m_iPid, 1022)
    end
end

function CStall:SendAllGridCash()
    local mRet = {}
    for iPos, iCash in pairs(self.m_mCashInfo) do
        local mCash = {}
        mCash.pos_id = iPos
        mCash.cash = iCash
        table.insert(mRet, mCash)
    end
    local mNet = {}
    mNet.cash_list = mRet
    self:Send("GS2CWithdrawAllCash", mNet)
end

function CStall:AddSellCash(iPos, iPrice)
    if not self.m_mCashInfo[iPos] then
        self.m_mCashInfo[iPos] = 0
    end
    
    self.m_mCashInfo[iPos] = self.m_mCashInfo[iPos] + iPrice
    self:Dirty()

    self:Send("GS2CStallRedPoint", {})

    self:RecordWarning(oPlayer, false, iPrice)    
end

function CStall:UnlockGrid()
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end
   
    if self.m_iSizeLimit >= defines.ITEM_SIZE_LIMIT then
        self:Notify(oPlayer:GetPid(), 1010, {num=defines.ITEM_SIZE_LIMIT})
        return
    end

    local iCost = defines.GetUnlockCost()
    if not oPlayer:ValidGoldCoin(iCost) then
        return
    end

    local mLogData = oPlayer:LogData()
    mLogData["size_old"] = self.m_iSizeLimit

    oPlayer:ResumeGoldCoin(iCost, "开摆摊格子")
    self:AddSizeLimit(1)
    local mNet = {size_limit = self.m_iSizeLimit}
    self:Send("GS2CSendSizeLimit", mNet)
    self:Notify(oPlayer:GetPid(), 1020)

    mLogData["size_now"] = self.m_iSizeLimit
    mLogData["goldcoin"] = iCost
    record.log_db("economic", "stall_upsize", mLogData)

    analylog.LogSystemInfo(oPlayer, "stall_upsize", nil, {[gamedefines.MONEY_TYPE.GOLD]=iCost})
end

function CStall:SendDefaultPrice(iSid)
    local oPlayer = self:GetPlayer()
    if oPlayer then
        local iPrice = self:GetDefaultPrice(iSid)
        local mNet = {}
        mNet.sid = iSid
        mNet.price = iPrice
        oPlayer:Send("GS2CDefaultPrice", mNet)
    end
end

function CStall:PackStallItem(oSell)
    local mUnit = {}
    mUnit.sid = oSell:SID()
    mUnit.amount = oSell:GetAmount()
    mUnit.price = oSell:GetPrice()
    mUnit.type = defines.ITEM_TYPE_STALL
    mUnit.pos_id = oSell:GetPos()
    mUnit.status = defines.ITEM_STATUS_NORMAL

    local mNet = {}
    mNet.cat_id = oSell:GetCatalogId()
    mNet.unit = mUnit
    return mNet
end

function CStall:ClearItemByPos(iPos)
    local oProxyItem = self.m_mItemInfo[iPos]
    self.m_mItemInfo[iPos] = nil
    if oProxyItem then
        self:Dirty()
        baseobj_delay_release(oProxyItem)
    end
end

function CStall:GetSellSize()
    return table_count(self.m_mItemInfo)
end

function CStall:GetSellObj(iPos)
    return self.m_mItemInfo[iPos]
end

function CStall:CreateItem(iSid, mData)
    local oItem = global.oItemLoader:Create(iSid)
    local id = self:DispatchProxyId()
    local oProxyItem = proxy.NewItemObj(id, oItem)
    mData.TraceNo = nil
    oProxyItem:Load(mData)
    oProxyItem.m_bNeedRelease = true
    oProxyItem.m_oDataCtrl:Setup()
    return oProxyItem
end

function CStall:BuildCatalogIndex(iPos, oSell)
    local oStallMgr = global.oStallMgr
    local oSysCatalog = oStallMgr.m_oSysCatalog
    oSysCatalog:AddProxyItem(oSell)
end

function CStall:RemoveCatalogIndex(oSell)
    local oStallMgr = global.oStallMgr
    local oSysCatalog = oStallMgr.m_oSysCatalog
    oSysCatalog:RemoveProxyItem(oSell)
end

function CStall:GetPlayer(iPid)
    iPid = iPid or self.m_iPid
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CStall:GetOwner()
    return self.m_iPid
end

function CStall:GetStallMgr()
    return global.oStallMgr
end

function CStall:GetPriceMgr()
    local oStallMgr = self:GetStallMgr()
    return oStallMgr.m_oPriceMgr
end

function CStall:GetDefaultPrice(iSid)
    local oPriceMgr = self:GetPriceMgr()
    return oPriceMgr:GetLastPrice(iSid)
end

function CStall:Notify(sMsg)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(self:GetOwner(), sMsg)
end

function CStall:PackGridInfo(iPos)
    local oSell = self.m_mItemInfo[iPos]
    if not oSell then return end
    
    local mNet = {}
    mNet.pos_id = iPos
    mNet.sid = oSell:SID()
    mNet.amount = oSell:GetAmount()
    mNet.price = oSell:GetPrice()
    mNet.sell_time = oSell:GetSellTime()
    mNet.cash = self.m_mCashInfo[iPos]
    mNet.quality = oSell:TrueQuality()
    mNet.query_id = oSell:QueryIdx()
    return mNet
end

function CStall:SendAllGridInfo()
    local mNet, mData = {}, {}
    for iPos, oSell in pairs(self.m_mItemInfo) do
        local mInfo = self:PackGridInfo(iPos)
        table.insert(mData, mInfo)
    end
    mNet.grid_all = mData
    mNet.size_limit = self.m_iSizeLimit
    self:Send("GS2CStallAllGrid", mNet)
end

function CStall:SendOneGridInfo(iPos)
    local mPack = self:PackGridInfo(iPos)
    self:Send("GS2CStallOneGrid", {grid_unit= mPack})
end

function CStall:Send(sProto, mNet)
    local oPlayer = self:GetPlayer()
    if oPlayer then
        oPlayer:Send(sProto, mNet)
    end
end

function CStall:OnLogin(oPlayer, bReEnter)
    for iPos, iCash in pairs(self.m_mCashInfo) do
        if iCash > 0 then
            self:Send("GS2CStallRedPoint", {})
            break
        end
    end
end

function CStall:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(iPid, sMsg)
end

function CStall:DebugMsg(iPid, sMsg)
    if not is_production_env() then
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CStall:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"stall"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function CStall:GetItemTable(iSid)
    local mData = res["daobiao"]["stall"]["iteminfo"]
    return mData[iSid]
end

function CStall:GetCatalog()
    local oCatalogMgr = global.oCatalogMgr
    local iPid = self.m_iPid
    return oCatalogMgr:GetCatalogByPid(iPid)
end

function CStall:ConfigSaveFunc()
    local iPid = self:GetOwner()
    self:ApplySave(function ()
        CheckSaveDb(iPid)
    end)
end

function CStall:_CheckSaveDb()
    assert(not is_release(self), "stall is releasing "..self:GetOwner())
    assert(self:IsLoaded(), "stall is loading "..self:GetOwner())
    self:SaveDb()
end

function CStall:SaveDb()
    if not self:IsLoaded() then return end
    if not self:IsDirty() then return end

    local mInfo = {
        module = "stalldb",
        cmd = "SaveInfoToStallByPid",
        cond = {pid = self:GetOwner()},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("stall", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CheckSaveDb(iPid)
    local oStall = global.oStallMgr:GetStallObj(iPid)
    if oStall then
        oStall:_CheckSaveDb()
    end
end
