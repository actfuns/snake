local global = require "global"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local loadsumm = import(service_path("summon.loadsummon"))
local proxy = import(service_path("auction.proxybase"))
local defines = import(service_path("auction.defines"))
local gamedb = import(lualib_path("public.gamedb"))


function NewPlayerUnit(...)
    local o = CPlayerUnit:New(...)
    return o
end

CPlayerUnit = {}
CPlayerUnit.__index = CPlayerUnit
inherit(CPlayerUnit, datactrl.CDataCtrl)

function CPlayerUnit:New(iPid)
    local o = super(CPlayerUnit).New(self)
    o:Init(iPid)
    return o
end

function CPlayerUnit:Release()
    super(CPlayerUnit).Release(self)
end

function CPlayerUnit:Init(iPid)
    self.m_iPid = iPid
    self.m_mFollows = {}        --玩家的商品关注列表
    self.m_mAuctions = {}       --玩家进行拍卖的商品
end

function CPlayerUnit:Save()
    local mItem, mSumm = {}, {}
    for iProxy, oProxy in pairs(self.m_mAuctions) do
        if oProxy:Type() == defines.PROXY_TYPE_ITEM then
            table.insert(mItem, oProxy:Save())
        else
            table.insert(mSumm, oProxy:Save())
        end
    end

    local mData = {}
    mData.item = mItem
    mData.summ = mSumm
    return mData
end

function CPlayerUnit:Load(m)
    if not m then return end


    for _, mItem in ipairs(m.item or {}) do
        local oItem = global.oItemLoader:LoadItem(mItem.datactrl.sid, mItem.datactrl)
        local oProxyItem = proxy.NewProxyItem(oItem)
        oProxyItem:Load(mItem)
        self:AddAuction(oProxyItem:GetID(), oProxyItem)
        global.oAuction:OnLoadProxy(oProxyItem)
    end
    for _, mSumm in ipairs(m.summ or {}) do
        local oSumm = loadsumm.LoadSummon(mSumm.datactrl.sid, mSumm.datactrl)
        local oProxySummon = proxy.NewProxySummon(oSumm)
        oProxySummon:Load(mSumm)
        self:AddAuction(oProxySummon:GetID(), oProxySummon)
        global.oAuction:OnLoadProxy(oProxySummon)
    end
end

function CPlayerUnit:MergeFrom(m)
    if not m then
        return false, "not exist data form:"..self.m_iPid
    end
    self:Dirty()
    if self.m_iPid ~= 0 then
        self:Load(m)
        return true
    end

    for _, mItem in ipairs(m.item or {}) do
        local oItem = global.oItemLoader:Create(mItem.datactrl.sid)
        local oProxyItem = proxy.NewProxyItem(oItem)
        oProxyItem:Load(mItem)
        self:AddAuction(oProxyItem:GetID(), oProxyItem)
        global.oAuction:OnLoadProxy(oProxyItem)
        oProxyItem:CancelAuction(true)
    end
    for _, mSumm in ipairs(m.summ or {}) do
        local oSumm = loadsumm.CreateSummon(mSumm.datactrl.sid)
        local oProxySummon = proxy.NewProxySummon(oSumm)
        oProxySummon:Load(mSumm)
        self:AddAuction(oProxySummon:GetID(), oProxySummon)
        global.oAuction:OnLoadProxy(oProxySummon)
        oProxySummon:CancelAuction(true)
    end
    return true
end

function CPlayerUnit:GetPid()
    return self.m_iPid
end

function CPlayerUnit:AddFollow(id)
    self.m_mFollows[id] = 1
end

function CPlayerUnit:RemoveFollow(id)
    self.m_mFollows[id] = nil
end

function CPlayerUnit:GetFollows()
    return self.m_mFollows
end

function CPlayerUnit:AddAuction(id, oProxy)
    self.m_mAuctions[id] = oProxy
    self:Dirty()
end

function CPlayerUnit:RemoveAuction(id)
    self.m_mAuctions[id] = nil
    self:Dirty()
end

function CPlayerUnit:Dirty()
    super(CPlayerUnit).Dirty(self)
end

function CPlayerUnit:GetAuctions()
    return self.m_mAuctions
end

function CPlayerUnit:ConfigSaveFunc()
    if not self.m_iSaveId then
        local iPid = self.m_iPid
        self:ApplySave(function()
            CheckApplySave(iPid)
        end)
    end
end

function CPlayerUnit:CheckProxyStatus()
    local lProxy = table_key_list(self.m_mAuctions)
    for _, iProxy in ipairs(lProxy) do
        local oProxy = self.m_mAuctions[iProxy]
        if oProxy then
            safe_call(oProxy.CheckStatus, oProxy)
        end
    end
end

function CPlayerUnit:_CheckSaveDb()
    assert(not is_release(self), "auction playerunit is releasing")
    assert(self:IsLoaded(), "auction playerunit is loading")
    self:SaveDb()
end

function CPlayerUnit:SaveDb()
    if not self:IsLoaded() then return end
    if not self:IsDirty() then return end
    
    local mInfo = {
        module = "auctiondb",
        cmd = "SaveAuctionInfoByPid",
        cond = {pid = self:GetPid()},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("auction", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CPlayerUnit:LoadDb()
    local mInfo = {
        module = "auctiondb",
        cmd = "LoadAuctionInfoByPid",
        cond = {pid = self:GetPid()},
    }
    gamedb.LoadDb("auction", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CPlayerUnit:AfterLoad()
    local iPid = self.m_iPid
    local f
    f = function()
        local oUnit = global.oAuction.m_mPlayerInfo[iPid]
        if oUnit then
            local iDelay = math.max(1, (get_time()+60)//60*60 - get_time())
            oUnit:DelTimeCb("_CheckProxyStatus")
            oUnit:AddTimeCb("_CheckProxyStatus", iDelay*1000, f)
            safe_call(oUnit.CheckProxyStatus, oUnit)
        end
    end
    f()
end

function CPlayerUnit:IsDirty()
    return super(CPlayerUnit).IsDirty(self)
end

function CheckApplySave(iPid)
    local oUnit = global.oAuction.m_mPlayerInfo[iPid]
    if oUnit then
        oUnit:_CheckSaveDb()
    end
end


