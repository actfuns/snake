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
CTask.m_sName = "treasureconvoy"
CTask.m_sTempName = "秘宝护送"
inherit(CTask, taskobj.CTask)

local PLAYERTAG = {
    NOTASK = 0,
    HAVETASk = 1,
}

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:Init()
    super(CTask).Init(self)
end

function CTask:TransStringFuncSubmitNpc(pid,npcobj)
    local iType = self:Target()
    local oHD = self:GetHD()
    local oNpc = oHD:GetNpc(iType)
    local sSubmit = ""
    if oNpc then
       	sSubmit = global.oToolMgr:FormatColorString("#submitnpc", {submitnpc = oNpc:Name()})
    end
    return sSubmit
end

function CTask:GetNpcObjByType(npctype)
    local oHD = self:GetHD()
    local oNpc = oHD:GetNpc(npctype)
    return oNpc
end

function CTask:OnAddDone(oPlayer)
    super(CTask).OnAddDone(self, oPlayer)
    self:ChangePlayerTag(PLAYERTAG.HAVETASk)
    local oHD = self:GetHD()
    if oHD then
        oHD:AddTaskDone(oPlayer, self)
        oHD:GS2CTreasureConvoyFlag(oPlayer:GetPid(), 1)
    end
end

function CTask:OtherScript(pid,npcobj,s,mArgs)
    local sCmd = string.match(s,"^([$%a]+)")
    if not sCmd then return end

    local sArgs = string.sub(s, #sCmd+1, -1)
    if sCmd == "CONVOYDONE" then
        local oHD = self:GetHD()
        oHD:ConvoyDone(pid)
    end
end

function CTask:Remove()
    self:ChangePlayerTag(PLAYERTAG.NOTASK)
    local oHD = self:GetHD()
    if oHD then
        local iPid = self:GetOwner()
        oHD:GS2CTreasureConvoyFlag(iPid, 0)
    end
    super(CTask).Remove(self)
end

function CTask:ChangePlayerTag(iTag)
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mInfo = {
            treasureconvoy_tag = iTag or PLAYERTAG.NOTASK
        }
        oPlayer:SyncSceneInfo(mInfo)
    end
end

function CTask:Abandon(oPlayer)
    local oHd = self:GetHD()
    if oHd then
        oHd:RemoveConvoyTask(oPlayer:GetPid())
    end
end

function CTask:GetRewardEnv(oAwardee)
    local mEnv = super(CTask).GetRewardEnv(self, oAwardee)
    local oHd = self:GetHD()
    if oHd then
        local iPid = self:GetOwner()
        local mInfo = oHd:GetPlayerInfo(iPid)
        if mInfo and mInfo.convoy_grade > 0 then
            mEnv.lv = mInfo.convoy_grade
        end
    end
    return mEnv
end

function CTask:GetHD()
	return global.oHuodongMgr:GetHuodong("treasureconvoy")
end