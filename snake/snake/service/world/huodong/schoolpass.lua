local global  = require "global"
local res = require "base.res"
local record = require "public.record"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local handleteam = import(service_path("team/handleteam"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

local GAME_NONE = 0
local GAME_PREPARE = 1
local GAME_START = 2
local GAME_END = 3

local AUTO_TEAM_SCHOOLPASS = 1500

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "门派试炼"
CHuodong.m_iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_SCHOOLPASS
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iNpcId = 0
    o.m_iGameState = GAME_NONE
    o.m_iScheduleID = 1013
    return o
end

function CHuodong:Init()
    self:ClearTimer()
    self:RefreshSchedule()
    self:InitParam()
end

function CHuodong:InitParam()
    self.m_mSchoolTarget = {}
    self.m_mTeamResult = {}
    self.m_mLeaderName = {}
    self.m_mPlayerResult = {}
    self.m_mPlayerName = {}
    self.m_mTop3Team = {}
    self.m_mTop3Player = {}
end

function CHuodong:ClearTimer()
    self:DelTimeCb("GameTip")
    self:DelTimeCb("ResultAnnounce")
    self:DelTimeCb("GameEnd")
    self:DelTimeCb("NpcRelease")
end

function CHuodong:LogData(oPlayer)
    local mLogData = {}
    mLogData.pid = oPlayer:GetPid()
    mLogData.show_id = oPlayer:GetShowId()
    return mLogData
end

function CHuodong:GetConfig()
    if not self.m_mReplace then
        return res["daobiao"]["huodong"][self.m_sName]["condition"][1]
    else
        return self.m_mReplace
    end
end

function CHuodong:GetOpenWeekday()
    return self:GetConfig().open_weekday
end

function CHuodong:GetOpenTime()
    local mConfig = self:GetConfig()
    local sTime = mConfig.open_time
    local hour, min = sTime:match("^(%d+)%:(%d+)")
    assert(hour and min, string.format("schoolpass GetOpenTime err %s %s", hour, min))
    local iHour, iMin = tonumber(hour), tonumber(min)
    return {iHour, iMin}
end

function CHuodong:GetTipTime()
    local mOpenTime = self:GetOpenTime()
    local iHour, iMin = table.unpack(mOpenTime)
    local iTipShift = self:GetConfig().tip_time_shift
    if iMin + iTipShift < 0 then
        iHour = iHour - 1
        iMin = iMin + iTipShift + 60
    else
        iMin = iMin + iTipShift
    end
    return {iHour, iMin}
end

function CHuodong:GetEndTime()
    local iOpenHour, iOpenMin = table.unpack(self:GetOpenTime())
    local iContinue = self:GetContinueTime()
    local iEndMin = math.floor(iOpenMin + iContinue) % 60
    local iEndHour = math.floor(iOpenMin + iContinue) // 60 + iOpenHour
    assert(iEndHour<=24, string.format("schoolpass endtime err"))
    return {iEndHour, iEndHour}
end

function CHuodong:GetContinueTime()
    local mConfig = self:GetConfig()
    return tonumber(mConfig.continue_time)
end

function CHuodong:GetLimitGrade()
    return global.oToolMgr:GetSysOpenPlayerGrade("SCHOOLPASS")
end

function CHuodong:RefreshSchedule()
    if not self:IsOpenDay() then
        return
    end
    local iNowTime = get_time()
    local date = os.date("*t", iNowTime)
    local iOpenHour, iOpenMin = table.unpack(self:GetOpenTime())
    local iOpenTime = os.time({year=date.year,month=date.month,day=date.day,hour=iOpenHour,min=iOpenMin,sec=0})
    if iNowTime >= iOpenTime then
        -- 起服时已超活动开启时间,由GM指令开启
        return
    end
    local iTipHour, iTipMin = table.unpack(self:GetTipTime()) 
    if date.hour<=iOpenHour then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
    if iTipHour == date.hour then
        if iTipMin > date.min then
            self:AddTimeCb("GameTip", ((iTipMin - date.min) * 60 - date.sec) * 1000, function()
                self:GamePrepare()
            end)
        else
            self:GamePrepare()
        end
    end
    if iOpenHour == date.hour then
        if iOpenMin > date.min then
            self:AddTimeCb("GameStart", ((iOpenMin - date.min) * 60 - date.sec) * 1000, function()
                self:GameStart()
            end)
        end
    end
end

function CHuodong:NewDay(mNow)
    if self:IsOpenDay() then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:GetStartTime()
    local mConfig = self:GetConfig()
    local sTime = mConfig.open_time
    local sHour, sMin = sTime:match("^(%d+)%:(%d+)")
    return string.format("%s:%s", sHour, sMin)
end

function CHuodong:ValidReplaceStart(mReplace)
    if self:IsOpenDay() then return false end

    if not table_in_list(mReplace.open_weekday, get_weekday()) then
        return false
    end

    local tbl = get_hourtime({hour=0})
    local iCurrHour = tbl.date.hour
    local iHour, iMin = mReplace.open_time:match("^(%d+)%:(%d+)")

    if iCurrHour ~= tonumber(iHour) then return false end

    return true
end

function CHuodong:ReplaceStart(mReplace)
    if not self:ValidReplaceStart(mReplace) then
        return
    end

    self:ClearTimer()
    self:InitParam()
    self.m_mReplace = nil

    local mConfig = self:GetConfig()
    self.m_mReplace = table_copy(mReplace)
    for sKey, rVal in pairs(mConfig) do
        if not self.m_mReplace[sKey] then
            self.m_mReplace[sKey] = rVal
        end
    end

    local tbl = get_hourtime({hour=0})
    local iHour = tbl.date.hour
    local iTipHour, iTipMin = table.unpack(self:GetTipTime())
    local iOpenHour, iOpenMin = table.unpack(self:GetOpenTime())
    if iHour == iTipHour then
        self:DelTimeCb("GameTip")
        self:AddTimeCb("GameTip", iTipMin * 60 * 1000, function()
            self:GamePrepare()
        end)
    end
    if iHour == iOpenHour then
        if iOpenMin == 0 then
            self:GameStart()
        else
            self:DelTimeCb("GameStart")
            self:AddTimeCb("GameStart", iOpenMin * 60 * 1000, function()
                self:GameStart()
            end)
        end
    end
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
end

function CHuodong:NewHour(mNow)
    if not self:IsOpenDay() then
        return
    end
    local iHour = mNow.date.hour
    local iTipHour, iTipMin = table.unpack(self:GetTipTime())
    local iOpenHour, iOpenMin = table.unpack(self:GetOpenTime())
    if iHour == iTipHour then
        self:DelTimeCb("GameTip")
        self:AddTimeCb("GameTip", iTipMin * 60 * 1000, function()
            self:GamePrepare()
        end)
    end
    if iHour == iOpenHour then
        if iOpenMin == 0 then
            self:GameStart()
        else
            self:DelTimeCb("GameStart")
            self:AddTimeCb("GameStart", iOpenMin * 60 * 1000, function()
                self:GameStart()
            end)
        end
    end
end

function CHuodong:GamePrepare()
    self.m_iGameState = GAME_PREPARE
    record.info("schoolpass GamePrepare")
    self:InitParam()
    self:DelTimeCb("GameTip")
    self:CreateHuodongNpc()

    local mChuanwen = res["daobiao"]["chuanwen"][1028]
    local sMsg = mChuanwen.content
    local iHorse = mChuanwen.horse_race
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)

 
    local lSchools = table_value_list(gamedefines.PLAYER_SCHOOL)
    for _, iSchool in pairs(lSchools) do
        interactive.Request(".rank", "rank", "GetGradeSchoolRank", {school = iSchool},
        function(mRecord, mData)
            self:InitSchoolTarget(mData)
        end)
    end
end

function CHuodong:InitSchoolTarget(mData)
    local iSchool = mData.school
    local lSortList = mData.sort_list
    lSortList = list_split(lSortList, 1, 50)
    self.m_mSchoolTarget[iSchool] = lSortList
end

function CHuodong:GetMirrorMonsterData(iSchool, func)
    local oWorldMgr = global.oWorldMgr
    local lSortList = self.m_mSchoolTarget[iSchool] or {}
    local sPid
    if #lSortList > 0 then
        sPid =  lSortList[math.random(#lSortList)]
    end
    if sPid then
        local pid = tonumber(sPid)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local mModelInfo = oPlayer:GetModelInfo()
            mModelInfo.horse = nil
            local mData = {
                school = oPlayer:GetSchool(),
                name = oPlayer:GetName(),
                grade = oPlayer:GetGrade(),
                model_info = mModelInfo,
            }
            func(mData)
        else
            oWorldMgr:LoadProfile(pid, function (oProfile)
                GetMirrorMonsterData(oProfile, func)
            end)
            return
        end
    else
        func()
    end
end

function CHuodong:do_look(oPlayer, npcobj)
    local pid = oPlayer:GetPid()
    if self:IsGamePrepare() then
        local iNowTime = get_time()
        local iHour, iMin = table.unpack(self:GetOpenTime())
        local date = os.date("*t", iNowTime)
        local iBeginTime = os.time({year = date.year, month = date.month, day = date.day, hour = iHour, min = iMin, sec = 0})
        local iTime = iBeginTime - iNowTime
        if iTime > 0 then
            self:SayText(pid, npcobj, self:GetTextData(1001), nil, iTime)
            return
        end
    elseif self:IsGameEnd() then
        self:SayText(pid, npcobj, self:GetTextData(1010))
        return
    else
        local oSchoolPassHandler = global.oSchoolPassHandler
        local oTask = oSchoolPassHandler:GetTask(oPlayer)
        if oTask then
            local mNet = {}
            local mData = oTask:GetDialogData(1001)
            for _, mDialog in pairs(mData) do
                mDialog["content"] = oTask:DetailDesc()
            end
            mNet["dialog"] = mData
            mNet["npc_name"] = npcobj:Name()
            mNet["model_info"] = npcobj:ModelInfo()
            oPlayer:Send("GS2CDialog", mNet)
            return
        end
    end
    super(CHuodong).do_look(self, oPlayer, npcobj)
end

function CHuodong:OtherScript(pid, npcobj, s, mArgs)
    if s == "GiveTask" then
        if self:IsGameEnd() then
            self:SayText(pid, npcobj, self:GetTextData(1011))
        end
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:GiveTask(oPlayer)
            return true
        end
    elseif s == "AutoTeam" then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer.m_oActiveCtrl:QuickTeamup(oPlayer, AUTO_TEAM_SCHOOLPASS)
            return true
        end
    end
end

function CHuodong:GameStart()
    self.m_iGameState = GAME_START
    record.info("schoolpass GameStart")
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:DelTimeCb("GameStart")
    self:AddTimeCb("ResultAnnounce", 30 * 60 * 1000, function()
        self:ResultAnnounce()
    end)

    local iContinueTime = self:GetContinueTime()
    self:AddTimeCb("GameEnd", iContinueTime * 60 * 1000, function()
        self:GameEnd()
    end)
end

function CHuodong:IsOpenDay()
    local lOpenWeekday = self:GetOpenWeekday()
    return table_in_list(lOpenWeekday, get_weekday())
end

function CHuodong:ValidHuodongProcess()
    return self.m_iGameState > GAME_PREPARE
end

function CHuodong:IsGamePrepare()
    return self.m_iGameState == GAME_PREPARE
end

function CHuodong:IsGameStart()
    return self.m_iGameState == GAME_START
end

function CHuodong:IsGameEnd()
    return self.m_iGameState == GAME_END
end

function CHuodong:CreateHuodongNpc()
    if self:GetHuodongNpc() then
        return
    end
    local oNpc = self:CreateTempNpc(5999)    -- 天机老人
    self.m_iNpcId = oNpc:ID()
    self:Npc_Enter_Map(oNpc)
end

function CHuodong:GetHuodongNpc()
    local oNpc = self:GetNpcObj(self.m_iNpcId)
    return oNpc
end

function CHuodong:FindNpcPath(pid)
    local npcobj = self:GetHuodongNpc()
    if npcobj then
        local iMap = npcobj:MapId()
        local mPosInfo = npcobj:PosInfo()
        local iX = mPosInfo["x"]
        local iY = mPosInfo["y"]
        local oSceneMgr = global.oSceneMgr
        if not oSceneMgr:SceneAutoFindPath(pid, iMap, iX, iY, self.m_iNpcId) then
            self:OpenHDSchedule(pid)
        end
    end
end

function CHuodong:ValidTeamMemberGrade(oPlayer, bNotify)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return false end

    local iOpenLevel = self:GetLimitGrade()

    local function FilterCannotFightMember(oMember)
        if oMember:GetGrade() < iOpenLevel then
            return oMember:GetName()
        end
    end
    
    local lName = oTeam:FilterTeamMember(FilterCannotFightMember)
    if next(lName) and bNotify then
        local sText = self:GetTextData(1006)
        sText = oToolMgr:FormatColorString(sText, {role = table.concat(lName, "、"), level = iOpenLevel})
        oNotifyMgr:Notify(oPlayer:GetPid(), sText)
        return false
    end
    return true
end

function CHuodong:ValidGiveTask(oPlayer, bNotify)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr


    local bRet = true
    local sText
    if not oToolMgr:IsSysOpen("SCHOOLPASS",oPlayer,true) then
        bRet = false
    elseif not self:IsGameStart() then
        bRet = false
    elseif not oPlayer:IsTeamLeader() then
        sText = self:GetTextData(1004)
        bRet = false
    else
        local oTeam = oPlayer:HasTeam()
        if oTeam:MemberSize() < 3 then
            sText = self:GetTextData(1005)
            bRet = false
        else
            if not self:ValidTeamMemberGrade(oPlayer, bNotify) then
                bRet = false
            end
        end
    end
    if sText and bNotify then
        oNotifyMgr:Notify(oPlayer:GetPid(), sText)
    end
    return bRet
end

function CHuodong:GiveTask(oPlayer)
    if not self:ValidGiveTask(oPlayer, true) then
        return
    end
    local oSchoolPassHandler = global.oSchoolPassHandler
    oSchoolPassHandler:AddNextRingTask(oPlayer:GetPid())
    safe_call(oSchoolPassHandler.LogAnalyInfo, oSchoolPassHandler, oPlayer, 1)
end

function CHuodong:ResultAnnounce()
    self:DelTimeCb("ResultAnnounce")
    self:AddTimeCb("ResultAnnounce", 10 * 60 * 1000, function()
        self:ResultAnnounce()
    end)
    local lName = {}
    for _, data in ipairs(self.m_mTop3Team) do
        local sTeam = data["team"]
        table.insert(lName, self.m_mLeaderName[sTeam])
    end
    local iAmount = table_count(lName)
    if iAmount > 0 then
        local oToolMgr = global.oToolMgr
        local oChatMgr = global.oChatMgr
        local sName = table.concat(lName, "、")
        local mChuanwen = res["daobiao"]["chuanwen"][1029]
        local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = sName, amount = iAmount})
        oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end
end

function CHuodong:GameEnd()
    self:DelTimeCb("GameEnd")
    self:DelTimeCb("ResultAnnounce")
    self.m_iGameState = GAME_END
    record.info("schoolpass GameEnd")
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    
    
    if table_count(self.m_mPlayerName) > 0 then
        local sName = table.concat(self.m_mPlayerName, "、")
        local oToolMgr = global.oToolMgr
        local oChatMgr = global.oChatMgr
        local mChuanwen = res["daobiao"]["chuanwen"][1030]
        local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = sName})
        oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end
    self:GameReward()
    self:AddTimeCb("NpcRelease", 15 * 60 * 1000, function()
        self:NpcRelease()
    end)
   
    self.m_mReplace = nil 
