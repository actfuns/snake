local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))
local taskdefines = import(service_path("task/taskdefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "秘宝护送"
inherit(CHuodong, huodongbase.CHuodong)

local GAMESTATE = {
    PRESTART = 1,
    START = 2,
    END = 3,
}

local TASKTYPE = {
    NORMAL = 1,
    ADVANCE = 2
}

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mTimes = {}
    o.m_iScheduleID = 1043
    return o
end

function CHuodong:Init()
    self.m_iState = GAMESTATE.END
    self.m_iEndTime = 0
    self.m_iSceneId = nil
    self.m_mNpc = {}
    self.m_mInfo = {}
    self.m_mRob = {}
end

function CHuodong:Save()
    local mData = {}
    mData.state = self.m_iState
    mData.info = self.m_mInfo
    mData.times = self.m_mTimes
    return mData
end

function CHuodong:Load(mData)
    self:Dirty()
    mData = mData or {}
    self.m_iState = mData.state or GAMESTATE.END
    self.m_mInfo = mData.info or {}
    self.m_mTimes = mData.times or {}
end

function CHuodong:AfterLoad()
    local mConfig = self:GetConfig()
    local iWeedDay = mConfig.weekday
    if iWeedDay == get_weekday()then
        self:CheckState(mNow)
    elseif self:GetGameState() ~= GAMESTATE.END then
        self:GameEnd()
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:NewHour(mNow)
    local mConfig = self:GetConfig()
    local iWeedDay = mConfig.weekday
    if iWeedDay == mNow.date.wday then
        self:CheckState(mNow)
    end
end

function CHuodong:ValidShow(oPlayer)
    return (self:GetGameState() == GAMESTATE.PRESTART or self:GetGameState() == GAMESTATE.START)
end

function CHuodong:GetNPCMenu()
    return "参加护宝"
end

function CHuodong:JoinGame(oPlayer,oNpc)
    if not global.oToolMgr:IsSysOpen("TREASURECONVOY", oPlayer) then
        return
    end

    if oPlayer:HasTeam() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(1031))
        return
    end
    self:EnterScene(oPlayer)
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("TREASURECONVOY")
    if global.oToolMgr:IsSysOpen("TREASURECONVOY", oPlayer , true) then
        if oPlayer:GetGrade() < iOpenGrade then
            self:AddUpgradeEvent(oPlayer)
            return
        end
    end

    if not bReEnter then
        local iTaskType = taskdefines.TASK_KIND.TREASURECONVOY
        local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(iTaskType)
        if oTask then
            oTask:FullRemove()
            self:ResetConvoyInfo(oPlayer:GetPid())
        end
    end

    if self:GetGameState() ~= GAMESTATE.END then
        self:GS2CTreasureConvoyState(oPlayer)
        local iPid = oPlayer:GetPid()
        if self.m_mInfo[iPid] then
            self:GS2CTreasureConvoyInfo(oPlayer)
            if self.m_mInfo[iPid].task_id then
                self:GS2CTreasureConvoyFlag(iPid, 1)
            end
        end
    end
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade, iGrade)
    local iLimitGrade = global.oToolMgr:GetSysOpenPlayerGrade("TREASURECONVOY")
    if self:GetGameState() == GAMESTATE.PRESTART
        and self:GetGameState() == GAMESTATE.START
        and iLimitGrade <= iGrade 
        and iFromGrade < iLimitGrade then
        self:GS2CTreasureConvoyState(oPlayer)
        self:DelUpgradeEvent(oPlayer)
    end
end

function CHuodong:CheckState(mNow)
    local iTime = mNow and mNow.time or get_time()
    local iPreStartTime = self:GetPreStartTime()
    local iStartTime = self:GetTCStartTime()
    local iEndTime = self:GetTCEndTime()
    if self:GetGameState() == GAMESTATE.END then
        local iSub = iPreStartTime - iTime
        if iSub <= 0 and iTime < iStartTime then
            self:GamePreStart()
        elseif iSub > 0 and iSub < 3600 then
            self:AddGamePreStartCb()
        end
    elseif self:GetGameState() == GAMESTATE.PRESTART then
        local iSub = iStartTime - iTime
        if iSub <= 0 then
            self:GameStart()
        elseif iSub > 0 and iSub < 3600 then
            self:AddGameStartCb()
        end
    elseif self:GetGameState() == GAMESTATE.START then
        local iSub = iEndTime - iTime
        if iSub <= 0 then
            self:GameEnd()
        elseif iSub > 0 and iSub < 3600 then
            self:AddGameEndCb()
        end
    end
end

function CHuodong:AddGamePreStartCb()
    local iPreStartTime = self:GetPreStartTime()
    local iTime = iPreStartTime - get_time()
    self.m_iEndTime = 0
    self:DelTimeCb("GameTCPreStart")
    self:AddTimeCb("GameTCPreStart", iTime * 1000, function()
        if self:GetGameState() == GAMESTATE.END then
            self:GamePreStart()
        end
    end)
end

function CHuodong:AddGameStartCb()
    local iStartTime = self:GetTCStartTime()
    local iTime = iStartTime - get_time()
    self.m_iEndTime = iStartTime
    self:DelTimeCb("GameTCStart")
    self:AddTimeCb("GameTCStart", iTime * 1000, function()
        if self:GetGameState() == GAMESTATE.PRESTART then
            self:GameStart()
        end
    end)
end

function CHuodong:AddGameEndCb()
    local iEndTime = self:GetTCEndTime()
    local iTime = iEndTime - get_time()
    self.m_iEndTime = iEndTime
    self:DelTimeCb("GameTCEnd")
    self:AddTimeCb("GameTCEnd", iTime * 1000, function()
        if self:GetGameState() == GAMESTATE.START then 
            self:GameEnd() 
        end
    end)
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:SetHuodongState(iState)
    local mConfig = self:GetConfig()
    local sTime = mConfig.start_time
    local iStartTime = self:GetTCStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime, iStartTime)
