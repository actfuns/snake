local global = require "global"
local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))
local res = require "base.res"

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "xuanshang"
CTask.m_sTempName = "悬赏任务"
inherit(CTask, taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:Init()
    super(CTask).Init(self)
    self.m_iScheduleID = 1031
end

function CTask:ValidFight(iPid, npcobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local LIMIT_GRADE = res["daobiao"]["open"]["XUANSHANG"]["p_level"]
    if oPlayer and not oPlayer:IsSingle() and oPlayer:IsTeamLeader() then
        local lMemName = {}
        for _, iPid in ipairs(oPlayer:GetTeamMember()) do
            if iPid ~= oPlayer:GetPid() then
                local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
                if oMember and oMember:GetGrade() < LIMIT_GRADE then
                    table.insert(lMemName, oMember:GetName())
                end
            end
        end

        if #lMemName > 0 then
            local sMsg = table.concat(lMemName, ",")
            sMsg = global.oToolMgr:FormatColorString(self:GetTextData(900014), {role = sMsg})
            oPlayer:NotifyMessage(sMsg)
            return false
        end
    end
    return super(CTask).ValidFight(self, iPid, npcobj)
end

function CTask:OnWarWin(oWar, pid, npcobj, mWarCbArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local lFighterPid = self:GetFighterList(oPlayer, mWarCbArgs)
    if not table_in_list(lFighterPid, self:GetOwner()) then
        return
    end
    super(CTask).OnWarWin(self, oWar, pid, npcobj, mWarCbArgs)
end

function CTask:IsLogTaskWanfa()
    return true
end

function CTask:AfterMissionDone(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iTask = self:GetId()
    oPlayer.m_oScheduleCtrl:Add(self.m_iScheduleID)
    oPlayer.m_oScheduleCtrl:HandleRetrieve(self.m_iScheduleID, 1)
    oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:TaskDone(self)
end

function CTask:GenRewardContent(oPlayer, rewardinfo, mArgs, bPreview)
    local mRewardInfo = table_deep_copy(rewardinfo)
    if oPlayer and oPlayer.m_oTaskCtrl and not mArgs.team_member then
        local iStar = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:GetStar(self:GetId())
        local iItem = 1000 + iStar
        mRewardInfo.item = { iItem }
    end
    return super(CTask).GenRewardContent(self, oPlayer, mRewardInfo, mArgs, bPreview)
end

function CTask:Reward(pid, sIdx, mArgs)
    mArgs.bEffect = true
    super(CTask).Reward(self, pid, sIdx, mArgs)
end

function CTask:GetRewardEnv(oAwardee)
    local mEnv = super(CTask).GetRewardEnv(self, oAwardee)
    mEnv.factor = 1    
    if oAwardee then
        local iOwner = self:GetOwner()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
        if oPlayer then
            local fFactor = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:GetStarFactor(self:GetId())
            mEnv.factor = fFactor
        end
    end
    return mEnv
end

function CTask:MonsterCreateExt(oWar, iMonsterIdx, oNpc)
    local iOwner = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    local result = {}
    if oPlayer and oNpc then
        local iStar = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:GetStar(self:GetId())
        local fFactor = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:GetStarFactor(self:GetId())
        fFactor = math.floor(fFactor * 100)
        result = {
            env = { factor = fFactor , star = iStar}
        }
    end
    return result
end

function CTask:SayText(pid, npcobj, sText, mArgs, iMenuType)
    local iOwner = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if not oPlayer then return end

    local iStar = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:GetStar(self:GetId())
    if iStar >= 3 then
        super(CTask).SayText(self, pid, npcobj, sText, mArgs, iMenuType)
    else
        local iEvent = self:GetEvent(npcobj:ID())
        local mData = self:GetEventData(iEvent)
        if not mData then return end 
        local sFight = mData["answer"][1]
        self:DoScriptCallbackUnit(pid, npcobj, sFight, mArgs)
    end
end