end

function CHuodong:GameReward()
    local mExclude = {}
    local mReward = {"10003", "10004", "10005"}
    local mLogData, mRank = {}, {}
    for idx, data in ipairs(self.m_mTop3Player) do
        local sReward = mReward[idx]
        local plist = table_key_list(data["plist"])
        mRank[db_key(idx)] = plist

        for _, sPid in pairs(plist) do
            local pid = tonumber(sPid)
            self:Reward(pid, sReward)
            mExclude[sPid] = 1
        end
    end
    mRank.other = table_deep_copy(self.m_mPlayerResult)
    mLogData.info = mRank
    record.user("huodonginfo", "schoolpass", mLogData)

    self:GameBaseReward(table_key_list(self.m_mPlayerResult), mExclude)
end

function CHuodong:GameBaseReward(plist, mExclude)
    self:DelTimeCb("GameBaseReward")
    local iCnt = 0
    for _, sPid in pairs(plist) do
        iCnt = iCnt + 1
        if not mExclude[sPid] then
            local pid = tonumber(sPid)
            self:Reward(pid, tostring(10006))
        end
        if iCnt >= 100 then
            local iStart = iCnt + 1
            local iEnd = table_count(plist)
            if iStart <= iEnd then
                local plist = list_split(plist, iStart, iEnd)
                self:AddTimeCb("GameBaseReward", 100, function()
                    self:GameBaseReward(plist, mExclude)
                end)
                break
            end
        end
    end