end

function CHuodong:GamePreStart()
    if not global.oToolMgr:IsSysOpen("TREASURECONVOY") then return end
    record.info(string.format("%s GamePreStart", self.m_sName))
    self:Dirty()
    self:Init()
    self.m_iState = GAMESTATE.PRESTART
    self:LogState()
    self:CreateScene()
    self:CreateNPC()
    self:AddGameStartCb()
    self:BroadcastState()
    self:SysAnnounce(1112)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
end

function CHuodong:GameStart()
    record.info(string.format("%s GameStart", self.m_sName))
    self:Dirty()
    self.m_iState = GAMESTATE.START
    self:LogState()
    self:AddGameEndCb()
    self:BroadcastState()
    self:SysAnnounce(1113)
    self:BroadcastStart()
end

function CHuodong:BroadcastStart()
    if not self.m_iSceneId then return end
    local oScene = global.oSceneMgr:GetScene(self.m_iSceneId)
    local lAllPid = oScene:GetAllPlayerIds()
    for _, iPid in ipairs(lAllPid) do
        self:AskToNpcA(iPid, 1030)
    end
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd", self.m_sName))
    self:Dirty()
    self.m_iState = GAMESTATE.END
    self:LogState()
    self:BroadcastState()
    self:SysAnnounce(1114)
    self:BroadcastEnd()
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
end

function CHuodong:BroadcastEnd()
    if not self.m_iSceneId then return end
    for iPid, mInfo in pairs(self.m_mInfo) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local oScene = oPlayer:GetNowScene()
            if oScene:GetSceneId() == self.m_iSceneId then
                if not oPlayer:InWar() then
                    self:ClearPlayer(iPid)
                end
            else
                self.m_mInfo[iPid] = nil
            end
        else
            self.m_mInfo[iPid] = nil
        end
    end
    self:TryRemoveScene()
end

function CHuodong:ClearPlayer(iPid)
    if self.m_mInfo[iPid] and self.m_mInfo[iPid].task_id then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1026))
    end
    self:DoLeaveScene(iPid)
    self.m_mInfo[iPid] = nil
end

function CHuodong:TryRemoveScene()
    if table_count(self.m_mInfo) == 0 then
        global.oSceneMgr:RemoveScene(self.m_iSceneId)
        self:Init()
    end
end

function CHuodong:CreateScene()
    if self.m_iSceneId then return end
    local iScene = self:GetConfig().scene_id
    local mConfig = self:GetSceneConfig(iScene)
    local mData = {
        map_id = mConfig.map_id,
        team_allowed = mConfig.team_allowed,
        deny_fly = mConfig.deny_fly,
        is_durable = mConfig.is_durable ==1,
        has_anlei = mConfig.has_anlei == 1,
        url = {"huodong", self.m_sName, "scene", iScene},
    }
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    self.m_iSceneId = oScene:GetSceneId()
end

function CHuodong:CreateNPC()
    local mConfig = self:GetConfig()
    local lNpcs = mConfig.npcs
    for _, iNpc in ipairs(lNpcs) do
        local oNpc  = self:CreateTempNpc(iNpc)
        self:Npc_Enter_Scene(oNpc, self.m_iSceneId)
        self.m_mNpc[iNpc] = oNpc
    end
end

function CHuodong:GetNpc(iNpc)
    return self.m_mNpc[iNpc]
end

function CHuodong:OtherScript(pid, npcobj,s,mArgs)
    local sCmd = string.match(s,"^([$%a]+)")
    if sCmd then
        local sArgs = string.sub(s,#sCmd + 1,-1)
        if sCmd == "GetTask" then
            self:GetTask(pid)
        elseif sCmd == "LeaveScene" then
            self:LeaveScene(pid)
        elseif sCmd == "SubmitTask" then
            self:SubmitTask(pid, npcobj:NpcID())
        end
    end
end

function CHuodong:GetTask(iPid)
    if not self:ValideAcceptTask(iPid) then return end
    self:GS2CTreasureConvoyOpenView(iPid)
end

function CHuodong:ValideAcceptTask(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if self:GetGameState() ~= GAMESTATE.START then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1003))
        return
    end

    local mInfo = self.m_mInfo[iPid]
    if mInfo.task_id then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1004))
        return
    end

    local iCount = self.m_mInfo[iPid].convoy_count
    local mConfig = self:GetConfig()
    if iCount >= mConfig.convoy_limit then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1005))
        return
    end
    return true
end

function CHuodong:LeaveScene(iPid)
    if not self.m_iSceneId then return end
    local mInfo = self.m_mInfo[iPid]
    if mInfo and mInfo.task_id then
        self:LeaveSceneConfirm(iPid)
    else
        self:DoLeaveScene(iPid)
    end
end

function CHuodong:LeaveSceneConfirm(iPid)
    local mData = {
        sContent = self:GetTextData(1028),
        sConfirm = "确认",
        sCancle = "取消",
    }
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI",mData,nil,function (oPlayer,mData)
        local iAnswer = mData["answer"]
        if iAnswer == 1 then
            self:DoLeaveScene(iPid)
        end
    end)
end

