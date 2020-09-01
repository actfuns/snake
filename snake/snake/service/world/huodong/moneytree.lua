local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "摇钱树"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1020
    o.m_iStartTime = 0
    o.m_iEndTime = 0
    o.m_mOrgStat = {}
    return o
end

function CHuodong:Init()
    self:DelTimeCb("GameStart")
    self:DelTimeCb("GameOver")
    self:DelTimeCb("Refresh")
    self:DelTimeCb("NotifyGameStart1")
    self:DelTimeCb("NotifyGameStart2")
    self.m_mOrgStat = {}
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    
    self:InitGameStartTime()
    self:CheckAddTimer()
    if self:IsOpenDay() then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:NewHour(mNow)
    local iWeekDay = mNow.date.wday
    local iTime = mNow.time
    if table_in_list(self:GetWeekDays(), iWeekDay) then
        self:InitGameStartTime(mNow)
        self:CheckAddTimer(mNow)
        if self:IsOpenDay(iTime) then
            self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
        end
    end
end

--替代其他活动开启
function CHuodong:ReplaceStart(mReplace)
    if self:InGameTime() then return end

    local mConfig = self:GetConfig()
    local iStartTime = self:AnalyseTime(mConfig.start_time)
    if get_time() < iStartTime then
        self.m_iStartTime = iStartTime
        self.m_iEndTime = iStartTime + mConfig.continue_time*60
        self:CheckAddTimer()
        if self:IsOpenDay() then
            self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
        end
    end
end

function CHuodong:InitGameStartTime(mNow)
    local mConfig = self:GetConfig()
    local iStartTime = self:AnalyseTime(mConfig.start_time)

    local iTime = mNow and mNow.time or get_time()
    local iWDay = mNow and mNow.date.wday or get_weekday()
    if table_in_list(self:GetWeekDays(), iWDay) and iTime < iStartTime then
        self.m_iStartTime = iStartTime
        self.m_iEndTime = iStartTime + mConfig.continue_time*60
        return
    end
end

function CHuodong:CheckAddTimer(mNow)
    if self.m_iStartTime == 0 then return end

    local mConfig = self:GetConfig()
    local iCurrTime = mNow and mNow.time or get_time()
    local iDelta = self.m_iStartTime - iCurrTime
    if iDelta > 0 and iDelta <= 3600 then
        local iPrepare1 = self.m_iStartTime + mConfig.tip_time_shift1*60
        if iPrepare1 - iCurrTime > 1 then
            self:DelTimeCb("NotifyGameStart1")
            self:AddTimeCb("NotifyGameStart1", (iPrepare1-iCurrTime)*1000, function()
                self:NotifyGameStartStep(1)
            end)
        end

        local iPrepare2 = self.m_iStartTime + mConfig.tip_time_shift2*60
        if iPrepare2 - iCurrTime > 1 then
            self:DelTimeCb("NotifyGameStart2")
            self:AddTimeCb("NotifyGameStart2", (iPrepare2-iCurrTime)*1000, function()
                self:NotifyGameStartStep(2)
            end)
        else
            self:NotifyGameStartStep(2)
        end
    end
end

function CHuodong:NotifyGameStartStep(iFlag)
    record.info("prepare game start moneytree "..iFlag)

    if iFlag == 1 then
        local sMsg, iHorse = self:GetChuanwen(1041)
        global.oChatMgr:HandleSysChat(sMsg,gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,iHorse)
    elseif iFlag == 2 then
        local sMsg, iHorse = self:GetChuanwen(1042)
        global.oChatMgr:HandleSysChat(sMsg,gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,iHorse)
        self:DelTimeCb("GameStart")
        local iDelay = math.max(1, self.m_iStartTime-get_time())
        self:AddTimeCb("GameStart", iDelay*1000, function()
            self:GameStart()
        end)
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:GameStart()
    self:DelTimeCb("GameStart")
    record.info("game true start moneytree")

    local sMsg, iHorse = self:GetChuanwen(1043)
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)

    self:DelTimeCb("GameOver")
    self:AddTimeCb("GameOver", (self.m_iEndTime-self.m_iStartTime)*1000, function()
        self:GameOver()
    end)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:TryStartRewardMonitor()
    
    self:RefreshAllOrgNpc()
end

