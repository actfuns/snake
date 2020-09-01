local global = require "global"
local skynet = require "skynet"
local bson = require "bson"
local interactive = require "base.interactive"
local record = require "public.record"

function NewSystemObj(...)
    local o = CSystemObj:New(...)
    return o
end

CSystemObj = {}
CSystemObj.__index = CSystemObj
inherit(CSystemObj, logic_base_cls())

function CSystemObj:New()
    local o = super(CSystemObj).New(self)
    o.m_mCostInfos = {}
    o.m_mGameSystemInfos = {}
    return o
end

function CSystemObj:Init()
    self:Schedule()
end

function CSystemObj:Release()
    release(self)
end

function CSystemObj:PushCostData(sType, iPid, mCosts, mRewards, bRecordPlayer)
    if bRecordPlayer == nil then
        bRecordPlayer = true
    end
    local mInfo = self.m_mCostInfos[sType]
    if not mInfo then
        mInfo = {}
        self.m_mCostInfos[sType] = mInfo
    end
    mInfo["total"] = (mInfo["total"] or 0) + 1
    if bRecordPlayer then
        self:AddCostPlayerCnt(sType, iPid)
    else
        if not mInfo["pids"] then
            mInfo["pids"] = {}
        end
    end
    local mCostInfo = mInfo["cost"]
    if not mCostInfo then
        mCostInfo = {}
        mInfo["cost"] = mCostInfo
    end
    for id, amount in pairs(mCosts) do
        id = db_key(id)
        mCostInfo[id] = (mCostInfo[id] or 0) + amount
    end
    local mRewardInfo = mInfo["reward"]
    if not mRewardInfo then
        mRewardInfo = {}
        mInfo["reward"] = mRewardInfo
    end
    for id, amount in pairs(mRewards) do
        id = db_key(id)
        mRewardInfo[id] = (mRewardInfo[id] or 0) + amount
    end
end

function CSystemObj:AddCostPlayerCnt(sType, iPid)
    local mInfo = self.m_mCostInfos[sType]
    if not mInfo then
        mInfo = {}
        self.m_mCostInfos[sType] = mInfo
    end
    if mInfo["pids"] then
        mInfo["pids"][db_key(iPid)] = true
    else
        mInfo["pids"] = {[db_key(iPid)] = true}
    end
end

function CSystemObj:PushGameSystemReward(sType, mRewards, iRecordPid)
    local mRecord = self.m_mGameSystemInfos[sType]
    if not mRecord then
        mRecord = {reward={}, total=0, pids={}}
        self.m_mGameSystemInfos[sType] = mRecord
    end

    local mTempReward = mRecord["reward"] or {}
    for iSid, iAmount in pairs(mRewards or {}) do
        local sSid = db_key(iSid)
        mTempReward[sSid] = (mTempReward[sSid] or 0) + iAmount
    end

    if iRecordPid then
        mRecord["total"] = (mRecord["total"] or 0) + 1

        local mPid = mRecord["pids"] or {}
        local sPid = db_key(iRecordPid)
        if not mPid[sPid] then
            mPid[sPid] = true
            mRecord["pids"] = mPid 
        end
    end
end

function CSystemObj:AddGameSystemCnt(sType, iPid)
    if not iPid then return end
        
    local mRecord = self.m_mGameSystemInfos[sType]
    if not mRecord then
        mRecord = {reward={}, total=0, pids={}}
        self.m_mGameSystemInfos[sType] = mRecord
    end

    mRecord["total"] = (mRecord["total"] or 0) + 1
    local mPid = mRecord["pids"] or {}
    local sPid = db_key(iPid)
    if not mPid[sPid] then
        mPid[sPid] = true
        mRecord["pids"] = mPid
    end
end

function CSystemObj:RecordOrgMember(mMember, mOrg)
    record.user("gamesys", "org_member", {member=mMember, org=mOrg})
end

function CSystemObj:Schedule()
    local f1
    f1 = function ()
        local oSystemObj = global.oSystemObj
        if oSystemObj then
            oSystemObj:DelTimeCb("_CheckWriteLog")
            oSystemObj:AddTimeCb("_CheckWriteLog", 20*60*1000, f1)
            oSystemObj:_CheckWriteLog()
        end
    end
    f1()
end

function CSystemObj:_CheckWriteLog()
    if table_count(self.m_mCostInfos) then
        for sType, mInfo in pairs(self.m_mCostInfos) do
            record.user("statistics", sType, mInfo)
        end
        self.m_mCostInfos = {}
    end

    if table_count(self.m_mGameSystemInfos) then
        for sType, mInfo in pairs(self.m_mGameSystemInfos) do
            record.user("gamesys", sType, mInfo)
        end
        self.m_mGameSystemInfos = {}
    end
end