function CHuodong:DoLeaveScene(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    self:RemoveConvoyTask(iPid)
    self:TransferHome(oPlayer)
end

function CHuodong:RemoveConvoyTask(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    self:ClearConvoyCb(oPlayer)
    local mInfo = self.m_mInfo[iPid]
    if mInfo and mInfo.task_id then
        local oTask = oPlayer.m_oTaskCtrl:HasTask(mInfo.task_id)
        if oTask then
            oTask:FullRemove()
            self:ResetConvoyInfo(iPid)

            local mConfig = self:GetConfig()
            local iBuff = mConfig.buff_id
            oPlayer.m_oStateCtrl:RemoveState(iBuff)
        end
    end
end

function CHuodong:ClearConvoyCb(oPlayer)
    oPlayer:DelTimeCb("TreasureConvoyTask")
    oPlayer:DelTimeCb("GameTCMonsterEvent")
    oPlayer:DelTimeCb("TreasureConvoyCdTime")  
end

function CHuodong:SubmitTask(iPid, iNpcId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mInfo = self.m_mInfo[iPid]
    if mInfo and mInfo.task_id then
        local oTask = oPlayer.m_oTaskCtrl:HasTask(mInfo.task_id)
        if oTask then
            local iTarget = oTask:Target()
            if iTarget == iNpcId then
                oTask:DoScript2(iPid, nil, "DONE")
            else
                local sMsg = self:GetTextData(1033)
                global.oNotifyMgr:Notify(iPid, sMsg)
            end
        end
    else
        local sMsg = self:GetTextData(1034)
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CHuodong:EnterScene(oPlayer)
    if self:GetGameState() == GAMESTATE.END then return end
    if not self.m_iSceneId then return end

    local oNpcA = self.m_mNpc[1001]
    if not oNpcA then return end

    local bFly = oPlayer.m_oRideCtrl:GetRideFly()
    if bFly == 1 then
        oPlayer.m_oRideCtrl:SetRideFly(0)
    end
    local iPid = oPlayer:GetPid()
    oPlayer.m_oRideCtrl:UnUseRide() --下马

    if not self.m_mInfo[iPid] then
        self:InitPlayerInfo(iPid)
    end
    if not self.m_mTimes[iPid] then
        self:InitPlayerTimes(iPid)
    end

    self:GS2CTreasureConvoyInfo(oPlayer)
    self:TransferNpcA(oPlayer, self:GetGameState() == GAMESTATE.START)
end

function CHuodong:TransferHome(oPlayer)
    local iMapID = 101000
    local oScene = global.oSceneMgr:SelectDurableScene(iMapID)
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId())
end

function CHuodong:TransferNpcA(oPlayer, bFindPath)
    local oNpcA = self.m_mNpc[1001]
    if not oNpcA then return end

    local mPosInfo = oNpcA.m_mPosInfo
    local iRandomX = math.random(1, 2)  
    local iRandomY = math.random(1, 2)
    local mPos = {x = mPosInfo.x + iRandomX, y = mPosInfo.y + iRandomY }
    global.oSceneMgr:DoTransfer(oPlayer, self.m_iSceneId, mPos)
    if bFindPath then
        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oNpcA)
    end
end

function CHuodong:InitPlayerInfo(iPid)
    self.m_mInfo[iPid] = {
        convoy_count = 0,
        rob_count = 0,
        robbed_count = 0,

        convoy_pregress = 0,
        convoy_type = TASKTYPE.NONE,
        convoy_grade = 0,
        convoy_endtime = 0,
        task_id = nil,
        rob_cdtime = 0,
        cash_pledge = 0,
        origin_cash_pledge = 0,
        selected_monster = {},
    }
end

function CHuodong:InitPlayerTimes(iPid)
    self.m_mTimes[iPid] = {
        normal_convoy = 0,
        advance_convoy = 0,
        rob = 0,
    }
end

function CHuodong:GetPlayerInfo(iPid)
    return self.m_mInfo[iPid]
end

function CHuodong:C2GSTreasureConvoySelectTask(oPlayer, iType)
    if not self:ValideAcceptTask(oPlayer:GetPid(), iType) then return end
    if not self:ValideConsume(oPlayer, iType) then return end

    local mConfig = self:GetConfig()
    local iTaskId = mConfig.normal_task
    if iType ~= TASKTYPE.NORMAL then
        iTaskId = mConfig.advance_task
    end
    local oTask = global.oTaskLoader:CreateTask(iTaskId)
    local bSuc = oPlayer.m_oTaskCtrl:AddTask(oTask)
    if not bSuc then
        self:ReturnCashPledge(oPlayer:GetPid())
    else
        local iTextId = (iType == TASKTYPE.NORMAL) and 1009 or 1010
        local sMsg = self:GetTextData(iTextId)
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    end
end

function CHuodong:ValideConsume(oPlayer, iType)
    local iGrade = oPlayer:GetGrade()
    local mConfig = self:GetConfig()
    local iPid = oPlayer:GetPid()

    local sReason = "秘宝护送"
    local iCashPledge
    if iType == TASKTYPE.NORMAL then
        local sCashPledge = mConfig.normal_cashpledge
        iCashPledge = formula_string(sCashPledge, {lv = iGrade})
        if not oPlayer:ValidSilver(iCashPledge) then return end
        oPlayer:ResumeSilver(iCashPledge, sReason)
    else
        local sCashPledge = mConfig.advance_cashpledge
        iCashPledge = formula_string(sCashPledge, {lv = iGrade})
        if not oPlayer:ValidGold(iCashPledge) then return end
        oPlayer:ResumeGold(iCashPledge, sReason)
    end
    self.m_mInfo[iPid].convoy_type = iType
    self.m_mInfo[iPid].cash_pledge = iCashPledge
    self.m_mInfo[iPid].origin_cash_pledge = iCashPledge
    return true
end

function CHuodong:AddTaskDone(oPlayer, oTask)
    self:Dirty()
    local mConfig = self:GetConfig()
    local iPid = oPlayer:GetPid()
    local iTaskId = oTask:GetId()
    local mInfo = self.m_mInfo[iPid]
    if iTaskId == mConfig.normal_task or iTaskId == mConfig.advance_task then
        local iLimitTime = mConfig.limit_time
        mInfo.convoy_pregress = 0
        mInfo.convoy_grade = oPlayer:GetGrade()
        mInfo.convoy_endtime = iLimitTime + get_time()
        mInfo.convoy_count = mInfo.convoy_count + 1

        self:AddTaskCb(oPlayer, iLimitTime)
        self:AddMonsterCb(oPlayer)
    end
    mInfo.convoy_pregress = mInfo.convoy_pregress + 1
    mInfo.task_id = iTaskId
    oTask:Click(iPid)

    self:GS2CTreasureConvoyInfo(oPlayer)
end

function CHuodong:AddTaskCb(oPlayer, iTime)
    local iPid = oPlayer:GetPid()
    local func = function()
        local oHd = global.oHuodongMgr:GetHuodong("treasureconvoy")
        if oHd then
            oHd:RemoveConvoyTask(iPid)
            local sMsg = self:GetTextData(1025)
            global.oNotifyMgr:Notify(iPid, sMsg)
        end
    end
    oPlayer:DelTimeCb("TreasureConvoyTask")
    oPlayer:AddTimeCb("TreasureConvoyTask", iTime*1000, func)
end

function CHuodong:AddMonsterCb(oPlayer)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iTime = mConfig.event_time
    oPlayer:DelTimeCb("GameTCMonsterEvent")
    oPlayer:AddTimeCb("GameTCMonsterEvent", iTime * 1000, function()
        if self:GetGameState() == GAMESTATE.START then
            local oHd = global.oHuodongMgr:GetHuodong("treasureconvoy")
            if oHd then
                oHd:TriggerMonsterEvent(iPid)
            end
        end
    end)
end

function CHuodong:TriggerMonsterEvent(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mConfig = self:GetConfig()
    local mInfo = self.m_mInfo[iPid]
    local iRadio = math.random(100)
    local iConfigRatio = mConfig.event_ratio
    if self.m_mRob[iPid] and not oPlayer:InWar() and iRadio <= iConfigRatio then
        local iMonster = self:ChooseOneMonster(iPid)
        if iMonster then
            local mMonsterConfig = self:GetMonsterConfig(iMonster)
            local iFight = mMonsterConfig.fight_id
            self:ChangeRobStatus(iPid, false)
            self:Fight(iPid, nil, iFight)
            mInfo.selected_monster[iMonster] = true

            local sMsg = self:GetTextData(1036)
            sMsg = global.oToolMgr:FormatColorString(sMsg, {monster = mMonsterConfig.name})
            global.oNotifyMgr:Notify(iPid, sMsg)
        end
    end

    if table_count(mInfo.selected_monster) < 3 then
        self:AddMonsterCb(oPlayer)
    end
end

function CHuodong:ChooseOneMonster(iPid)
    local mConfig = self:GetMonsterConfig()
    local mInfo = self.m_mInfo[iPid]
    local mRandom = {}
    for iMonsterId, mData in pairs(mConfig) do
        if not mInfo.selected_monster[iMonsterId] then
            mRandom[iMonsterId] = mData.ratio
        end
    end
    return table_choose_key(mRandom)
end

function CHuodong:WarFightEnd(oWar, pid, npcobj, mArgs)
    super(CHuodong).WarFightEnd(self, oWar, pid, npcobj, mArgs)
    if self:GetGameState() == GAMESTATE.END then
        self:ClearPlayer(pid)
        self:TryRemoveScene()
    else
        self:ChangeRobStatus(pid, true)
    end
end

function CHuodong:OnWarWin(oWar, pid, npcobj, mArgs)
    super(CHuodong).OnWarWin(self, oWar, pid, npcobj, mArgs)
    local iFight = oWar.m_iIdx
    if iFight == 1001 or iFight == 1002 then
        local mMonsterConfig = self:GetMonsterConfig(iFight)
        local iReward = mMonsterConfig.reward_id
        self:Reward(pid, iReward)
    elseif iFight == 1003 then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local mConfig = self:GetConfig()
            local iBuff = mConfig.buff_id
            local iTime = mConfig.buff_time
            oPlayer.m_oStateCtrl:AddState(iBuff, {time=iTime})
        end
    end
end

function CHuodong:OnWarFail(oWar, pid, npcobj, mArgs)
    super(CHuodong).OnWarFail(self, oWar, pid, npcobj, mArgs)
    local iFight = oWar.m_iIdx
    if iFight == 1001 then
        local iRobbedLoss = self:GetRobbedLoss(pid)
        if iRobbedLoss then
            local iCashPledge = self.m_mInfo[pid].cash_pledge
            self.m_mInfo[pid].cash_pledge = iCashPledge - iRobbedLoss
            self:LogRobbedCashPledge(pid, iFight, iCashPledge)
        end
    end
end

--获取被打劫时,损失的押金
function CHuodong:GetRobbedLoss(iPid)
    local mInfo = self.m_mInfo[iPid]
    if mInfo.task_id then
        local mConfig = self:GetConfig()
        local iConvoyType = mInfo.convoy_type
        local iConvoyGrade = mInfo.convoy_grade
        local sRobbedLoss = mConfig.normal_robbedloss
        if iConvoyType == TASKTYPE.ADVANCE then
            sRobbedLoss = mConfig.advance_robbedloss
        end
        local iRobbedLoss = formula_string(sRobbedLoss, {lv = iConvoyGrade})
        return iRobbedLoss
    end
end

--押送完成
function CHuodong:ConvoyDone(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    self:ClearConvoyCb(oPlayer)
    
    local mInfo = self.m_mInfo[iPid]
    local iConvoyType = mInfo.convoy_type
    local mTimes = self.m_mTimes[iPid]
    if iConvoyType == TASKTYPE.NORMAL then
        mTimes.normal_convoy = mTimes.normal_convoy + 1
    else
        mTimes.advance_convoy = mTimes.advance_convoy + 1
    end
    self:TryGiveTitle(iPid)
    self:ReturnCashPledge(iPid)
    self:ResetConvoyInfo(iPid)

    local mConfig = self:GetConfig()
    local iBuff = mConfig.buff_id
    oPlayer.m_oStateCtrl:RemoveState(iBuff)

    local mInfo = self.m_mInfo[iPid]
    local mConfig = self:GetConfig()
    local iCount = mInfo.convoy_count
    if iCount < mConfig.convoy_limit then
        self:AskToNpcA(iPid, 1024)
    end
end

--给称号
function CHuodong:TryGiveTitle(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mTimes = self.m_mTimes[iPid]
    local mConfig = self:GetTitleConfig()
    local iConvoyTime = mTimes.normal_convoy + mTimes.advance_convoy
    for iTitleId, mData in pairs(mConfig) do
        local oTitle = oPlayer.m_oTitleCtrl:GetTitleByTid(iTitleId)
        if not oTitle and iConvoyTime >= mData.convoy and mTimes.rob >= mData.rob then
            global.oTitleMgr:AddTitle(iPid, iTitleId)
            return
        end
    end
end

--重置护送的数据
function CHuodong:ResetConvoyInfo(iPid)
    self:Dirty()
    local mInfo = self.m_mInfo[iPid]
    if not mInfo then return end
    mInfo.task_id = nil
    mInfo.convoy_pregress = 0
    mInfo.convoy_grade = 0
    mInfo.convoy_endtime = 0
    mInfo.convoy_type = TASKTYPE.NORMAL
    mInfo.cash_pledge = 0
    mInfo.origin_cash_pledge = 0
    mInfo.selected_monster = {}
    self:ChangeRobStatus(iPid, false)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:GS2CTreasureConvoyInfo(oPlayer)
    end
end

--返还押金
function CHuodong:ReturnCashPledge(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local sReason = "秘宝护送押金返还"
    local mInfo = self.m_mInfo[iPid]
    if mInfo and mInfo.cash_pledge and mInfo.cash_pledge > 0 then
        local iConvoyType = mInfo.convoy_type
        local iCashPledge = mInfo.cash_pledge
        if iConvoyType == TASKTYPE.NORMAL then
            oPlayer:RewardSilver(iCashPledge, sReason)
        elseif iConvoyType == TASKTYPE.ADVANCE then
            oPlayer:RewardGold(iCashPledge, sReason)
        end

        if iCashPledge == mInfo.origin_cash_pledge then
            local sMsg = self:GetTextData(1022)
            sMsg = global.oToolMgr:FormatColorString(sMsg, {amount = iCashPledge})
            global.oNotifyMgr:Notify(iPid, sMsg)
        else
            local iSub = mInfo.origin_cash_pledge - iCashPledge
            local sMsg = self:GetTextData(1023)
            sMsg = global.oToolMgr:FormatColorString(sMsg, {robbed = iSub, leave = iCashPledge})
            global.oNotifyMgr:Notify(iPid, sMsg)
        end
    end
end

function CHuodong:AskToNpcA(iPid, iText)
    local mData = {
        sContent = self:GetTextData(iText),
        sConfirm = "确认",
        sCancle = "取消",
    }
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil, function (oPlayer,mData)
        local iAnswer = mData["answer"]
        if iAnswer == 1 then
            local oHd = global.oHuodongMgr:GetHuodong("treasureconvoy")
            if oHd then
                oHd:TransferNpcA(oPlayer, true)
            end
        end
    end)
end

function CHuodong:C2GSTreasureConvoyMatchRob(oPlayer)
    local iPid = oPlayer:GetPid()

    if self:GetGameState() ~= GAMESTATE.START then 
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1003)) 
        return 
    end

    if not self:ValidRob(iPid) then return end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    oScene:QueryRemote("aoiview_players", {pid = oPlayer:GetPid()}, function (mRecord, mData)
        local lPid = mData and mData.data.lpid
        if lPid then
            local iTargetPid = self:MatchConvoyPlayer(iPid, lPid)
            if iTargetPid then
                self:RobConvoy(iPid, iTargetPid)
            end
        end
    end)
end

function CHuodong:MatchConvoyPlayer(iPid, lPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if #lPid == 0 then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1029))
        return
    end

    local mConfig = self:GetConfig()
    local iLimitGrade = mConfig.level_limit

    local mPlayer = {}
    for _, iTargetPid in ipairs(lPid) do
        if self.m_mRob[iTargetPid] then
            local iGrade = oPlayer:GetGrade()
            local iSub = iGrade - self.m_mInfo[iTargetPid].convoy_grade
            iSub = math.abs(iSub)
            if iSub <= iLimitGrade then
                mPlayer[iSub] = mPlayer[iSub] or {}
                table.insert(mPlayer[iSub], iTargetPid)
            end
        end
    end

    if table_count(mPlayer) == 0 then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1029))
        return
    end

    for iGrade=0, iLimitGrade do
        if mPlayer[iGrade] then
            local iTargetPid =mPlayer[iGrade][math.random(#mPlayer[iGrade])]
            return iTargetPid
        end
    end
    global.oNotifyMgr:Notify(iPid, self:GetTextData(1029))
end

function CHuodong:C2GSTreasureConvoyRob(oPlayer, iTargetPid)
    local iPid = oPlayer:GetPid()

    if self:GetGameState() ~= GAMESTATE.START then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1003)) 
        return
    end

    if not self:ValidRob(iPid) then return end
    self:RobConvoy(iPid, iTargetPid)
end

--打劫
function CHuodong:RobConvoy(iPid, iTargetPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    if not oTarget then return end

    if not self:ValidRobbed(oPlayer, oTarget) then return end

    local iWar = self:CreateSingleWar(oPlayer, oTarget)
    global.oWarMgr:StartWar(iWar)
    self:ChangeRobStatus(iTargetPid, false)

    local sMsg = self:GetTextData(1037)
    sMsg = global.oToolMgr:FormatColorString(sMsg, {name = oPlayer:GetName()})
    global.oNotifyMgr:Notify(iTargetPid, sMsg)
end

function CHuodong:CreateSingleWar(oPlayer, oTarget)
    local mConfig = self:GetConfig()
    local iWarType = gamedefines.WAR_TYPE.PVP_TYPE
    local iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_TREASURECONVOY
    local mWarConfig = {
        barrage_show = mConfig.barrage_show,
        barrage_send = mConfig.barrage_send,
        GamePlay = self.m_sName,
        bout_out = {bout = mConfig.bout_out, result=1},
    }
    local oWar = global.oWarMgr:CreateWar(iWarType, iSysType, mWarConfig)
    local iWar = oWar:GetWarId()
    for idx, oFighter in ipairs({oPlayer, oTarget}) do
        global.oWarMgr:EnterWar(oFighter, iWar, {camp_id=idx}, true, 4)
    end
    global.oWarMgr:SetCallback(iWar, function(mArgs)
        self:OnSingleFightEnd(iWar, mArgs)
    end)
    return iWar
end

function CHuodong:OnSingleFightEnd(iWar, mArgs)
    local lWinner, lLoser, lWinnerEscape, lLoserEscape, lLoserDie = self:GetJoinSingleWarMember(mArgs)
    local iWinner = lWinner[1]
    local iLoser = lLoser[1] or lLoserEscape[1] or lLoserDie[1]
    assert(iWinner and iLoser)

    local oWinner = global.oWorldMgr:GetOnlinePlayerByPid(iWinner)
    if not oWinner then return end

    local oLoser = global.oWorldMgr:GetOnlinePlayerByPid(iLoser)
    if not oLoser then return end

    --打劫者赢了
    local iWinSide = mArgs.win_side
    if iWinSide == 1 then
        local iRobbedLoss = self:GetRobbedLoss(iLoser)
        if iRobbedLoss then
            local iCashPledge = self.m_mInfo[iLoser].cash_pledge
            self.m_mInfo[iLoser].cash_pledge = iCashPledge - iRobbedLoss
            self.m_mInfo[iLoser].robbed_count = self.m_mInfo[iLoser].robbed_count + 1
            self:LogRobbedCashPledge(iWinner, iLoser, iRobbedLoss)

            local sMsg = self:GetTextData(1020)
            sMsg = global.oToolMgr:FormatColorString(sMsg, {amount = iRobbedLoss})
            global.oNotifyMgr:Notify(iLoser, sMsg)

            local sReason = "秘宝护送打劫"
            local iConvoyType = self.m_mInfo[iLoser].convoy_type
            if iConvoyType == TASKTYPE.NORMAL then
                oWinner:RewardSilver(iRobbedLoss, sReason)
            elseif iConvoyType == TASKTYPE.ADVANCE then
                oWinner:RewardGold(iRobbedLoss, sReason)
            end
            self.m_mInfo[iWinner].rob_count = self.m_mInfo[iWinner].rob_count + 1
            self.m_mTimes[iWinner].rob = self.m_mTimes[iWinner].rob + 1
            self:TryGiveTitle(iWinner)

            local oScene = global.oSceneMgr:GetScene(self.m_iSceneId)
            local sMsg = self:GetTextData(1021)
            local mFormat = {winner=oWinner:GetName(), loser = oLoser:GetName()}
            sMsg = global.oToolMgr:FormatColorString(sMsg, mFormat)
            oScene:BroadcastMessage("GS2CNotify", {cmd=sMsg})

            self:GS2CTreasureConvoyInfo(oWinner)
            self:GS2CTreasureConvoyInfo(oLoser)
        end
    end

    --双方进入冷却时间
    self:SetRobCdTime(iWinner)
    self:SetRobCdTime(iLoser)

    self:LogRob(iWar, iWinSide, iWinner, iLoser)

    if self:GetGameState() == GAMESTATE.END then
        self:ClearPlayer(iWinner)
        self:ClearPlayer(iLoser)
        self:TryRemoveScene()
    end
end

function CHuodong:GetJoinSingleWarMember(mArgs)
    local iWinSide = mArgs.win_side
    local iLoseSide = 3 - iWinSide
    local lWinner = self:GetWarriorBySide(mArgs.player, iWinSide)
    local lLoser = self:GetWarriorBySide(mArgs.player, iLoseSide)
    local lWinnerEscape = self:GetWarriorBySide(mArgs.escape, iWinSide)
    local lLoserEscape = self:GetWarriorBySide(mArgs.escape, iLoseSide)
    local lLoserDie = self:GetWarriorBySide(mArgs.die, iLoseSide)
    return lWinner, lLoser, lWinnerEscape, lLoserEscape, lLoserDie
end

function CHuodong:GetWarriorBySide(mPlayer, iSide)
    local lPlayer = {}
    for _, iPid in ipairs(mPlayer[iSide] or {}) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer and oPlayer:IsTeamLeader() then
            table.insert(lPlayer, 1, iPid)
        else
            table.insert(lPlayer, iPid)
        end
    end
    return lPlayer
end

--设置打劫冷却时间
function CHuodong:SetRobCdTime(iPid)
    local mConfig = self:GetConfig()
    local iCdTime = mConfig.rob_cdtime
    local iCdEndTime = iCdTime + get_time()

    local mInfo = self.m_mInfo[iPid]
    if mInfo then
        mInfo.rob_cdtime = iCdEndTime
        if mInfo.task_id then
            self:AddRobCdTimeCb(iPid, iCdTime)
        end
    end
end

function CHuodong:AddRobCdTimeCb(iPid, iTime)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local func = function()
            local oHd = global.oHuodongMgr:GetHuodong("treasureconvoy")
            if oHd then
                oHd:ChangeRobStatus(iPid, true)
            end
        end
        oPlayer:DelTimeCb("TreasureConvoyCdTime")
        oPlayer:AddTimeCb("TreasureConvoyCdTime", iTime*1000, func)
    end
end

--验证打劫方
function CHuodong:ValidRob(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then 
        return 
    end

    local mInfo = self.m_mInfo[iPid]
    if not mInfo then return end

    local mConfig = self:GetConfig()
    if mInfo.rob_count == mConfig.rob_limit then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1012))
        return
    end

    if mInfo.task_id and oPlayer.m_oTaskCtrl:HasTask(mInfo.task_id) then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1004))
        return
    end

    local iSub = mInfo.rob_cdtime - get_time()
    if iSub > 0 then
        local sMsg = self:GetTextData(1017)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {sec = iSub})
        global.oNotifyMgr:Notify(iPid, sMsg)
        return
    end
    return true
