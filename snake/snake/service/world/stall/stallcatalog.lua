local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local defines = import(service_path("stall.defines"))
local proxy = import(service_path("stall.itemobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))
local analylog = import(lualib_path("public.analylog"))

function NewCatalogMgr()
    local o = CCatalogMgr:New()
    return o
end


CCatalogMgr = {}
CCatalogMgr.__index = CCatalogMgr
inherit(CCatalogMgr, logic_base_cls())

function CCatalogMgr:New(...)
    local o = super(CCatalogMgr).New(self)
    o:Init()
    return o
end

function CCatalogMgr:Init()
    self.m_iProxyId = 0
    self.m_mCatalogObj = {}
end

function CCatalogMgr:DispatchProxyId()
    self.m_iProxyId = self.m_iProxyId + 1
    return self.m_iProxyId
end

function CCatalogMgr:GetCatalogByPid(iPid)
    if self.m_mCatalogObj[iPid] then
        return self.m_mCatalogObj[iPid]
    end
    local obj = NewCatalog(iPid)
    self.m_mCatalogObj[iPid] = obj
    obj:RefreshCatalog()
    return obj
end

function CCatalogMgr:OnLogin(oPlayer, bReEnter)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer, true) then
        return
    end

    local iPid = oPlayer:GetPid()
    local obj = self:GetCatalogByPid(iPid)
    obj:OnLogin(oPlayer, bReEnter)
end

function CCatalogMgr:OnLogout(oPlayer)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer, true) then
        return
    end

    local iPid = oPlayer:GetPid()
    local obj = self.m_mCatalogObj[iPid]
    if obj then
        obj:OnLogout(oPlayer)
        self.m_mCatalogObj[iPid] = nil
    end
end

---------------目录管理------------
function NewCatalog(iPid, ...)
    local o = CCatalog:New(iPid, ...)
    return o
end

CCatalog = {}
CCatalog.__index = CCatalog
inherit(CCatalog, logic_base_cls())

function CCatalog:New(iPid, ...)
    local o = super(CCatalog).New(self)
    o:Init(iPid)
    return o
end

function CCatalog:Init(iPid)
    self.m_iPid = iPid
    self.m_mCatalog = {}
    self.m_iRefresh = 0
    self.m_mTmpItemObj = {}
end

function CCatalog:GetPid()
    return self.m_iPid
end

function CCatalog:GetItem(iSid)
    local iTrueSid, iMinQ, iMaxQ = defines.DecodeSid(iSid)
    if not self.m_mTmpItemObj[iSid] then
        local oItem = global.oItemLoader:Create(iTrueSid)
        self.m_mTmpItemObj[iSid] = oItem
    end
    return self.m_mTmpItemObj[iSid]
end

function CCatalog:Release()
    self:ReleaseItem()
    self:ReleaseTmpItem()
    super(CCatalog).Release(self)
end

function CCatalog:ReleaseItem()
    if self.m_mCatalog then
        for iCat, lItemList in pairs(self.m_mCatalog) do
            for idx, oItem in pairs(lItemList) do
                baseobj_delay_release(oItem)
            end
            self.m_mCatalog[iCat] = {}
        end
    end
    self.m_mCatalog = {}
end

function CCatalog:ReleaseTmpItem()
    for iSid, oItem in pairs(self.m_mTmpItemObj) do
        baseobj_delay_release(oItem)
    end
    self.m_mTmpItemObj = {}
end

function CCatalog:InitAllCatalog()
    local mData = res["daobiao"]["stall"]["catalog"]
    for iCat, lSidList in pairs(mData) do
        self:InitSubCatalog(iCat, lSidList)
    end
end

