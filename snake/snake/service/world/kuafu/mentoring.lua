local global = require "global"
local router = require "base.router"
local datactrl = import(lualib_path("public.datactrl"))

function NewMentoring()
    return CMentoring:New()
end

CMentoring = {}
CMentoring.__index = CMentoring
inherit(CMentoring, datactrl.CDataCtrl)

function CMentoring:New()
    local o = super(CMentoring).New(self)
    return o
end

function CMentoring:AddTaskCnt(oLeader, iTask, iCnt, sReason)
    local oTeam = oLeader:HasTeam()
    if not oTeam then return end

    local mApprentice2Mentor = {}
    local lPlayer = {}
    for _, oMem in ipairs(oTeam:GetMember()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer then
            local oFriend = oPlayer:GetFriend()
            local mPid = oFriend:GetApprentice()
            for iPid, _ in pairs(mPid) do
                mApprentice2Mentor[iPid] = oMem.m_ID
            end
            table.insert(lPlayer, oPlayer)
        end
    end
    for _, oPlayer in ipairs(lPlayer) do
        if mApprentice2Mentor[oPlayer:GetPid()] then
            local iApprentice = oPlayer:GetPid()
            local iMentor = mApprentice2Mentor[iApprentice]
            self:KS2GSAddTaskCnt(iMentor, iApprentice, iTask, iCnt, sReason)
        end
    end
end

function CMentoring:AddStepResultCnt(oLeader, iStep, iCnt)
    local oTeam = oLeader:HasTeam()
    if not oTeam then return end

    local mApprentice2Mentor = {}
    local lPlayer = {}
    for _, oMem in ipairs(oTeam:GetMember()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer then
            local oFriend = oPlayer:GetFriend()
            local mPid = oFriend:GetApprentice()
            for iPid, _ in pairs(mPid) do
                mApprentice2Mentor[iPid] = oMem.m_ID
            end
            table.insert(lPlayer, oPlayer)
        end
    end
    for _, oPlayer in ipairs(lPlayer) do
        if mApprentice2Mentor[oPlayer:GetPid()] then
            local iApprentice = oPlayer:GetPid()
            local iMentor = mApprentice2Mentor[iApprentice]

            self:KS2GSAddStepResultCnt(iMentor, iApprentice, iStep, iCnt)
        end
    end
end

function CMentoring:KS2GSAddTaskCnt(iMentor, iApprentice, iTask, iCnt, sReason)
    local sServerTag = global.oWorldMgr:GetServerKey(iMentor)
    sServerTag = sServerTag or global.oWorldMgr:GetServerKey(iApprentice)

    local mArgs = {
        mentor = iMentor,
        apprentice = iApprentice,
        task = iTask,
        cnt = iCnt,
        reason = sReason.."(跨服)",
    }
    router.Send(sServerTag, ".world", "kuafu_gs", "KS2GSAddTaskCnt", mArgs)
end

function CMentoring:KS2GSAddStepResultCnt(iMentor, iApprentice, iStep, iCnt)
    local sServerTag = global.oWorldMgr:GetServerKey(iMentor)
    sServerTag = sServerTag or global.oWorldMgr:GetServerKey(iApprentice)

    local mArgs = {
        mentor = iMentor,
        apprentice = iApprentice,
        step = iStep,
        cnt = iCnt,
    }
    router.Send(sServerTag, ".world", "kuafu_gs", "KS2GSAddStepResultCnt", mArgs)
end

