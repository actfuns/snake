-- 画舫灯谜
local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local interactive = require "base.interactive"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local hfdmdefines = import(service_path("huodong.hfdm.defines"))
local hfdmscenectrl = import(service_path("huodong.hfdm.scenectrl"))
local hfdmskill = import(service_path("huodong.hfdm.skill"))
local handleteam = import(service_path("team.handleteam"))

QUES_STATE = {
    QUES_ST_WAITING = 1,
    QUES_ST_ANSWERING = 2,
    QUES_ST_END = 3,
    QUES_ST_PREPARE = 4,
}

TIME_BATCH = {
    REWARD_QUES = "BatchRewardQues",
    RANK_BROADCAST = "BatchRankBroadcast",
    BIANSHEN = "BatchBianshen",
    CLEAR_BIANSHEN = "BatchClearBianshen",
}

function GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"huodong", "hfdm"})
end

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "画舫灯谜"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o:Init()
    o.m_oSceneCtrl = hfdmscenectrl.CSceneCtrl:New(sHuodongName)
    o.m_oSkillMgr = hfdmskill.CHuodongSkillMgr:New(sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1026
    self.m_iPrepareStartTime = 0
    self.m_iPrepareEndTime = 0
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iHasRewardedRankWeekNo = nil
    self:Reset()
end

function CHuodong:Reset()
    self.m_mAllQuesConfig = {} -- {iQuesId={reverse=<bool>,judged=<bool>,select={iPid={answer=<int>iAnswer, time=<int>choosetime}}}}
    self.m_lQuesList = {}

    self.m_mPosFakeSelect = {}

    self.m_mPlayerCorrect = {} -- {iPid={iRound=true}}

    self.m_mRewardPlayers = {} -- {iRound={iPid=mRewardEnv}}

    self.m_mPlayerSkill = {} -- {iPid={iSkillId={cd=0}}}

    self.m_mContinuousAnswerWrong = {} -- {iPid={last_round=<int>, continunous_cnt=<int>}}}
    self.m_mToBianshen = {} -- {iPid=iBianshenId}}

    self.m_iCurStepEndTimestamp = -1

    self.m_bDealHuodong = nil
    self.m_bQuesHuodongOn = nil
    self.m_lWinnerNames = nil
    self:StopBatch(TIME_BATCH.REWARD_QUES)
    self:StopBatch(TIME_BATCH.RANK_BROADCAST)
    self:DelTimeCb("TryEndHuodong")
    self:DelTimeCb("EndQuestion")
    self:DelTimeCb("TailQuesEndWait")
    self:DelTimeCb("NextQuesWaiting")
    self:DelTimeCb("ToQuesShowAnswer")
end

function CHuodong:Clear()
    self.m_oSceneCtrl:RecycleAllRooms()
    self.m_oSkillMgr:ClearAll()
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Load(mData)
    if not mData then return end
    self.m_iHasRewardedRankWeekNo = mData.rwded_rank_weekno
end

function CHuodong:Save()
    return {
        rwded_rank_weekno = self.m_iHasRewardedRankWeekNo,
    }
end

function CHuodong:MergeFrom(mFromData)
    self.m_iHasRewardedRankWeekNo = nil
    self:Dirty()
    return true, ""
end

function CHuodong:NewHour(mNow)
    -- 为了不影响此后的正常活动状态，每逢刷时都重置测试时间
    if self:GetHuodongState() == gamedefines.ACTIVITY_STATE.STATE_END then
        self.m_iTestDeltaTime = nil
    end
    self:InitGameTime(mNow) -- 不信任oHuodongMgr的输入（0点判断）
end

function CHuodong:GetGlobalConfig(sKey, rDefault)
    return table_get_depth(res, {"daobiao", "huodong", self.m_sName, "global_config", sKey}) or rDefault
end

function CHuodong:GetTimeConfig()
    return table_get_depth(res, {"daobiao", "huodong", self.m_sName, "time_ctrl"})
end

function CHuodong:GetQuestionConfig()
    return table_get_depth(res, {"daobiao", "huodong", self.m_sName, "questions"})
end

function CHuodong:GetAnswerWrongBianshenConfig()
    return table_get_depth(res, {"daobiao", "huodong", self.m_sName, "answer_wrong_bianshen"})
end

function CHuodong:GetSkillConfig(iSkillId)
    if iSkillId then
        return table_get_depth(res, {"daobiao", "huodong", self.m_sName, "skill", iSkillId})
    end
    return table_get_depth(res, {"daobiao", "huodong", self.m_sName, "skill"})
end

function CHuodong:GetSysRealTime(iTime)
    return iTime - (self.m_iTestDeltaTime or 0)
end

function CHuodong:GetSysTime()
    return get_time() + (self.m_iTestDeltaTime or 0)
end

function CHuodong:GetHuodongState()
    return self.m_iHuodongState
end

function CHuodong:SetHuodongState(iState)
    self.m_iHuodongState = iState
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime, self.m_iStartTime)
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:InHuodongTime()
    local iCurrTime = get_time()
    return iCurrTime > self.m_iStartTime and iCurrTime < self.m_iEndTime
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", self:GetSysTime())
    local hour,min= sTime:match('^(%d+)%:(%d+)')
    return os.time({
        year = mCurrDate.year,
        month = mCurrDate.month,
        day = mCurrDate.day,
        hour = tonumber(hour),
        min = tonumber(min),
        sec = 0,
    })
end

function CHuodong:GetOneHuodongTimeConfig(sEvent)
    local mTimeConfig = self:GetTimeConfig()
    for iWeekDay, lConfig in pairs(mTimeConfig) do
        for _, mConfig in ipairs(lConfig) do
            if mConfig.event == sEvent then
                return iWeekDay, mConfig
            end
        end
    end
end

function CHuodong:IsSysOpen()
    return global.oToolMgr:IsSysOpen("HFDM")
end

function CHuodong:InitGameTime(mNow)
    if not self:IsSysOpen() then
        -- 看看是否需要更新huodongState下行（删除日程）
        return
    end
    local iWeekDay = mNow and mNow.date.wday or get_weekday(self:GetSysTime())
    local mTimeConfig = self:GetTimeConfig()
    local lConfig = mTimeConfig[iWeekDay]
    if not lConfig then return end

    local iState, iResState
    for _, mConfig in ipairs(lConfig) do
        if mConfig.event == "prepare" then
            iState = self:GenPrepare(mConfig)
            if not iResState then
                iResState = iState
            end
        elseif mConfig.event == "game_start" then
            iState = self:GenGameStart(mConfig)
            if iState then
                iResState = iState
            end
        else
            record.warning("hfdm event [%s] not config", mConfig.event)
        end
    end
    if iResState then
        self:SetHuodongState(iResState)
    end
end

function CHuodong:RandomEnterPos()
    return self:RandomAnswerPos(0)
end

function CHuodong:RandomAnswerPos(iAnswer)
    local mRange
    if not iAnswer or iAnswer == 0 then
        mRange = self:GetGlobalConfig("enter_pos_range")
    elseif iAnswer == 1 then
        mRange = self:GetGlobalConfig("jump_left_pos_range")
    elseif iAnswer == 2 then
        mRange = self:GetGlobalConfig("jump_right_pos_range")
    else
        assert(nil, string.format("answer pos with answer: %s", iAnswer))
    end
    local rX = math.random(math.floor(mRange.x1 * 1000), math.floor(mRange.x2 * 1000)) / 1000
    local rY = math.random(math.floor(mRange.y1 * 1000), math.floor(mRange.y2 * 1000)) / 1000
    return rX, rY
