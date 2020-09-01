local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function BuildShareObj(mRecord, mData)
    local mShare = mData.share
    global.oMentoring:BuildShareObj(mShare)
end

function UpdateMentorInfo(mRecord, mData)
    local iPid = mData.pid
    local mInfo = mData.info
    global.oMentoring:UpdateMentorInfo(iPid, mInfo)
end

function UpdateApprenticeInfo(mRecord, mData)
    local iPid = mData.pid
    local mInfo = mData.info
    global.oMentoring:UpdateApprenticeInfo(iPid, mInfo)
end

function UpdateOnline(mRecord, mData)
    local iPid = mData.pid
    global.oMentoring:UpdateOnline(iPid, mData)
end

function UpdateOffline(mRecord, mData)
    local iPid = mData.pid
    global.oMentoring:UpdateOffline(iPid)
end

function MatchMentor(mRecord, mData)
    local iPid = mData.pid
    local iSchool = mData.school
    local lArray = global.oMentoring:MatchMentor(iPid, iSchool) or {}
    interactive.Response(mRecord.source, mRecord.session, {
        match_list = lArray,
    })
end