end

--验证被打劫方
function CHuodong:ValidRobbed(oPlayer, oTarget)
    local iPid = oPlayer:GetPid()
    local iTargetPid = oTarget:GetPid()
    local mInfo = self.m_mInfo[iTargetPid]
    if not mInfo or not mInfo.task_id then 
        return
    end

    local mConfig = self:GetConfig()
    if mInfo.robbed_count == mConfig.robbed_limit then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1011))
        return
    end

    local mConfig = self:GetConfig()
    local iLimitGrade = mConfig.level_limit
    local iSub = oTarget:GetGrade() - oPlayer:GetGrade()
    iSub = iSub >= 0 and iSub or -iSub
    if iSub > iLimitGrade then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1013))
        return
    end

    if oTarget:InWar() then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1016))
        return
    end

    local iSub = mInfo.rob_cdtime - get_time()
    if iSub > 0 then
        local sMsg = self:GetTextData(1018)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {sec = iSub})
        global.oNotifyMgr:Notify(iPid, sMsg)
        return
    end

    if not self.m_mRob[iTargetPid] then
        local sMsg = self:GetTextData(1032)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {sec = iSub})
        global.oNotifyMgr:Notify(iPid, sMsg)
        return
    end

    return true
end

function CHuodong:ChangeRobStatus(iPid, bFlag)
    if self:GetGameState() ~= GAMESTATE.START then return end
    local mInfo = self.m_mInfo[iPid]
    if mInfo.task_id and self.m_mRob[iPid] ~= bFlag  then
        self.m_mRob[iPid] = bFlag
    end
