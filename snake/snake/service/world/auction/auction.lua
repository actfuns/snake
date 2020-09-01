local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local loadsumm = import(service_path("summon.loadsummon"))
local proxy = import(service_path("auction.proxybase"))
local defines = import(service_path("auction.defines"))
local player = import(service_path("auction.player"))
local operator = import(service_path("auction.operator"))
local gamedb = import(lualib_path("public.gamedb"))


function NewAuction(...)
    local o = CAuction:New(...)
    return o
end


CAuction = {}
CAuction.__index = CAuction
inherit(CAuction, datactrl.CDataCtrl)

function CAuction:New()
    local o = super(CAuction).New(self)
    o.m_iDispatchId = 0
    o:Init()
    return o
end

function CAuction:Init()
    --存储所有拍卖品
    self.m_mItemTable = {}

    --用于索引拍卖品
    self.m_mItemCatalog = {}

    --存储玩家相关信息
    self.m_mPlayerInfo = {}

    --操作行为
    self.m_oOperator = operator.NewOperator(self)
end

function CAuction:Save()
    for iPid, oUnit in pairs(self.m_mPlayerInfo) do
        oUnit:SaveDb()
    end
end

function CAuction:Load(m)
    if not m then return end
    for _, mInfo in ipairs(m) do
        local oUnit = self:GetPlayerUnit(mInfo.pid)
        oUnit:Load(mInfo.data)
        oUnit:OnLoaded()
    end
end

function CAuction:MergeFrom(mData)
    local iPid = mData.pid
    if not self.m_mPlayerInfo[iPid] then
        self:GetPlayerUnit(iPid)
    end
    return self.m_mPlayerInfo[iPid]:MergeFrom(mData.data)
end

function CAuction:AfterLoad()
    self:Schedule()
end

function CAuction:OnLoadProxy(oProxy)
    local id = oProxy:GetID()
    self.m_mItemTable[id] = oProxy

    if oProxy:GetPriceTime() > get_time() then
        local iCat, iSub = oProxy:GetCatalog()
        self:Insert2Catalog(iCat, iSub, id)
    end
end

function CAuction:Insert2Catalog(iCat, iSub, id)
    local mData = table_get_set_depth(self.m_mItemCatalog, {iCat, iSub})
    mData[id] = 1
end

function CAuction:RemoveCatalog(iCat, iSub, id)
    local mData = table_get_set_depth(self.m_mItemCatalog, {iCat, iSub})
    mData[id] = nil
end

function CAuction:GetCatalogInfo(iCat, iSub)
    return table_get_depth(self.m_mItemCatalog, {iCat, iSub})
end

function CAuction:GetPlayerUnit(iPid)
    if not self.m_mPlayerInfo[iPid] then
        local oPlayerUnit = player.NewPlayerUnit(iPid)
        self.m_mPlayerInfo[iPid] = oPlayerUnit
        oPlayerUnit:OnLoaded()
    end
    return self.m_mPlayerInfo[iPid]
end

function CAuction:AddAuctionItem(iPid, oProxy)
    local oUnit = self:GetPlayerUnit(iPid)
    oUnit:AddAuction(oProxy:GetID(), oProxy)
    self:OnLoadProxy(oProxy)

    record.log_db("huodong", "auction", {info = {
        action = "上架拍品",
        item = oProxy:LogName(),
    }})
end

function CAuction:DispatchProxyId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CAuction:GetProxyById(id)
    return self.m_mItemTable[id]
end

function CAuction:RemoveProxy(id)
    local oProxy = self.m_mItemTable[id]
    if not oProxy then return end

    local iCat, iSub = oProxy:GetCatalog()
    self:RemoveCatalog(iCat, iSub, id)

    local iOwner = oProxy:GetOwner()
    if iOwner then
        local oUnit = self:GetPlayerUnit(iOwner)
        oUnit:RemoveAuction(id)
    end

    self.m_mItemTable[id] = nil
    oProxy:RemoveFollows()
    baseobj_delay_release(oProxy)
end

function CAuction:CreateProxyItem(iSid, mItem)
    local oItem = nil
    if not mItem or table_count(mItem) <= 0 then
        oItem = global.oItemLoader:Create(iSid)
    else
        oItem = global.oItemLoader:LoadItem(iSid, mItem)
    end
    local oProxy = proxy.NewProxyItem(oItem)
    return oProxy
end

function CAuction:CreateProxySummon(iSid, mSummon)
    mSummon.traceno = nil
    local oSummon = nil
    if not mSummon or table_count(mSummon) <= 0 then
        oSummon = loadsumm.CreateSummon(iSid)
    else
        oSummon = loadsumm.LoadSummon(iSid, mSummon)
    end
    local oProxy = proxy.NewProxySummon(oSummon)
    return oProxy
end

