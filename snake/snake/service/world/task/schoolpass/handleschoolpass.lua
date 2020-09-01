local global = require "global"
local record = require "public.record"

local taskdefines = import(service_path("task/taskdefines"))
local handleteam = import(service_path("team/handleteam"))
local analy = import(lualib_path("public.dataanaly"))

function NewSchoolPassHandler()
    local o = CSchoolPassHandler:New()
    return o
end

CSchoolPassHandler = {}
CSchoolPassHandler.__index = CSchoolPassHandler
inherit(CSchoolPassHandler, logic_base_cls())

function CSchoolPassHandler:GetTask(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local oTask = oTeam:GetTaskByType(taskdefines.TASK_KIND.SCHOOLPASS)
        return oTask
    end
    return false
end

function CSchoolPassHandler:ValidOwnTask(oPlayer)
    if self:GetTask(oPlayer) then
        return true
    else
        return false
    end
end

function CSchoolPassHandler:ValidAcceptTask(oPlayer)
    if self:ValidOwnTask(oPlayer) then
        return false
    end
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
    if oHuodong and oHuodong:ValidGiveTask(oPlayer) then
        return true
    end
    return false
end

function CSchoolPassHandler:AddNextRingTask(pid, mFilter)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
    if not oHuodong or not oHuodong:IsGameStart() then
        return
    end

    mFilter = mFilter or {}
    mFilter.begintime = mFilter.begintime or get_time()
    local iDoneRing = mFilter.donering or -1
    
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer or not self:ValidAcceptTask(oPlayer) then
        return
    end
    
    if iDoneRing < 6 then
        local mExclude = mFilter.exclude or {}
        local mTask = {}
        if iDoneRing == 5 then
            mTask = {62021, 62022, 62023, 62024, 62025, 62026}
        else
            for task = 62011, 62016 do
                if not mExclude[task] then
                    table.insert(mTask, task)
                end
            end
        end
        local iTask = mTask[math.random(#mTask)]
        local oTask = global.oTaskLoader:CreateTask(iTask)
        assert(oTask, string.format("schoolpass task err %s", iTask))
        mFilter.donering = iDoneRing + 1
        oTask:SetData("filter", mFilter)
        oTask:SetData("ring", mFilter.donering + 1)
        handleteam.AddTask(pid, oTask)
        oTask:Click(pid)
    else
        local iPassTime = get_time() - mFilter.begintime

        local iTeam = oPlayer:TeamID()
        local oTeam = oPlayer:HasTeam()
        local lMember = oTeam:GetTeamMember()

        local bNoTeamResult = mFilter.noteamresult
        if not bNoTeamResult then
            oHuodong:AddTeamResult(iTeam, iPassTime, oPlayer:GetName())
        end
        local mResultCancel = mFilter.resultcancel or {}
        for _, target in pairs(lMember) do
            if not mResultCancel[tostring(target)] then
                local oTarget = oWorldMgr:GetOnlinePlayerByPid(target)
                oHuodong:AddPlayerResult(target, iPassTime, oTarget:GetName())
            end
        end

        local mLogData = {}
        mLogData.pid = pid
        mLogData.noteamresult = bNoTeamResult or 0
        mLogData.resultcancel = mResultCancel
        mLogData.teammember = lMember
        record.user("huodong", "schoolpass_result", mLogData)
    
        local sTime = get_second2string(iPassTime)
        local sMsg = "该轮试炼耗时#schoolpass_time\n是否继续领取门派试炼任务"
        local oToolMgr = global.oToolMgr
        sMsg = oToolMgr:FormatColorString(sMsg, {schoolpass_time = sTime})
        local oCbMgr = global.oCbMgr
        local mData = {
            sContent = sMsg,
            sConfirm = "继续",
            sCancle = "取消",
            time = 60,
            extend_close = 3,
        }
        mData = oCbMgr:PackConfirmData(nil, mData)
        local func = function(oPlayer, mData)
            local iAnswer = mData["answer"]
            if iAnswer == 1 then
                local oHuodongMgr = global.oHuodongMgr
                local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
                if not oHuodong then return end
                local oNpc = oHuodong:GetHuodongNpc()
                if not oNpc then return end
                local iMap = oNpc:MapId()
                local iX = oNpc.m_mPosInfo["x"]
                local iY = oNpc.m_mPosInfo["y"]
                local oSceneMgr = global.oSceneMgr
                oSceneMgr:SceneAutoFindPath(pid, iMap, iX, iY, oNpc:ID())
            end
        end
        oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mData, nil, func)
        safe_call(self.LogAnalyInfo, self, oPlayer, 2)
    end
end

function CSchoolPassHandler:Fight(oPlayer, npcid)
    local oNpcMgr = global.oNpcMgr
    local npcobj = oNpcMgr:GetObject(npcid)
    if not npcobj then
        return
    end
    local oTask = self:GetTask(oPlayer)
    if oTask then
       oTask:TaskFight(oPlayer:GetPid(), npcobj)
    else
        local oHuodongMgr = global.oHuodongMgr
        local oNotifyMgr = global.oNotifyMgr
        local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
        local sText = oHuodong:GetTextData(1008)
        oNotifyMgr:Notify(oPlayer:GetPid(), sText)
    end
end

function CSchoolPassHandler:LogAnalyInfo(oPlayer, iOperation)
    if not oPlayer then return end

    local oTeam = oPlayer:HasTeam()
    local lMember = oTeam:GetTeamMember()

    local oWorldMgr = global.oWorldMgr
    for _, iPid in pairs(lMember) do
        local o = oWorldMgr:GetOnlinePlayerByPid(iPid)
        local mAnalyLog = o:BaseAnalyInfo()
        mAnalyLog["turn_times"] = 0
        mAnalyLog["operation"] = iOperation
        mAnalyLog["activity_type"] = "schoolpass"
        analy.log_data("TimelimitActivity", mAnalyLog)
    end
end