end

function CHuodong:C2GSTreasureConvoyEnterNpcArea(iPid, iNpcId)
    if not is_production_env() then
        global.oNotifyMgr:Notify(iPid, "测试提示:进入保护区")
    end
    self:ChangeRobStatus(iPid, false)
end

function CHuodong:C2GSTreasureConvoyExitNpcArea(iPid, iNpcId)
    if not is_production_env() then
        global.oNotifyMgr:Notify(iPid, "测试提示:离开保护区")
    end
    self:ChangeRobStatus(iPid, true)
end

function CHuodong:BroadcastState()
    local mData = {
        state = self.m_iState,
        end_time = self.m_iEndTime,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CTreasureConvoyState",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = mData,
        exclude = {},
    })
end

function CHuodong:GS2CTreasureConvoyState(oPlayer)
    local mData = {
        state = self.m_iState,
        end_time = self.m_iEndTime,
    }
    oPlayer:Send("GS2CTreasureConvoyState", mData)
end

function CHuodong:GS2CTreasureConvoyInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mInfo[iPid]
    local mData = {
        convoy_count = mInfo.convoy_count,
        rob_count = mInfo.rob_count,
        robbed_count = mInfo.robbed_count,
        convoy_pregress = mInfo.convoy_pregress,
        convoy_endtime = mInfo.convoy_endtime,
    }
    oPlayer:Send("GS2CTreasureConvoyInfo", mData)