function CHuodong:GameOver()
    record.info("game over moneytree")
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)

    local sMsg, iHorse = self:GetChuanwen(1044)
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)

    safe_call(self.RemoveAllOrgNpc, self)

    local mConfig = self:GetConfig()
    for iOrg, iCnt in pairs(self.m_mOrgStat) do
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        if not oOrg then goto continue end

        local iOrgCash = formula_string(mConfig.org_cash, {kill_cnt=iCnt})
        if iOrgCash > 0 then
            oOrg:AddCash(iOrgCash)
    
            local sMsg = self:GetTextData(1006)
            local mReplace = {org_cash = iOrgCash}
            sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
            global.oChatMgr:SendMsg2Org(sMsg, iOrg)
        end

        ::continue::
    end

    self:Init()
    self:TryStopRewardMonitor()
end

function CHuodong:RefreshAllOrgNpc()
    if not self:InGameTime() then return end

    safe_call(self.RemoveAllOrgNpc, self)

    for iOrg, oOrg in pairs(global.oOrgMgr:GetNormalOrgs() or {}) do
        safe_call(self.RefreshOrgNpc, self, oOrg)
    end

    self:DelTimeCb("Refresh")
    self:AddTimeCb("Refresh", 3*60*1000, function()
        self:RefreshAllOrgNpc()
    end)
end

function CHuodong:RefreshOrgNpc(oOrg)
    local iOrgScene = oOrg:GetOrgSceneID()
    local oScene = global.oSceneMgr:GetScene(iOrgScene)
    local mConfig = self:GetConfig()
    local iOnline = self.m_iTestOnline or oOrg:GetOnlineMemberCnt()
    local iCnt = formula_string(mConfig.amount, {online=iOnline})
    local mRefresh = formula_string(mConfig.refresh_npc, {})
    for iNpcIdx, iRatio in pairs(mRefresh) do
        local iTotal = math.max(1, math.floor(iCnt * iRatio / 100))
        for i = 1, iTotal do
            local oNpc = self:CreateTempNpc(iNpcIdx)
            oNpc.m_iOrgID = oOrg:OrgID()
            local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
            oNpc.m_mPosInfo.x = iX
            oNpc.m_mPosInfo.y = iY
            self:Npc_Enter_Scene(oNpc, iOrgScene)
        end
    end
end

function CHuodong:RemoveAllOrgNpc()
    for iNpc, oNpc in pairs(self.m_mNpcList) do
        if not is_release(oNpc) and not oNpc:InWar() then
            self:RemoveTempNpc(oNpc)
        end
    end
end

function CHuodong:RespondLook(oPlayer, nid, iAnswer)
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        self:TeamNotify(oPlayer, 2009)
        return
    end
    super(CHuodong).RespondLook(self, oPlayer, nid, iAnswer)
end

function CHuodong:CheckAnswer(oPlayer, oNpc, iAnswer)
    if oNpc:NpcID() == 7001 or oNpc:NpcID() == 7002 then
        --如意仙女
        if iAnswer ~= 1 then return false end

        if not oNpc then
            self:TeamNotify(oPlayer, 2009)
            return false
        end
        
        local iRet, mReplace = self:ValidJoinFight(oPlayer, oNpc)
        if iRet ~= 1 then
            self:TeamNotify(oPlayer, iRet, mReplace)
            return false
        end

        return true
    end
end

function CHuodong:ValidJoinFight(oPlayer, oNpc)
    if not oNpc or oNpc:InWar() then
        return 2007, {name=oNpc:Name()}
    end
    local iStatus = oPlayer.m_oActiveCtrl:GetWarStatus() 
    if iStatus ~= gamedefines.WAR_STATUS.NO_WAR then
        return 2007, {name=oPlayer:GetName()}
    end
    if not self:InGameTime() then
        return 2002
    end
    local iOrg = oPlayer:GetOrgID()
    if not iOrg or iOrg ~= oNpc.m_iOrgID then
        return 2003, {name=oPlayer:GetName()}
    end
    if not oPlayer:IsTeamLeader() then
        return 2004
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam:MemberSize() < 3 then
        return 2005
    end

    local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade("MONEYTREE")
    local lName = oTeam:FilterTeamMember(function(oMember)
        local iMem = oMember.m_ID
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
        if oTarget and not global.oToolMgr:IsSysOpen("MONEYTREE", oTarget, true) then
            return oTarget:GetName()
        end
    end)
    
    if next(lName) then
        return 2006, {name=table.concat(lName, "、"), level = iOpenLevel}
    end
    return 1
end

function CHuodong:SingleFight(pid,npcobj,iFight, mConfig)
    super(CHuodong).SingleFight(self,pid,npcobj,iFight, mConfig)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local lMember = oPlayer:GetTeamMember()
        for _, iMem in ipairs(lMember or {}) do
            local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
            if oMember then
                self:AddSchedule(oMember)
                oMember:MarkGrow(45)
            end
        end
    end
