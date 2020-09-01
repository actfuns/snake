local global = require "global"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))
local rewardmonitor = import(service_path("rewardmonitor"))

function NewTaskMgr()
    return CTaskMgr:New()
end

CTaskMgr = {}
CTaskMgr.__index = CTaskMgr
inherit(CTaskMgr, logic_base_cls())

function CTaskMgr:New()
    local o = super(CTaskMgr).New(self)
    o.m_lqPlayerTodos = extend.Queue.create()
    o.m_oTaskRewardMonitor = rewardmonitor.CTaskRewardMonitor:New()
    o.m_oStoryRewardMonitor = rewardmonitor.CStoryTaskRewardMonitor:New()
    return o
end

function CTaskMgr:Release()
    self.m_lqPlayerTodos = nil
    baseobj_safe_release(self.m_oTaskRewardMonitor)
    self.m_oTaskRewardMonitor = nil
    baseobj_safe_release(self.m_oStoryRewardMonitor)
    self.m_oStoryRewardMonitor = nil
    super(CTaskMgr).Release(self)
end

function CTaskMgr:OnTryTeamWarWin(oTask, oWar, pid, npcobj, mWarCbArgs)
    -- 战斗特殊规则：如果队员的任务和队长一样，那么同样推进其任务
    local iType = oTask:TaskType()
    local iTaskid = oTask:GetId()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    -- 组队任务
    if oTask:IsTeamTask() then
        local oTeam = oTask:GetTeamObj()
        if not oTeam then
            baseobj_delay_release(oTask)
            return
        end
        self:DealingFightMemTaskWarWin(oTask, oPlayer, oWar, npcobj, mWarCbArgs)
        return
    end
    -- 单人任务
    local lMem = {}
    if extend.Table.find({gamedefines.TASK_TYPE.TASK_ANLEI, gamedefines.TASK_TYPE.TASK_NPC_FIGHT}, iType) then
        lMem = oTask:GetFighterList(oPlayer, mWarCbArgs)
    end
    for _, iMem in ipairs(lMem) do
        local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
        if oMem then
            local oMemTask = oMem.m_oTaskCtrl:GetTask(iTaskid)
            if oMemTask then
                self:DealingFightMemTaskWarWin(oMemTask, oMem, oWar, npcobj, mWarCbArgs)
            end
        end
    end
end

function CTaskMgr:DealingFightMemTaskWarWin(oMemTask, oMem, oWar, npcobj, mWarCbArgs)
    local iMem = oMem:GetPid()
    oMemTask:OnDealMemberSameTaskWarWin(oWar, iMem, npcobj, mWarCbArgs)
end

function CTaskMgr:GetUserTask(oPlayer, iTaskid, bLeader)
    local iPid = oPlayer:GetPid()
    if global.oTaskLoader:IsTeamTask(iTaskid) then
        local oTeam = oPlayer:HasTeam()
        if not oTeam then
            return nil
        end
        if bLeader then
            if not oTeam:IsLeader(iPid) then
                return nil
            end
        end
        local oTask = oTeam:GetTask(iTaskid)
        if oTask then
            local mOwners = oTask:GetOwners()
            if mOwners[iPid] then
                return oTask
            end
        end
    else
        return oPlayer.m_oTaskCtrl:GetTask(iTaskid)
    end
end

function CTaskMgr:DealMissionDone(oTask, iPid, npcobj, mArgs)
    if oTask:IsDone() then
        return
    end
    if oTask:IsTimeOut() then
        oTask:TimeOut()
        return
    end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:RecordAnalyContent()
    end

    oTask:SetDone()
    oTask:OnMissionDone(iPid)
    -- 摘除任务 TODO 暂等TeamTask逻辑分出去再改为Detach
    oTask:Remove()
    local mData = oTask:GetTaskData()
    -- 完成任务后触发器
    local s = mData["missiondone"]
    oTask:DoScript(iPid, npcobj, s, mArgs)
    oTask:RewardMissionDone(iPid, npcobj, mArgs)
    oTask:AfterMissionDone(iPid)

    oTask:LogTaskWanfaInfo(oPlayer, 2)
    oTask:LogAnalyInfo(oPlayer)
    if oPlayer then
        oPlayer:ClearAnalyContent()
    end

    baseobj_delay_release(oTask)
end

