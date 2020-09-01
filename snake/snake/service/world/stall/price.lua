local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))


function NewPriceMgr(...)
    local o = CPriceMgr:New(...)
    return o
end

CPriceMgr = {}
CPriceMgr.__index = CPriceMgr
inherit(CPriceMgr, datactrl.CDataCtrl)

function CPriceMgr:New(...)
    local o = super(CPriceMgr).New(self)
    o:Init()
    return o
end

function CPriceMgr:Init()
    self.m_mItemPrice = {}
    self.m_mLastPrice = {}      --昨天的平均价作为今天的行情价
end

function CPriceMgr:AddPrice(iSid, iPrice, iAmount)
    local mData = self.m_mItemPrice[iSid] 
    mData = mData or {price=0, amount=0, dayno=get_dayno()}
    local iToday = get_dayno()

    if iToday ~= mData.dayno then
        self:GenLastPrice(iSid)
        mData.price = 0
        mData.amount = 0
        mData.dayno = iToday
    end
    local iTotal = mData.amount + iAmount
    if iTotal > 0 then
        local iPrice = (mData.amount/iTotal)*(mData.price or 0) + (iAmount/iTotal)*iPrice
        mData.price = iPrice
        mData.amount = iTotal
        self.m_mItemPrice[iSid] = mData
        self:Dirty()
    end
end

function CPriceMgr:GenLastPrice(iSid)
    local mData = self.m_mItemPrice[iSid]
    if not mData then return end
    
    local iToday = get_dayno()
    if iToday == mData.dayno then
        return  
    end

    local iPrice = math.floor(mData.price or 0)
    self.m_mLastPrice[iSid] = {price=iPrice, dayno=mData.dayno}
    self:Dirty()
end

function CPriceMgr:GetLastPrice(iSid)
    self:GenLastPrice(iSid)

    local mBase = res["daobiao"]["stall"]["iteminfo"]
    local iDayNo = get_dayno() - 1
    local mData = self.m_mLastPrice[iSid]
    if mData and mData.dayno == iDayNo then
        local mInfo = mBase[iSid]
        return math.min(math.max(mData.price, mInfo.min_price), mInfo.max_price)
    end

    return table_get_depth(mBase, {iSid, "base_price"}) or 0
end

function CPriceMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        global.oStallMgr.m_oPriceMgr:_CheckSaveDb()
    end)
end

function CPriceMgr:Save()
    local mData = {}
    local mItemPrice = {}
    for iSid, mInfo in pairs(self.m_mItemPrice) do
        mItemPrice[db_key(iSid)] = mInfo
    end
    local mLastPrice = {}
    for iSid, mInfo in pairs(self.m_mLastPrice) do
        mLastPrice[db_key(iSid)] = mInfo
    end
    mData.item_price = mItemPrice
    mData.last_price = mLastPrice
    return mData
end

function CPriceMgr:Load(m)
    for sKey, mData in pairs(m.item_price or {}) do
        local iSid = tonumber(sKey)
        self.m_mItemPrice[iSid] = mData
    end
    for sKey, mData in pairs(m.last_price or {}) do
        local iSid = tonumber(sKey)
        self.m_mLastPrice[iSid] = mData
    end
end

function CPriceMgr:MergeFrom(mFromData)
    return true
end

function CPriceMgr:SaveDb()
    if not self:IsLoaded() then return end
    if not self:IsDirty() then return end

    local mInfo = {
        module = "pricedb",
        cmd = "SavePriceByName",
        cond = {name = "stall_price"},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("stall", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CPriceMgr:LoadDb()
    local mInfo = {
        module = "pricedb",
        cmd = "LoadPriceByName",
        cond = {name = "stall_price"},
    }
    gamedb.LoadDb("stall", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CPriceMgr:_CheckSaveDb()
    assert(not is_release(self), "pricemgr is releasing")
    assert(self:IsLoaded(), "pricemgr is loading")
    self:SaveDb()
end

function CPriceMgr:Release()
    self.m_mItemPrice = {}
    self.m_mLastPrice = {}
    super(CPriceMgr).Release(self)
end