function CCatalog:InitSubCatalog(iCat, lSidList)
    lSidList = lSidList or self:GetAllSubCatalog(iCat)
    for idx, oItem in pairs(self.m_mCatalog[iCat] or {}) do
        baseobj_delay_release(oItem)
    end
    local lResult = {}
    self.m_mCatalog[iCat] = {}
    if iCat == 4 then
        lResult = self:InitCookCatalog(iCat, lSidList)
    elseif iCat == 5 then
        lResult = self:InitCatalogWithQuality(iCat, lSidList)
    else
        lResult = self:InitCatalog(iCat, lSidList)
    end
    lResult = extend.Random.random_size(lResult, #lResult)
    self.m_mCatalog[iCat] = lResult
    for idx, oProxyItem in ipairs(self.m_mCatalog[iCat]) do
        oProxyItem:SetPos(idx)
    end
end

function CCatalog:InitCatalog(iCat, lSidList)
    local iRet = 3 * #lSidList
    local lResult, lFilter = {}, {}

    for _, iSid in ipairs(lSidList) do
        local lItem = self:ChooseItem(iCat, iSid, 2)
        list_combine(lResult, lItem)
        lFilter[iSid] = list_generate(lItem, function(oItem)
        if oItem then
            return oItem:GetIdentify() end
        end)

        if iRet > 0 then
            local lItem = self:ChooseStallItem(lFilter[iSid], iCat, iSid, 4)
            list_combine(lResult, lItem)
            iRet = iRet - #lItem
        end
    end
    return lResult
end

function CCatalog:InitCatalogWithQuality(iCat, lSidList)
    local mTrueSid, lResult = {}, {}
    for _, iSid in ipairs(lSidList) do
        local iTrueSid, _, _ = defines.DecodeSid(iSid)
        if not mTrueSid[iTrueSid] then
            mTrueSid[iTrueSid] = 0
        end
        local lItem = self:ChooseStallItem({}, iCat, iSid, 2)
        mTrueSid[iTrueSid] = mTrueSid[iTrueSid] + #lItem
        list_combine(lResult, lItem)
    end
    for _, iSid in ipairs(lSidList) do
        local iTrueSid, _, _ = defines.DecodeSid(iSid)
        if mTrueSid[iTrueSid] <= 0 then
            local lItem = self:ChooseSysItem(iCat, iSid, 2)
            list_combine(lResult, lItem)
        end
    end
    return lResult
end

function CCatalog:InitCookCatalog(iCat, lSidList)
    local lLowSid, lHighSid = {}, {}
    for _, iSid in ipairs(lSidList) do
        local iTrueSid, _, iMax = defines.DecodeSid(iSid)
        if iMax <= 70 then
            table.insert(lLowSid, iSid)
        else
            table.insert(lHighSid, iSid)
        end
    end
    local lResult = self:InitCatalog(iCat, lHighSid)
    local lTmp = self:InitCatalogWithQuality(iCat, lLowSid)
    list_combine(lResult, lTmp)
    return lResult
end

function CCatalog:ChooseItem(iCat, iSub, iAmount)
    local oSysCatalog = self:GetSysCatalog()
    local lItem = self:ChooseStallItem({}, iCat, iSub, iAmount)
    local iRet = iAmount - #lItem
    if iRet > 0 then
        local lTmp = self:ChooseSysItem(iCat, iSub, iRet)
        lItem = list_combine(lItem, lTmp)
    end
    return lItem
end

function CCatalog:ChooseSysItem(iCat, iSid, iAmount)
    local oWorldMgr = global.oWorldMgr
    local iSlv = oWorldMgr:GetServerGrade()
    local lResult = {}
    local mItem = res["daobiao"]["stall"]["iteminfo"][iSid]

    if mItem and mItem.is_supply == 1 and mItem.slv <= iSlv then
        local iType = defines.ITEM_TYPE_SYS
        local iTrueSid, iMinQ, iMaxQ = defines.DecodeSid(iSid)

        for i = 1, iAmount do
            local oProxyItem = self:CreateProxyItem(iTrueSid, nil, iType, iSid)

            --local sType = oProxyItem:ItemType()
            --if sType == "cook" or sType == "medicine" then
            if (10046<=iTrueSid and iTrueSid<=10050) or (10058<=iTrueSid and iTrueSid<=10064) then
                local iQuality = math.random(iMinQ, iMaxQ)
                oProxyItem.m_oDataCtrl:SetData("quality", iQuality)
            end
            if defines.FUZHUAN[iTrueSid] then
                local iSkillLevel = iMaxQ//10
                oProxyItem.m_oDataCtrl:SetData("skill_level", iSkillLevel)
            end

            local iQuery = oProxyItem:QueryIdx()
            local iPrice = math.floor(self:GetDefaultPrice(iQuery) * 1.45)
            iPrice = math.min(math.max(iPrice, mItem.min_price), mItem.max_price)
            oProxyItem:SetPrice(iPrice)

            table.insert(lResult, oProxyItem)
        end
    end
    return lResult
end

function CCatalog:ChooseStallItem(lFilter, iCat, iSub, iAmount)
    local oSysCatalog = self:GetSysCatalog()
    local lItem = oSysCatalog:ChooseStallItem(lFilter, iCat, iSub, iAmount)
    local iType = defines.ITEM_TYPE_STALL
    local lResult = {}
    for _, oItem in pairs(lItem) do
        local iIdentify = defines.EncodeKey(oItem:GetOwner(), oItem:GetPos())
        local oProxy = self:CreateProxyItem(oItem:SID(), oItem:Save(), iType, iSub)
        oProxy:SetIdentify(iIdentify)
        table.insert(lResult, oProxy)
    end
    return lResult
end

function CCatalog:CreateProxyItem(iSid, mItem, iType, iEncodeSid)
    local oStall = self:GetStallByPid(self:GetPid())
    local id = oStall:DispatchProxyId()
    if iType == defines.ITEM_TYPE_STALL then
        local oItem = global.oItemLoader:Create(iSid)
        local oProxyItem = proxy.NewCatalogItem(id, oItem)
        oProxyItem:Load(mItem)
        oProxyItem:SetOwner(self.m_iPid)
        oProxyItem.m_bNeedRelease = true
        return oProxyItem
    else
        local oItem = global.oItemLoader:GetItem(iSid)
        local oStallItem = nil
        local oProxyItem = nil
        if oItem:ItemType() == "equip" then
            oStallItem = self:GetItem(iEncodeSid)
            oProxyItem = proxy.NewCatalogItem(id, oStallItem)
        elseif (10046<=iSid and iSid<=10050) or (10058<=iSid and iSid<=10064) then
            oStallItem = self:GetItem(iEncodeSid)
            oProxyItem = proxy.NewCatalogItem(id, oStallItem)
        elseif defines.FUZHUAN[iSid] then
            oStallItem = self:GetItem(iEncodeSid)
            oProxyItem = proxy.NewCatalogItem(id, oStallItem)
        else
            oStallItem = global.oItemLoader:GetItem(iSid)
            oProxyItem = proxy.NewCatalogItem(id, oStallItem)
        end

        oProxyItem:SetAmount(1)
        oProxyItem:SetOwner(self.m_iPid)
        return oProxyItem
    end
end

function CCatalog:GetSysCatalog()
    local oStallMgr = global.oStallMgr
    if oStallMgr then
        return oStallMgr.m_oSysCatalog
    end
end

function CCatalog:GetAllSubCatalog(iCat)
    local mData = res["daobiao"]["stall"]["catalog"]
    return mData[iCat] or {}
end

function CCatalog:GetPlayer()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
end

function CCatalog:GetBuyItem(iCat, iPos)
    return table_get_depth(self.m_mCatalog, {iCat, iPos})
end

function CCatalog:SendCatalog(iCat, iPage, iFirst, iItemSid)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    if iFirst == 1 then
        if self.m_iRefresh + defines.REFRESH_TIME <= get_time() then
            self:RefreshCatalog()
        end
    end

    local mCatalog = self.m_mCatalog[iCat] or {}
    local iStart = defines.PAGE_AMOUNT * (iPage - 1) + 1
    if #mCatalog < iStart then
        oPlayer:Send("GS2CSendCatalog", {cat_id=iCat, page=iPage, refresh=self.m_iRefresh})
        return
    end

    if iItemSid and iItemSid > 0 then
        local iItemPos = self:FindItemPosBySid(oPlayer, iCat, iItemSid)
        if iItemPos then
            iPage = math.ceil(iItemPos / defines.PAGE_AMOUNT)
        end
    end

    local iStart = defines.PAGE_AMOUNT * (iPage - 1) + 1
    local iEnd = defines.PAGE_AMOUNT * iPage

    local mCatalog = self.m_mCatalog[iCat] or {}
    local lCatalog = {}
    for i = iStart, iEnd do
        local oItem = mCatalog[i]
        if not oItem then
            break
        end
        local mUnit = self:PackItemUnit(oItem)
        table.insert(lCatalog, mUnit)
    end

    local mNet = {
        cat_id = iCat,
        page = iPage,
        refresh = self.m_iRefresh,
        catalog = lCatalog,
        total = #mCatalog,
    }
    oPlayer:Send("GS2CSendCatalog", mNet)
end

-- 查找sid对应的位置
function CCatalog:FindItemPosBySid(oPlayer, iCat, iItemSid)
    local mCatalog = self.m_mCatalog[iCat]
    if not mCatalog or not next(mCatalog) then
        return
    end
    for idx, oProxyItem in ipairs(mCatalog) do
        if oProxyItem:SID() == iItemSid then
            return idx
        end
    end
end

function CCatalog:SendCatalogUnit(iCat, iPos)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local oItem = self:GetBuyItem(iCat, iPos)
    local mUnit = self:PackItemUnit(oItem)
    mUnit.pos_id = iPos
    local mNet = {}
    mNet.cat_id = iCat
    mNet.unit = mUnit
    oPlayer:Send("GS2CSendCatalogUnit", mNet)
end

function CCatalog:SendSellItemDetail(iCatalog, iPos)
    local oItem = self:GetBuyItem(iCatalog, iPos)
    local oPlayer = self:GetPlayer()
    if oItem and oPlayer then
        local mNet = {}
        mNet.itemdata = oItem.m_oDataCtrl:PackItemInfo()
        oPlayer:Send("GS2CSendItemDetail", mNet)
    end
end

function CCatalog:TryRefreshCatalog(iCat, iGold)
    if not self:ValidRefreshCatalog(iGold==1) then
        return
    end
    self:RefreshCatalog()
    --self:RefreshSubCatalog(iCat)
    self:SendCatalog(iCat, 1)

    local iCost = 0
    if iGold == 1 then
        iCost = defines.REFRESH_GOLD
    end

    local oPlayer = self:GetPlayer()
    if oPlayer then
        analylog.LogSystemInfo(oPlayer, "stall_refresh", nil, {[gamedefines.MONEY_TYPE.GOLD]=iCost})
    end
end

function CCatalog:ValidRefreshCatalog(bGold)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return false end

    if bGold then
        local iCost = defines.REFRESH_GOLD
        if not oPlayer:ValidGold(iCost) then
            return false
        end
        oPlayer:ResumeGold(iCost, "摆摊刷新购买")
        return true
    end

    local iRet = self.m_iRefresh + defines.REFRESH_TIME - get_time()
    if iRet > 0 then
        self:Notify(oPlayer:GetPid(), 1017, {second = iRet})
        return false
    end

    return true
end

function CCatalog:RefreshCatalog()
    self.m_iRefresh = get_time()
    self:InitAllCatalog()
end

function CCatalog:RefreshSubCatalog(iCat)
    self.m_iRefresh = get_time()
    self:InitSubCatalog(iCat)
end

function CCatalog:BuySellItem(iCatalog, iPos, iAmount)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    if iAmount <= 0 then
        record.info("buy sellitem amount error " .. iAmount)
        return
    end

    local oItem = self:GetBuyItem(iCatalog, iPos)
    if not oItem then
        self:Notify(oPlayer:GetPid(), 1012)
        self:SendCatalogUnit(iCatalog, iPos)
        return
    end

    if oItem:GetIdentify() then
        self:BuyStallItem(oItem, iAmount)
    else
        self:BuySysItem(oItem, iAmount)
    end
end

function CCatalog:ValidBuyStallItem(oPlayer, oItem, oSell, iAmount)
    if not oSell or oSell:GetSellTime() ~= oItem:GetSellTime() then
        oItem:SetAmount(0)
        return 1012, 1
    end
    if oItem:GetSellTime() + defines.GetKeepTime() < get_time() then
        return 1013, 1
    end
    if iAmount > oItem:GetAmount() then
        return 1019, 1
    end
    if iAmount > oSell:GetAmount() then
        oItem:SetAmount(oSell:GetAmount())
        return 1019, 1
    end
    local iTotal = iAmount * oSell:GetPrice()
    if not oPlayer:ValidSilver(iTotal, {cancel_tip=1}) then
        return 1014, 0
    end
    if not oPlayer:ValidGive({[oSell:SID()] = iAmount}) then
        return 1015, 0
    end
    return 1, 0
end

function CCatalog:BuyStallItem(oItem, iAmount)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local iIdentify = oItem:GetIdentify()
    local iSeller, iSellPos = defines.DecodeKey(iIdentify)
    local oStall = self:GetStallByPid(iSeller)
    local oSell = oStall:GetSellItem(iSellPos)
    local iCat = oItem:GetCatalogId()
    local iPos = oItem:GetPos()

    local iRet, iRefresh = self:ValidBuyStallItem(oPlayer, oItem, oSell, iAmount)
    if iRefresh == 1 then
        self:SendCatalogUnit(iCat, iPos)
    end
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet)
        return
    end

    iAmount = math.min(iAmount, oSell:GetAmount())
    local iTotal = iAmount * oSell:GetPrice()
    -- local sReason = string.format("buy_stall_item_%d", oSell:SID())
    local sReason = "摆摊购买"
    oPlayer:ResumeSilver(iTotal, sReason)
    oSell:AddAmount(-iAmount)
    oItem:SetAmount(oSell:GetAmount())
    oStall:AddSellCash(oSell:GetPos(), iTotal)
    self:SendCatalogUnit(iCat, iPos)

    local oNewItem = global.oItemLoader:LoadItem(oSell:SID(), oSell:ItemBaseData())
    oNewItem:SetAmount(iAmount)
    oNewItem:Setup()
    oNewItem:SetData("stall_buy_price", oSell:GetPrice())
    oPlayer:RewardItem(oNewItem, sReason, {cancel_tip=true})
    oStall:Dirty(oPlayer:GetPid())
    global.oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=oNewItem:SID(), amount=iAmount, type=1})

    local iQuery = oSell:QueryIdx()
    self:RecordPrice(iQuery, oSell:GetPrice(), iAmount)

    local mLogData = oPlayer:LogData()
    mLogData["sell_owner"] = iSeller
    mLogData["sell_pos"] = iSellPos
    mLogData["buy_amount"] = iAmount
    mLogData["buy_cost"] = iTotal
    mLogData["query_id"] = iQuery
    record.log_db("economic", "stall_buy", mLogData)

    -- 数据中心log
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["operation"] = 1
    mAnalyLog["shop_id"] = 1
    mAnalyLog["currency_type"] = gamedefines.MONEY_TYPE.SILVER
    mAnalyLog["item_id"] = oSell:SID()
    mAnalyLog["num"] = iAmount
    mAnalyLog["consume_count"] = iTotal
    mAnalyLog["remain_currency"] = oPlayer:GetSilver()
    analy.log_data("ItemBuy", mAnalyLog)
