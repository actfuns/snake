local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local taskdefines = import(service_path("task/taskdefines"))

local FIRSTSTAGE_TASK_ID = 622501

local STATE_CLOSE = 0
local STATE_FIRSTSTAGE = 1
local STATE_FIRSTSTAGE_CLOSE = 2
local STATE_SECONDSTAGE = 3

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "天问答题"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    local mNow = get_timetbl()
    self.m_iOpenDayID = 0
    self.m_iScheduleID = 1041
    self.m_iState = STATE_CLOSE
    self.m_mQuestion = {}
    self.m_mUseTime = {}
    self:NewDay(mNow)
end

function CHuodong:NeedSave()
    return false
end

function CHuodong:Save()
end

function CHuodong:Load(mData)
end

function CHuodong:GetHuodongTextData(oPlayer, iText)
    local sText = self:GetTextData(iText)
    if iText == 1015 or iText == 1007 then
        local oTask = self:GetHuodongTask(oPlayer)
        if oTask then
            local iCurRound = self:GetCurRound(oPlayer:GetPid())
            if iCurRound > self:GetTotalRound() then return end
            local oValidNpc = self:GetNpcObjByRound(oPlayer:GetPid(), iCurRound)
            local sValidNpcName = oValidNpc:Name()
            sText = global.oToolMgr:FormatColorString(sText, {npcname = sValidNpcName})
        else
            return nil
        end
    elseif iText == 1008 then
        local oValidNpc = global.oNpcMgr:GetGlobalNpc(5304)
        local sValidNpcName = oValidNpc:Name()
        sText = global.oToolMgr:FormatColorString(sText, {npcname = sValidNpcName})
    end
    return sText
end

function CHuodong:ValidGiveTask(oPlayer)
    if not global.oToolMgr:IsSysOpen("IMPERIALEXAM", oPlayer, false) then
        return 1
    end
    if self:GetGameState() == STATE_CLOSE or self:GetGameState() == STATE_FIRSTSTAGE_CLOSE then
        return 1004
    end
    if self.m_iOpenDayID == 0 then
        return 1004
    end

    -- if oPlayer:HasTeam() then
    --     return 1014
    -- end

    if self:GetHuodongTask(oPlayer) then
        return 1015
    end
    
    if self:GetGameState() == STATE_FIRSTSTAGE then
        local pid = oPlayer:GetPid()
        local mPlayerQuestion = self.m_mQuestion[pid]
        if mPlayerQuestion and mPlayerQuestion.curround > self:GetTotalRound() then 
            return 1009 
        end
        return 1005
    end

    if self:GetGameState() == STATE_SECONDSTAGE then
        local pid = oPlayer:GetPid()
        local mPlayerQuestion = self.m_mQuestion[pid]
        if mPlayerQuestion and mPlayerQuestion.curround > self:GetTotalRound() then
            return 1010
        end
        if not self.m_mSecondStagePid[pid] then
            return 1011
        end
        return 1006
    end

    return 1
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:SetGameState(iState)
    self.m_iState = iState
end

function CHuodong:IsFirstStage()
    return self:GetGameState() == STATE_FIRSTSTAGE
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local mNet = {}
    mNet.state = self:GetGameState()
    oPlayer:Send("GS2CImperialexamState", mNet)
end

-- 活动是否开启的入口
function CHuodong:NewDay(mNow)
    mNow = mNow or get_timetbl()
    local mConfig = self:GetTimeConfig()
    for index, mData in pairs(mConfig) do
        if mNow.date.wday == mData["open_day"] then
            self.m_iOpenDayID = index
            self:SetHuodongTime()
            global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_READY, mData["firststage_opentime"], nil)
            self:CheckAddTimer(mNow)
            return
        end
    end
end

function CHuodong:NewHour(mNow)
    self:CheckAddTimer(mNow)
end