end

function CHuodong:RemoveTop3Team(sTeam)
    local iPos
    for idx, data in ipairs(self.m_mTop3Team) do
        if data["team"] == sTeam then
            iPos = idx
            break
        end
    end
    if iPos then
        table.remove(self.m_mTop3Team, iPos)
    end
end

function CHuodong:JoinTop3Team(sTeam, iPassTime)
    local iPos
    if #self.m_mTop3Team == 0 then
        iPos = 1
    else
        for idx, data in ipairs(self.m_mTop3Team) do
            if iPassTime < data["passtime"] then
                iPos = idx
                break
            else
                iPos = idx + 1
            end
        end
    end
    if iPos and iPos <= 3 then
        local data = {}
        data.passtime = iPassTime
        data.team = sTeam
        table.insert(self.m_mTop3Team, iPos, data)
        if #self.m_mTop3Team > 3 then
            self.m_mTop3Team = list_split(self.m_mTop3Team, 1, 3)
        end
    end
end

function CHuodong:AddTeamResult(iTeam, iPassTime, sLeaderName)
    local sTeam = tostring(iTeam)
    if self.m_mTeamResult[sTeam] then
        if self.m_mTeamResult[sTeam] <= iPassTime then
            return
        end
        self.m_mTeamResult[sTeam] = iPassTime
        self.m_mLeaderName[sTeam] = sLeaderName
        self:RemoveTop3Team(sTeam)
    else
        self.m_mTeamResult[sTeam] = iPassTime
        self.m_mLeaderName[sTeam] = sLeaderName
    end
    self:JoinTop3Team(sTeam, iPassTime)
