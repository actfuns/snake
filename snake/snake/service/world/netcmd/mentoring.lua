local skynet = require "skynet"
local global = require "global"

function C2GSToBeMentor(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MENTORING", oPlayer) then
        return
    end

    global.oMentoring:ToBeMentor(oPlayer, mData.option_list)
end

function C2GSToBeApprentice(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MENTORING", oPlayer) then
        return
    end

    global.oMentoring:ToBeApprentice(oPlayer, mData.option_list)
end

function C2GSDirectBuildReleationship(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MENTORING", oPlayer) then
        return
    end

    global.oMentoring:TryDirectBuildRelationship(oPlayer, mData.pid)
end

function C2GSMentoringTaskReward(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MENTORING", oPlayer) then
        return
    end

    global.oMentoring:MentoringTaskReward(oPlayer, mData.type, mData.target, mData.idx)
end

function C2GSMentoringStepResultReward(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MENTORING", oPlayer) then
        return
    end

    global.oMentoring:MentorStepResultReward(oPlayer, mData.type, mData.target, mData.idx)
end