end

function CCatalog:BuySysItem(oItem, iAmount)
    assert(iAmount>0, "stall buy amount less then 0")

    local oPlayer = self:GetPlayer()
    if iAmount > oItem:GetAmount() then
        self:Notify(oPlayer:GetPid(), 1019)
        return
    end

    local iSid = oItem:SID()
    local iQuery = oItem:QueryIdx()
    local iPrice = oItem:GetPrice() or math.floor(self:GetDefaultPrice(iQuery) * 1.45)
    local iTotal = iPrice * iAmount

    if not oPlayer:ValidSilver(iTotal, {cancel_tip=1}) then
        self:Notify(oPlayer:GetPid(), 1014)
        return
    end
    if not oPlayer:ValidGive({[iSid] = iAmount}) then
        self:Notify(oPlayer:GetPid(), 1015)
        return
    end

    -- local sReason = string.format("stall_buy_%d", iSid)
    local sReason = "摆摊购买"
    oPlayer:ResumeSilver(iTotal, sReason)

    local oNewItem = global.oItemLoader:LoadItem(iSid, oItem:ItemBaseData())
    oNewItem:Setup()
    oNewItem:SetAmount(iAmount)
    oNewItem:SetData("stall_buy_price", iPrice)
    oPlayer:RewardItem(oNewItem, sReason, {cancel_tip=true})
    global.oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=oNewItem:SID(), amount=iAmount, type=1})

    oItem:AddAmount(-iAmount)
    local iCat = oItem:GetCatalogId()
    self:SendCatalogUnit(iCat, oItem:GetPos())

    self:RecordPrice(iQuery, iPrice, iAmount)

    local mLogData = oPlayer:LogData()
    mLogData["sell_owner"] = 0
    mLogData["sell_pos"] = 0
    mLogData["buy_amount"] = iAmount
    mLogData["buy_cost"] = iTotal
    mLogData["query_id"] = iQuery
    record.log_db("economic", "stall_buy", mLogData)

    -- 数据中心log
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["operation"] = 1
    mAnalyLog["shop_id"] = 0
    mAnalyLog["currency_type"] = gamedefines.MONEY_TYPE.SILVER
    mAnalyLog["item_id"] = iSid
    mAnalyLog["num"] = iAmount
    mAnalyLog["consume_count"] = iTotal
    mAnalyLog["remain_currency"] = oPlayer:GetSilver()
    analy.log_data("ItemBuy", mAnalyLog)
