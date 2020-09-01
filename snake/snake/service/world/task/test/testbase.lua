--import module

local global = require "global"
local taskobj = import(service_path("task/taskobj"))

CTask = {}
CTask.__index = CTask
CTask.m_sName = "test"
CTask.m_sTempName = "测试任务"
inherit(CTask,taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    local iLinkId = global.oTaskLoader:GetLinkHeads(self.m_sName)[taskid]
    if iLinkId then
        o:SetLinkId(iLinkId)
    end
    return o
end

-- RecLinkDone操作参考sidebase


function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end