end

function CHuodong:GetRandomAnswer()
    local iAnswer = math.random(1, 2)
    return iAnswer
end

function CHuodong:GetTheOtherAnswer(iPid)
    local iCurPosAnswer = self:GetPosAnswer(iPid)
    if iCurPosAnswer == 1 then
        return 2
    elseif iCurPosAnswer == 2 then
        return 1
    end
end

function CHuodong:GetAnswerPosName(iAnswer)
    if not iAnswer or iAnswer == 0 then
        return GetTextData(3101)
    elseif iAnswer == 1 then
        return GetTextData(3102)
    elseif iAnswer == 2 then
        return GetTextData(3103)
    end
end

function CHuodong:CheckEnterRoom(oPlayer)
    if self:GetHuodongState() ~= gamedefines.ACTIVITY_STATE.STATE_START then
        oPlayer:NotifyMessage(GetTextData(1001))
        return
    end
    if oPlayer:HasTeam() then
        oPlayer:NotifyMessage(GetTextData(1002))
        return
    end
    local iSysNeedGrade = global.oToolMgr:GetSysOpenPlayerGrade("HFDM")
    if oPlayer:GetGrade() < iSysNeedGrade then
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(1003), {grade = iSysNeedGrade}))
        return
    end
    if not global.oToolMgr:IsSysOpen("HFDM", oPlayer) then
        return
    end
    if self.m_oSceneCtrl:InRoom(oPlayer) then
        oPlayer:NotifyMessage(GetTextData(1004))
        return
    end
    local iPid = oPlayer:GetPid()
    if self:ToConfirmEnterRoom(oPlayer) then
        return
    end
    return true
end

function CHuodong:DoConfirmEnterRoom(oPlayer, iType)
    local iPid = oPlayer:GetPid()
    local mNet = self:GetTextData(1005)
    local func = function(oPlayer, mData)
        CancleAutoMatchToEnter(oPlayer, mData, iType)
    end
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mNet, nil, func)
end

AUTO_MATCH_TYPE = {
    NORMAL = 1,
    LINGXI = 2,
}

function CancleAutoMatchToEnter(oPlayer, mData, iType)
    if mData["answer"] ~= 1 then
        return
    end
    if iType == AUTO_MATCH_TYPE.NORMAL then
        handleteam.PlayerCancelAutoMatch(oPlayer)
    elseif iType == AUTO_MATCH_TYPE.LINGXI then
        local oLingxiHuodong = global.oHuodongMgr:GetHuodong("lingxi")
        if oLingxiHuodong then
            oLingxiHuodong:RemoveFromMatchTeamPool(oPlayer)
        end
    end
    local oHuodong = global.oHuodongMgr:GetHuodong("hfdm")
    oHuodong:EnterRoom(oPlayer)
end

function CHuodong:ToConfirmEnterRoom(oPlayer)
    -- 二次确认框取消自动组队再继续
    local bAutoMatching = oPlayer.m_oActiveCtrl:GetInfo("auto_matching", false)
    if bAutoMatching then
        self:DoConfirmEnterRoom(oPlayer, AUTO_MATCH_TYPE.NORMAL)
        return true
    end
    local oLingxiHuodong = global.oHuodongMgr:GetHuodong("lingxi")
    if oLingxiHuodong then
        if oLingxiHuodong:IsMatching(oPlayer:GetPid()) then
            self:DoConfirmEnterRoom(oPlayer, AUTO_MATCH_TYPE.LINGXI)
            return true
        end
    end
end

function CHuodong:EnterRoom(oPlayer)
    if not self:CheckEnterRoom(oPlayer) then
        return
    end
    local oRoom = self.m_oSceneCtrl:GetAbleRoom(iPid)
    if not oRoom then
        -- oPlayer:NotifyMessage("找不到房间")
        assert(nil, "hfdm find/create room fail, pid:" .. iPid)
    end

    self.m_oSkillMgr:TouchPlayer(oPlayer:GetPid())
    local mNowPos = oPlayer:GetNowPos()
    local iX, iY = self:RandomEnterPos()
    local mPos = table_deep_copy(mNowPos)
    mPos.x = iX
    mPos.y = iY
    oRoom:EnterScene(oPlayer, mPos)
    return true
end

function CHuodong:LeaveRoom(oPlayer)
    return self.m_oSceneCtrl:LeaveRoom(oPlayer)
end

function CHuodong:OnLeaveRoom(oPlayer, oScene, iNewScene, bLogout)
    oPlayer:Send("GS2CHfdmInScene", {is_in = 0})
    -- player:RemoveServState("hfdm") -- 不可坐骑，不可组队
    local iPid = oPlayer:GetPid()

    -- local iMapId = oScene:MapId()
    -- local sVirtual = table_get_depth(res, {"daobiao", "map", iMapId, "virtual_game"})
    -- if sVirtual == "hfdm" then return end

    self.m_oSkillMgr:HideShield(oPlayer)
    local iBianshenId = oPlayer.m_oActiveCtrl:GetData("_hfdm_bianshen")
    if iBianshenId then
        oPlayer:DelBianShenGroup(gamedefines.BIANSHEN_GROUP.HUODONG_HFDM)
    end
end

function CHuodong:OnEnterRoom(oPlayer, bReEnter, oScene, iFromSceneId)
    if not bReEnter then
        self:TouchUnRide(oPlayer)
        -- player:AddServState("hfdm") -- 不可坐骑，不可组队
        self:ReSyncInHuodong(oPlayer)
        self.m_oSkillMgr:ShowShield(oPlayer)
        local iBianshenId = oPlayer.m_oActiveCtrl:GetData("_hfdm_bianshen", 0)
        if iBianshenId ~= 0 then
            local iSec = self.m_iEndTime - get_time()
            local mSource = {type = "hfdm"}
            oPlayer:BianShen(iBianshenId, iSec, gamedefines.BIANSHEN_PRIORITY.HIGH, gamedefines.BIANSHEN_GROUP.HUODONG_HFDM, mSource)
        end
    end
end

function CHuodong:ReSyncInHuodong(oPlayer)
    local iPid = oPlayer:GetPid()
    oPlayer:Send("GS2CHfdmInScene", {is_in = 1})
    self:SendQuesInfo({[iPid] = 1})
    self:SendNeedCorrectRewardInfo(oPlayer)
    self:SendSkillInfo(oPlayer)
    interactive.Send(".rank", "rank", "SendHfdmRank", {one_pid = {[iPid]=1}})
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local iPid = oPlayer:GetPid()
    local oRoom = self.m_oSceneCtrl:GetPlayerInRoom(iPid)
    if oRoom then
        self:ReSyncInHuodong(oPlayer)
    end
    if not self.m_bDealHuodong then
        local iBianshenId = oPlayer.m_oActiveCtrl:GetData("_hfdm_bianshen")
        if iBianshenId then
            oPlayer.m_oActiveCtrl:SetData("_hfdm_bianshen", nil)
            oPlayer:DelBianShenGroup(gamedefines.BIANSHEN_GROUP.HUODONG_HFDM)
        end
    end
