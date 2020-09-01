local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))

function NewTaskHandler()
    return CTaskHandler:New()
end

CTaskHandler = {}
CTaskHandler.__index = CTaskHandler

function CTaskHandler:New()
    local o = setmetatable({}, self)
    return o
end

function CTaskHandler:DoClickTask(oPlayer, taskid)
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid)
    if not oTask then
        return
    end
    if not oTask:CanDealTask(oPlayer) then
        return
    end

    local oNotifyMgr = global.oNotifyMgr
    local oTeam = oPlayer:HasTeam()
    local iPid = oPlayer:GetPid()
    if oTeam and not oTask:AbleTeamMemberClick(iPid) and not (oTeam:IsLeader(iPid) or oTeam:IsShortLeave(iPid)) then
        oNotifyMgr:Notify(iPid, "您在队伍中，不能进行任务")
        return
    end
    if not oTask:AbleInWarClick(iPid) and oPlayer.m_oActiveCtrl:GetNowWar() then
        --异宝寻物的取消下边这条提示
        if oTask:Type() == 6 and oTask:TaskType() == 2 then
            return
        end
        oNotifyMgr:Notify(iPid, "您在战斗中，不能进行任务")
        return
    end
    if oPlayer:IsFixed() then
        return
    end
    oTask:Click(iPid)
end

function CTaskHandler:DoClickTaskNpc(oPlayer, npcid, taskid)
    local iPid = oPlayer.m_iPid
    local iCurTime = get_time()
    if not oPlayer.m_tmp_ClickTaskNpcCounter or oPlayer.m_tmp_ClickTaskNpcCounter.time ~= iCurTime or oPlayer.m_tmp_ClickTaskNpcCounter.npcid ~= npcid or oPlayer.m_tmp_ClickTaskNpcCounter.taskid ~= taskid then
        oPlayer.m_tmp_ClickTaskNpcCounter = {
            time = iCurTime,
            npcid = npcid,
            taskid = taskid,
            cnt = 1,
        }
    elseif oPlayer.m_tmp_ClickTaskNpcCounter.cnt > 3 then
        -- assert(nil, string.format("task npc click over 3times/sec, pid:%d, taskid:%d", iPid, taskid))
        return
    else
        oPlayer.m_tmp_ClickTaskNpcCounter.cnt = (oPlayer.m_tmp_ClickTaskNpcCounter.cnt or 1) + 1
        -- if oPlayer.m_tmp_ClickTaskNpcCounter.cnt > 3 then
        --     -- 已经不应该处理了
        --     return
        -- end
    end
    -- 考虑到任务点击的操作也许允许战斗中执行，不屏蔽战斗中的点击处理
    local oNpcMgr = global.oNpcMgr
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid)
    if not oTask then
        return
    end
    if not oTask:CanDealTask(oPlayer) then
        return
    end

    local oNpc = oTask:GetNpcObj(npcid)
    if not oNpc then
        return
    end
    if oNpc:Type() == oTask:Target() then
        local bCan = oTask:CanTaskSubmit(oNpc)
        if not bCan then
            -- 与前端确定方案：返回任务失败协议后，前端重新展现上一次Say的内容（恢复到自动执行C2GSTaskEvent前），由于前端未上行Answer协议，故会话还保留
            oPlayer:Send("GS2CSubmitTaskFail", {taskid = taskid, npcid = npcid})
            -- 不可使用oNpc:Say(iPid, global.oToolMgr:GetTextData(2001, {"task_ext"}))，常驻npc会引发前端判断自动点击交付流程
            return
        end
    end
    local bDidEvent = oTask:DoNpcEvent(iPid,npcid)
    if not bDidEvent and not oTask:GetClientObj(npcid) then
        oNpc:do_look(oPlayer)
    end
end

function CTaskHandler:AbandonTask(oPlayer, taskid)
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
    if not oTask then
        return
    end
    oTask:Abandon(oPlayer)
end

local funcStepTask = {
    [gamedefines.TASK_TYPE.TASK_PICK] = "StepPickTask",
    [gamedefines.TASK_TYPE.TASK_USE_ITEM] = "StepItemUseTask",
}

function CTaskHandler:DoStepTask(oPlayer, taskid, iRestStep)
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
    if not oTask then
        return
    end

    local sDealFunc = funcStepTask[oTask:TaskType()]
    if sDealFunc then
        local func = oTask[sDealFunc]
        if not func then
            return
        end
        func(oTask, oPlayer, iRestStep)
    end