end

function CCatalog:OnLogin(oPlayer, bReEnter)
    if not bReEnter and self.m_iRefresh + defines.REFRESH_TIME <= get_time() then
        self:RefreshCatalog()
    end
end

function CCatalog:OnLogout(oPlayer)
    self:Release()
end

function CCatalog:PackItemUnit(oProxyItem)
    if not oProxyItem then return {} end

    local mNet = {}
    mNet.sid = oProxyItem:SID()
    mNet.amount = oProxyItem:GetAmount()
    mNet.price = oProxyItem:GetPrice()
    mNet.pos_id = oProxyItem:GetPos()
    mNet.status = oProxyItem:Status()
    mNet.quality = oProxyItem.m_oDataCtrl:Quality()
    return mNet
end

function CCatalog:GetStallByPid(iPid)
    local oStallMgr = global.oStallMgr
    local oStall = oStallMgr:GetStallObj(iPid)
    return oStall
end

function CCatalog:GetDefaultPrice(iQuery)
    local oStallMgr = global.oStallMgr
    local oPriceMgr = oStallMgr.m_oPriceMgr
    return oPriceMgr:GetLastPrice(iQuery)
end

function CCatalog:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(iPid, sMsg)
end

function CCatalog:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"stall"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function CCatalog:RecordPrice(iQuery, iPrice, iAmount)
    local oStallMgr = global.oStallMgr
    local oPriceMgr = oStallMgr.m_oPriceMgr
    oPriceMgr:AddPrice(iQuery, iPrice, iAmount)
end