end

function CHuodong:GS2CTreasureConvoyOpenView(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CTreasureConvoyOpenView", {})
    end
end

function CHuodong:GS2CTreasureConvoyFlag(iPid, iFlag)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CTreasureConvoyFlag", {flag = iFlag})
    end
end

function CHuodong:GetPreStartTime(mNow)
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local sPreStartTime = mConfig.prestart_time
    return self:GetTCTimeStamp(iTime, sPreStartTime)
end

function CHuodong:GetTCStartTime(mNow)
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local sStartTime = mConfig.start_time
    return self:GetTCTimeStamp(iTime, sStartTime)
end

function CHuodong:GetTCEndTime(mNow)
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local sEndTime = mConfig.end_time
    return self:GetTCTimeStamp(iTime, sEndTime)
end

function CHuodong:GetTCTimeStamp(iTime, sConfigTime)
    iTime = iTime or get_time()
    local sToday = os.date("%Y-%m-%d", iTime)
    local sCurTime = string.format("%s %s", sToday, sConfigTime)
    return get_str2timestamp(sCurTime)
end

function CHuodong:NpcFuncGroup(sGroup)
    return string.format("%s.%s", "task", self.m_sName)
end

function CHuodong:GetSceneId()
    return self.m_iSceneId
end

function CHuodong:LogState()
    local mLogData = {
        state = self:GetGameState(),
    }
    record.log_db("huodong", "treasureconvoy_state", mLogData)
end

function CHuodong:LogRob(iWar, iWinSide, iWinner, iLoser)
    local mLogData = {
        war = iWar,
        winside = iWinSide,
        winner = iWinner,
        loser = iLoser
    }
    record.log_db("huodong", "treasureconvoy_rob", mLogData)
end

function CHuodong:LogRobbedCashPledge(iPid, iRob, iCashLoss)
    local mInfo = self.m_mInfo[iPid]
    if mInfo and mInfo.task_id then
        local mLogData = {
            pid = iPid,
            rob = iRob,
            cash_type = mInfo.convoy_type,
            cash_loss = iCashLoss,
            leave_cashpledge = mInfo.cash_pledge,
        }
        record.log_db("huodong", "treasureconvoy_robbed_cashpledge", mLogData)
    end
end

function CHuodong:GetConfig()
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    assert(mConfig, string.format("%s huodong GetConfig error", self.m_sName))
    return mConfig
end

function CHuodong:GetMonsterConfig(iMonster)
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["monster"]
    assert(mConfig, string.format("%s huodong GetMonsterConfig error", self.m_sName))
    if iMonster then
        local mOneConfig = mConfig[iMonster]
        assert(mOneConfig, string.format("%s huodong GetMonsterConfig one error %d", self.m_sName, iMonster))
        return mOneConfig
    end
    return mConfig
end

function CHuodong:GetSceneConfig(iScene)
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["scene"]
    assert(mConfig, string.format("%s huodong GetSceneConfig error", self.m_sName))
    local mScene = mConfig[iScene]
    assert(mScene, string.format("%s huodong GetSceneConfig scene error %d", self.m_sName, iScene))
    return mScene
end

function CHuodong:GetTitleConfig()
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["convoy_title"]
    assert(mConfig, string.format("%s huodong GetTitleConfig error", self.m_sName))
    return mConfig
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    self.m_iTestDay = nil
    local mCommand={
        "100 指令查看",
        "101 活动准备阶段 huodongop treasureconvoy 101 {sec = 2}",
        "102 活动开始阶段 huodongop treasureconvoy 102 {sec = 2}",
        "103 活动结束阶段 huodongop treasureconvoy 103 {sec = 2}",
        "104 进入场景 huodongop treasureconvoy 104",
        "105 任务n秒后过期 huodongop treasureconvoy 105 {sec = 2}",
        "106 清空玩家数据 huodongop treasureconvoy 106",
        "107 加护卫加成 huodongop treasureconvoy 107",
        "108 清护卫加成 huodongop treasureconvoy 108",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        if self:GetGameState() == GAMESTATE.END then
            local iTime = mArgs.sec or 2
            self:DelTimeCb("GameTCStart")
            self:AddTimeCb("GameTCStart", iTime * 1000, function()
                if self:GetGameState() == GAMESTATE.END then
                    self:GamePreStart()
                end
            end)
            local sMsg = string.format("%d秒后准备阶段开启", iTime)
            oNotifyMgr:Notify(pid, sMsg)
        else
            oNotifyMgr:Notify(pid, "活动不在结束阶段,不可调整准备开启时间")
        end
    elseif iFlag == 102 then
        if self:GetGameState() == GAMESTATE.PRESTART then
            local iTime = mArgs.sec or 2
            self:DelTimeCb("GameTCStart")
            self:AddTimeCb("GameTCStart", iTime * 1000, function()
                if self:GetGameState() == GAMESTATE.PRESTART then
                    self:GameStart()
                end
            end)
            local sMsg = string.format("%d秒后活动开始", iTime)
            oNotifyMgr:Notify(pid, sMsg)
        else
            oNotifyMgr:Notify(pid, "活动不在准备阶段,不可调整开启时间")
        end
    elseif iFlag == 103 then
        if self:GetGameState() == GAMESTATE.START then
            local iTime = mArgs.sec or 2
            self:DelTimeCb("GameTCStart")
            self:AddTimeCb("GameTCStart", iTime * 1000, function()
                if self:GetGameState() == GAMESTATE.START then
                    self:GameEnd()
                end
            end)
            local sMsg = string.format("%d秒后活动结束", iTime)
            oNotifyMgr:Notify(pid, sMsg)
        else
            oNotifyMgr:Notify(pid, "活动不在开启阶段,不可调整结束时间")
        end
    elseif iFlag == 104 then
        self:JoinGame(oPlayer)
    elseif iFlag == 105 then
        if self:GetGameState() == GAMESTATE.START then
            local iTime = mArgs.sec or 2
            local func = function()
                local oHd = global.oHuodongMgr:GetHuodong("treasureconvoy")
                if oHd then
                    oHd:RemoveConvoyTask(pid)
                    local sMsg = self:GetTextData(1025)
                    global.oNotifyMgr:Notify(pid, sMsg)
                end
            end
            oPlayer:DelTimeCb("TreasureConvoyTask")
            oPlayer:AddTimeCb("TreasureConvoyTask", iTime*1000, func)
            local sMsg = string.format("%d秒后任务倒计时结束", iTime)
            oNotifyMgr:Notify(pid, sMsg)
        else
            oNotifyMgr:Notify(pid, "活动不在开启阶段,不可调整任务时间")
        end
    elseif iFlag == 106 then
        self:RemoveConvoyTask(pid)
        self:InitPlayerInfo(pid)
        self:GS2CTreasureConvoyInfo(oPlayer)
    elseif iFlag == 107 then
        local mConfig = self:GetConfig()
        local iBuff = mConfig.buff_id
        local iTime = mConfig.buff_time
        oPlayer.m_oStateCtrl:AddState(iBuff, {time=iTime})
    elseif iFlag == 108 then
        local mConfig = self:GetConfig()
        local iBuff = mConfig.buff_id
        oPlayer.m_oStateCtrl:RemoveState(iBuff) 
    end
end