end


function CTaskHandler:CallAcceptTask(oPlayer, npcid, taskid)
    local oNpcMgr = global.oNpcMgr
    local oNpc
    local iNpcType = 0
    if npcid and npcid ~= 0 then
        oNpc = oNpcMgr:GetObject(npcid)
        if not oNpc then
            return
        end
        -- TODO ?是否要校验npc的坐标等
        iNpcType = oNpc:Type() or 0
    end
    if not oPlayer.m_oTaskCtrl.m_oAcceptableMgr:IsTaskAcceptable(taskid) then
        return
    end
    local mTaskData = global.oTaskLoader:GetTaskBaseData(taskid)
    local iTaskAcceptNpcType = mTaskData.acceptNpcId or 0
    if iTaskAcceptNpcType ~= iNpcType then
        return
    end
    self:GiveTask(oPlayer, taskid, oNpc)
end

function CTaskHandler:GiveTask(oPlayer, taskid, oNpc)
    local oTask = global.oTaskLoader:CreateTask(taskid)
    if not oTask then
        return
    end
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    local bPass, iErr = oTaskCtrl:CanAddTask(oTask)
    if not bPass then
        baseobj_delay_release(oTask)
        return
    end
    -- PS. 改为在前端实现，主要是因为前端不能在交互中预判二级菜单出现并保持UI不关闭
    -- if oTaskCtrl:ToConfirmAddTask(oTask, oNpc) then
    --     return
    -- end
    oTaskCtrl:DoAddTask(oTask, oNpc)
end

function CTaskHandler:IsTaskVisible(oPlayer, taskid)
    local mCondition = global.oTaskLoader:GetPreCondition(taskid)
    if not mCondition then
        return true
    end
    local iValue = mCondition.grade
    if iValue then
        if oPlayer:GetGrade() < iValue then
            return false, taskdefines.TASK_ERROR.GRADE_LIMIT
        end
    end

    local iValue = mCondition.prelock
    if iValue then
        -- 不记录曾经完成过的任务，前置条件通过中间标记转储，每个前置任务的条件都可以转为对应系统的对应标记，若是任务系统本身，结合任务阶段表，记录玩家当前阶段
        if oPlayer.m_oTaskCtrl:IsTagLocked(iValue) then
            return false, taskdefines.TASK_ERROR.PRE_LOCKED
        end
    end

    local lNeedRoleShapes = mCondition.roleshape
    if lNeedRoleShapes then
        if type(lNeedRoleShapes) == "number" then
            lNeedRoleShapes = {lNeedRoleShapes}
        end
        if table_count(lNeedRoleShapes) and not extend.Table.find(lNeedRoleShapes, oPlayer:GetOriginShape()) then
            return false, taskdefines.TASK_ERROR.ROLE_SHAPE_LIMIT
        end
    end

    local xValue = mCondition.school
    if xValue then
        local lNeedSchools
        if type(xValue) == "number" then
            lNeedSchools = {xValue}
        elseif type(xValue) == "table" then
            lNeedSchools = xValue
        end
        if table_count(lNeedSchools) and not extend.Table.find(lNeedSchools, oPlayer:GetSchool()) then
            return false, taskdefines.TASK_ERROR.SCHOOL_LIMIT
        end
    end
    return true
end

function CTaskHandler:ValidAcceptBaotuTask(oPlayer)
    if oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.BAOTU) then
        return 1015
    end
    if oPlayer.m_oScheduleCtrl:IsFullTimes(1028) then
        return 1016
    end
    return 1
end

function CTaskHandler:TryAcceptBaotuTask(oPlayer, bNotify, mExclude)
    if not global.oToolMgr:IsSysOpen("BAOTU", oPlayer) then
        return
    end
    local iRet = self:ValidAcceptBaotuTask(oPlayer)
    if iRet ~= 1 then
        if bNotify then
            local sMsg = global.oToolMgr:GetTextData(iRet, {"task_ext"})
            global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
        end
        return
    end
    local mTask = table_get_depth(res["daobiao"], {"task", "baotu", "task"})
    local lTask = table_key_list(mTask)
    if mExclude then
        for iExclude, _ in pairs(mExclude) do
            extend.Array.remove(lTask, iExclude)
        end
    end
    local iTask = extend.Random.random_choice(lTask)
    local oTask = global.oTaskLoader:CreateTask(iTask)
    oPlayer.m_oTaskCtrl:DoAddTask(oTask)
end
