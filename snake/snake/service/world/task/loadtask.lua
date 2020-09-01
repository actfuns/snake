local global = require "global"
local taskdefines = import(service_path("task/taskdefines"))

local mTaskDir = {
    ["test"] = {1,200},
    ["story"] = {10001,29999},
    ["lead"] = {30001,30100},
    ["side"] = {40001,59999},
    ["shimen"] = {61001,61999},
    ["ghost"] = {62000,62010},
    ["schoolpass"] = {62011,62030},
    ["lingxi"] = {62031,62040},
    ["orgtask"] = {62200,62400},
    ["runring"] = {63001, 63050},
    ["yibao"] = {70000,70299},
    ["fuben"] = {73000,73999},
    ["jyfuben"] = {74000,75000},
    ["baotu"] = {80001, 80100},
    ["guessgame"] = {622401, 622402},
    ["xuanshang"] = {90001, 90100},
    ["zhenmo"] = {91000, 91999},
    ["imperialexam"] = {622501, 622502},
    ["treasureconvoy"] = {622601, 622699},
}

-- 组队任务
local mTeamTasks = {
    fuben = true,
    ghost = true,
    schoolpass = true,
    lingxi = true,
    jyfuben = true,
}

-- 可接多条链的任务大分类
local mMultiLinksKind = {
    [taskdefines.TASK_KIND.LEAD] = true,
    [taskdefines.TASK_KIND.BRANCH] = true,
}

local mTaskKindName = {
    [taskdefines.TASK_KIND.TEST] = "test",
    [taskdefines.TASK_KIND.TRUNK] = "story",
    [taskdefines.TASK_KIND.LEAD] = "lead",
    [taskdefines.TASK_KIND.BRANCH] = "side",
    [taskdefines.TASK_KIND.SHIMEN] = "shimen",
    [taskdefines.TASK_KIND.GHOST] = "ghost",
    [taskdefines.TASK_KIND.YIBAO] = "yibao",
    [taskdefines.TASK_KIND.FUBEN] = "fuben",
    [taskdefines.TASK_KIND.SCHOOLPASS] = "schoolpass",
    [taskdefines.TASK_KIND.ORGTASK] = "orgtask",
    [taskdefines.TASK_KIND.LINGXI] = "lingxi",
    [taskdefines.TASK_KIND.GUESSGAME] = "guessgame",
    [taskdefines.TASK_KIND.JYFUBEN] = "jyfuben",
    [taskdefines.TASK_KIND.BAOTU] = "baotu",
    [taskdefines.TASK_KIND.RUNRING] = "runring",
    [taskdefines.TASK_KIND.XUANSHANG] = "xuanshang",
    [taskdefines.TASK_KIND.ZHENMO] = "zhenmo",
    [taskdefines.TASK_KIND.TREASURECONVOY] = "treasureconvoy",
}

function NewTaskLoader()
    return CTaskLoader:New()
end

CTaskLoader = {}
CTaskLoader.__index = CTaskLoader

function CTaskLoader:New()
    local o = setmetatable({}, self)
    return o
end

function CTaskLoader:GetKindName(iKind)
    return mTaskKindName[iKind]
end

function CTaskLoader:GetKindShowName(iKind)
    local res = require "base.res"
    return table_get_depth(res, {"daobiao", "task_type", iKind, "name"})
end

function CTaskLoader:IsTeamTask(taskid)
    local sDir = self:GetDir(taskid)
    return mTeamTasks[sDir]
end

function CTaskLoader:GetDir(taskid)
    for sDir,mPos in pairs(mTaskDir) do
        local iStart,iEnd = table.unpack(mPos)
        if iStart <= taskid and taskid <= iEnd then
            return sDir
        end
    end
end

function CTaskLoader:GetTaskIdRange(sTaskDir)
    local lRange = mTaskDir[sTaskDir]
    if type(lRange) == "table" and #lRange == 2 then
        return table.unpack(lRange)
    end
end

function CTaskLoader:GetTaskBaseData(taskid)
    assert(taskid and taskid > 0, string.format("bad taskid:%s", taskid))
    local res = require "base.res"
    local sDir = self:GetDir(taskid)
    local mData = table_get_depth(res, {"daobiao", "task", sDir, "task", taskid})
    assert(mData, string.format("GetBaseTaskData err, taskid:%s", taskid))
    return mData
end

function CTaskLoader:CreateTask(taskid)
    local sDir = self:GetDir(taskid)
    assert(sDir, "nil taskDir:" .. taskid)
    local sPath = string.format("task/%s/%sbase",sDir,sDir)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("Create Task err:%d %s",taskid,sPath))
    local oTask = oModule.NewTask(taskid)
    return oTask
end

function CTaskLoader:LoadTask(taskid,mArgs)
    local oTask = self:CreateTask(taskid)
    oTask:Load(mArgs)
    return oTask
end

function CTaskLoader:GetPreCondition(taskid)
    local mData = self:GetTaskBaseData(taskid)
    return mData._parsed_precondi
end

function CTaskLoader:GetLinkHeads(sDir)
    -- local sDir = GetKindName(iKind)
    local res = require "base.res"
    local mHeads = table_get_depth(res, {"daobiao", "task", sDir, "taskhead", "head"})
    return mHeads or {}
end

function CTaskLoader:GetLinkIdByHead(sDir, iTaskId)
    local mHeads = self:GetLinkHeads(sDir)
    return mHeads[iTaskId]
end

function CTaskLoader:GetKindLinks(sDir)
    local res = require "base.res"
    local mLinks = table_get_depth(res, {"daobiao", "task", sDir, "taskhead", "link"})
    return mLinks
end

function CTaskLoader:GetLinkInfo(sDir, iLinkId)
    local res = require "base.res"
    local mLinkInfo = table_get_depth(res, {"daobiao", "task", sDir, "taskhead", "link", iLinkId})
    return mLinkInfo
end

function CTaskLoader:GetStoryChapterInfo(iChapter)
    local res = require "base.res"
    return table_get_depth(res, {"daobiao", "task", "story", "story_chapter", iChapter}) or {}
end

function CTaskLoader:CanKindMultiLinks(iKind)
    return mMultiLinksKind[iKind]
end