function CAuction:CheckAuction()
    if not global.oToolMgr:IsSysOpen("AUCTION") then
        return
    end
    
    local iCurr = get_time()
    local iMaxShift = 24*60*60
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local mGroup = res["daobiao"]["auction"]["group"]
    local mAllItem = res["daobiao"]["auction"]["sys_auction"]
    for idx, mItem in pairs(mAllItem) do
        if mItem.is_open == 0 then
            goto continue
        end
        if mItem.slv > iServerGrade then
            goto continue
        end
        if self:IsSysUp(idx) then
            goto continue
        end
        local iTime = 0
        iTime = self:AnalyseUpTime(mItem)
        if iCurr > iTime or iTime-iCurr > iMaxShift then
            goto continue
        end

        local iType = mItem.auction_type
        local iSid = mItem.sid
        local mAttr = formula_string(mItem.attr, {})
        local iPrice = mItem.price
        local iMoneyType = mItem.money_type

        if mGroup[iSid] then
            iType, iSid, mAttr, iPrice, iMoneyType = self:ChooseGroupAuction(iSid)
        end

        if not iType then goto continue end

        local oProxy = nil
        if iType == defines.PROXY_TYPE_ITEM then
            oProxy = self:CreateProxyItem(iSid, mAttr)
        else
            oProxy = self:CreateProxySummon(iSid, mAttr)
        end
        oProxy:SetAmount(1)
        oProxy:SetOwner(0)
        oProxy:SetSys(idx)
        oProxy:SetPrice(iPrice)
        oProxy:SetMoneyType(iMoneyType)
        oProxy:InitTime(iTime)
        self:AddAuctionItem(0, oProxy)
        ::continue::
    end
end

function CAuction:IsSysUp(iSys)
    local oUnit = self:GetPlayerUnit(0)
    for _, oProxy in pairs(oUnit:GetAuctions()) do
        if oProxy:GetSys() == iSys and get_time() < oProxy:GetPriceTime() then
            return true
        end
    end
    return false
end

function CAuction:ChooseGroupAuction(iGroup)
    local iRandom = math.random(10000)
    local mGroup = res["daobiao"]["auction"]["group"][iGroup]
    local iTotal = 0
    for idx, mItem in ipairs(mGroup) do
        iTotal = iTotal + mItem.ratio
        if iRandom <= iTotal then
            return mItem.auction_type, mItem.sid, formula_string(mItem.attr, {}), mItem.price, mItem.money_type
        end
    end
end

function CAuction:AnalyseUpTime(mItem)
    if #mItem.week > 0 then
        local sTime = mItem.week
        local week,hour,min = sTime:match('^(%d+) (%d+)%:(%d+)')
        local mTime = os.date("*t")
        local iTime = os.time({
            year = mTime.year,
            month = mTime.month,
            day = mTime.day + (week-get_weekday()+7) % 7,
            hour = tonumber(hour),
            min = tonumber(min),
            sec = 0,
        })
        return iTime
    else
        local sTime = mItem.up_time
        local year,month,day,hour,min= sTime:match('^(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)')
        local mDate = os.date("*t")
        local iTime = os.time({
            year = year=="0" and mDate.year or tonumber(year),
            month = month=="0" and mDate.month or tonumber(month),
            day = day=="0" and mDate.day or tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = 0,
        })
        if day == "0" and iTime < get_time() then
            iTime = iTime + 24 * 60 * 60
        end
        return iTime
    end
end

function CAuction:LoadDb()
    if self:IsLoaded() then return end
    local mInfo = {
        module = "auctiondb",
        cmd = "LoadAuctionInfo",
    }
    gamedb.LoadDb("auction", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        if not self:IsLoaded()  then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CAuction:Schedule()
    local f
    f = function()
        self:DelTimeCb("_CheckAuction")
        local iDelay = self:GetNextCheckTime()
        if iDelay <= 0 then iDelay = 300 end
        self:AddTimeCb("_CheckAuction", iDelay*1000, f)
        safe_call(self.CheckAuction, self)
    end

    local iRet = self:GetNextCheckTime()
    if iRet <= 0 then
        f()
    else
        self:DelTimeCb("_CheckAuction")
        self:AddTimeCb("_CheckAuction", iRet*1000, f)
    end
end

function CAuction:GetNextCheckTime()
    local iCurr = get_time()
    local mDate = os.date("*t")
    local iFactor = mDate.min // 10
    local mNext = {
        year    = mDate.year,
        month   = mDate.month,
        day     = mDate.day,
        hour    = mDate.hour,
        sec     = 0,
    }

    if mDate.min % 10 <= 5 then
        mNext.min = 5 + iFactor * 10
    else
        mNext.min = (iFactor + 1) * 10
    end
    
    return os.time(mNext) - iCurr
end

function CAuction:OnLogout(oPlayer)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer, true) then
        return
    end
    self.m_oOperator:DelOpenUIPlayer(oPlayer:GetPid())
end

function CAuction:OnLogin(oPlayer)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer, true) then
        return
    end
    self.m_oOperator:DelOpenUIPlayer(oPlayer:GetPid())
end
