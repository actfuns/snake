local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local rankbase = import(service_path("common.resume_goldcoin"))

--强化狂人

function NewRankObj(...)
    return CRank:New(...)
end


CRank = {}
CRank.__index = CRank
inherit(CRank, rankbase.CRank)

function CRank:Init(idx, sName)
    super(CRank).Init(self, idx, sName)
    self.m_iShowLimit = 50
    self.m_iSaveLimit = 100
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.cnt, mData.time, mData.score, mData.pid, mData.name, mData.school,}
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = super(CRank).PackShowRankData(self, iPid, iPage)
    
    mNet.strength_equip = mNet.resume_goldcoin
    mNet.resume_goldcoin = nil
    return mNet
end