function CHuodong:SetHuodongTime()
    if self.m_iOpenDayID == 0 then return end
    local mConfig = self:GetTimeConfig()[self.m_iOpenDayID]
    self.m_iFirststageOpentime = self:AnalyseTime(mConfig["firststage_opentime"])
    self.m_iFirststageClosetime = self:AnalyseTime(mConfig["firststage_closetime"])
    self.m_iSecondstageOpentime = self:AnalyseTime(mConfig["secondstage_opentime"])
    self.m_iSecondstageClosetime = self:AnalyseTime(mConfig["secondstage_closetime"])
end

function CHuodong:GetFirststageClosetime()
    return self.m_iFirststageClosetime
end

function CHuodong:CheckAddTimer(mNow)
    if self.m_iOpenDayID == 0 then return end
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetTimeConfig()[self.m_iOpenDayID]
    local iCurState = self:GetGameState()
    local iFirstStageOpen = self.m_iFirststageOpentime
    local iFirstStageClose = self.m_iFirststageClosetime
    local iSecondStageOpen = self.m_iSecondstageOpentime
    local iSecondStageClose = self.m_iSecondstageClosetime

    if iCurState == STATE_CLOSE then
        local iCheckTime = iFirstStageOpen
        local iDelta = iCheckTime - iTime
        local sTimerName = "IMPERIALEXAM_FIRST_START"
        -- 开启活动的定时器
        if iDelta > 0 and iDelta <= 3600 then
            self:DelTimeCb(sTimerName)
            self:AddTimeCb(sTimerName, iDelta * 1000, function()
                self:StartFirstStage()
            end)
        end
    end
    if iTime >= iFirstStageOpen and iTime <= iFirstStageClose then
        if iCurState == STATE_FIRSTSTAGE then
            local iCheckTime = iFirstStageClose
            local iDelta = iCheckTime - iTime
            local sTimerName = "IMPERIALEXAM_FIRST_END"
            if iDelta <= 0 then
                self:DelTimeCb(sTimerName)
                self:EndFirstStage()
            elseif iDelta >0 and iDelta <= 3600 then
                self:DelTimeCb(sTimerName)
                self:AddTimeCb(sTimerName, iDelta * 1000, function()
                    self:EndFirstStage()
                end)
            end
        end
    end
    if iTime >= iSecondStageOpen and iTime <= iSecondStageClose then
        if iCurState == STATE_FIRSTSTAGE_CLOSE then
            local iCheckTime = iSecondStageOpen
            local iDelta = iCheckTime - iTime
            local sTimerName = "IMPERIALEXAM_SECOND_START"
            if iDelta <= 0 then
                self:DelTimeCb(sTimerName)
                self:StartSecondStage()
            elseif iDelta > 0 and iDelta <= 3600 then
                self:DelTimeCb(sTimerName)
                self:AddTimeCb(sTimerName, iDelta * 1000, function()
                    self:StartSecondStage()
                end)
            end
        elseif iCurState == STATE_SECONDSTAGE then
            local iCheckTime = iSecondStageClose
            local iDelta = iCheckTime - iTime
            local sTimerName = "IMPERIALEXAM_SECOND_END"
            if iDelta <= 0 then
                self:DelTimeCb(sTimerName)
                self:EndSecondStage()
            elseif iDelta > 0 and iDelta <= 3600 then
                self:DelTimeCb(sTimerName)
                self:AddTimeCb(sTimerName, iDelta * 1000, function()
                    self:EndSecondStage()
                end)
            end
        end
    end
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", get_time())
    local hour, min = sTime:match('^(%d+):(%d+)')
    mCurrDate.hour = tonumber(hour)
    mCurrDate.min = tonumber(min)
    mCurrDate.sec = 0
    return os.time(mCurrDate)
end

