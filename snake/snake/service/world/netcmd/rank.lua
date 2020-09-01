local global = require "global"
local interactive = require "base.interactive"

function C2GSGetRankInfo(oPlayer, mData)
    Forward(oPlayer, "C2GSGetRankInfo", mData)
end

function C2GSGetRankTop3(oPlayer, mData)
    Forward(oPlayer, "C2GSGetRankTop3", mData)
end

function CleanRank(oPlayer, mData)
    Forward(oPlayer, "CleanRank", mData)
end

function C2GSGetRankSumInfo(oPlayer, mData)
    Forward(oPlayer, "C2GSGetRankSumInfo", mData)
end

function Forward(oPlayer, sProtocol, mData)
    local mInfo = {}
    mInfo.cmd = sProtocol
    mInfo.data = mData
    mInfo.pid = oPlayer:GetPid()
    mInfo.ext = {}
    local oOrg = oPlayer:GetOrg()
    if oOrg then
        mInfo.ext.orgid = oOrg:OrgID()
    end
    interactive.Send(".rank", "rank", "Forward", mInfo)
end

function C2GSGetUpvoteAmount(oPlayer, mData)
    local iTarget = mData.pid
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    oWorldMgr:LoadProfile(iTarget, function (o)
        GS2CGetUpvoteAmount(iPid, o)
    end)
end

function GS2CGetUpvoteAmount(iPid, oProfile)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mNet = {}
        mNet.pid = oProfile:GetPid()
        mNet.upvote = oProfile:GetUpvoteAmount()
        oPlayer:Send("GS2CGetUpvoteAmount", mNet)
    end
end
