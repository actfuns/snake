local global = require "global"
local res = require "base.res"
local record = require "public.record"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))


function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "schoolpass"
CTask.m_sTempName = "门派闯关"
inherit(CTask, taskobj.CTeamTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:OtherScript(pid, npcobj, s, mArgs)
    if s == "$looknpc" then
        self:LookNpc(pid, npcobj)
        return true
    elseif s == "$win" then
        self:FightWin(pid, npcobj, mArgs)
        return true
    end
end

function CTask:FightWin(pid, npcobj, mArgs)
    local iRing = self:GetData("ring", 1)
    self:SchoolPassReward(pid, iRing, mArgs)

    local mFilter = self:GetData("filter", {})
    local mExclude = mFilter.exclude or {}
    mExclude[self:GetId()] = 1
    mFilter.exclude = mExclude
    
    self:MissionDone(oNpc)
    global.oSchoolPassHandler:AddNextRingTask(pid, mFilter)
end

function CTask:ValidFight(pid, npcobj, iFight)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oSchoolPassHandler = global.oSchoolPassHandler

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return false
    end

    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
    if not oHuodong then
        return false
    end

    if not oSchoolPassHandler:ValidOwnTask(oPlayer) then
        oNotifyMgr:Notify(pid, oHuodong:GetTextData(1008))
        return false
    end

    if oPlayer:GetMemberSize() + oPlayer:Query("testman", 0) < 3 then
        oNotifyMgr:Notify(pid, oHuodong:GetTextData(1009))
        return false
    end

    if not oHuodong:ValidTeamMemberGrade(oPlayer, true) then
        return false
    end
    
    local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oWar then
        return false
    end
    return true
end

function CTask:LookNpc(pid, npcobj)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    npcobj:do_look(oPlayer)
end

function CTask:TransCountingStr()
    return string.format("(%d/%d)", self:GetData("ring",1), taskdefines.SCHOOLPASS_INFO.ROUND_RINGS)
end

function CTask:Name()
    return super(CTask).Name(self) .. self:TransCountingStr()
end

function CTask:RewardMissionDone(pid, npcobj, mRewardArgs)
end

function CTask:SchoolPassReward(pid, iRing, mArgs)
    if iRing == taskdefines.SCHOOLPASS_INFO.ROUND_RINGS then
        self:TeamReward(pid, 10002, mArgs)
    else
        self:TeamReward(pid, 10001, mArgs)
    end
end

function CTask:TeamReward(iPid, sIdx, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oLeader = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader then
        return
    end
    local iLimit = self:GetRewardLimitByIdx(sIdx)
    local sLimitKey = "schoolpassreward"..sIdx
    local lPlayers = self:GetFighterList(oLeader, mArgs)

    for _,pid in ipairs(lPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        -- 超过80次不给奖励
        if oPlayer:IsTeamLeader() then
            self:RewardLeaderPoint(oPlayer, "schoolpass", "门派闯关", #lPlayers)
        end

        oPlayer.m_oScheduleCtrl:Add(1013)
        local iRewardCnt = oPlayer.m_oToday:Query(sLimitKey, 0)
        if iRewardCnt >= iLimit then
            goto continue
        end
        iRewardCnt = iRewardCnt + 1
        oPlayer.m_oToday:Set(sLimitKey, iRewardCnt)
        oPlayer:MarkGrow(47)

        local mLogData = {}
        mLogData.pid = oPlayer:GetPid()
        mLogData.show_id = oPlayer:GetShowId()
        mLogData.reward = sIdx
        mLogData.rewardcnt = iRewardCnt
        mLogData.task = self:GetId()
        record.user("huodong", "schoolpass_reward", mLogData)

        self:Reward(pid, sIdx, mArgs)
        ::continue::
    end
end

function CTask:LeaveTeam(iPid, iFlag)
    local mFilter = self:GetData("filter", {})
    local mResultCancel = mFilter.resultcancel or {}
    mResultCancel[tostring(iPid)] = 1
    mFilter.resultcancel = mResultCancel
    mFilter.noteamresult = true
    self:SetData("filter", mFilter)

    super(CTask).LeaveTeam(self, iPid, iFlag)
end

function CTask:EnterTeam(iPid, iFlag)
    local mFilter = self:GetData("filter", {})
    local mResultCancel = mFilter.resultcancel or {}
    mResultCancel[tostring(iPid)] = 1
    mFilter.resultcancel = mResultCancel
    self:SetData("filter", mFilter)

    super(CTask).EnterTeam(self, iPid, iFlag)
end

function CTask:GetRewardEnv(oAwardee)
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local mFilter = self:GetData("filter", {})
    local iRing = self:GetData("ring",1)
    return {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
        ring = iRing,
    }
end
 
function CTask:TaskFight(pid, npcobj)
    if not self:ValidFight(pid, npcobj) then
        return
    end

    local iType = npcobj:Type()
    local mData = self:GetTollGateData(iType)
    local iSchool = mData["mirror_school"]

    if iSchool <= 0 or (iSchool > 0 and self:GetData("mirrormonster")) then
        self:Fight(pid, npcobj, iType)
        return
    end

    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
    assert(oHuodong, string.format("schoolpass task not huodong"))

    local iNpc = npcobj:ID()
    local iTask = self:GetId()
    local func = function(mInfo)
        OnTaskFight(pid, iNpc, iTask, mInfo)
    end
    oHuodong:GetMirrorMonsterData(iSchool, func)
end

function CTask:SetMirrorMonsterData(mData)
    if mData then
        self:SetData("mirrormonster", mData)
    end
end

function CTask:GetMirrorMonsterData(mMonsterData, npcobj)
    local mMirrorMonster = self:GetData("mirrormonster")
    if mMirrorMonster then
        return mMirrorMonster
    end
end

function CTask:SetMirrorMonsterAttr(mAttrData, oWar, mData, mMirror, npcobj, bSummon)
    self:SetNormalMonsterGrade(mAttrData, oWar, mData)
    self:SetNormalMonsterAttr(mAttrData, oWar, mData)
    local mMirrorMonster = self:GetData("mirrormonster")
    if mMirrorMonster then
        mAttrData["mirror_school"] = mMirrorMonster["school"]
        mAttrData["name"] = mMirrorMonster["name"]
        mAttrData["grade"] = mMirrorMonster["grade"]
        mAttrData["model_info"] = mMirrorMonster["model_info"]
    else
        print("cg_debug",debug.traceback(""))
        mAttrData["name"] = "神秘高手"
        local mModelInfo = {}
        mModelInfo.shape = 3106
        mModelInfo.weapon = 21202
        mAttrData["model_info"] = mModelInfo
        mAttrData["grade"] = 1
    end
end


function CTask:FillWarStartArgs(mTollgateData, mArgs)
    mArgs = super(CTask).FillWarStartArgs(self, mTollgateData, mArgs)
    
    local iSpeekId = mTollgateData.custom_speek_id or 0
    local mData = res["daobiao"]["fight"][self.m_sName]["custom_speek"][iSpeekId]
    if mData then
        mArgs.custom_speek = mData
    end
    return mArgs
end

function CTask:GetRewardLimitByIdx(sIdx)
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["condition"][1]
    if tonumber(sIdx) == 10001 then
        return mConfig.reward10001_limit
    elseif tonumber(sIdx) == 10002 then
        return mConfig.reward10002_limit
    end
    return 80
end

function OnTaskFight(pid, npcid, taskid, mData)
    local oWorldMgr = global.oWorldMgr
    local oTaskMgr = global.oTaskMgr
    local oNpcMgr = global.oNpcMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oTask = oTaskMgr:GetUserTask(oPlayer, taskid, true)
    if not oTask then return end
    local npcobj = oNpcMgr:GetObject(npcid)
    if not npcobj then return end

    oTask:SetMirrorMonsterData(mData)
    local iType = npcobj:Type()
    oTask:Fight(pid, npcobj, iType)
end

