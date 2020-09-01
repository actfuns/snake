local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

local FIRSTSTAGE_TASK_ID = 622501

CTask = {}
CTask.__index = CTask
CTask.m_sName = "imperialexam"
CTask.m_sTempName = ""
inherit(CTask, taskobj.CTask)

function CTask:Init()
    super(CTask).Init(self)
    local oHuodong = self:GetHuodong()
    self.m_iTotal = oHuodong:GetTotalRound()
end


function CTask:ConfigTimeOut()
    local oHuodong = self:GetHuodong()
    local iTimeout = oHuodong:GetFirststageClosetime() - self:GetCreateTime()
    self:SetTimer(iTimeout)
end

function CTask:TrueDoClick(oPlayer)
    self:FindHuodongTempNpc()
end

function CTask:GetHuodong()
    return global.oHuodongMgr:GetHuodong("imperialexam")
end

function CTask:GetTotalRound()
    return self.m_iTotal
end

function CTask:GetCurRound()
    local oHuodong = self:GetHuodong()
    return oHuodong:GetCurRound(self:GetOwner())
end

function CTask:TransFuncTable()
    local mTable = super(CTask).TransFuncTable(self)
    mTable.total = "GetTotalRound"
    mTable.round = "GetCurRound"
    return mTable
end

function CTask:EndOneQuestion()
    local iCurRound = self:GetCurRound()
    if iCurRound > self:GetTotalRound() then
        self:MissionDone()
    else
        self:Refresh({targetdesc = true})
    end
end

function CTask:Abandon()
    super(CTask).Abandon(self)
end

function CTask:FindHuodongTempNpc()
    local iCurRound = self:GetCurRound()
    local oHuodong = self:GetHuodong()
    oHuodong:FindPathToNpc(self:GetOwner(), iCurRound)
end
    
function CTask:AchieveFirstStage()
    local oHuodong = self:GetHuodong()
    oHuodong:AchieveFirstStage(self:GetOwner())
end

function CTask:OnLogin(oPlayer, bReEnter)
    local oHuodong = self:GetHuodong()
    if not oHuodong:IsFirstStage() then
        self:Abandon()
    else
        local iCurRound = self:GetCurRound()
        if iCurRound == 0 then
            self:Abandon()
        end
    end
end