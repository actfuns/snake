--import module
local global = require "global"
local skynet = require "skynet"
local playersend = require "base.playersend"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
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
    self.m_lSortDesc = {true, false}
end

function CRank:NewDay()
    self:DoStubShowData()
    self:RemoveTitle()
    self:RewardTitle()
end

function CRank:NewHour(iDay,iHour)
    if iHour == 0 then
        return 
    end
    if not self:ValidRefresh(iDay,iHour) then
        return
    end
    self:DoStubShowData()
end

function CRank:GenRankUnit(mData)
    return db_key(mData.orgid), {mData.prestige, mData.orgid, mData.orgname, mData.leadpid, mData.leadname, mData.orglv}
end

function CRank:GetOrgInfo()
    return 2, 3, "orgid", "orgname", true
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:PushDataToRank(mData)
    if mData.prestige == 0 then
        local sKey, _ = self:GenRankUnit(mData)
        self:RemoveUnitByKey(sKey)
        return
    end    
    super(CRank).PushDataToRank(self, mData)
end

function CRank:RemoveUnitByKey(sKey)
    if self.m_mRankData[sKey] then
        self:Dirty()
        self.m_mRankData[sKey] = nil
        extend.Array.remove(self.m_lSortList, sKey)
    end
end

function CRank:RewardTitle()
    local lRecordPlist = {}
    local lRewardTitle = {}
    for idx, sOrg in pairs(self.m_lSortList) do
        local iTitle = self:GetRewardTitle(idx)
        if not iTitle then break end

        local mData = self.m_mRankData[sOrg]
        local iPid = mData[4]
        table.insert(lRewardTitle, {pid=iPid, title=iTitle})
        table.insert(lRecordPlist,{pid = iPid,title = iTitle})
    end
    self:RecordTitlePlayer(lRecordPlist)
    local mLogData={}
    mLogData.rank = self.m_iRankIndex
    mLogData.sTitle = extend.Table.serialize(lRewardTitle)
    record.log_db("rank", "reward_title",mLogData)
    if #lRewardTitle > 0 then
        interactive.Send(".world", "rank", "RankReward", lRewardTitle)
    end
end

function CRank:GetRewardTitle(iRank)
    local mData = res["daobiao"]["rankreward"][self.m_iRankIndex]
    if not mData then return end
         
    return mData["title_list"][iRank] 
end

function CRank:PackShowRankData(iPid, iPage, mArgs)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub

    local iOrg = mArgs.orgid
    mNet.my_rank = self.m_mShowRank[db_key(iOrg)]
    local lNetRank, iCount = {}, 0
    local mData = self:GetShowRankData(iPage)
    for idx, lInfo in ipairs(mData) do
        local lInfo2 = self.m_mRankData[db_key(lInfo[2])] or lInfo
        local mUnit = {}
        mUnit.orgid = lInfo[2]
        mUnit.orgname = lInfo2[3]
        mUnit.orglv = lInfo2[6]
        mUnit.pid = lInfo[4]
        mUnit.name = lInfo2[5]
        mUnit.prestige = lInfo[1]
        table.insert(lNetRank, mUnit)
    end
    if #lNetRank > 0 then
        mNet.prestige_rank = lNetRank
    end
    return mNet
end

function CRank:PackOrgPrestigeInfo(iOrg)
    local mNet = {}
    if iOrg then
        mNet.my_rank = self:GetRankByOrg(iOrg)
        local mData = self.m_mRankData[db_key(iOrg)]
        if mData then
            mNet.my_prestige = mData[1]     
        end
    end
    return mNet
end

function CRank:GetRankByOrg(iOrg)
    if not iOrg then return 0 end

    local sOrg = db_key(iOrg)
    for idx, sKey in ipairs(self.m_lSortList) do
        if idx > self.m_iShowPage then break end

        if sKey == sOrg then return idx end
    end
    return 0
end

function CRank:GS2COrgPrestigeInfo(mData)
    local iOrg = mData.orgid
    local iPid = mData.pid
    playersend.Send(iPid, "GS2COrgPrestigeInfo", self:PackOrgPrestigeInfo(iOrg))     
end

function CRank:MergeFrom(mFromData)
    if not mFromData then return false end
        
    self:Dirty()
    for sKey, mUnit in pairs(mFromData.rank_data or {}) do
        self:InsertToOrderRank(sKey, mUnit)
    end
    self:MergeTitleRecord(mFromData)
    return true
end

function CRank:MergeFinish()
    self:DoStubShowData()
    self:RemoveTitle()
    self:RewardTitle()
end

