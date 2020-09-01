--import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local rankbase = import(service_path("rankbase"))


function NewRankObj(...)
    return CRank:New(...)
end

CRank = {}
CRank.__index = CRank
inherit(CRank, rankbase.CRankBase)

function CRank:Init(idx, sName)
    super(CRank).Init(self, idx, sName)
    self.m_lSortDesc = {true, true}
    self.m_iShowLimit = 10
    self.m_iShowPage = 10
    self.m_iSaveLimit = 20
end

function CRank:NewHour(iDay,iHour)
    self:DoStubShowData()
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.score, mData.goldcoin, mData.pid, mData.name}
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:MergeFrom(mFromData)
    if not mFromData then
        return false ,string.format("rank %s no merge_from_data",self.m_sRankName)
    end
    self:Dirty()
    for sKey,mUnit in pairs(mFromData.rank_data) do
        self:InsertToOrderRank(sKey,mUnit)
    end
    return true
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[3]}
end

function CRank:GetIndex()
    return 3, 4
end

function CRank:PackShowRankData(iPid, iPage, mArgs)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]

    local mData = self:GetShowRankData(iPage)
    local lRank = {}

    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.score = lInfo[1]
        mUnit.pid = lInfo[3]
        mUnit.name = lInfo[4]
        mUnit.rank_shift = lInfo[5]
        table.insert(lRank, mUnit)
    end
    if #lRank > 0 then
        mNet.jubaopen_score_rank = lRank
    end
    return mNet
end

function CRank:PackRewardData()
    local mRewardPlayer = {}
    local mData = self:GetShowRankData(1)
    for idx, lInfo in ipairs(mData) do
        table.insert(mRewardPlayer,lInfo[3])
    end
    return mRewardPlayer
end