--import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local playersend = require "base.playersend"
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
    self.m_lSortDesc = {true, false, false}
    self.m_iStubShow = -1
    self.m_iShowPage = 100
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.score, mData.time, mData.pid, mData.name}
end

function CRank:NewDay(iDay)
    if iDay == 1 then
        self:ClearRankData()
    end
end

function CRank:PackWeekRankData()
    local mNet = {}
    local mData = self:GetShowRankData(1)
    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.score = lInfo[1]
        mUnit.pid = lInfo[3]
        mUnit.name = lInfo[4]
        table.insert(mNet, mUnit)
    end
    return mNet
end

function CRank:PackWeekRankData2()
    local mNet, iCount = {}, 0

    for idx, sKey in ipairs(self.m_lSortList) do
        local lInfo = self.m_mRankData[sKey]
        if lInfo then
            local mUnit = {}
            mUnit.score = lInfo[1]
            mUnit.pid = lInfo[3]
            mUnit.name = lInfo[4]
            table.insert(mNet, mUnit)
            iCount = iCount + 1
        end

        if iCount >= self.m_iShowPage then break end
    end
    return mNet
end

function CRank:PackBaikeWeekRankTop()
    local mNet = {}
    local iTopScore
    for idx, sKey in ipairs(self.m_lSortList) do
        local lInfo = self.m_mRankData[sKey]
        if lInfo then
            local mUnit = {}
            local iScore = lInfo[1]
            if not iTopScore then
                iTopScore = iScore
            end
            if iTopScore > iScore then
                break
            end
            mUnit.score = iScore
            mUnit.pid = lInfo[3]
            mUnit.name = lInfo[4]
            table.insert(mNet, mUnit)
        end
    end
    return mNet
end

function CRank:PackHfdmRank()
    local mNet = {}
    for idx = 1, 6 do
        local sKey = self.m_lSortList[idx]
        local lInfo = self.m_mRankData[sKey]
        if not lInfo then
            break
        end
        local mUnit = {}
        mUnit.score = lInfo[1]
        mUnit.pid = lInfo[3]
        mUnit.name = lInfo[4]
        mUnit.rank = idx
        table.insert(mNet, mUnit)
        end
    return mNet
end

function CRank:SendHfdmRankForOne(mOnePid)
    local mRankNet = self:PackHfdmRank()
    for iPid, _ in pairs(mOnePid) do
        playersend.Send(iPid, "GS2CHfdmRankInfo", {ranks = mRankNet})
        local lInfo = self.m_mRankData[db_key(iPid)]
        if lInfo then
            playersend.Send(iPid, "GS2CHfdmMyRank", {score = lInfo[1]})
        end
    end
end

function CRank:SendHfdmRank(mPids)
    local mRankNet = self:PackHfdmRank()
    for idx, sKey in ipairs(self.m_lSortList) do
        local lInfo = self.m_mRankData[sKey]
        if lInfo then
            local iPid = lInfo[3]
            if mPids[iPid] then
                playersend.Send(iPid, "GS2CHfdmRankInfo", {ranks = mRankNet})
                local mUnit = {}
                mUnit.score = lInfo[1]
                -- mUnit.pid = lInfo[3]
                -- mUnit.name = lInfo[4]
                mUnit.rank = idx
                playersend.Send(iPid, "GS2CHfdmMyRank", mUnit)
                mPids[iPid] = nil
            end
        end
    end
    for iPid, _ in pairs(mPids) do
        playersend.Send(iPid, "GS2CHfdmRankInfo", {ranks = mRankNet})
        playersend.Send(iPid, "GS2CHfdmMyRank", {})
    end
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[3]}
end

function CRank:RemoteGetTop3Profile()
end

function CRank:ClearRankData()
    self:Dirty()
    self.m_mRankData = {}
    self.m_lSortList = {}
    self.m_mShowData = {}
    self.m_mShowRank = {}
end

function CRank:GetIndex()
    return 3, 4
end

function CRank:MergeFrom(mFromData)
    if not mFromData then return true end
        
    self:Dirty()
    for sKey, mUnit in pairs(mFromData.rank_data or {}) do
        self:InsertToOrderRank(sKey, mUnit)
    end
    return true
end
