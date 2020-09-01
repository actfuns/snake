local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"

local stall = import(service_path("stall.stallobj"))
local syscatalog = import(service_path("stall.syscatalog"))
local pricemgr = import(service_path("stall.price"))
local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))
local defines = import(service_path("stall.defines"))

function NewStallMgr()
    local o = CStallMgr:New()
    return o
end


CStallMgr = {}
CStallMgr.__index = CStallMgr
inherit(CStallMgr, datactrl.CDataCtrl)

function CStallMgr:New()
    local o = super(CStallMgr).New(self)
    o:Init()
    return o
end

function CStallMgr:Init()
    self.m_mStall = {}
    self.m_oSysCatalog = syscatalog.NewCatalogMgr()
    self.m_oPriceMgr = pricemgr:NewPriceMgr()
end

function CStallMgr:GetStallObj(iPid)
    if self.m_mStall[iPid] then
        return self.m_mStall[iPid]
    end
    local obj = stall.NewStallObj(iPid)
    obj:OnLoaded()
    self.m_mStall[iPid] = obj
    return obj
end

function CStallMgr:Release()
    self.m_mStall = {}
    super(CStallMgr).Release(self)
end

function CStallMgr:SaveAll()
    for iPid, oStall in pairs(self.m_mStall) do
        oStall:SaveDb()
    end
end

function CStallMgr:Load(m)
    for _, mInfo in pairs(m or {}) do
        local iPid = mInfo.pid
        local mStall = mInfo.data
        local oStall = stall.NewStallObj(iPid)
        oStall:Load(mStall)
        oStall:OnLoaded()
        self.m_mStall[iPid] = oStall
    end
end

function CStallMgr:LoadDb()
    local mInfo = {
        module = "stalldb",
        cmd = "LoadAllInfoFromStall",
    }
    gamedb.LoadDb("stall", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CStallMgr:MergeFrom(mInfo)
    if not mInfo then return false, "not data" end

    local iPid = mInfo.pid
    local mStall = mInfo.data
    local oStall = stall.NewStallObj(iPid)
    oStall:Load(mStall)
    oStall:OnLoaded()
    self.m_mStall[iPid] = oStall
    for iPos, oSell in pairs(oStall.m_mItemInfo) do
        if oSell:GetSellTime() + defines.GetKeepTime() >= get_time() then
            oSell:SetSellTime(get_time() - defines.GetKeepTime() - 60)
        end
    end
    oStall:SaveDb()
    return true
end

function CStallMgr:OnLogin(oPlayer, bReEnter)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer, true) then
        return
    end

    local oStallObj = self:GetStallObj(oPlayer:GetPid())
    oStallObj:OnLogin(oPlayer, bReEnter)
end

