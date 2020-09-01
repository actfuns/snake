--import module
local global = require "global"
local skynet = require "skynet"
local playersend = require "base.playersend"
local interactive = require "base.interactive"
local rankbase = import(service_path("rankbase"))


function NewRankObj(...)
    return CRank:New(...)
end

CRank = {}
CRank.__index = CRank
inherit(CRank, rankbase.CRankBase)

function CRank:Init(idx, sName)
    super(CRank).Init(self, idx, sName)
    self.m_iStubShow = -1
    self.m_iSaveLimit = 1100
    self.m_lSortDesc = {true, true, false, false}
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.point, mData.grade, mData.time, mData.pid, mData.name, mData.school, mData.orgname, mData.orgid}
end

function CRank:GetOrgInfo()
    return 8, 7, "orgid", "orgname", false
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub

    if self.m_mRankData[db_key(iPid)] then
        mNet.my_rank = self:GetRankByPid(iPid)
        mNet.my_point = self.m_mRankData[db_key(iPid)][1]
    end

    local lNetRank, iCount = {}, 0
    for idx, sPid in pairs(self.m_lSortList) do
        local mData = self.m_mRankData[sPid]
        local mUnit = {}
        mUnit.pid = mData[4]
        mUnit.point = mData[1]
        mUnit.grade = mData[2]
        mUnit.name = mData[5]
        mUnit.school = mData[6]
        mUnit.org_name = mData[7]
        table.insert(lNetRank, mUnit)
        iCount = iCount + 1
        if iCount > self.m_iShowPage then
            break
        end
    end
    if #lNetRank > 0 then
        mNet.mengzhuplayer_rank = lNetRank
    end
    return mNet
end

function CRank:GetRankByPid(iPid)
    local sPid = db_key(iPid)
    for idx, sKey in ipairs(self.m_lSortList) do
        if sKey == sPid and idx <= 1000 then
            return idx
        end
    end
    return 0
end

function CRank:OnUpdateName(iPid, sName)
    local sPid = db_key(iPid)
    if not self.m_mRankData[sPid] then return end
    self.m_mRankData[sPid][5] = sName
    self:Dirty()
end

function CRank:OnUpdateOrgName(iOrg, sName)
    for sPid, mData in pairs(self.m_mRankData) do
        if mData[8] == iOrg then
            mData[7] = sName
        end
    end
    self:Dirty()
end

function CRank:GS2CMengzhuOpenPlayerRank(mData)
    local iPid = mData.pid
    local mPack = self:PackShowRankData(iPid, 1)

    local mNet = {}
    mNet.boss_time = mData.mengzhu_cd
    mNet.plunder_time = mData.plunder_cd
    mNet.my_point = mData.point
    mNet.game_start_time = mData.game_start_time
    mNet.my_rank = mPack.my_rank
    mNet.player_list = mPack.mengzhuplayer_rank

    playersend.Send(iPid, "GS2CMengzhuOpenPlayerRank", mNet)
end

function CRank:FilterPlunderList(mData)
    local iOrg = mData.org_id
    local mFriends = mData.friend_list
    local lResult, iTotal, iPos = {}, 0, nil
    for idx, sPid in ipairs(self.m_lSortList) do
        local mInfo = self.m_mRankData[sPid]
        local iPid = tonumber(sPid)

        if iPid == mData.pid then
            iPos = iTotal
        else
            if mInfo[8] == iOrg then
                goto continue
            end
            if mFriends[sPid] then
                goto continue
            end
            if mInfo[1] < 10 then
                goto continue
            end

            iTotal = iTotal + 1
            table.insert(lResult, iPid)
        end
        ::continue::
    end

    if iTotal <= 0 then return {} end

    local lPlayerList = {}
    if not iPos then
        for i = iTotal-10, iTotal do
            if lResult[i] then
                table.insert(lPlayerList, lResult[i])
            end
        end
    else
        local iBegin = iPos - 1
        local iEnd = iPos
        for i=1, 11 do
            if iBegin > 0 and iBegin <= iTotal then
                table.insert(lPlayerList, lResult[iBegin])
            end
            if iEnd > 0 and iEnd <= iTotal then
                table.insert(lPlayerList, lResult[iEnd])
            end
            iBegin = iBegin - 1
            iEnd = iEnd + 1
            if #lPlayerList >= 10 then
                break
            end
        end
    end
    return lPlayerList
end

function CRank:GetIndex()
    return 4, 5
end

function CRank:MergeFrom(mFromData)
    --玩法榜，不需要合并
    return true
end

