--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local loadsummon = import(service_path("summon.loadsummon"))
local summondefines = import(service_path("summon.summondefines"))


local CANGKU_SIZE = 4
local MAX_CANGKU_SIZE = 10   

CSummCkCtrl = {}
CSummCkCtrl.__index = CSummCkCtrl
inherit(CSummCkCtrl, datactrl.CDataCtrl)

function CSummCkCtrl:New(iPid)
    local o = super(CSummCkCtrl).New(self,{pid=iPid})
    o:Init()
    return o
end

function CSummCkCtrl:Init()
    self.m_iSize = CANGKU_SIZE
    self.m_iExtendSize = 0
    self.m_mSummons = {}
    self.m_mSummonScore = {}
end

function CSummCkCtrl:Release()
    for _,o in pairs(self.m_mSummons) do 
        baseobj_safe_release(o)
    end
    self.m_mSummons = {}
    super(CSummCkCtrl).Release(self)    
end

function CSummCkCtrl:Load(mData)
    local mData = mData or {}
    local summondata = mData.summondata or {}
    for _, data in pairs(summondata) do
        local oSummon = loadsummon.LoadSummon(data["sid"], data)
        assert(oSummon, string.format("summon ck sid error:%s,%s", self:GetInfo("pid"), data["sid"]))
        self.m_mSummons[oSummon.m_iID] = oSummon
    end
    self.m_iExtendSize = mData.extend_size or 0
end

function CSummCkCtrl:Save()
    local mData = {}
    mData.extend_size = self.m_iExtendSize
    mData.summondata = {}
    for _, oSummon in pairs(self.m_mSummons) do
        table.insert(mData.summondata, oSummon:Save())
    end
    return mData
end

function CSummCkCtrl:OnLogin(oPlayer, bReEnter)
    -- if bReEnter then return end
    if not bReEnter then
        self:SetupSummonScore()
    end

    self:GS2CLoginCKSummon(oPlayer)
end

function CSummCkCtrl:SetupSummonScore()
    self.m_mSummonScore = {}
    for _,o in pairs(self.m_mSummons) do
        self.m_mSummonScore[o:ID()] = o:GetScore()
    end
end

function CSummCkCtrl:GetCkSize()
    return self.m_iSize + self:GetExtendCkSize()
end

function CSummCkCtrl:CanExtendCkSize()
    return self:GetCkSize() < MAX_CANGKU_SIZE 
end

function CSummCkCtrl:GetExtendCkSize()
    return self.m_iExtendSize or 0
end

function CSummCkCtrl:AddExtendCkSize(iSize)
    self.m_iExtendSize = self:GetExtendCkSize() + iSize
    self:Dirty()
end

function CSummCkCtrl:GS2CLoginCKSummon(oPlayer)
    local mNet = {}
    mNet.extsize = self:GetExtendCkSize()
    mNet.summondata = {}
    for id, oSummon in pairs(self.m_mSummons) do
        table.insert(mNet.summondata, oSummon:SummonInfo())
    end
    oPlayer:Send("GS2CLoginCkSummon", mNet)
end

function CSummCkCtrl:EmptyCkSpaceCnt()
    return self:GetCkSize() - table_count(self.m_mSummons)
end

function CSummCkCtrl:GetCkSummon(iSummon)
    return self.m_mSummons[iSummon]
end

function CSummCkCtrl:AddCkSummon(oSummon)
    self.m_mSummons[oSummon:ID()] = oSummon
    self.m_mSummonScore[oSummon:ID()] = oSummon:GetScore()
    self:Dirty()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CAddCkSummon", {summondata=oSummon:SummonInfo()})
    end
end

function CSummCkCtrl:RemoveCkSummon(oSummon)
    self.m_mSummons[oSummon:ID()] = nil
    self.m_mSummonScore[oSummon:ID()] = nil
    baseobj_delay_release(oSummon)
    self:Dirty()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CDelCkSummon", {id=oSummon:ID()})
    end
end

function CSummCkCtrl:GetSummonScore()
    return self.m_mSummonScore
end

function CSummCkCtrl:PackBackendInfo()
    local mData = {}
    mData.summondata = {}
    for _, oSummon in pairs(self.m_mSummons) do
        table.insert(mData.summondata, oSummon:PackBackendInfo())
    end
    return mData
end


