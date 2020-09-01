--import module

local global = require "global"
local res = require "base.res"
local record = require "public.record"

local buildbase = import(service_path("org/build/buildbase"))

function NewBuild(...)
    return CBuildShop:New(...)
end

CBuildShop = {}
CBuildShop.__index = CBuildShop
inherit(CBuildShop, buildbase.CBuildBase)

function CBuildShop:New(iBid, iOrgId)
    local o = super(CBuildShop).New(self, iBid, iOrgId)
    return o
end

function CBuildShop:Init()
    super(CBuildShop).Init(self)
    self.m_iRefreshTime = get_time()
    self.m_mMemItem = {}
    self.m_mMemBuy = {}
    self.m_mMemRefTime = {}
    self.m_iBox = -1
end

function CBuildShop:Load(mData)
    super(CBuildShop).Load(self, mData)

    for iPid, iTime in pairs(mData.member_reftime or {}) do
        self.m_mMemRefTime[tonumber(iPid)] = iTime
    end

    self.m_iRefreshTime = mData.refreshtime or get_time()

    for sPid, lItem in pairs(mData.member_item) do
        self.m_mMemItem[tonumber(sPid)] = lItem
    end

    for sPid, mItem in pairs(mData.member_buy or {}) do
        self.m_mMemBuy[tonumber(sPid)] = {}
        for iItem, iCnt in pairs(mItem) do
            self.m_mMemBuy[tonumber(sPid)][tonumber(iItem)] = iCnt
        end
    end 

    self.m_iBox = mData.box or -1
end

function CBuildShop:Save()
    local mData = super(CBuildShop).Save(self)
    
    mData.refreshtime = self.m_iRefreshTime
    local member_reftime = {}
    for iPid, iTime in pairs(self.m_mMemRefTime) do
        member_reftime[db_key(iPid)] = iTime
    end
    mData.member_reftime = member_reftime

    local member_item = {}
    for iPid, lItem in pairs(self.m_mMemItem) do
        member_item[db_key(iPid)] = lItem
    end
    mData.member_item = member_item

    local mem_buy = {}
    for iPid, mItem in pairs(self.m_mMemBuy) do
        mem_buy[db_key(iPid)] = {}
        for iItem, iCnt in pairs(mItem) do
            mem_buy[db_key(iPid)][db_key(iItem)] = iCnt
        end
    end
    mData.member_buy = mem_buy

    mData.box = self.m_iBox
    return mData
end

function CBuildShop:GetItemData(iItem)
    return res["daobiao"]["org"]["shop"][iItem]
end

function CBuildShop:IsNeedRefresh(iPid)
    return (self.m_mMemRefTime[iPid] or 0) < self.m_iRefreshTime
end

function CBuildShop:RefreshShop(iPid)
    self.m_mMemBuy[iPid] = {}
    self.m_mMemItem[iPid] = self:RefreshItem()
    self.m_mMemRefTime[iPid] = get_time()
    self:Dirty()
end

function CBuildShop:GetRefreshItemNum()
    return self:GetBuildData()["effect1"]
end

function CBuildShop:RefreshItem()
    local iRefreshNum = self:GetRefreshItemNum()
    local mData = res["daobiao"]["org"]["orgshop"][self:Level()]
    if not mData then return {} end
    
    local iTotal, lData = mData["total"], mData["data"]

    local lItem = {}
    if table_count(lData) <= iRefreshNum then
        for _,v in ipairs(lData) do
            table.insert(lItem, v.ibuy)
        end
        return lItem
    end

    for i = 1, iRefreshNum do
        local iRan, iTemp = math.random(iTotal), 0
        for _, m in pairs(lData) do
            if table_in_list(lItem, m.ibuy) then
                iTemp = iTemp + m.max - m.min
            else
                if m.min < iRan + iTemp and iRan + iTemp <= m.max then
                    table.insert(lItem, m.ibuy)
                    iTotal = iTotal - m.max + m.min
                    break
                end
            end
        end
    end
    return lItem
end

function CBuildShop:GetItemsByPid(iPid)
    return self.m_mMemItem[iPid] or {}
end

function CBuildShop:GetBuyCnt(iPid, iBuy)
    local mData = self.m_mMemBuy[iPid] or {}
    return mData[iBuy] or 0
end

function CBuildShop:AddBuyCnt(iPid, iBuy, iVal)
    local mData = self.m_mMemBuy[iPid] or {}
    local iCnt = mData[iBuy] or 0
    mData[iBuy] = iCnt + iVal
    self.m_mMemBuy[iPid] = mData
    self:Dirty()
end

