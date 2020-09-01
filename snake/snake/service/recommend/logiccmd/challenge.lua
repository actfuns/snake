--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function AddChallengeMatchInfo(mRecord,mData)
    local pid = mData.pid
    local iGrade = mData.grade
    local iScore = mData.score
    local iSchool = mData.school

    local oChallengeObj = global.oChallengeObj
    oChallengeObj:AddChallengeMatchInfo(pid, iGrade, iScore, iSchool)
end

function GetChallengeTarget(mRecord, mData)
    local iGrade = mData.grade
    local iScore = mData.score
    local mExclude = mData.exclude
    local iGradeLimit = mData.gradelimit

    local oChallengeObj = global.oChallengeObj
    local mTarget = oChallengeObj:GetChallengeTarget(iGrade, iScore, mExclude, iGradeLimit)
    interactive.Response(mRecord.source, mRecord.session, {
        target = mTarget,
    })
end

function AddTrialMatchInfo(mRecord, mData)
    local sPid = tostring(mData.pid)
    local mInfo = {
        school = mData.data.school,
        score = mData.data.score,
        grade = mData.data.grade,
    }
    global.oTrialMatchMgr:AddTrialMatchInfo(sPid, mInfo)
end

function GetTrialMatchInfo(mRecord, mData)
    local mInfo = {
        school = mData.school,
        score = mData.score,
        grade = mData.grade,
        exclude = mData.exclude,
    }
    local iErr, lResult = global.oTrialMatchMgr:GetTrialMatchInfo(mInfo)
    interactive.Response(mRecord.source, mRecord.session, {
        err_code = iErr,
        match_list = lResult,
    })
end