end

function CHuodong:TouchUnRide(oPlayer)
    if oPlayer.m_oRideCtrl:TouchUnRide() then
        oPlayer:NotifyMessage(GetTextData(1201))
    end
end

function CHuodong:GenPrepare(mConfig)
    local iStartTime = self:AnalyseTime(mConfig.start_time)
    local iCurrTime = self:GetSysTime()
    local iDeltaStart = iStartTime - iCurrTime
    self.m_iPrepareStartTime = self:GetSysRealTime(iStartTime)
    local iContinueSec = (mConfig.continue_min or 0) * 60
    if iContinueSec <= 0 then
        record.error("hfdm prepare time config error, continue_min:%s", mConfig.continue_min)
    end
    if iDeltaStart == 0 then
        iDeltaStart = 1
    end
    local iDeltaEnd = iDeltaStart + iContinueSec
    self.m_iPrepareEndTime = self.m_iPrepareStartTime + iContinueSec
    if iDeltaStart > 0 then
        if iDeltaStart < 3600 then
            self:DelTimeCb("PrepareStart")
            self:AddTimeCb("PrepareStart", iDeltaStart * 1000, function()
                self:PrepareStart(mConfig)
            end)
            self:DelTimeCb("PrepareEnd")
            self:AddTimeCb("PrepareEnd", iDeltaEnd * 1000, function()
                self:PrepareEnd(mConfig)
            end)
            -- -- 添加心跳提示活动准备
            -- local iNotifyPrepareSec = self:GetGlobalConfig("prepare_sec")
            -- self:DelTimeCb("NotifyPrepare")
            -- self:AddTimeCb("NotifyPrepare", (iDeltaEnd - iNotifyPrepareSec) * 1000, function()
            --     self:NotifyPrepare(mConfig)
            -- end)
        end
        return gamedefines.ACTIVITY_STATE.STATE_READY
    end
end

function CHuodong:NotifyPrepare(mConfig)
    self.m_iQuesState = QUES_STATE.QUES_ST_PREPARE
    self.m_iCurStepEndTimestamp = self.m_iStartTime
    self:SendQuesInfo(nil, {state = true})
end

function CHuodong:GenGameStart(mConfig)
    local iStartTime = self:AnalyseTime(mConfig.start_time)
    local iCurrTime = self:GetSysTime()
    local iDeltaStart = iStartTime - iCurrTime
    self.m_iStartTime = self:GetSysRealTime(iStartTime)
    local iContinueSec = (mConfig.continue_min or 0) * 60
    if iContinueSec <= 0 then
        record.error("hfdm prepare time config error, continue_min:%s", mConfig.continue_min)
    end
    if iDeltaStart == 0 then
        iDeltaStart = 1
    end
    local iDeltaEnd = iDeltaStart + iContinueSec
    self.m_iEndTime = self.m_iStartTime + iContinueSec
    if iDeltaStart > 0 then
        if iDeltaStart < 3600 then
            self:DelTimeCb("GameStart")
            self:AddTimeCb("GameStart", iDeltaStart * 1000, function()
                self:GameStart(mConfig)
            end)
            self:DelTimeCb("GameEnd")
            self:AddTimeCb("GameEnd", iDeltaEnd * 1000, function()
                self:GameEnd(mConfig)
            end)
        end
        return gamedefines.ACTIVITY_STATE.STATE_READY
    elseif iCurrTime >= self.m_iEndTime then
        return gamedefines.ACTIVITY_STATE.STATE_END
    else -- 执行期间无法开启活动
    end
end

function CHuodong:OnServerStartEnd()
    local mNow = get_timetbl()
    self:InitGameTime(mNow)
end

function CHuodong:IsOpenDay()
    if not self:IsSysOpen() then
        return false
    end
    -- local iWeekDay = get_morningweekday(self:GetSysTime())
    -- local iWeekDay = get_weekday(self:GetSysTime() - 5*3600)
    local iWeekDay = get_weekday(self:GetSysTime())
    local mTimeConfig = self:GetTimeConfig()
    for _, mConfig in pairs(mTimeConfig[iWeekDay] or {}) do
        if mConfig.event == "game_start" then
            return true
        end
    end
    return false
end

function CHuodong:SetSysTime(mArgs)
    local mCurrDate = os.date("*t", get_time())
    local iTestTime = os.time({
        year = mArgs.year or mCurrDate.year,
        month = mArgs.month or mCurrDate.month,
        day = mArgs.day or mCurrDate.day,
        hour = mArgs.hour or mCurrDate.hour,
        min = mArgs.min or mCurrDate.min,
        sec = mArgs.sec or 0,
    })
    self.m_iTestDeltaTime = iTestTime - get_time()
end