end

function CHuodong:RemoveTop3Player(sPid, iPassTime)
    local iRemove
    for idx, data in ipairs(self.m_mTop3Player) do
        if data["passtime"] == iPassTime then
            local plist = data["plist"]
            if plist[sPid] then
                plist[sPid] = nil
            end
            if table_count(plist) <= 0 then
                iRemove = idx
            end
            break
        end
    end
    if iRemove then
        table.remove(self.m_mTop3Player, iRemove)
    end
end

function CHuodong:JoinTop3Player(sPid, iPassTime, sName)
    local iPos
    if #self.m_mTop3Player == 0 then
        iPos = 1
    else
        for idx, data in ipairs(self.m_mTop3Player) do
            local passtime = data["passtime"]
            if iPassTime < passtime then
                iPos = idx
                break
            elseif iPassTime > passtime then
                iPos = idx + 1 
            else
                data["plist"][sPid] = 1
                if idx == 1 then
                    table.insert(self.m_mPlayerName, sName)
                end
                return
            end
        end
    end
    if iPos and iPos <= 3 then
        local plist= {}
        plist[sPid] = 1
        local data = {}
        data.passtime = iPassTime
        data.plist = plist
        table.insert(self.m_mTop3Player, iPos, data)
        if iPos == 1 then
            self.m_mPlayerName = {sName}
        end
        if #self.m_mTop3Player > 3 then
            self.m_mTop3Player = list_split(self.m_mTop3Player, 1, 3)      
        end
    end