end

function CHuodong:PackMonster(oMonster)
    local mRet = super(CHuodong).PackMonster(self, oMonster)
    if oMonster:Type() == 10010 or oMonster:Type() == 10020 then
        mRet.all_monster = oMonster.m_mAllMonster
    end
    return mRet
end

function CHuodong:OnMonsterCreate(oWar, oMonster, mData, npcobj)
    if oMonster:Type() == 10010 or oMonster:Type() == 10020 then
        local mResult = {}
        local mAllMonster = res["daobiao"]["fight"][self.m_sName]["monster"]
        for iMonster, mInfo in pairs(mAllMonster) do
            if iMonster == 10010 then goto continue end
            if iMonster == 10020 then goto continue end
            local oMonster = self:CreateMonster(oWar, iMonster, npcobj)
            mResult[iMonster] = oMonster:PackAttr()
            ::continue::
        end
        oMonster.m_mAllMonster = mResult
    end
    super(CHuodong).OnMonsterCreate(self, oWar, oMonster, mData, npcobj)
end

function CHuodong:WarFightEnd(oWar, iPid, oNpc, mArgs)
    local iWinSide = mArgs.win_side
    if iWinSide == 1 or not self:InGameTime() then 
        self:RemoveTempNpc(oNpc)
    end
    super(CHuodong).WarFightEnd(self, oWar, iPid, oNpc, mArgs)
end

function CHuodong:OnWarWin(oWar, iPid, oNpc, mArgs)
    mArgs.argenv = self:GenRewardEnv(mArgs)
    if oNpc then
        mArgs.npc_name = oNpc:Name()
    end
    super(CHuodong).OnWarWin(self, oWar, iPid, oNpc, mArgs)
end

function CHuodong:GetPartnerLimit(oWar)
    return 0
end

function CHuodong:GenRewardEnv(mArgs)
    local iSide = gamedefines.WAR_WARRIOR_SIDE.ENEMY
    local mInfo = table_get_depth(mArgs, {"warresult", "monster_info", "monster_dead", iSide}) or {}

    local mEnv = {}
    for i = 10011, 10018 do
        local sKey = string.format("killcnt_%d", i)
        mEnv[sKey] = mInfo[i] or 0
    end

    for i = 20011, 20018 do
        local sKey = string.format("killcnt_%d", i)
        mEnv[sKey] = mInfo[i] or 0
    end
    return mEnv
end

function CHuodong:PlayerExpEffect()
    return false
end