function CBuildShop:Buy(oPlayer, iBuy, iVal) 
    if iVal <= 0 then return end

    local mBoxConfig = self:GetBoxConfig()
    local lItem = self:GetItemsByPid(oPlayer:GetPid())
    if iBuy ~= mBoxConfig.box_id and not table_in_list(lItem, iBuy) then return end

    local mItem = self:GetItemData(iBuy)
    if not mItem then return end

    local iCnt = self:GetBuyCnt(oPlayer:GetPid(), iBuy)
    if mItem.sell_num > 0 and iCnt + iVal > mItem.sell_num then return end

    if iBuy == mBoxConfig.box_id then
        if iVal > self.m_iBox then
            self:GS2COrgRefreshShopUnit(oPlayer, iBuy, self.m_iBox)
            oPlayer:NotifyMessage(global.oOrgMgr:GetOrgText(4002))
            return
        end

        local iTodayCnt = oPlayer.m_oTodayMorning:Query("org_build_shop_box", 0)
        if iTodayCnt >= mBoxConfig.limit_cnt then
            oPlayer:NotifyMessage(global.oOrgMgr:GetOrgText(4003))
            return
        end

        local iRamain = mBoxConfig.limit_cnt - iTodayCnt
        if iVal > iRamain then
            oPlayer:NotifyMessage(global.oOrgMgr:GetOrgText(4004))
            return
        end
    end

    local lGive = {}
    lGive[mItem.item] = mItem.cnt * iVal
    if not oPlayer:ValidGive(lGive) then
        oPlayer:NotifyMessage("背包空间不足，请先整理背包")
        return 
    end

    local mCost = mItem["cost"]
    local mLog = oPlayer:LogData()
    mLog["buy_id"] = iBuy
    mLog["buy_cnt"] = iVal
    mLog["org_id"] = self:OrgID()
    mLog["cost_type"] = mCost["name"]
    mLog["cost_val"] = mCost["val"]  * iVal
    mLog["item_id"] = mItem["item"]
    mLog["item_cnt"] = mItem["cnt"] * iVal
    record.log_db("org", "shop_buy", mLog)

    -- TODO 需要调整
    if mCost["name"] == "帮贡" then
        if oPlayer:GetOffer() < mCost["val"] * iVal then return end

        oPlayer:AddOrgOffer(-mCost["val"] * iVal, "buildshop buy")
        if iBuy == mBoxConfig.box_id then
            self.m_iBox = self.m_iBox - iVal
            oPlayer.m_oTodayMorning:Add("org_build_shop_box", iVal)
            self:GS2COrgRefreshShopUnit(oPlayer, iBuy, self.m_iBox)
        else
            self:AddBuyCnt(oPlayer:GetPid(), iBuy, iVal)
        end
    else
        return
    end

    local iSid = mItem["item"]
    local iAmount = mItem["cnt"] * iVal
    oPlayer:RewardItems(iSid, iAmount, "帮派商店", {cancel_tip=true, cancel_chat=true})

    local oNewItem = global.oItemLoader:GetItem(iSid)
    global.oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=iSid, amount=iAmount})
    local sMsg = global.oToolMgr:FormatString("获得#item×#G#amount#n", {amount = iAmount, item = oNewItem:TipsName()})
    global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    if oNewItem:Quality() >= 3 then
        local oOrgMgr = global.oOrgMgr
        local oOrg = self:GetOrg()
        local sMsg = oOrgMgr:GetOrgText(2002, {role=oPlayer:GetName(), item=oNewItem:TipsName()})
        oOrg:AddLog(oPlayer:GetPid(), sMsg)
    end

    return true
end

function CBuildShop:PackShopInfo(iPid)
    local mNet = {}
    for _, iItem in pairs(self:GetItemsByPid(iPid)) do
        table.insert(mNet, {item_id=iItem, buy_cnt=self:GetBuyCnt(iPid, iItem)})
    end

    --宝箱特殊处理，buy_cnt为剩余数量
    if self.m_iBox >= 0 then
        local mConfig = self:GetBoxConfig()
        table.insert(mNet, {item_id=mConfig.box_id, buy_cnt=self.m_iBox})
    end
    return mNet
end

function CBuildShop:SetRefreshTime()
    self:Dirty()
    self.m_iRefreshTime = get_time()
end

function CBuildShop:GetRefreshBoxNum()
    local mData = res["daobiao"]["org"]["shopboxnum"]
    assert(mData, "CBuildShop: shop box num config error")
    local iLevel = self:Level()
    if not mData[iLevel] then
        -- record.warning(string.format("CBuildShop:GetRefreshBoxNum-error--%s", iLevel))
        return 0
    end
    return mData[iLevel].cnt
end

function CBuildShop:RefreshBox()
    local iRefreshNum = self:GetRefreshBoxNum()
    if not iRefreshNum or iRefreshNum <= 0 then
        return
    end
    if self.m_iBox < 0 then self.m_iBox = 0 end
    local iLimitNum = iRefreshNum * 3
    local iRealNum = 0
    if self.m_iBox + iRefreshNum > iLimitNum then
        iRealNum = iLimitNum - self.m_iBox
        self.m_iBox = iLimitNum
    else
        iRealNum = iRefreshNum
        self.m_iBox = self.m_iBox + iRefreshNum
    end
    self:Dirty()

    if iRealNum > 0 then
        local mData = self:GetBuildData()
        local oOrgMgr = global.oOrgMgr
        local sMsg = oOrgMgr:GetOrgText(4001, {build=mData.name, amount=iRealNum})
        local oOrg = self:GetOrg()
        if oOrg then
            oOrg:AddLog(iPid, sMsg)
        end
    end
end

function CBuildShop:GS2COrgRefreshShopUnit(oPlayer, iItem, iNum)
    if not oPlayer then return end
    local mData = {
        item_id = iItem,
        buy_cnt = iNum
    }
    oPlayer:Send("GS2COrgRefreshShopUnit", mData)
end

function CBuildShop:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 5 then
        self.m_iBox = 0
        self:SetRefreshTime()
    end

    --经验宝箱
    local iWeekDay = mNow.date.wday
    if iWeekDay == 6 or iWeekDay == 7 then
        if iHour >= 8 then
            self:RefreshBox()
        end
    else
        self.m_iBox = -1
        self:Dirty()
    end
end

function CBuildShop:GetBoxConfig()
    local mData = res["daobiao"]["org"]["shopbox"][1]
    assert(mData, "CBuildShop: shop box config error")
    return mData
end