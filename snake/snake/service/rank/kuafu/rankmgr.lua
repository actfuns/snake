--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"

local rankmgr = import(service_path("rankmgr"))


function NewRankMgr(...)
    local o = CRankMgr:New(...)
    return o
end

local RANK_LIST = {
    ["singlewar"] = "singlewar",
}

CRankMgr = {}
CRankMgr.__index = CRankMgr
inherit(CRankMgr, rankmgr.CRankMgr)


function CRankMgr:New()
    local o = super(CRankMgr).New(self)
    return o
end

function CRankMgr:GetRankObj(idx)
    if self.m_mRankObj[idx] then
        return self.m_mRankObj[idx]
    end

    local sName = self:GetRankName(idx)
    if not sName then return nil end

    local sPath = self:GetRankPath(sName)
    local sModule = import(service_path(sPath))
    local oRank = sModule.NewRankObj(idx, sName)
    self.m_mRankObj[idx] = oRank
    self.m_mName2RankObj[sName] = oRank
    return oRank
end

function CRankMgr:LoadAllRank()
    local mAllInfo = self:GetAllRankInfo()
    for id, mInfo in pairs(mAllInfo) do
        local idx, sName = mInfo.idx, mInfo.name
        if RANK_LIST[sName] then
            local sPath = self:GetRankPath(sName)
            local sModule = import(service_path(sPath))
            local oRank = sModule.NewRankObj(idx, sName)
            self.m_mRankObj[idx] = oRank
            self.m_mName2RankObj[sName] = oRank
        end
    end
end