function CHuodong:Reward(iPid, sIdx, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local sKey = "moneytree_reward_cnt"
    local mConfig = self:GetConfig()
    if oPlayer.m_oTodayMorning:Query(sKey, 0) >= mConfig.reward_max then
        self:Notify(iPid, 2008)
        return
    end

    self:AddRideExp(iPid, sIdx)

    oPlayer.m_oTodayMorning:Add(sKey, 1)
    return super(CHuodong).Reward(self, iPid, sIdx, mArgs)
end

function CHuodong:AddRideExp(iPid, sIdx)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer or not sIdx then return end

    local mData = self:GetRewardData(tonumber(sIdx))
    if not mData then return end
    
    local iExp = mData.ride_exp
    oPlayer.m_oRideCtrl:AddExp(iExp, "金玉满堂")
end

function CHuodong:GenRewardContent(oPlayer, mReward, mArgs, bPreview)
    local mEnv = mArgs.argenv

    --将强化水晶加入
    if mReward.strength_stone_ratio and mReward.strength_stone_reward then
        local radio = math.floor(formula_string(mReward.strength_stone_ratio, mEnv))
        if math.random(100) <= radio then
            mReward = table_deep_copy(mReward)
            table.insert(mReward.item, mReward.strength_stone_reward)
        end
    end

    local mContent = super(CHuodong).GenRewardContent(self, oPlayer, mReward, mArgs, bPreview)
    if mReward.item_ratio then
        mContent.item_ratio = math.floor(formula_string(mReward.item_ratio, mEnv))
    end

    return mContent
end

function CHuodong:SendRewardContent(oPlayer, mContent, mArgs)
    mArgs.item_ratio = mContent.item_ratio
    super(CHuodong).SendRewardContent(self, oPlayer, mContent, mArgs)


    local oOrg = oPlayer:GetOrg()
    if oOrg then
        local iOrg = oOrg:OrgID()
        self:AddOrgStat(iOrg, 1)
    end
    
    if oPlayer:IsTeamLeader() and oOrg then
        self:RewardOrgPrestige(oPlayer, mArgs.npc_name) 
    end
end

function CHuodong:RewardOrgPrestige(oPlayer, sName)
    local oOrg = oPlayer:GetOrg() 
    if not oOrg then return end

    local sFormula = self:GetConfig()["org_prestige"]
    local iPrestige = formula_string(sFormula, {})
    sName = sName or "BOSS"
    local sMsg = global.oOrgMgr:GetOrgText(1169, {role={oPlayer:GetName(), sName}, amount=iPrestige})
    oOrg:AddPrestige(iPrestige, "金玉满堂", {chat_msg=sMsg})
end

function CHuodong:RewardItems(oPlayer, rValue, mArgs)
    if math.random(100) <= mArgs.item_ratio then
        super(CHuodong).RewardItems(self, oPlayer, rValue, mArgs)
    end
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:IsOpenDay(iTime)
    return get_dayno(self.m_iStartTime) == get_dayno(iTime)
end

function CHuodong:InGameTime()
    local iCurrTime = get_time()
    return iCurrTime >= self.m_iStartTime and iCurrTime <= self.m_iEndTime
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", get_time())
    local year,month,day,hour,min= sTime:match('^(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)')
    return os.time({
        year = year == "0" and mCurrDate.year or tonumber(year),
        month = month == "0" and mCurrDate.month or tonumber(month),
        day = (day == "0") and mCurrDate.day or tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = 0,
    })
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["condition"][1]
end

function CHuodong:GetRewardInfo()
    return res["daobiao"]["huodong"][self.m_sName]["reward"]
end

function CHuodong:GetChuanwen(iText)
    local mInfo = res["daobiao"]["chuanwen"][iText]
    return mInfo.content, mInfo.horse_race
end

function CHuodong:GetWeekDays()
    local mConfig = self:GetConfig()
    if self.m_iTestWeekDay then
        return {self.m_iTestWeekDay}
    else
        return mConfig.week_days
    end
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:TeamNotify(oPlayer, iChat, mReplace)
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        oTeam:TeamNotify(sMsg)
    else
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    end
end

function CHuodong:AddOrgStat(iOrg, iCnt)
    if not self.m_mOrgStat[iOrg] then
        self.m_mOrgStat[iOrg] = 0
    end
    self.m_mOrgStat[iOrg] = self.m_mOrgStat[iOrg] + iCnt
end

function CHuodong:TryEnterOrgScene(oPlayer)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iPid = oPlayer:GetPid()
    if oPlayer:InWar() then
        self:Notify(iPid, 2007, {name=oPlayer:GetName()})
        return 
    end
    if oPlayer:IsFixed() then
        return
    end

    local oTeam = oPlayer:HasTeam()
    if oTeam and not oPlayer:IsTeamLeader() and not oTeam:IsShortLeave(oPlayer:GetPid()) then
        self:Notify(iPid, 2011)
        return
    end
    if oPlayer:GetNowScene():GetSceneId() == oOrg:GetOrgSceneID() then
        self:Notify(iPid, 2010)
        return true
    end
    return oOrg:EnterOrgScene(oPlayer)
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 活动开启，发活动前10分钟传闻 
        102 - 发5分钟传闻
        103 - 马上开始，刷怪
        104 - 设置帮派在线人数 {100}
        105 - 活动结束
        201 - 设置活动开启星期
        ]])
    elseif iFlag == 101 then
        local mConfig = self:GetConfig()
        self.m_iStartTime = get_time() - mConfig.tip_time_shift1*60
        self.m_iEndTime = self.m_iStartTime + mConfig.continue_time*60
        self:NotifyGameStartStep(1)
    elseif iFlag == 102 then
        local mConfig = self:GetConfig()
        self.m_iStartTime = get_time() - mConfig.tip_time_shift2*60
        self.m_iEndTime = self.m_iStartTime + mConfig.continue_time*60
        self:NotifyGameStartStep(2)
    elseif iFlag == 103 then
        --self:GameOver()
        local mConfig = self:GetConfig()
        self.m_iStartTime = get_time()
        self.m_iEndTime = self.m_iStartTime + mConfig.continue_time*60
        self:GameStart()
    elseif iFlag == 104 then
        self.m_iTestOnline = math.min(100, tonumber(mArgs[1]))
    elseif iFlag == 105 then
        self:GameOver()
    elseif iFlag == 201 then
        self.m_iTestWeekDay = tonumber(mArgs[1]) or get_weekday()
    elseif iFlag == 203 then
        self:NewHour(get_hourtime({hour=0}))
    else
    end
end
