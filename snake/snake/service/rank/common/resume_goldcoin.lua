local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local rankbase = import(service_path("rankbase"))

--每日消费榜

function NewRankObj(...)
    return CRank:New(...)
end

CRank = {}
CRank.__index = CRank
inherit(CRank, rankbase.CRankBase)

function CRank:Init(idx, sName)
    super(CRank).Init(self, idx, sName)
    self.m_lSortDesc = {true, false, true, false}
    self.m_iStubShow = -1
    self.m_iShowLimit = 20
    self.m_iSaveLimit = 40
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.cnt, mData.time, mData.score, mData.pid, mData.name, mData.school,}
end

function CRank:InsertToOrderRank(sKey, mUnit)
    super(CRank).InsertToOrderRank(self, sKey, mUnit)
    self:DoStubShowData()
end

function CRank:MergeFrom(mFromData)
    if not mFromData then
        return false ,string.format("rank %s no merge_from_data",self.m_sRankName)
    end
    self:Dirty()
    for sKey,mUnit in pairs(mFromData.rank_data) do
        self:InsertToOrderRank(sKey,mUnit)
    end
    self:MergeTitleRecord(mFromData)
    return true
end

function CRank:MergeFinish()
    self:DoStubShowData()
    self:RemoveTitle()
    self:RewardTitle()
end

function CRank:GetIndex()
    return 4, 5
end

function CRank:NewHour(iDay, iHour)
    if iHour ~= 5 then return end

    self:DoStubShowData()
    self:RemoveTitle()
    self:RewardTitle()
    self:Init(self.m_iRankIndex, self.m_sRankName)
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    local iRank = self.m_mShowRank[db_key(iPid)]
    if iRank and iRank <= self.m_iShowLimit then
        mNet.my_rank = iRank
    end

    local mData = self:GetShowRankData(iPage)
    local lRankList = {}
    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.cnt = lInfo[1]
        mUnit.score = lInfo[3]
        mUnit.pid = lInfo[4]
        mUnit.name = lInfo[5]
        mUnit.school = lInfo[6]
        table.insert(lRankList, mUnit)
    end
    if #lRankList > 0 then
        mNet.resume_goldcoin = lRankList
    end
    return mNet
end

function CRank:GetRewardTitle(iRank)
    local mRes = res["daobiao"]["rankreward"][self.m_iRankIndex]
    if not mRes then
        return 
    end
    if not mRes["title_list"][iRank] then
        return 
    end
    return mRes["title_list"][iRank] 
end

function CRank:RewardTitle()
    local mLogData={}
    local lPageData = self.m_mShowData[1] or {}
    local iSize = math.min(3, #lPageData)
    if iSize <= 0 then 
        mLogData.rank = self.m_iRankIndex
        mLogData.sTitle = "无"
        record.log_db("rank", "reward_title",mLogData)
        return 
    end
    local iPidPos, _ = self:GetIndex()
    local lRecordPlist = {}
    local lRewardTitle = {}
    for i = 1, iSize do
        local iTitle = self:GetRewardTitle(i)
        local iPid = lPageData[i][iPidPos]
        if iTitle and iPid then
            table.insert(lRewardTitle,{pid = iPid, title = iTitle})
        end
    end
    mLogData.rank = self.m_iRankIndex
    mLogData.sTitle = extend.Table.serialize(lRewardTitle)
    record.log_db("rank", "reward_title", mLogData)

    local mArgs = {
        rank_name = self:GetAlias(),
        rank_list = lRewardTitle,
    }
    interactive.Send(".world", "rank", "MailRankReward", mArgs)
end