function CHuodong:StartFirstStage()
    self:SetGameState(STATE_FIRSTSTAGE)
    local mTimeConf = self:GetTimeConfig()
    local sTime = mTimeConf[self.m_iOpenDayID]["firststage_opentime"]
    self.m_mTempRandomList = {}
    local iTotal = self:GetTotalRound()
    for i = 1, 2 * iTotal do
        table.insert(self.m_mTempRandomList, i)
    end
    self:InitNpc()
    self:CheckAddTimer()
    local mNet = {}
    mNet.state = self:GetGameState()
    global.oNotifyMgr:WorldBroadcast("GS2CImperialexamState", mNet)
    self.m_iScheduleID = 1041
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_START, sTime, nil)
    self:SysAnnounce(1105, {})
    record.info("imperialexam firststage start")
end

function CHuodong:CreateTempNpc(iTempNpc, pid)
    local oTempNpc = super(CHuodong).CreateTempNpc(self, iTempNpc, pid)
    local iNpcType = oTempNpc:Type()
    if not self.m_mNpcIDListByType[iNpcType] then
        self.m_mNpcIDListByType[iNpcType] = {}
        table.insert(self.m_mNpcIDListByType[iNpcType], oTempNpc:ID())
    else
        table.insert(self.m_mNpcIDListByType[iNpcType], oTempNpc:ID())
    end
    return oTempNpc
end

function CHuodong:InitNpc()
    self.m_mNpcIDListByType = {}
    local mConfig = self:GetNpcConfig()
    for iTempNpc, mNpcData in pairs(mConfig) do
        local oNpc = self:CreateTempNpc(iTempNpc)
        self:Npc_Enter_Map(oNpc)
    end
end

function CHuodong:GetNpcObjByRound(pid, iRound)
    local mConfig = self:GetNpcConfig()
    if not mConfig[iRound + 1000] then return end
    local iNpcType = iRound + 1000
    local lNpcList = self.m_mNpcIDListByType[iNpcType]
    local iLength = #lNpcList
    local iNpcID
    if iLength == 1 then
        iNpcID = lNpcList[1]
    else 
        iNpcID = lNpcList[pid % iLength]
    end
    local oNpc = self:GetNpcObj(iNpcID)
    return oNpc
end

function CHuodong:EndFirstStage()
    self:SetGameState(STATE_FIRSTSTAGE_CLOSE)
    for _,oNpc in pairs(self.m_mNpcList) do
        self:RemoveTempNpc(oNpc)
    end
    -- 清除玩家身上任务
    local lAllOnlinePid = {}
    for pid , _ in pairs(self.m_mQuestion) do
        table.insert(lAllOnlinePid, pid)
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid, 400, 1000, 0, "ImperialexamTaskAbandon",function (pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        local oTask = self:GetHuodongTask(oPlayer)
        if oTask then
            oTask:Abandon()
        end
        local sMsg = self:GetTextData(1016)
        global.oNotifyMgr:Notify(pid, sMsg)
    end)
    self.m_mUseTime = {}
    self.m_mQuestion = {}
    self.m_mNpcIDListByType = {}
    self:Dirty()
    self:RemoteQueryRank("imperialexam_firststage")
    local mNet = {}
    mNet.state = self:GetGameState()
    global.oNotifyMgr:WorldBroadcast("GS2CImperialexamState", mNet)
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_END, sTime, nil)
end

