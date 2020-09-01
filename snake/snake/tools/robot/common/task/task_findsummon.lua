--寻宠任务
local taskobj = require("common/task/taskobj")

local CTaskObj = {m_iTaskType = 0}
CTaskObj.__index = CTaskObj
setmetatable(CTaskObj,taskobj)

function CTaskObj:New(iTaskType)
    local o = setmetatable({}, CTaskObj)
    o.m_iTaskType = iTaskType
    return o
end

return CTaskObj