end

function CHuodong:AddPlayerResult(pid, iPassTime, sName)
    local sPid = tostring(pid)
    local iOldPassTime = self.m_mPlayerResult[sPid]
    if iOldPassTime then
        if iOldPassTime <= iPassTime then
            return
        end
        self.m_mPlayerResult[sPid] = iPassTime
        self:RemoveTop3Player(sPid, iOldPassTime)
    else
        self.m_mPlayerResult[sPid] = iPassTime
    end
    self:JoinTop3Player(sPid, iPassTime, sName)
end

function CHuodong:NpcRelease()
    self.m_iGameState = GAME_NONE
    self:DelTimeCb("NpcRelease")
    self:InitParam()
    local npcobj = self:GetHuodongNpc()
    if npcobj then
        self:RemoveTempNpc(npcobj)
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local extend = require "base.extend"
    local pid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand = {
        "100 指令查看",
        "101 模拟刷时\nhuodongop schoolpass 101 {weekday = 星期几, hour = 小时}",
        "201 进入活动准备阶段\nhuodongop schoolpass 201",
        "202 进入活动开始阶段\nhuodongop schoolpass 202",
        "203 活动结束\nhuodongop schoolpass 203",
        "204 执行NPC退出场景\nhuodongop schoolpass 204",
        "301 执行成绩公告\nhuodongop schoolpass 301",
        "302 模拟活动结束发奖励\nhuodongop schoolpass 302",
        "303 模拟点击日程参与\nhuodongop schoolpass 303",
        "304 门派试练已获得奖励次数\nhuodongop schoolpass 304",
        "305 打印排名信息\nhuodongop schoolpass 305",
        "306 设置已获得任务奖励次数\nhuodongop schoolpass 306 {time = 次数}",
    }
    if iFlag == 100 then
        for idx=#mCommand, 1, -1 do
            oChatMgr:HandleMsgChat(oPlayer, mCommand[idx])
        end
        oNotifyMgr:Notify(pid, "请查看消息频道咨询指令")
    elseif iFlag == 101 then
        if not mArgs.weekday or not mArgs.hour then
            oNotifyMgr:Notify(pid, "参数格式错误")
            return
        end
        local iWDay = tonumber(mArgs.weekday)
        local iHour = tonumber(mArgs.hour)
        self:NewHour(get_wdaytime({wday=iWDay, hour=iHour}))
    elseif iFlag == 201 then
        self:CreateHuodongNpc()
        self:GamePrepare()
    elseif iFlag == 202 then
        self:GameStart()
    elseif iFlag == 203 then
        self:GameEnd()
    elseif iFlag == 204 then
        self:NpcRelease()
    elseif iFlag == 301 then
        self:ResultAnnounce()
    elseif iFlag == 302 then
        self:GameReward()
    elseif iFlag == 303 then
        self:FindNpcPath(pid)
    elseif iFlag == 304 then
        local iRewardCnt = oPlayer.m_oToday:Query("schoolpassreward", 0)
        oNotifyMgr:Notify(pid, string.format("已获得门派试练任务奖励次数: %s", iRewardCnt))
    elseif iFlag == 305 then
        local mTop3Team = self.m_mTop3Team or {}
        local mTop3Player = self.m_mTop3Player or {}
        oChatMgr:HandleMsgChat(oPlayer, string.format("队伍成绩: %s 个人成绩: %s", extend.Table.serialize(mTop3Team), extend.Table.serialize(mTop3Player)))
        oNotifyMgr:Notify(pid, "请查看消息频道咨询指令")
    elseif iFlag == 306 then
        if not mArgs.time then
            oNotifyMgr:Notify(pid, "参数格式错误")
            return
        end
        local iTime = tonumber(mArgs.time)
        oPlayer.m_oToday:Set("schoolpassreward", iTime)
        oNotifyMgr:Notify(pid, string.format("已设置获得奖励次数为%s", iTime))
    end
end


function GetMirrorMonsterData(oProfile, func)
    local mData
    if oProfile then
        local mModelInfo = table_copy(oProfile:GetModelInfo())
        mModelInfo.horse = nil
        mData = {
            school = oProfile:GetSchool(),
            name = oProfile:GetName(),
            grade = oProfile:GetGrade(),
            model_info = mModelInfo,
        }
    end
    func(mData)
end

