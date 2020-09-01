local global = require "global"

local handleteam = import(service_path("team/handleteam"))
local taskdefines = import(service_path("task/taskdefines"))


Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

function GetTarget(oMaster, iTargetPid)
    if not iTargetPid or iTargetPid == 0 then
        return oMaster
    else
        return global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    end
end


Opens.addtask = true
Helpers.addtask={
    "增加任务",
    "addtask 目标pid(0为自己) 任务编号",
    "addtask 0 101"
}
function Commands.addtask(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if not taskid then
        return
    end
    taskid = tonumber(taskid)
    if not taskid then
        return
    end
    local oTask = global.oTaskLoader:CreateTask(taskid)
    if not oTask then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if oTask:IsTeamTask() then
        oNotifyMgr:Notify(oMaster:GetPid(), "添加失败，添加组队任务使用addteamtask")
        return
    end

    --处理gm添加任务引起的报错
    local sDirName = oTask.m_sName
    local iLinkId = global.oTaskLoader:GetLinkIdByHead(sDirName, taskid) or global.oTaskLoader:GetTaskBaseData(taskid).linkid
    if iLinkId then
        local oAcceptableMgr = oMaster.m_oTaskCtrl.m_oAcceptableMgr
        if oAcceptableMgr:IsLinkDone(sDirName, iLinkId) then
            local mRecorder = table_get_set_depth(oAcceptableMgr.m_mDoneLinks, {sDirName})
            if mRecorder[iLinkId] then
                mRecorder[iLinkId] = nil
                oAcceptableMgr:Dirty()
            end
            
            local oRewardMonitor = global.oTaskMgr:GetStoryTaskRewardMonitor()
            if oRewardMonitor then
                local iPid = oMaster:GetPid()
                local sTaskId = tostring(taskid)
                local mRecorder = table_get_depth(oRewardMonitor.m_mRecord, {iPid, sDirName})
                if mRecorder[sTaskId] then
                    mRecorder[sTaskId] = nil
                end
            end
        end
    end

    if not oTarget:AddTask(oTask) then
        baseobj_delay_release(oTask)
        oMaster:NotifyMessage(string.format("角色[%s]添加任务失败", oTarget:GetPid()))
        return
    end
    oMaster:NotifyMessage(string.format("角色[%s]添加任务完成", oTarget:GetPid()))
end

Opens.addteamtask = true
Helpers.addteamtask={
    "增加组队任务",
    "addteamtask 目标pid(0为自己) 任务编号",
    "addteamtask 0 101"
}
function Commands.addteamtask(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if not taskid then
        return
    end
    local oTask = global.oTaskLoader:CreateTask(taskid)
    if not oTask then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if not oTask:IsTeamTask() then
        oNotifyMgr:Notify(oMaster:GetPid(), "添加失败，非队伍任务类型")
        return
    end
    handleteam.AddTask(oTarget:GetPid(), oTask)
    oMaster:NotifyMessage("操作完成")
end

Opens.cleartask = true
Helpers.cleartask={
    "清除任务",
    "cleartask 目标pid(0为自己)",
    "cleartask 0 1",
}
function Commands.cleartask(oMaster, iTargetPid, iRecordKeep)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    for taskid,oTask in pairs(oTarget.m_oTaskCtrl.m_List) do
        oTask:FullRemove()
    end
    local oTeam = global.oTeamMgr:GetTeamByPid(oTarget:GetPid())
    if oTeam then
        for taskid, oTask in pairs(oTeam.m_mTask) do
            oTask:FullRemove()
        end
    end
    if not iRecordKeep or iRecordKeep == 0 then
        global.oTaskMgr.m_oStoryRewardMonitor:ClearPlayerRecord(oTarget:GetPid())
        global.oTaskMgr.m_oTaskRewardMonitor:ClearPlayerRecord(oTarget:GetPid())
    end
    oMaster:NotifyMessage("操作完成")
end

Opens.doneatask = true
Helpers.doneatask = {
    "完成一项任务",
    "doneatask 目标pid(0为自己) 任务id",
    "doneatask 0 10061",
}
function Commands.doneatask(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end

    if not taskid then
        local iTaskType = taskdefines.TASK_KIND.TRUNK
        local oTask = oTarget.m_oTaskCtrl:GotTaskKind(iTaskType)
        if oTask then
            taskid = oTask:GetId()
        end
    end

    local oTask = global.oTaskMgr:GetUserTask(oTarget, taskid, false)
    local pid = oTarget:GetPid()
    if oTask then
        if oTask:Type() == taskdefines.TASK_KIND.GHOST then
            local iRing = oTask:GetData("ring", 1)
            local iNpctype = oTask:Target()
            local oTargetNpc = oTask:GetNpcObjByType(oTask:Target())
            local iEvent = oTask:GetEvent(oTargetNpc:ID())
            local mEvent = oTask:GetEventData(iEvent)
            if not mEvent then
                oMaster:NotifyMessage("无法用指令完成此任务")
                return
            end
            oTask:DoScript(pid, oTargetNpc, mEvent["look"])
            local oWar = oTarget.m_oActiveCtrl:GetNowWar()
            if oWar then
                oWar:TestCmd("warend", pid,{})
                oMaster:NotifyMessage(string.format("完成此任务的战斗(第%d环)", iRing))
            else
                oMaster:NotifyMessage(string.format("此任务无战斗(第%d环)", iRing))
            end
            return
        else
            oTask:MissionDone()
            oMaster:NotifyMessage("完成此任务")
        end
    else
        oMaster:NotifyMessage("没有此任务")
    end
end

Opens.donekindtask = true
Helpers.donekindtask = {
    "完成某类任务",
    "donekindtask",
}
function Commands.donekindtask(oMaster, iKind)
    local oTask = oMaster.m_oTaskCtrl:GotTaskKind(iKind)
    if oTask then
        local iTaskid = oTask:GetId()
        Commands.doneatask(oMaster, oMaster:GetPid(), iTaskid)
    else
        local oTeam = oMaster:HasTeam()
        if oTeam then
            oTask = oTeam:GetTaskByType(iKind)
            if oTask then
                local iTaskid = oTask:GetId()
                Commands.doneatask(oMaster, oMaster:GetPid(), iTaskid)
                return
            end
        end
        oMaster:NotifyMessage("没有该类型任务")
    end
end

Opens.borntask = false
Helpers.borntask={
    "领取出生任务",
    "borntask 目标pid(0表示自己)",
    "borntask 0",
}
function Commands.borntask(oMaster, iTargetPid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    oTarget:InitNewRoleTask()
    oMaster:NotifyMessage("操作完成")
end

Opens.removeatask = true
Helpers.removetask = {
    "移除任务",
    "removeatask 目标pid(0表示自己) taskid",
    "removeatask 0 10061",
}
function Commands.removeatask(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local oTaskCtrl = oTarget.m_oTaskCtrl
    local oTask = oTaskCtrl.m_List[taskid]
    if oTask then
        oTask:FullRemove()
    end
    oMaster:NotifyMessage("操作完成")
end

Opens.showtask = false
Helpers.showtask={
    "查看任务详细数据",
    "showtask 目标pid(0表示自己) taskid",
    "showtask 0 30094",
}
function Commands.showtask(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local oTask = global.oTaskMgr:GetUserTask(oTarget, taskid)
    oMaster:NotifyMessage(string.format("目标玩家[%s]的任务[%d]内容：%s", iTargetPid, taskid, ConvertTblToStr(oTask)))
end

Opens.listalltask = true
Helpers.listalltask={
    "列出全部任务",
    "listalltask 目标pid(0表示自己)",
    "listalltask 0",
}
function Commands.listalltask(oMaster, iTargetPid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local taskids = ""
    for taskid,oTask in pairs(oTarget.m_oTaskCtrl.m_List) do
        if #taskids == 0 then
            taskids = taskids .. taskid
        else
            taskids = taskids .. ", " .. taskid
        end
    end
    if #taskids == 0 then
        taskids = "无"
    end
    local oTeam = global.oTeamMgr:GetTeamByPid(oTarget:GetPid())
    local teamtaskids = ""
    if oTeam then
        for taskid, oTask in pairs(oTeam.m_mTask) do
            if #teamtaskids == 0 then
                teamtaskids = teamtaskids .. taskid
            else
                teamtaskids = teamtaskids .. ", " .. taskid
            end
        end
        if #teamtaskids == 0 then
            teamtaskids = "无"
        end
    else
        teamtaskids = "无队伍"
    end
    local sMsg = "所有任务ID：" .. taskids .. "\n组队任务：" .. teamtaskids
    oMaster:NotifyMessage(sMsg)
end

Opens.shimenweek = false
Helpers.shimenweek={
    "设置师门当日环数",
    "shimenweek 目标pid(0为自己) 环数（0或空 表示清除）",
    "shimenweek 0 2"
}
function Commands.shimenweek(oMaster, iTargetPid, iRing)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if iRing then
        if iRing == 0 then
            iRing = nil
        elseif iRing < 0 then
            global.oNotifyMgr:Notify(oMaster:GetPid(), "参数应为非负整数或空")
            return
        end
    end
    oTarget.m_oWeekMorning:Set("shimen_done", iRing)
    global.oNotifyMgr:Notify(oMaster:GetPid(), "设置完成")
end

Opens.doneashimen = false
Helpers.doneashimen = {
    "完成师门",
    "doneashimen 目标pid(0为自己)",
    "doneashimen 0",
}
function Commands.doneashimen(oMaster, iTargetPid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local iPid = oMaster:GetPid()
    for taskid, oTask in pairs(oMaster.m_oTaskCtrl.m_List) do
        if oTask:Type() == taskdefines.TASK_KIND.SHIMEN then
            oTask:MissionDone()
            oMaster:NotifyMessage("完成此任务")
            return
        end
    end
    oMaster:NotifyMessage("没有此任务")
end

Opens.newacceptable = false
Helpers.newacceptable={
    "新增一个可接任务(不备份当前任务信息)",
    "newacceptable 目标pid(0为自己) 任务id",
    "newacceptable 0 100",
}
function Commands.newacceptable(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    oTarget.m_oTaskCtrl.m_oAcceptableMgr:SetSingleTaskAcceptable(taskid, true)
    oTarget.m_oTaskCtrl.m_oAcceptableMgr:MakeAcceptable()
    oTarget.m_oTaskCtrl.m_oAcceptableMgr:SendAcceptable()
    oMaster:NotifyMessage("操作完成")
end

Opens.delacceptable = false
Helpers.delacceptable={
    "删除一个可接任务",
    "delacceptable 目标pid(0为自己) 任务id(-1:所有记录)",
    "delacceptable 0 100",
}
function Commands.delacceptable(oMaster, iTargetPid, taskid)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local oAcceptableMgr = oTarget.m_oTaskCtrl.m_oAcceptableMgr
    if taskid == -1 then
        oAcceptableMgr:ClearAll()
    else
        oAcceptableMgr:UnsetSingleTaskAcceptable(taskid)
    end
    oAcceptableMgr:MakeAcceptable()
    oAcceptableMgr:SendAcceptable()
    oMaster:NotifyMessage("操作完成")
end

Opens.linkdone = true
Helpers.linkdone={
    "记录任务链完成",
    "linkdone 目标pid(0为自己) 任务类型(文字或编号) 链编号(-1为当前全部)",
    "linkdone 0 side 1",
}
function Commands.linkdone(oMaster, iTargetPid, xKind, iLinkId)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if not xKind then
        oMaster:NotifyMessage(string.format("参数：分类名/分类id 链id/-1表示全部链"))
        return
    end
    if type(xKind) == "number" then
        xKind = global.oTaskLoader:GetKindName(xKind)
    end
    local mLinks = global.oTaskLoader:GetKindLinks(xKind)
    if not iLinkId then
        iLinkId = 0
    end
    local function DoRecLinkDone(oMaster, sDirName, iLinkId)
        oMaster.m_oTaskCtrl:RecLinkDone(sDirName, iLinkId)
        local iHeadTaskid = table_get_depth(global.oTaskLoader:GetLinkInfo(sDirName), {iLinkId, "head"})
        if iHeadTaskid then
            oMaster.m_oTaskCtrl.m_oAcceptableMgr:UnsetSingleTaskAcceptable(iHeadTaskid)
        end
        for iTaskid, mSaveData in pairs(oMaster.m_oTaskCtrl.m_oAcceptableMgr.m_mRecAcceptableTask) do
            if type(mSaveData) == "table" then
                if table_get_depth(mSaveData, {"m_mData", "linkid"}) == iLinkId and global.oTaskLoader:GetDir(iTaskid) == sDirName then
                    oMaster.m_oTaskCtrl.m_oAcceptableMgr:UnsetSingleTaskAcceptable(iTaskid)
                end
            end
        end
    end
    if iLinkId < 0 then
        for iLinkId, _ in pairs(mLinks) do
            DoRecLinkDone(oMaster, xKind, iLinkId)
        end
        oMaster:NotifyMessage(string.format("任务%s分类的全部链[%s]记录完成", xKind, table.concat(table_key_list(mLinks), ",")))
    else
        if not mLinks[iLinkId] then
            oMaster:NotifyMessage(string.format("任务%s分类的链[%d]不存在", xKind, iLinkId))
            return
        end
        DoRecLinkDone(oMaster, xKind, iLinkId)
        oMaster:NotifyMessage(string.format("任务%s分类的链[%d]记录完成", xKind, iLinkId))
    end
    oMaster.m_oTaskCtrl.m_oAcceptableMgr:MakeAcceptable()
    oMaster.m_oTaskCtrl.m_oAcceptableMgr:SendAcceptable()
end

Opens.shimenring = false
Helpers.shimenring = {
    "门派任务环数",
    "shimenring 目标pid(0为自己) 环数",
    "shimenring 0 10"
}
function Commands.shimenring(oMaster, iTargetPid, iRing)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local iTaskType = taskdefines.TASK_KIND.SHIMEN
    local oNotifyMgr = global.oNotifyMgr
    local oTask = oTarget.m_oTaskCtrl:GotTaskKind(iTaskType)
    if not oTask then
        oMaster:NotifyMessage("没有门派修行任务")
        return
    end
    if not iRing then
        return
    end
    iRing = oTask:GetNextRing(iRing - 1)
    oTask:SetData("Ring",iRing)
    oTask:Refresh()
    oMaster:NotifyMessage("操作完成")
end

Opens.shimenday = false
Helpers.shimenday={
    "设置师门当日环数",
    "shimenday 目标pid(0为自己) 环数（0表示满次数,1表示清空）",
    "shimenday 0 2"
}
function Commands.shimenday(oMaster, iTargetPid, iRing)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local oTaskCtrl = oTarget.m_oTaskCtrl
    if not iRing then
        iRing = 0
    end
    if iRing > 0 then
        oTarget.m_oTodayMorning:Set("perfect_shimen", nil)
    else
        iRing = 1 + taskdefines.SHIMEN_INFO.LIMIT_RINGS
    end

    global.oShimenMgr:RecordShimenTodayDoneRing(oTarget, iRing - 1)
    local oHasTask = oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.SHIMEN)
    if oHasTask then
        if iRing > taskdefines.SHIMEN_INFO.LIMIT_RINGS then
            oHasTask:FullRemove()
        else
            oHasTask:SetCurRing(iRing)
            oHasTask:Refresh()
        end
    else
        if iRing <= taskdefines.SHIMEN_INFO.LIMIT_RINGS then
            local taskid = oTaskCtrl:AddShimenTask()
            if not taskid then
                global.oNotifyMgr:Notify(oMaster:GetPid(), string.format("门派修行任务无法发放第%d环", iRing))
                return
            end
        end
    end

    local iDoneRing = global.oShimenMgr:GetShimenTodayDoneRing(oMaster)
    global.oNotifyMgr:Notify(oMaster:GetPid(), string.format("设置完成，已完成%d环", iDoneRing))
end

Opens.yibaonew = false
Helpers.yibaonew={
    "重新领异宝任务",
    "yibaonew 目标pid(0为自己) 是否归零再发",
    "yibaonew 0 [1]",
}
function Commands.yibaonew(oMaster, iTargetPid, iReNew)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if iReNew and iReNew > 0 then
        oTarget.m_oTodayMorning:Set("yibao_times", nil)
        oTarget.m_oTodayMorning:Set("yibao_help_explore_times", nil)
        oTarget.m_oTodayMorning:Set("yibao_help_gather_times", nil)
        global.oTaskMgr.m_oTaskRewardMonitor:ClearRecordByType(oTarget:GetPid(), "yibao")
    end
    if iReNew == 2 then
        oMaster:NotifyMessage("已将今日异宝领取次数归零")
        return
    end
    global.oYibaoMgr:ClearTasks(oTarget)
    global.oYibaoMgr:NewTasks(oTarget)
    global.oYibaoMgr:TouchSubTasks(oTarget)
    oMaster:NotifyMessage("操作完成")
end

Opens.everydaytask = false
Helpers.everydaytask = {
    "每日任务",
    "everydaytask 目标pid(0为自己) [cmd]",
    "everydaytask 0 new等参数",
}
function Commands.everydaytask(oMaster, iTargetPid, cmd, mArgs)
    local sHelpMsg = [[参数：
new：重新领任务
done：完成某任务 {id = 1}
reward: 领取某完成任务的奖励 {id = 1}
]]
    if not cmd or cmd == "" then
        oMaster:NotifyMessage(sHelpMsg)
        return
    end
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if cmd == "new" then
        oTarget.m_oTaskCtrl.m_oEverydayCtrl:ReNew()
        oTarget.m_oTaskCtrl.m_oEverydayCtrl:GS2CAllEverydayTaskInfo()
    elseif cmd == "done" then
        local iETId = mArgs.id
        local oEverydayCtrl = oTarget.m_oTaskCtrl.m_oEverydayCtrl
        local oETask = oEverydayCtrl:GetTask(iETId)
        if not oETask then
            oMaster:NotifyMessage("其没有这个任务")
            return
        end
        local iMax = oETask:Max()
        oETask:SetCount(iMax, iMax)

        local lUpdateETs = {iETId}
        local lSpUpdated = oEverydayCtrl:RecheckSpTasks()
        if lSpUpdated then
            list_combine(lUpdateETs, lSpUpdated)
        end
        oEverydayCtrl:GS2CUpdateEverydayTasks(lUpdateETs)
    elseif cmd == "reward" then
        local iETId = mArgs.id
        local oEverydayCtrl = oTarget.m_oTaskCtrl.m_oEverydayCtrl
        oEverydayCtrl:RewardTask(oMaster, iETId)
    else
        oMaster:NotifyMessage(sHelpMsg)
        return
    end
    oMaster:NotifyMessage("操作完成")
end

Opens.ghostring = false
Helpers.ghostring = {
    "设置金刚伏魔环数",
    "ghostring 目标pid(0为自己) 环数",
    "ghostring 0 10",
}
function Commands.ghostring(oMaster, iTargetPid, val)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if type(val) ~= "number" then return end

    local oTeam = oTarget:HasTeam()
    if not oTeam then
        oNotifyMgr:Notify(oMaster:GetPid(), "请先组队")
        return
    end

    local oTask = oTeam:GetTaskByType(5)
    if not oTask then
        oNotifyMgr:Notify(oMaster:GetPid(), "没有金刚伏魔")
        return
    end

    oTask:SetData("ring", val)
    local sMsg = string.format("金刚伏魔环数为%d", val)
    oTask:Refresh()
    oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
end

Opens.ghostbase = false
Helpers.ghostbase = {
    "设置今日无双倍金刚伏魔次数",
    "ghostbase 目标pid(0为自己) 次数",
    "ghostbase 0 10",
}
function Commands.ghostbase(oMaster, iTargetPid, val)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if type(val) ~= "number" then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    oTarget.m_oTodayMorning:Set("ghost_base", val)
    local sMsg = string.format("设置今日无双倍金刚伏魔次数为%d", val)
    oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
end

Opens.ghostbase = false
Helpers.ghostbase = {
    "设置目标的当前双倍点数",
    "ghostbase 目标pid(0为自己 次数",
    "ghostbase 0  10" 
}
function Commands.ghostdouble(oMaster,iTargetPid,val)
    local oTarget = GetTarget(oMaster,iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]当前不在线",iTargetPid))
        return
    end
    if type(val) ~= "number" then
        return
    end
    local iCurPoint = oTarget.m_oBaseCtrl:GetDoublePoint()
    local iAdd = val - iCurPoint
    oTarget.m_oBaseCtrl:AddDoublePoint(iAdd)
    local oState = oTarget.m_oStateCtrl:GetState(1004)
    if oState then
        oState:Refresh(oTarget:GetPid())
    end 
    global.oNotifyMgr:Notify(oMaster:GetPid(),"指令执行成功")
end

Opens.ghostrun = false
Helpers.ghostrun = {
    "不停金刚伏魔",
    "ghostrun 目标pid(0为自己) 是否开启",
    "ghostrun 0 1",
}
function Commands.ghostrun(oMaster, iTargetPid, iOpen)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local sMsg
    if iOpen == 1 then
        sMsg = "开启无限金刚伏魔模式"
        oTarget.m_bTestGhostRun = true
    else
        sMsg = "关闭无限金刚伏魔模式"
        oTarget.m_bTestGhostRun = false
    end
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
end

Opens.chapterop = false
Helpers.chapterop = {
    "主线章节测试指令",
    "chapterop 目标pid(0为自己) sOrder xArgs",
    "chapterop 0 [full 1 | reset]",
}
function Commands.chapterop(oMaster, iTargetPid, sOrder, xArgs)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    oTarget.m_oTaskCtrl:TestChapterOp(oTarget, sOrder, xArgs)
    oMaster:NotifyMessage("操作完成")
end

Opens.fuben = false
Helpers.fuben = {
    "开副本",
    "fuben 目标pid(0为自己) iFuben",
    "fuben 0 10001",
}
function Commands.fuben(oMaster, iTargetPid, iFuben)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    global.oFubenMgr:TryStartFuben(oTarget, iFuben)
    oMaster:NotifyMessage("操作完成")
end

Opens.runring = true
Helpers.runring = {
    "跑环",
    "runring 目标pid(0为自己) cmd",
    "runring 0 reset_acc",
}
function Commands.runring(oMaster, iTargetPid, sCmd, mArgs)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local iPid = oMaster:GetPid()
    global.oRunRingMgr:TestOp(oMaster, oTarget, sCmd, mArgs)
end

Opens.xuanshang = true
Helpers.xuanshang = {
    "悬赏",
    "xuanshang 0 cmd",
    "xuanshang 0 101",
}
function Commands.xuanshang(oMaster, iTargetPid, sCmd, mArgs)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local iPid = oMaster:GetPid()
    oTarget.m_oTaskCtrl.m_oXuanShangCtrl:TestOp(oMaster, oTarget, sCmd, mArgs)
end

Opens.zhenmo = true
Helpers.zhenmo = {
    "悬赏",
    "zhenmo 0 cmd",
    "zhenmo 0 101",
}
function Commands.zhenmo(oMaster, iTargetPid, sCmd, mArgs)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    oTarget.m_oBaseCtrl.m_oZhenmoCtrl:TestOp(oMaster, oTarget, sCmd, mArgs)
end