function CHuodong:AfterRemoteQueryRank()
    if  self:GetGameState() == STATE_FIRSTSTAGE_CLOSE then
        local mTimeConf = self:GetTimeConfig()
        local mConfig = self:GetConfig()
        local mMailData, sMailName = global.oMailMgr:GetMailInfo(2077)
        mMailData.context = global.oToolMgr:FormatColorString(mMailData.context, { start_time = mTimeConf[self.m_iOpenDayID]["secondstage_opentime"], end_time = mTimeConf[self.m_iOpenDayID]["secondstage_closetime"]})
        
        for index = 1, math.min(mConfig.qualification, #self.m_mMailPidList) do
            local pid = self.m_mMailPidList[index].pid
            global.oMailMgr:SendMailNew(0, sMailName, pid, mMailData)
        end
        mMailData, sMailName = global.oMailMgr:GetMailInfo(2078)
        for index = mConfig.qualification + 1, #self.m_mMailPidList do
            local pid = self.m_mMailPidList[index].pid
            global.oMailMgr:SendMailNew(0, sMailName, pid, mMailData)
        end
        self:SysAnnounce(1107, {})
        record.info("imperialexam firststage end")
        self:CheckAddTimer()
    elseif self:GetGameState() == STATE_CLOSE then
        local mRewardConf = self:GetTop3Reward()
        local oToolMgr = global.oToolMgr
        for index = 1, 3 do
            if not self.m_mMailPidList[index] then
                break
            else
                local pid = self.m_mMailPidList[index].pid
                local mMailData, sMailName = global.oMailMgr:GetMailInfo(2079)
                mMailData.title = oToolMgr:FormatColorString(mMailData.title, {title = mRewardConf[index].title})
                mMailData.context = oToolMgr:FormatColorString(mMailData.context, {title = mRewardConf[index].title})
                local lItemIdx = self:RewardId2ItemIdx(mRewardConf[index].reward_id)
                local mItemList = self:InitMailRewardItem(pid, lItemIdx)
                local mMailReward = {}
                mMailReward["items"] = mItemList
                global.oMailMgr:SendMailNew(0, sMailName, pid, mMailData, mMailReward)
            end
        end
        local mMailData, sMailName = global.oMailMgr:GetMailInfo(2080)
        local lItemIdx = self:RewardId2ItemIdx(mRewardConf[4].reward_id)
        for index = 4, #self.m_mMailPidList do
            local pid = self.m_mMailPidList[index].pid
            local mItemList = self:InitMailRewardItem(pid, lItemIdx)
            local mMailReward = {}
            mMailReward["items"] = mItemList
            global.oMailMgr:SendMailNew(0, sMailName, pid, mMailData, mMailReward)
        end
        -- 传闻
        local iLength = #self.m_mMailPidList
        if iLength >= 3 then
            self:SysAnnounce(1108, {player1 = self.m_mMailPidList[1].name, player2 = self.m_mMailPidList[2].name, player3 = self.m_mMailPidList[3].name})
        elseif iLength >= 2 then
            self:SysAnnounce(1109, {player1 = self.m_mMailPidList[1].name, player2 = self.m_mMailPidList[2].name})
        elseif iLength >= 1 then
            self:SysAnnounce(1110, {player1 = self.m_mMailPidList[1].name})
        else
            self:SysAnnounce(1111,{})
        end
        record.info("imperialexam secondstage end")
    end
end

function CHuodong:StartSecondStage()
    self:SetGameState(STATE_SECONDSTAGE)
    self.m_mTempRandomList = {}
    local iTotal = self:GetTotalRound()
    for i = 1, 2 * iTotal do
        table.insert(self.m_mTempRandomList, i)
    end
    self:CheckAddTimer()
    local mNet = {}
    mNet.state = self:GetGameState()
    global.oNotifyMgr:WorldBroadcast("GS2CImperialexamState", mNet)
    self.m_iScheduleID = 1042
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_START, sTime, nil)
    record.info("imperialexam secondstage start")
end

function CHuodong:EndSecondStage()
    self:SetGameState(STATE_CLOSE)
    self.m_mUseTime = {}
    self.m_mQuestion = {}
    self:Dirty()
    self:RemoteQueryRank("imperialexam_secondstage")
    local mNet = {}
    mNet.state = self:GetGameState()
    global.oNotifyMgr:WorldBroadcast("GS2CImperialexamState", mNet)
    local mTimeConf = self:GetTimeConfig()
    local sTime = mTimeConf[self.m_iOpenDayID]["secondstage_closetime"]
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, gamedefines.ACTIVITY_STATE.STATE_END, sTime, nil)
end