function CHuodong:TestOp(sFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not sFlag then
        global.oNotifyMgr:Notify(iPid, [[
        settime - 调时间 {day=15,hour=13,min=39,sec=40}
        curtime - 查看当前设置时间
        resettime - 重置时间
        game - 重新刷一下活动与日程
        stop - 结束活动
        resultrank - 结算结果再结束
        enter - 进入活动场景
        leave - 离开活动场景
        preparegame -  新一轮活动马上进入准备
        startgame - 新一轮活动马上进入答题
        ques - 重新出题
        answer - 回答 {answer=1}
        skill - 使用技能 {id=1001,target=<pid>}
        skillcd - 清空技能cd {id=1001}
        ]])
    elseif sFlag == "settime" then
        self:SetSysTime(mArgs)
    elseif sFlag == "curtime" then
        global.oNotifyMgr:Notify(iPid, get_time_format_str(self:GetSysTime(), "%y-%m-%d %H:%M:%S"))
    elseif sFlag == "resettime" then
        self.m_iTestDeltaTime = nil
    elseif sFlag == "enter" then
        if self:EnterRoom(oPlayer) then
            oPlayer:NotifyMessage("进房间成功")
        else
            oPlayer:NotifyMessage("进房间失败")
        end
    elseif sFlag == "leave" then
        if self:LeaveRoom(oPlayer) then
            oPlayer:NotifyMessage("离开房间成功")
        else
            oPlayer:NotifyMessage("离开房间失败")
        end
    elseif sFlag == "game" then
        local mNow = get_timetbl()
        self:InitGameTime(mNow)
    elseif sFlag == "stop" then
        self:GameEnd()
        self:Reset()
    elseif sFlag == "resultstop" then
        self:ToResultRank()
        self:DelTimeCb("_resultstop")
        self:AddTimeCb("_resultstop", 2000, function()
            self:GameEnd()
            self:Reset()
        end)
    elseif sFlag == "resultrank" then
        self:ToResultRank()
    elseif sFlag == "preparegame" then
        self:GameEnd()
        self:Reset()
        local iWeekDay, mTimeConfig = self:GetOneHuodongTimeConfig("prepare")
        local iStartTime = self:AnalyseTime(mTimeConfig.start_time)
        local mGmDate = os.date("*t", iStartTime - 1)
        self:SetSysTime({day=mGmDate.day,hour=mGmDate.hour,min=mGmDate.min,sec=mGmDate.sec})
        self:InitGameTime(get_wdaytime({wday=iWeekDay}))
        -- self:DelTimeCb("_test_enter")
        -- self:AddTimeCb("_test_enter", 1000, function()
        --     self:EnterRoom(oPlayer)
        -- end)
    elseif sFlag == "startgame" then
        self:GameEnd()
        self:Reset()
        local iWeekDay, mTimeConfig = self:GetOneHuodongTimeConfig("game_start")
        local iStartTime = self:AnalyseTime(mTimeConfig.start_time)
        -- local mGmDate = os.date("*t", iStartTime - 1)
        local mGmDate = os.date("*t", iStartTime)
        self:SetSysTime({day=mGmDate.day,hour=mGmDate.hour,min=mGmDate.min,sec=mGmDate.sec})
        self:InitGameTime(get_wdaytime({wday=iWeekDay}))
        -- self:DelTimeCb("_test_enter")
        -- self:AddTimeCb("_test_enter", 1000, function()
        --     self:EnterRoom(oPlayer)
        -- end)
    elseif sFlag == "ques" then
        self:Reset()
        -- self:SetSysTime({day=15,hour=13,min=44,sec=59})
        local iWeekDay, mTimeConfig = self:GetOneHuodongTimeConfig("game_start")
        local iStartTime = self:AnalyseTime(mTimeConfig.start_time)
        local mGmDate = os.date("*t", iStartTime)
        self:SetSysTime({day=mGmDate.day,hour=mGmDate.hour,min=mGmDate.min,sec=mGmDate.sec})
        self:InitGameTime(get_wdaytime({wday=iWeekDay}))
    elseif sFlag == "answer" then
        local iQuesId = self.m_lQuesList[self.m_iQuesRound]
        self:SelectAnswer(oPlayer, iQuesId, mArgs.answer)
    elseif sFlag == "skill" then
        local iSkillId = mArgs.id
        local iTarget = mArgs.target
        local iMyAnswer = mArgs.answer
        self:UseSkill(oPlayer, iSkillId, iTarget, iMyAnswer)
    elseif sFlag == "skillcd" then
        for iSkillId, oSkill in pairs(self.m_oSkillMgr.m_mPlayerSkills[iPid] or {}) do
            oSkill:ClearCd()
            self:SendSkillInfo(oPlayer)
        end
    end
end

function CHuodong:PrepareStart(mConfig)
    if not self:IsSysOpen() then
        return
    end
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self.m_iQuesState = QUES_STATE.QUES_ST_PREPARE
    self.m_iCurStepEndTimestamp = -1
    -- 传闻
    global.oChatMgr:HandleSysChat(GetTextData(8001), gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG)
    -- 提示活动开启改为从开始就提示
    self:NotifyPrepare(mConfig)
end

function CHuodong:PrepareEnd(mConfig)
end

function CHuodong:GameStart(mConfig)
    if not self:IsSysOpen() then
        if self:GetHuodongState() ~= gamedefines.ACTIVITY_STATE.STATE_START then
            return
        end
    end
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self.m_bQuesHuodongOn = true -- 答题玩法是否存在
    self.m_bDealHuodong = true -- 活动数据处理是否存在
    self:PrepareQuestions()
    self:BuildQuestion()
    self:TryBuildRank()
    self:TryStartRewardMonitor()
end

function CHuodong:GameEnd(mConfig)
    self.m_bQuesHuodongOn = nil
    local iCurState = self:GetHuodongState()
    if not iCurState or iCurState == gamedefines.ACTIVITY_STATE.STATE_END then
        return
    end
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    self:EndQuestion()
    if not self:TryEndHuodong() then
        return
    end
end

function CHuodong:TryEndHuodong()
    self:DelTimeCb("TryEndHuodong")
    -- 发奖可能导致活动的数据处理延期
    if self:HasBatch(TIME_BATCH.REWARD_QUES) or self:HasBatch(TIME_BATCH.CLEAR_BIANSHEN) then
        -- 这个判断下，其实可能存在self.m_lWinnerNames还没设值的情况，但一般意味着结束时间给的太少，ToResultRank的返回还没收到，不建议等待消息（可能会强行中断答题时间）
        self:AddTimeCb("TryEndHuodong", 2000, function()
            self:TryEndHuodong()
        end)
        return false
    end
    -- 重置自定义时间偏移，保证下一次开启正常
    self.m_iTestDeltaTime = nil
    self.m_bDealHuodong = nil
    self:ChuanwenEnd()
    self:DealWeekRank()
    self:Reset()
    self:Clear()
    self:TryStopRewardMonitor()
    return true
end

function CHuodong:OtherScript(iPid, npcobj, s, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    if s == "$leave" then
        self:LeaveRoom(oPlayer)
        return true
    elseif s == "$intro" then
        self:ShowIntro(oPlayer)
        return true
    else
        return super(CHuodong).OtherScript(self, iPid, npcobj, s, mArgs)
    end
end

function CHuodong:ShowIntro(oPlayer)
    oPlayer:Send("GS2CHfdmIntro", {})
end


----答题---------------------------------------

function CHuodong:PrepareQuestions()
    local iQuesCnt = self:GetGlobalConfig("ques_cnt")
    local mAllQuesData = self:GetQuestionConfig()
    iQuesCnt = math.min(iQuesCnt, table_count(mAllQuesData))
    local lQuesList = extend.Random.random_size(table_key_list(mAllQuesData), iQuesCnt)
    local mQuesConfig = {}
    for _, iQuesId in ipairs(lQuesList) do
        mQuesConfig[iQuesId] = {reverse = (math.random(0, 1) < 1)}
    end
    self.m_lQuesList = lQuesList
    self.m_mAllQuesConfig = mQuesConfig
end

function CHuodong:BuildQuestion()
    self:DelTimeCb("EndQuestion")
    local iQuesCnt = #self.m_lQuesList
    local iOneQuesSec = self:GetGlobalConfig("ques_answer_sec") + self:GetGlobalConfig("ques_wait_sec")
    self:AddTimeCb("EndQuestion", (iQuesCnt * iOneQuesSec) * 1000, function()
        self:EndQuestion()
    end)
    self:StartQuestion()
end

function CHuodong:StartQuestion()
    self.m_iQuesRound = 0
    self.m_iQuesState = QUES_STATE.QUES_ST_ANSWERING
    self:GoOnQuestions()
end

function CHuodong:EndQuestion()
    self:DelTimeCb("TailQuesEndWait")
    self:DelTimeCb("NextQuesWaiting")
    self:DelTimeCb("ToQuesShowAnswer")
    if self.m_iQuesState ~= QUES_STATE.QUES_ST_END then
        self.m_iQuesState = QUES_STATE.QUES_ST_END
    end
    self:StopBatch(TIME_BATCH.BIANSHEN)
    if not self:HasBatch(TIME_BATCH.CLEAR_BIANSHEN) then
        local fTickable = function()
            return self:IsClearBianshenTickable()
        end
        local fDeal = function()
            self:DealClearBianshen()
        end
        self:AsyncBatch(TIME_BATCH.CLEAR_BIANSHEN, 300, fTickable, fDeal)
    end
end

function CHuodong:IsClearBianshenTickable()
    return next(self.m_mContinuousAnswerWrong)
end

function CHuodong:DealClearBianshen()
    local iDealCnt = 400
    for _, iPid in ipairs(table_key_list(self.m_mContinuousAnswerWrong)) do
        if iDealCnt < 0 then
            return
        end
        self.m_mContinuousAnswerWrong[iPid] = nil
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local iBianshenId = oPlayer.m_oActiveCtrl:GetData("_hfdm_bianshen")
            if iBianshenId then
                oPlayer.m_oActiveCtrl:SetData("_hfdm_bianshen", nil)
                oPlayer:DelBianShenGroup(gamedefines.BIANSHEN_GROUP.HUODONG_HFDM)
                iDealCnt = iDealCnt - 1
            end
        end
    end
end

function CHuodong:GoOnQuestions()
    self.m_iQuesState = QUES_STATE.QUES_ST_ANSWERING
    self.m_iQuesRound = self.m_iQuesRound + 1
    local iQuesSec = self:GetGlobalConfig("ques_answer_sec")
    local iNow = get_time()
    self.m_iCurStepEndTimestamp = iNow + iQuesSec
    -- answering
    self:DelTimeCb("ToQuesShowAnswer")
    self:AddTimeCb("ToQuesShowAnswer", iQuesSec * 1000, function()
        self:ToQuesShowAnswer()
    end)
    local iQuesId = self.m_lQuesList[self.m_iQuesRound]
    local mQuesInfo = self.m_mAllQuesConfig[iQuesId]
    if mQuesInfo then
        mQuesInfo.starttime = iNow
    end
    self:SendQuesInfo(nil, {state = true, content = true})
end

function CHuodong:IsStateQuesTime()
    return self.m_iQuesState == QUES_STATE.QUES_ST_ANSWERING or self.m_iQuesState == QUES_STATE.QUES_ST_WAITING
end

function CHuodong:IsStateAnswering()
    return self.m_iQuesState == QUES_STATE.QUES_ST_ANSWERING
end

function CHuodong:PackQuesState()
    local mNet = {
        total_round = #self.m_lQuesList,
        state = self.m_iQuesState,
    }
    if self.m_iCurStepEndTimestamp < 0 then
        mNet.wait_sec = -1
    else
        mNet.wait_sec = self.m_iCurStepEndTimestamp - get_time()
        -- TODO 如果需要结束后加倒计时，此处处理状态
    end
    if self.m_iQuesState == QUES_STATE.QUES_ST_END then
        mNet.winners = self.m_lWinnerNames
    end
    return mNet
end

function CHuodong:PackQuesContent()
    local iQuesId = self.m_lQuesList[self.m_iQuesRound]
    if not iQuesId then
        return
    end
    local mQuesData = self:GetQuestionConfig()[iQuesId]
    if not mQuesData then
        return
    end
    local mNet = {
        round = self.m_iQuesRound,
        ques_id = iQuesId,
    }
    mNet.title = mQuesData.title
    local bReverse = table_get_depth(self.m_mAllQuesConfig, {iQuesId, "reverse"})
    local lChoices = table_copy(mQuesData.answers)
    if bReverse then
        lChoices = {lChoices[2], lChoices[1]}
    end
    mNet.choices = lChoices
    return mNet
end

function CHuodong:PackQuesAnswer()
    local iQuesId = self.m_lQuesList[self.m_iQuesRound]
    if not iQuesId then
        return
    end
    local mQuesData = self:GetQuestionConfig()[iQuesId]
    if not mQuesData then
        return
    end
    local iAnswer = self:GetQuesCorrectAnswer(iQuesId)
    local mNet = {
        ques_id = iQuesId,
        correct_answer = iAnswer,
    }
    return mNet
end

function CHuodong:GetQuesCorrectAnswer(iQuesId)
    local mQuesInfo = self.m_mAllQuesConfig[iQuesId]
    if mQuesInfo then
        if mQuesInfo.reverse then
            return 2
        else
            return 1
        end
    end
end

function CHuodong:SendQuesInfo(mPids, mActions)
    local mQuesState, mQuesContent, mQuesAnswer

    local bQuesState = not mActions or mActions.state
    local bQuesContent = (not mActions or mActions.content) and (self.m_iQuesState == QUES_STATE.QUES_ST_ANSWERING)
    local bQuesAnswer = (not mActions or mActions.answer) and (self.m_iQuesState == QUES_STATE.QUES_ST_WAITING) or (self.m_iQuesState == QUES_STATE.QUES_ST_END)
    if bQuesState then
        mQuesState = self:PackQuesState()
    end
    if bQuesContent then
        mQuesContent = self:PackQuesContent()
    end
    if bQuesAnswer then
        mQuesAnswer = self:PackQuesAnswer()
    end
    local iRound = self.m_iQuesRound
    local iQuesId = self.m_lQuesList[iRound]
    for iPid, iRoomNo in pairs(mPids or self.m_oSceneCtrl:GetPlayerRoomsInfo()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local iCorrectCnt = self:GetPlayerCorrectCnt(iPid)
            if mQuesState then
                mQuesState.correct_cnt = iCorrectCnt
                oPlayer:Send("GS2CHfdmQuesState", mQuesState)
            end
            if mQuesContent then
                oPlayer:Send("GS2CHfdmQuestion", mQuesContent)
            end
            if mQuesAnswer then
                local mAnswerNet = table_copy(mQuesAnswer)
                mAnswerNet.iscorrect = table_get_depth(self.m_mPlayerCorrect, {iPid, iRound}) and 1 or 0
                mAnswerNet.correct_cnt = iCorrectCnt
                mAnswerNet.my_answer = self:GetPlayerAnswer(iPid, iQuesId)
                oPlayer:Send("GS2CHfdmAnswerResult", mAnswerNet)
            end
        end
    end
end

function CHuodong:GetPlayerCorrectCnt(iPid)
    local mPCorrect = self.m_mPlayerCorrect[iPid]
    if not mPCorrect then
        return 0
    end
    return table_count(mPCorrect)
end

function _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    local oHuodong = global.oHuodongMgr:GetHuodong("hfdm")
    oHuodong:DelTimeCb(sBatchName)
    if fTickable() then
        oHuodong:AddTimeCb(sBatchName, iTickPeriod, function()
            _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
        end)
        fDeal()
    end
end

function CHuodong:AsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
end

function CHuodong:StopBatch(sBatchName)
    self:DelTimeCb(sBatchName)
end

function CHuodong:HasBatch(sBatchName)
    return self:GetTimeCb(sBatchName)
end

function CHuodong:IsQuesRewardTickable()
    return next(self.m_mRewardPlayers)
end

function CHuodong:DoRewardByEnv(iPid, iRound, mRewardEnv)
    local iQuesRwdId = mRewardEnv.correct and self:GetGlobalConfig("correct_rwd_tbl") or self:GetGlobalConfig("incorrect_rwd_tbl")
    self:ForceReward(iPid, iQuesRwdId, mRewardEnv)
    local bCountupReward = mRewardEnv.countup_rwd
    if bCountupReward then
        self:ForceReward(iPid, self:GetGlobalConfig("countup_rwd_tbl"), mRewardEnv)
    end
    self:RewardScore(iPid, mRewardEnv)
end

function CHuodong:ForceReward(iPid, iRewardId, mRewardEnv)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:Reward(iPid, iRewardId)
    else
        local mRewardInfo = self:GetRewardData(iRewardId)
        local iMailId = mRewardInfo.offline_mail
        if iMailId and iMailId > 0 then
            self:AsyncReward(iPid, iRewardId, function(mReward)
                self:RewardOffline(iPid, iMailId, mReward)
            end)
        end
    end
end

function CHuodong:RewardOffline(iPid, iMailId, mReward)
    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(iMailID)
    -- mData.context = global.oToolMgr:FormatColorString(mData.context, {rank = iRank})
    oMailMgr:SendMailNew(0, sName, iPid, mData, mReward)
end

function CHuodong:DealQuesReward()
    local lRoundList = table_key_list(self.m_mRewardPlayers)
    table.sort(lRoundList)
    local iDealCnt = 0
    for _, iRound in pairs(lRoundList) do
        for _, iPid in ipairs(table_key_list(self.m_mRewardPlayers[iRound])) do
            local mRewardEnv = table_get_depth(self.m_mRewardPlayers, {iRound, iPid})
            table_del_depth_casc(self.m_mRewardPlayers, {iRound}, iPid)
            iDealCnt = iDealCnt + 1
            safe_call(self.DoRewardByEnv, self, iPid, iRound, mRewardEnv)
            if iDealCnt > hfdmdefines.DEAL_PLAYERS_PER_TICK then
                return
            end
        end
    end
    -- 全部处理完
    self:TryResultRank()
end

function CHuodong:TryResultRank()
    -- 最后一轮题目答完才进行结算
    local iRound = self.m_iQuesRound
    if iRound ~= #self.m_lQuesList then
        return
    end
    local iQuesId = self.m_lQuesList[iRound]
    local mQuesInfo = self.m_mAllQuesConfig[iQuesId]
    if not mQuesInfo then
        record.warning("hfdm ques last round:%s, quesId:%s no data, cause ResultRank break", iRound, iQuesId)
        return
    end
    if not mQuesInfo.judged then
        return
    end
    self:ToResultRank()
end

function CHuodong:ToResultRank()
    interactive.Request(".rank", "rank", "GetBaikeWeekRankTop", {}, function (mRecord, mData)
        self:_ToResultRank(mData)
    end)
end

function CHuodong:_ToResultRank(mData)
    local lWinnerNames = {}
    for _, mUnit in ipairs(mData.net) do
        table.insert(lWinnerNames, mUnit.name)
    end
    self.m_lWinnerNames = lWinnerNames
    self:SendQuesInfo(nil, {state = true})
end

function CHuodong:ToQuesShowAnswer()
    if self.m_iQuesRound >= #self.m_lQuesList then
        local iLastQuesWaitSec = self:GetGlobalConfig("ques_last_wait_sec")
        -- self.m_iCurStepEndTimestamp = get_time() + iLastQuesWaitSec
        self.m_iCurStepEndTimestamp = -1 -- 结束倒计时无界面
        self.m_iQuesState = QUES_STATE.QUES_ST_END
        self:DelTimeCb("TailQuesEndWait")
        self:AddTimeCb("TailQuesEndWait", iLastQuesWaitSec * 1000, function()
            self:TailQuesEndWait()
        end)
    else
        local iQuesWaitSec = self:GetGlobalConfig("ques_wait_sec")
        self.m_iCurStepEndTimestamp = get_time() + iQuesWaitSec
        self.m_iQuesState = QUES_STATE.QUES_ST_WAITING
        self:DelTimeCb("NextQuesWaiting")
        self:AddTimeCb("NextQuesWaiting", iQuesWaitSec * 1000, function()
            self:GoOnQuestions()
        end)
    end
    self:DoJudgeAnswer()
    self:DoQuesShowAnswer()
end

function CHuodong:GetCurQuesId()
    local iRound = self.m_iQuesRound
    return self.m_lQuesList[iRound]
end

function CHuodong:GetPosAnswer(iPid)
    local iQuesId = self:GetCurQuesId()
    if not iQuesId then
        return nil
    end
    return self:GetPlayerAnswer(iPid, iQuesId)
    -- 后端不检查坐标
    -- local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    -- if not oPlayer then
    --     return
    -- end
    -- if not self.m_oSceneCtrl:GetPlayerInRoom(iPid) then
    --     return
    -- end
    -- local mNowPos = oPlayer:GetNowPos()
    -- local rLeftX = self:GetGlobalConfig("answer_left_judge_x")
    -- local rRightX = self:GetGlobalConfig("answer_right_judge_x")
    -- if mNowPos.x < rLeftX then
    --     return 1
    -- elseif mNowPos.x > rRightX then
    --     return 2
    -- end
end

function CHuodong:GetPlayerAnswer(iPid, iQuesId)
    return table_get_depth(self.m_mAllQuesConfig, {iQuesId, "select", iPid, "answer"})
end

function CHuodong:DoJudgeAnswer()
    local iRound = self.m_iQuesRound
    local iQuesId = self.m_lQuesList[iRound]
    local mQuesInfo = self.m_mAllQuesConfig[iQuesId]
    if not mQuesInfo then
        record.warning("hfdm ques round:%s, quesId:%s no data, cause judge break", iRound, iQuesId)
        return
    end
    local iCorrectAnswer
    mQuesInfo.judged = true
    if mQuesInfo.reverse then
        iCorrectAnswer = 2
    else
        iCorrectAnswer = 1
    end
    local mQuesSelects = mQuesInfo.select
    local iCountupRwdId = self:GetGlobalConfig("countup_rwd_tbl")
    if mQuesSelects then
        for iPid, mSelect in pairs(mQuesSelects) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            -- 后端不检查坐标
            local iPosAnswer = mSelect.answer
            -- local iPosAnswer = self:GetPosAnswer(iPid)
            -- if not iPosAnswer then
            --     -- 弃权
            --     goto continue_answer
            -- end
            -- if iPosAnswer ~= mSelect.answer then
            --     mSelect.answer = iPosAnswer
            --     mSelect.time = nil
            --     if oPlayer then
            --         oPlayer:Send("GS2CHfdmSelectAnswer", {ques_id = iQuesId, select = iPosAnswer})
            --     end
            -- end
            local bCorrect = (iPosAnswer == iCorrectAnswer)
            local iCorrectCnt
            local bCountupRewardable
            if bCorrect then
                self:RecAnswerCorrect(iPid)
                if oPlayer then
                    -- oPlayer:NotifyMessage("回答正确")
                    oPlayer:NotifyMessage(GetTextData(1103))
                    -- 累积奖励UI
                    self:SendNeedCorrectRewardInfo(oPlayer)
                end
            else
                self:RecAnswerWrong(iPid)
                if oPlayer then
                    -- oPlayer:NotifyMessage("回答错误")
                    oPlayer:NotifyMessage(GetTextData(1104))
                end
            end
            local mRewardEnv = self:GetQuesRewardEnv(iPid, mQuesInfo, mSelect, bCorrect)
            table_set_depth(self.m_mRewardPlayers, {iRound}, iPid, mRewardEnv)
            ::continue_answer::
        end
    end
end

function CHuodong:SendNeedCorrectRewardInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    local iCorrectCnt = self:GetPlayerCorrectCnt(iPid)
    local iCountupTotal, iCountupNeed, bCountupRewardable = self:GetCountupState(iCorrectCnt)
    oPlayer:Send("GS2CHfdmNeedCorrectRewardInfo", {
        total_cnt = iCountupTotal,
        need_cnt = iCountupNeed,
        rewardid = iCountupRwdId,
    })
end

function CHuodong:RecAnswerCorrect(iPid)
    table_set_depth(self.m_mPlayerCorrect, {iPid}, self.m_iQuesRound, true)
    self.m_mContinuousAnswerWrong[iPid] = nil
    self:TouchRecoverBianshen(iPid)
    self:StartAnswerWrongBianshenBeat()
end

function CHuodong:TouchRecoverBianshen(iPid)
    -- 恢复变身
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    self.m_mToBianshen[iPid] = 0
end

function CHuodong:TouchAnswerWrongBianshen(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local iWrongCnt = table_get_depth(self.m_mContinuousAnswerWrong, {iPid, "continunous_cnt"}) or 0
    local iBianshenId = self:GetBianshenId(iWrongCnt)
    if not iBianshenId then
        return
    end
    self.m_mToBianshen[iPid] = iBianshenId
end

function CHuodong:RecAnswerWrong(iPid)
    -- 计数变身
    local mWrong = table_get_set_depth(self.m_mContinuousAnswerWrong, {iPid})
    if mWrong.last_round == self.m_iQuesRound then
        return
    end
    mWrong.last_round = self.m_iQuesRound
    mWrong.continunous_cnt = (mWrong.continunous_cnt or 0) + 1
    self:TouchAnswerWrongBianshen(iPid)
    self:StartAnswerWrongBianshenBeat()
end

function CHuodong:StartAnswerWrongBianshenBeat()
    if not self:HasBatch(TIME_BATCH.BIANSHEN) and self:IsTouchBianshenTickable() then
        local fTickable = function()
            return self:IsTouchBianshenTickable()
        end
        local fDeal = function()
            self:DealTouchBianshen()
        end
        self:AsyncBatch(TIME_BATCH.BIANSHEN, 300, fTickable, fDeal)
    end
end

function CHuodong:IsTouchBianshenTickable()
    return next(self.m_mToBianshen)
end

function CHuodong:DealTouchBianshen()
    local iDealWeight = 2000
    local iSec = self.m_iEndTime - get_time()
    local mSource = {type = "hfdm"}
    for _, iPid in pairs(table_key_list(self.m_mToBianshen)) do
        if iDealWeight < 0 then
            return
        end
        local iBianshenId = self.m_mToBianshen[iPid]
        self.m_mToBianshen[iPid] = nil
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then
            goto continue_bianshen
        end
        if oPlayer.m_oActiveCtrl:GetData("_hfdm_bianshen") then
            oPlayer.m_oActiveCtrl:SetData("_hfdm_bianshen", nil)
            oPlayer:DelBianShenGroup(gamedefines.BIANSHEN_GROUP.HUODONG_HFDM)
            iDealWeight = iDealWeight - 3
        end
        if iSec <= 0 or iBianshenId == 0 then
            goto continue_bianshen
        end
        if oPlayer:BianShen(iBianshenId, iSec, gamedefines.BIANSHEN_PRIORITY.HIGH, gamedefines.BIANSHEN_GROUP.HUODONG_HFDM, mSource) then
            oPlayer.m_oActiveCtrl:SetData("_hfdm_bianshen", iBianshenId)
        end
        iDealWeight = iDealWeight - 10
        ::continue_bianshen::
    end
end

function CHuodong:GetBianshenId(iWrongCnt)
    local mAnswerWrongBianshenConfig = self:GetAnswerWrongBianshenConfig()
    local lCnts = table_key_list(mAnswerWrongBianshenConfig)

    table.sort(lCnts, function(a,b) return a>b end)
    for _, iCnt in ipairs(lCnts) do
        if iWrongCnt >= iCnt then
            return table_get_depth(mAnswerWrongBianshenConfig, {iCnt, "bianshen"})
        end
    end
end

function CHuodong:DoQuesShowAnswer()
    -- send answer
    self:SendQuesInfo(nil, {state = true, answer = true})
    -- batch reward，若当前有处理心跳，则使用当前心跳即可
    if not self:HasBatch(TIME_BATCH.REWARD_QUES) and self:IsQuesRewardTickable() then
        local fTickable = function()
            return self:IsQuesRewardTickable()
        end
        local fDeal = function()
            self:DealQuesReward()
        end
        self:AsyncBatch(TIME_BATCH.REWARD_QUES, hfdmdefines.DEAL_TICK_MS, fTickable, fDeal)
    end
    self:TryBuildRank()
end

function CHuodong:TailQuesEndWait()
    self:EndQuestion()
    self.m_iCurStepEndTimestamp = -1
    self:SendQuesInfo(nil, {state = true})
end

function CHuodong:CanSelectAnswer(oPlayer, iQuesId, iAnswer)
    if not iQuesId then
        return
    end
    -- if not iAnswer or iAnswer == 0 then
    --     oPlayer:NotifyMessage("请选择答案")
    --     return
    -- end
    if self.m_iQuesState ~= QUES_STATE.QUES_ST_ANSWERING then
        -- oPlayer:NotifyMessage(GetTextData(1101))
        return
    end
    local iRound = self.m_iQuesRound
    if iQuesId ~= self.m_lQuesList[iRound] then
        oPlayer:NotifyMessage(GetTextData(1102))
        return
    end
    return true
end

-- 假选坐标区域答案，用于在无视答题时间设置玩家的选项区(视为坐标)
function CHuodong:DoSetPosFakeSelect(oPlayer, iMyAnswer)
    local iPid = oPlayer:GetPid()
    if iMyAnswer <= 0 then
        iMyAnswer = nil
    end
    self.m_mPosFakeSelect[iPid] = iMyAnswer
end

function CHuodong:GetPosFakeSelect(iPid)
    return self.m_mPosFakeSelect[iPid]
end

function CHuodong:EnsureSkillSelect(oPlayer, iMyAnswer)
    local iQuesId = self:GetCurQuesId()
    if self:CanSelectAnswer(oPlayer, iQuesId, iAnswer) then
        self:DoSelectAnswer(oPlayer, iQuesId, iAnswer)
    end
    self:DoSetPosFakeSelect(oPlayer, iMyAnswer)
end

function CHuodong:SelectAnswer(oPlayer, iQuesId, iAnswer)
    if not self:CanSelectAnswer(oPlayer, iQuesId, iAnswer) then
        oPlayer:Send("GS2CHfdmSelectAnswer", {ques_id = iQuesId})
        return
    end
    self:DoSelectAnswer(oPlayer, iQuesId, iAnswer)
end

function CHuodong:DoSelectAnswer(oPlayer, iQuesId, iAnswer)
    local iPid = oPlayer:GetPid()
    local mQuesSelects = table_get_set_depth(self.m_mAllQuesConfig, {iQuesId, "select"})
    local mOldAnswer = mQuesSelects[iPid]
    if mOldAnswer and mOldAnswer.answer == iAnswer then
        oPlayer:Send("GS2CHfdmSelectAnswer", {ques_id = iQuesId, select = iAnswer})
        return
    end
    -- 支持中途弃权
    if not iAnswer or iAnswer == 0 then
        mQuesSelects[iPid] = nil
    else
        mQuesSelects[iPid] = {time = get_time(), answer = iAnswer}
    end
    oPlayer:Send("GS2CHfdmSelectAnswer", {ques_id = iQuesId, select = iAnswer})
end

-- @return: total_cnt, need_cnt, rewardable
function CHuodong:GetCountupState(iCorrectCnt)
    local iCountupRwdTimes = self:GetGlobalConfig("countup_rwd_times")
    local iCountupCnt = self:GetGlobalConfig("countup_cnt")
    local iMax = iCountupRwdTimes * iCountupCnt
    if iCorrectCnt > iMax then
        return 0, 0, false
    elseif iCountupCnt == iMax then
        return 0, 0, true
    end
    local iNeed = iCorrectCnt % iCountupCnt -- 正向计数
    return iCountupCnt, iNeed, iCountupCnt == iNeed
end

function CHuodong:GetQuesRewardEnv(iPid, mQuesInfo, mSelect, bCorrect)
    local iStartTime = mQuesInfo.starttime or 0
    local iAnswerTime = mSelect.time
    local iCostTime
    if iAnswerTime then
        iCostTime = iAnswerTime - iStartTime
    else
        iCostTime = self:GetGlobalConfig("ques_answer_sec")
    end
    if iCostTime < 0 then iCostTime = 0 end
    local iCorrectCnt = self:GetPlayerCorrectCnt(iPid)
    local bCountupRewardable
    if bCorrect then
        local iCountupTotal, iCountupNeed
        iCountupTotal, iCountupNeed, bCountupRewardable = self:GetCountupState(iCorrectCnt)
    end
    return {costtime = iCostTime, correct = bCorrect, correct_cnt = iCorrectCnt, countup_rwd = bCountupRewardable}
end

function CHuodong:CalcScore(iPid, mRewardEnv)
    if mRewardEnv.correct then
        local sFormula = self:GetGlobalConfig("score")
        return math.floor(formula_string(sFormula, mRewardEnv))
    end
    return 0
end

function CHuodong:RewardScore(iPid, mRewardEnv)
    local iScore = self:CalcScore(iPid, mRewardEnv)
    if iScore == 0 then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        -- 当前离线保护时间比较久，应当不会需要做离线玩家奖励
        return
    end
    local iWeekScore = oPlayer.m_oThisWeek:Query("baike_weekscore", 0)
    iWeekScore = iWeekScore + iScore
    oPlayer.m_oThisWeek:Set("baike_weekscore", iWeekScore)
    -- 榜推到排行服
    local oBaikeHuodong = global.oHuodongMgr:GetHuodong("baike")
    oBaikeHuodong:PushDataToBaikeRank(oPlayer, iWeekScore)
end

function CHuodong:TryBuildRank()
    if not self:HasBatch(TIME_BATCH.RANK_BROADCAST) and self:IsRankBroadcastTickable() then
        local fTickable = function()
            return self:IsRankBroadcastTickable()
        end
        local fDeal = function()
            self:DealRankBroadcast()
        end
        self:AsyncBatch(TIME_BATCH.RANK_BROADCAST, 5000, fTickable, fDeal)
    end
end

function CHuodong:IsRankBroadcastTickable()
    return self.m_bDealHuodong or self:IsQuesRewardTickable()
end

function CHuodong:DealRankBroadcast()
    local mPids = {}
    for iPid, _ in pairs(self.m_oSceneCtrl:GetPlayerRoomsInfo()) do
        mPids[iPid] = 1
    end
    if not next(mPids) then
        return
    end
    interactive.Send(".rank", "rank", "SendHfdmRank", {pids = mPids})
end

function CHuodong:ChuanwenEnd()
    local lWinnerNames = self.m_lWinnerNames or {}
    if not next(lWinnerNames) then
        record.info("hfdm end with no champion")
        local sMsg, iChuanwenHorse = global.oChatMgr:GetChuanwenMsg(1077)
        if sMsg then
            global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iChuanwenHorse)
        end
        return
    end
    local sMsg, iChuanwenHorse = global.oChatMgr:GetChuanwenMsg(1076)
    if not sMsg then
        return
    end
    sMsg = global.oToolMgr:FormatColorString(sMsg, {role = table.concat(lWinnerNames, "、")})
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iChuanwenHorse)
end

-- 发六道&灯谜总榜单奖励
function CHuodong:DealWeekRank()
    local iCurWeekNo = get_morningweekno(self:GetSysTime())
    if self.m_iHasRewardedRankWeekNo == iCurWeekNo then
        return
    end
    self.m_iHasRewardedRankWeekNo = iCurWeekNo
    self:Dirty()
    local oBaikeHuodong = global.oHuodongMgr:GetHuodong("baike")
    oBaikeHuodong:DealWeekRank()
end

------------------------------

function CHuodong:UseSkill(oPlayer, iSkillId, iTarget, iMyAnswer)
    local iPid = oPlayer:GetPid()
    self:EnsureSkillSelect(oPlayer, iMyAnswer)
    local bSucc, iErr, bResync = self.m_oSkillMgr:TryUseSkill(oPlayer, iSkillId, iTarget)
    -- PS. 调用放在skill内
    -- if not bSucc then
    --     self:NotifySkillErr(oPlayer, iErr)
    --     return
    -- end
    if bResync then
        self:SendSkillInfo(oPlayer)
    end
end

function CHuodong:NotifySkillErr(oPlayer, iErr, sSkillName)
    local sMsg
    if iErr == hfdmdefines.ERR_USE_SKILL.IN_CD then
        sMsg = GetTextData(3001)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {skill = sSkillName})
    elseif iErr == hfdmdefines.ERR_USE_SKILL.TARGET_FAIL then
        sMsg = GetTextData(3002)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {skill = sSkillName})
    elseif iErr == hfdmdefines.ERR_USE_SKILL.GIVE_UP then
        sMsg = GetTextData(3003)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {skill = sSkillName})
    elseif iErr == hfdmdefines.ERR_USE_SKILL.IN_SHIELD then
        sMsg = GetTextData(3004)
    elseif iErr == hfdmdefines.ERR_USE_SKILL.NO_SKILL then
        sMsg = GetTextData(3005)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {skill = sSkillName})
    elseif iErr == hfdmdefines.ERR_USE_SKILL.TIME_ERR then
        sMsg = GetTextData(3006)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {skill = sSkillName})
    elseif iErr == hfdmdefines.ERR_USE_SKILL.TARGET_OFFLINE then
        sMsg = GetTextData(3007)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {skill = sSkillName})
    end
    oPlayer:NotifyMessage(sMsg)
end

function CHuodong:PackSkillInfo(iPid)
    return self.m_oSkillMgr:PackSkillInfo(iPid)
end

function CHuodong:SendSkillInfo(oPlayer)
    oPlayer:Send("GS2CHfdmSkillStatus", {skills = self:PackSkillInfo(oPlayer:GetPid())})
end
