--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function PackProfile(obj)
    local mProfile = {}
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(obj:GetPid())
    if oPlayer then
        mProfile.model = oPlayer:GetModelInfo()
        mProfile.upvote = obj:GetUpvoteAmount()
        mProfile.name = oPlayer:GetName()
        mProfile.school = oPlayer:GetSchool()        
    else
        mProfile.model = table_copy(obj:GetModelInfo() or {})
        mProfile.upvote = obj:GetUpvoteAmount()
        mProfile.name = obj:GetName()
        mProfile.school = obj:GetSchool()
    end
    if mProfile.model then
        mProfile.model.horse = nil
    end
    return mProfile
end

function GetProfile(mRecord, mData)
    local iPid, iRank = mData.pid, mData.rank
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadProfile(iPid, function (obj)
        local mProfile = PackProfile(obj)
        mProfile.rank = iRank
        mProfile.pid = iPid
        interactive.Response(mRecord.source, mRecord.session, mProfile)
    end)
end

function KeepUpvoteShowRank(mRecord, mData)
    local mShowRank = mData.show_rank or {}
    local sRankName = mData.rank_name or ""
    local oRankMgr = global.oRankMgr
    oRankMgr:SetUpvoteShowRank(sRankName, mShowRank)
end

function UpdateJJCTop3(mRecord, mData)
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:UpdateJJCTop3(mData.data)
end

function RankReward(mRecord,mData)
    local oRankMgr = global.oRankMgr
    oRankMgr:RankReward(mData)
end

function RemoveTitle(mRecord,mData)
    local oRankMgr = global.oRankMgr
    oRankMgr:RemoveTitle(mData)
end

function MailRankReward(mRecord, mData)
    global.oRankMgr:MailRankReward(mData)
end