function CHuodong:InitMailRewardItem(pid, lItemIdx)
    local mItemList = {}
    for _, iItemIdx in ipairs(lItemIdx) do
        local mRewardInfo = self:GetItemRewardData(iItemIdx)
        if not mRewardInfo then
            goto continue
        end
        local mItemInfo = self:ChooseRewardKey(nil, mRewardInfo, iItemIdx, {})
        if not mItemInfo then
            goto continue
        end
        local mItemUnit = self:InitRewardItemUnitOffline(pid, mItemInfo)
        list_combine(mItemList, mItemUnit["items"])
        ::continue::
    end
    return mItemList
end

function CHuodong:InitRewardItemUnitOffline(pid, mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback("imperialexam mail reward item"))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape, {})
    oItem:SetAmount(iAmount)
    if iBind ~= 0 then
        oItem:Bind(pid)
    end
    mItems["items"] = {oItem}
    return mItems
end

function CHuodong:CheckGiveTask(oPlayer, oNpc)
    local iRet = self:ValidGiveTask(oPlayer)
    if iRet == 1005 then
        self:InitQuestion(oPlayer)
        local oTask = global.oTaskLoader:CreateTask(FIRSTSTAGE_TASK_ID)
        oPlayer.m_oTaskCtrl:AddTask(oTask, oNpc, true)
        local pid = oPlayer:GetPid()
        self:FindPathToNpc(pid, self:GetCurRound(pid))
    elseif iRet == 1006 then
        if not self.m_mQuestion[oPlayer:GetPid()] then
            self:InitQuestion(oPlayer)
        end
        self:GS2CImperialexamGiveQuestion(oPlayer)
    end
end

function CHuodong:OtherScript(pid, npcobj, s, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oTask = self:GetHuodongTask(oPlayer)
    local sCmd = string.match(s, "^($[%a]+)")
    if sCmd then
        local sArgs = string.sub(s,#sCmd + 1, -1)
        if sCmd == "$look" then
            if oTask then
                local iCurRound = self:GetCurRound(pid)
                if iCurRound > self:GetTotalRound() then return end
                if iCurRound ~= (npcobj:Type() - 1000) then
                    local sText = self:GetHuodongTextData(oPlayer, 1007)
                    if not sText then return end
                    self:SayText(pid, npcobj, sText, nil, nil, nil)
                else
                    self:GS2CImperialexamGiveQuestion(oPlayer)
                end
            else
                local iCurRound = self:GetCurRound(pid)
                if iCurRound > self:GetTotalRound() then
                    local sText = self:GetTextData(1009)
                    self:SayText(pid, npcobj, sText, nil, nil ,nil)
                else
                    local sText = self:GetHuodongTextData(oPlayer,1008)
                    self:SayText(pid, npcobj, sText, nil, nil, nil)
                end
            end
        elseif sCmd == "$answer" then
            if oTask then
                local iCurRound = self:GetCurRound(pid)
                if iCurRound ~= (npcobj:Type() - 1000) then
                    self:FindPathToNpc(pid, iCurRound)
                end
            else
                local iCurRound = self:GetCurRound(pid)
                if iCurRound > self:GetTotalRound() then
                    oPlayer:Send("GS2CHuodongIntroduce", { id = 17000 })
                else
                    local oValidNpc = global.oNpcMgr:GetGlobalNpc(5304)
                    if oValidNpc and oPlayer then
                        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oValidNpc, 1)
                    end
                end
            end
        end
    end
end

function CHuodong:FindPathToNpc(pid, iRound)
    local oNpc = self:GetNpcObjByRound(pid , iRound)
    if not oNpc then return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oNpc and oPlayer then
        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oNpc, 1)
    end
end

function CHuodong:CheckAnswer(oPlayer, oNpc, iAnswer)
    if iAnswer == 1 then
        return true
    end
end

function CHuodong:GetHuodongTask(oPlayer)
    local oTask = oPlayer.m_oTaskCtrl:HasTask(FIRSTSTAGE_TASK_ID)
    return oTask
end