function CTaskMgr:GetStoryTaskRewardMonitor()
    return self.m_oStoryRewardMonitor
end

function CTaskMgr:GetTaskRewardMonitor()
    return self.m_oTaskRewardMonitor
end

function CTaskMgr:ForeachAllTask(oPlayer, fDealFunc, ...)
    local mAllTasks = oPlayer.m_oTaskCtrl:TaskList()
    for _, iTaskid in pairs(table_key_list(mAllTasks)) do
        local oTask = mAllTasks[iTaskid]
        safe_call(fDealFunc, oPlayer, oTask, ...)
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local mAllTasks = oTeam:TaskList()
        for _, iTaskid in pairs(table_key_list(mAllTasks)) do
            local oTask = mAllTasks[iTaskid]
            if oTask then
                safe_call(fDealFunc, oPlayer, oTask, ...)
            end
        end
    end
end

function CTaskMgr:ResetPosForAnlei(oPlayer)
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    local iPid = oPlayer:GetPid()
    oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:DelPos(iPid)
end

function CTaskMgr:UpdatePosForAnlei(oPlayer, iMapId, mPosInfo, mExtra)
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    -- 改变AnleiCtrl的设定，全部任务注册同一个ctrl，更新坐标为共通数据，匹配到第一个可以触发的暗雷任务直接break
    oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:UpdateTriggerAnLei(oPlayer, iMapId, mPosInfo, mExtra)
end

function CTaskMgr:RunBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    self:DelTimeCb(sBatchName)
    self:AddTimeCb(sBatchName, 1, function()
        _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    end)
end

function _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    local oTaskMgr = global.oTaskMgr
    oTaskMgr:DelTimeCb(sBatchName)
    if fTickable() then
        oTaskMgr:AddTimeCb(sBatchName, iTickPeriod, function()
            _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
        end)
        fDeal()
    end
end

function CTaskMgr:TryRecLinkDone(oPlayer, oTask)
    -- 记录任务链完成（因为
    --  1.奖励经验触发升级会再次轮询任务发放，
    --  2.任务在missiondone中解任务锁导致事件触发MakeAcceptable将任务重新放回可接列表，
    -- 所以要先记录）
    if not oTask:IsDone() then
        return
    end
    if not oTask:TmpGetNext() then
        oPlayer.m_oTaskCtrl:RecLinkDone(oTask:GetDirName(), oTask:GetLinkId())
    end
end

-- 放弃的任务，备份断点到可接
function CTaskMgr:TryBackupAcceptable(oPlayer, oTask)
    if oTask:IsDone() then
        return
    end
    oPlayer.m_oTaskCtrl.m_oAcceptableMgr:ToBackupAbandonTaskData(oPlayer, oTask)
end

-- 这些功能可能会恢复，先留着
-- function CTaskMgr:AppendTodo(oTask, iTodo, npcid, mArgs)
--     if iTodo == taskdefines.TASK_ACTION.RELEASE then
--         if oTask.m_iTodoRelease then
--             return
--         end
--         oTask.m_iTodoRelease = true
--     end
--     extend.Queue.enqueue(self.m_lqPlayerTodos, {task = oTask, todo = iTodo, npcid = npcid, args = mArgs})
-- end

-- function CTaskMgr:ApplyTodos()
--     while true do
--         local mTodoBlk = extend.Queue.dequeue(self.m_lqPlayerTodos)
--         if not mTodoBlk then
--             break
--         end
--         self:DealTodo(mTodoBlk)
--     end
-- end

-- function CTaskMgr:DealTodo(mTodoBlk)
--     local iTodo = mTodoBlk.todo
--     if not iTodo then
--         return
--     end
--     local oTask = mTodoBlk.task
--     if not oTask then
--         return
--     end
--     local npcid = mTodoBlk.npcid
--     local mArgs = mTodoBlk.args

--     if iTodo == taskdefines.TASK_ACTION.RELEASE then
--         baseobj_delay_release(oTask)
--     -- elseif iTodo == taskdefines.TASK_ACTION.ADD then
--     --     local iPid = mTodoBlk.pid
--     --     local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
--     --     if not oPlayer then
--     --         return
--     --     end
--     --     oPlayer:AddTask(oTask, npcid)
--     -- elseif iTodo == taskdefines.TASK_ACTION.REMOVE then
--     end
-- end
