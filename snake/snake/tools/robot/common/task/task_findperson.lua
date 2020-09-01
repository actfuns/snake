--寻人任务
local taskobj = require("common/task/taskobj")

local CTaskObj = {m_iTaskType = 0}
CTaskObj.__index = CTaskObj
setmetatable(CTaskObj,taskobj)

function CTaskObj:New(iTaskType)
    local o = setmetatable({}, CTaskObj)
    o.m_iTaskType = iTaskType
    return o
end

function CTaskObj:GS2CAutoFindPath(oPlayer,mTaskInfoTbl,mArgs)
    oPlayer:run_cmd("C2GSTaskEvent",{npcid = mArgs.npcid,taskid = mTaskInfoTbl.taskid})
end

function CTaskObj:GS2CDialog(oPlayer, mTask, mArgs)
    local iSession = mArgs.sessionidx
    oPlayer:run_cmd("C2GSCallback", {sessionidx = iSession, answer=1})
end

return CTaskObj