function CHuodong:InitQuestion(oPlayer)
    local lQuestion = self:GetQuestionConfig()
    local iLength = #lQuestion
    local iSeed = tonumber(tostring(get_time()):reverse())
    math.randomseed(iSeed)
    local pid = oPlayer:GetPid()
    local mPlayerQuestion = {}
    mPlayerQuestion.question_list = {}
    mPlayerQuestion.curround = 1
    mPlayerQuestion.right = 0
    local iTotal = self:GetTotalRound()
    local iStart = math.random(1, iLength - 2 * iTotal)
    local mOffset =  extend.Random.random_size(self.m_mTempRandomList, iTotal)
    for _, iOffset in ipairs(mOffset) do
        table.insert(mPlayerQuestion.question_list, iStart + iOffset)
    end
    self.m_mQuestion[pid] = mPlayerQuestion
    local mUseTime = {}
    mUseTime.start_time = get_time()
    mUseTime.wrong_time = 0
    self.m_mUseTime[oPlayer:GetPid()] = mUseTime
    self:Dirty()
end

function CHuodong:AnswerQuestion(oPlayer, iQuestion, iAnswer)
    local iCurState = self:GetGameState()
    local pid = oPlayer:GetPid()
    if iCurState == STATE_FIRSTSTAGE_CLOSE then
        local sMsg = self:GetTextData(1016)
        global.oNotifyMgr:Notify(pid, sMsg)
        return
    elseif iCurState == STATE_CLOSE then
        local sMsg = self:GetTextData(1017)
        global.oNotifyMgr:Notify(pid, sMsg)
        return
    end
    local mPlayerQuestion = self.m_mQuestion[pid]
    local mUseTime = self.m_mUseTime[pid]
    if not mPlayerQuestion then
        local mNet = {}
        mNet.state = self:GetGameState()
        oPlayer:Send("GS2CImperialexamState", mNet)
        return
    end
    local mQuestionConfig = self:GetQuestionConfig()
    local mConfig = self:GetConfig()
    if mPlayerQuestion.curround > self:GetTotalRound() then return end
    local bRight = false

    if iQuestion == mPlayerQuestion.question_list[mPlayerQuestion.curround] then
        if mQuestionConfig[iQuestion]["answer"] == iAnswer then
            bRight = true
            mPlayerQuestion.right = mPlayerQuestion.right + 1
        end
    end

    local mNet = {}
    mNet.question_id = iQuestion
    mNet.right_answer = mQuestionConfig[iQuestion]["answer"]
    if bRight then
        mNet.wrong_time = 0
    elseif iCurState == STATE_FIRSTSTAGE then
        mNet.wrong_time = mConfig["firststage_wrongtime"]
    elseif iCurState == STATE_SECONDSTAGE then
        mNet.wrong_time = mConfig["secondstage_wrongtime"]
    end
    oPlayer:Send("GS2CImperialexamGiveAnswer", mNet)

    local iOldRound = mPlayerQuestion.curround
    mPlayerQuestion.curround = mPlayerQuestion.curround + 1
  
    if iCurState == STATE_FIRSTSTAGE then
        if bRight then
            self:Reward(pid, mConfig["firststage_right"])
        else
            self:Reward(pid, mConfig["firststage_wrong"])
            local mUseTime = self.m_mUseTime[pid]
            mUseTime.wrong_time = mUseTime.wrong_time + mConfig["firststage_wrongtime"]
        end

        if iOldRound  >= self:GetTotalRound() then
            self:AchieveFirstStage(pid)
            local sMsg = self:GetTextData(1013)
            local iUseTime = get_time() - mUseTime.start_time + mUseTime.wrong_time
            local sShowTime = get_second2string(iUseTime)
            sMsg = global.oToolMgr:FormatColorString(sMsg,{usetime = sShowTime })
            global.oNotifyMgr:Notify(pid, sMsg)
        else
            local sMsg = self:GetTextData(1012)
            local oValidNpc = self:GetNpcObjByRound(pid, mPlayerQuestion.curround)
            local sValidNpcName = oValidNpc:Name()
            sMsg = global.oToolMgr:FormatColorString(sMsg, { oldround = iOldRound, npcname = sValidNpcName})
            global.oNotifyMgr:Notify(pid, sMsg)
        end

        local oTask = self:GetHuodongTask(oPlayer)
        if oTask then
            oTask:EndOneQuestion()
        end
        oPlayer:MarkGrow(44)

    elseif iCurState == STATE_SECONDSTAGE then
        if bRight then
            self:Reward(pid, mConfig["secondstage_right"], {cancel_tip = true})
        else
            self:Reward(pid, mConfig["secondstage_wrong"], {cancel_tip = true})
            local mUseTime = self.m_mUseTime[pid]
            mUseTime.wrong_time = mUseTime.wrong_time + mConfig["secondstage_wrongtime"]
        end
        if mPlayerQuestion.curround > mConfig["secondstage_total"] then
            self:AchieveSecondStage(pid)
            local sMsg = self:GetTextData(1018)
            local iUseTime = get_time() - mUseTime.start_time + mUseTime.wrong_time
            local sShowTime = get_second2string(iUseTime)
            sMsg = global.oToolMgr:FormatColorString(sMsg,{usetime = sShowTime })
            global.oNotifyMgr:Notify(pid, sMsg)
        else
            self:GS2CImperialexamGiveQuestion(oPlayer)
        end
    end
    self:Dirty()
end

function CHuodong:C2GSImperialexamAnswerQuestion(oPlayer, iQuestion, iAnswer)
    self:AnswerQuestion(oPlayer, iQuestion, iAnswer)
end

function CHuodong:GS2CImperialexamGiveQuestion(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerQuestion = self.m_mQuestion[pid]
    local mUseTime = self.m_mUseTime[pid]
    local mNet = {}
    mNet.question_id = mPlayerQuestion.question_list[mPlayerQuestion.curround]
    mNet.use_time = get_time() - mUseTime.start_time + mUseTime.wrong_time
    mNet.cur_round = mPlayerQuestion.curround
    oPlayer:Send("GS2CImperialexamGiveQuestion", mNet)
end

function CHuodong:AchieveFirstStage(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local mUseTime = self.m_mUseTime[pid]
    local mQuestion = self.m_mQuestion[pid]
    local mConfig = self:GetConfig()
    mUseTime.end_time = get_time()
    self:AddSchedule(oPlayer)
    self:Dirty()
    local mData = {}
    mData.pid = pid
    mData.name = oPlayer:GetName()
    mData.grade = oPlayer:GetGrade()
    mData.right = mQuestion.right
    mData.end_time = mUseTime.end_time
    mData.usetime = mUseTime.end_time - mUseTime.start_time + mUseTime.wrong_time
    -- 认为作弊
    if mData.usetime <= mConfig["firststage_mintime"] then
        record.info("huodong imperialexam firststage %d cheating",pid)
        return 
    end
    global.oRankMgr:PushDataToRank("imperialexam_firststage", mData)
end

function CHuodong:AchieveSecondStage(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local mQuestion = self.m_mQuestion[pid] 
    local mUseTime = self.m_mUseTime[pid]
    local mConfig = self:GetConfig()
    mUseTime.end_time = get_time()
    self:AddSchedule(oPlayer)
    self:Dirty()
    local mData = {}
    mData.pid = pid
    mData.name = oPlayer:GetName()
    mData.grade = oPlayer:GetGrade()
    mData.right = mQuestion.right
    mData.firststage = self.m_mSecondStagePid[pid]
    mData.usetime = mUseTime.end_time - mUseTime.start_time + mUseTime.wrong_time
    -- 认为作弊
    if mData.usetime <= mConfig["secondstage_mintime"] then
        record.info("huodong imperialexam secondstage %d cheating",pid) 
        return
    end
    global.oRankMgr:PushDataToRank("imperialexam_secondstage", mData)
end

function CHuodong:GetCurRound(pid)
    local mPlayerQuestion = self.m_mQuestion[pid]
    if mPlayerQuestion then
        return mPlayerQuestion.curround
    else
        return 0
    end
end

function CHuodong:GetTotalRound()
    local mConfig = self:GetConfig()
    local iCurState = self:GetGameState()
    if iCurState == STATE_FIRSTSTAGE then
        return mConfig["firststage_total"]
    elseif iCurState == STATE_SECONDSTAGE then
        return mConfig["secondstage_total"]
    else
        return 0
    end
end

local function OnRemoteQueryRank(mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("imperialexam")
    if not oHuodong then return end
    oHuodong.m_mMailPidList = mData.rankdata
    oHuodong.m_mSecondStagePid = {}
    local iAmountLimit = oHuodong.GetConfig()["qualification"]
    for index = 1, math.min(iAmountLimit, #mData.rankdata) do
        local mPlayerInfo = mData.rankdata[index]
        oHuodong.m_mSecondStagePid[mPlayerInfo.pid] = index
    end
    oHuodong:AfterRemoteQueryRank()
end

function CHuodong:RemoteQueryRank(sRankName)
    local mData = {}
    mData.rankname = sRankName
    interactive.Request(".rank", "rank", "GetImperialexamData", mData,
        function(mRecord, mData)
            OnRemoteQueryRank(mData)
        end)
end

function CHuodong:GetQuestionConfig()
    if self:GetGameState() == STATE_FIRSTSTAGE then
        return res["daobiao"]["huodong"]["imperialexam"]["firststage_question"]
    else
        return res["daobiao"]["huodong"]["imperialexam"]["secondstage_question"]
    end
end

function CHuodong:GetNpcConfig()
    return res["daobiao"]["huodong"]["imperialexam"]["npc"]
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["imperialexam"]["config"][1]
end

function CHuodong:GetTimeConfig()
    return res["daobiao"]["huodong"]["imperialexam"]["time_ctrl"]
end

function CHuodong:GetTop3Reward()
    return res["daobiao"]["huodong"]["imperialexam"]["top3_reward"]
end

function CHuodong:RewardId2ItemIdx(iRewardId)
    local mReward = res["daobiao"]["reward"]["imperialexam"]["reward"]
    return mReward[iRewardId].item
end

function CHuodong:TestOp(iFlag, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(mArgs[#mArgs])
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oPlayer, [[
gm - huodongop imperialexam 100
103 - 放弃初试任务以及清空答题数据（可用来重新答题）
105 - 开始活动第一阶段（初试开始 ）
106 - 关闭活动第一阶段（初试关闭）
107 - 开始活动第二阶段 （终试开始）
108 - 关闭活动第二阶段（终试关闭）
            ]])
    elseif iFlag == 101 then
        self:NewDay()
    elseif iFlag == 105 then
        self.m_iOpenDayID = 1
        self:SetHuodongTime()
        self:SetGameState(STATE_CLOSE)
        for _, oNpc in pairs(self.m_mNpcList) do
            self:RemoveTempNpc(oNpc)
        end
        self:StartFirstStage()
    elseif iFlag == 106 then
        self:EndFirstStage()
    elseif iFlag == 107 then
        self:SetGameState(STATE_SECONDSTAGE)
        self:RemoteQueryRank("imperialexam_firststage")
        self:StartSecondStage()
    elseif iFlag == 108 then
        self:EndSecondStage()
    elseif iFlag == 103 then
        local oTask = self:GetHuodongTask(oPlayer)
        if oTask then
            oTask:Abandon()
        end
        self.m_mQuestion[oPlayer:GetPid()] = nil
        self.m_mUseTime[oPlayer:GetPid()] = nil
        self:Dirty()
    elseif iFlag == 104 then
        local netcmd = import(service_path("netcmd/huodong"))
        netcmd.C2GSImperialexamAnswerQuestion(oPlayer,{question_id = mArgs[1], answer = mArgs[2]})
    elseif iFlag == 110 then
        self:NewDay()
    end
end