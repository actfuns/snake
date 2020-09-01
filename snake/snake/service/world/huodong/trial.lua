local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analylog = import(lualib_path("public.analylog"))


SAVE_KEY = "trial_list"
STATUS_NULL = 0
STATUS_REWARD = 1
STATUS_REWARDED = 2

-----------TODO list------------
--1.内存泄露
--------------------------------

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "英雄试炼"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o:Init()
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1027
end

function CHuodong:ScheduleID()
    return self.m_iScheduleID or 1027
end

function CHuodong:CheckLastDayReward(oPlayer)
    local iTime = oPlayer.m_oTodayMorning.m_mKeepList[SAVE_KEY]
    if not iTime then return end
    
    local iCurrTime = self:GetMorningDayNo()
    if iTime == iCurrTime then return end

    local lTrialList = oPlayer.m_oTodayMorning:GetData(SAVE_KEY)
    if not lTrialList then return end

    local lReward = {}
    local mMatchRule = self:GetTrialMatchRule()
    for iPos, mTrial in pairs(lTrialList) do
        if not mMatchRule[iPos] then
            goto continue
        end
        if mTrial.status == STATUS_REWARD then
            mTrial.status = STATUS_REWARDED
            table.insert(lReward, mMatchRule[iPos].reward_id)
        end
        ::continue::
    end
    oPlayer.m_oTodayMorning:Set(SAVE_KEY, nil)
    if next(lReward) then
        self:TrySendMailReward(oPlayer, lReward)
    end
end
 
function CHuodong:TrySendMailReward(oPlayer, lReward)
    local iMailId, mContent = 2028, {}
    for _, iReward in ipairs(lReward) do
        local mInfo = self:GetRewardData(iReward)
        local mTmp = self:GenRewardContent(oPlayer, mInfo)
        for sType, rVal in pairs(mTmp) do
            if sType == "summexp" then
                self:RewardSummonExp(oPlayer, rVal)
                goto continue
            end
            if not mContent[sType] then
                mContent[sType] = rVal
            else
                if type(rVal) == "number" then
                    mContent[sType] = mContent[sType] + rVal
                elseif type(rVal) == "table" then
                    for k, v in pairs(rVal) do
                        mContent[sType][k] = v
                    end
                end
            end
            ::continue::
        end
    end
    local lItem = {}
    for iItemIdx, mItems in pairs(mContent.items or {}) do
        lItem = list_combine(lItem, mItems["items"])
    end
    mContent.items = lItem

    local mData, sName = global.oMailMgr:GetMailInfo(iMailId)
    if not mData then return end
    global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mData, mContent)
end

function CHuodong:GetTrialMatchInfo(oPlayer, iCnt)
    local iPid = oPlayer:GetPid()
    local mData = {
        school = oPlayer:GetSchool(),
        grade = oPlayer:GetGrade(),
        score = oPlayer:Query("max_score") or oPlayer:GetScore(),
        exclude = {[tostring(iPid)] = 1},
    }
    global.oChallengeMgr:GetTrialMatchInfo(iPid, mData, function(iPid, mData)
        self:KeepTrialList(iPid, mData, iCnt)
    end)
end

function CHuodong:C2GSTrialOpenUI(oPlayer)
    local sMsg = self:GetTextData(1001)
    if not global.oToolMgr:IsSysOpen("HEROTRIAL", oPlayer, false, {plevel_tips=sMsg, glevel_tips=sMsg}) then
        return
    end
    self:CheckLastDayReward(oPlayer)

    local lTrialList = oPlayer.m_oTodayMorning:Query(SAVE_KEY)
    if not lTrialList then
        self:GetTrialMatchInfo(oPlayer, 1)
    else
        self:TryOpenTrialUI(oPlayer, lTrialList, 1)
    end
end

function CHuodong:KeepTrialList(iPid, mData, iCnt)
    if mData.err_code ~= 0 or not mData.match_list then
        self:Notify(iPid, 1007)
        return
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local lTrialList = {}
        for iPos, iPid in ipairs(mData.match_list) do
            table.insert(lTrialList, {pid=iPid})
        end
        oPlayer.m_oTodayMorning:Set(SAVE_KEY, lTrialList)
        self:TryOpenTrialUI(oPlayer, lTrialList, iCnt)
    end
end

function CHuodong:TryOpenTrialUI(oPlayer, lTrialList, iCnt)
    local lNetTrial = {}
    local iPid = oPlayer:GetPid()
    for iPos, mTrial in pairs(lTrialList) do
        if mTrial.base_info then
            local mNet = {
                pid = mTrial.pid,
                base_info = mTrial.base_info,
                score = mTrial.score,
                status = mTrial.status,
            }
            table.insert(lNetTrial, mNet)
            if not mTrial.status or mTrial.status == STATUS_NULL or iPos == #lTrialList then
                local iMaxTimes = self:GetConfig().max_times
                local sKey = "trial_times" .. iPos
                local iTimes = oPlayer.m_oTodayMorning:Query(sKey, 0)
                local mSend = {
                    trial_list = lNetTrial,
                    ret_time = iMaxTimes-iTimes,
                    total = #lTrialList,
                }
                oPlayer:Send("GS2CTrialOpenUI", mSend)
                break
            end
        else
            global.oWorldMgr:LoadWanfaCtrl(mTrial.pid, function(oWanfaCtrl)
                self:AfterLoadWanfaCtrl(iPid, oWanfaCtrl, iPos, lNetTrial, iCnt)
            end)
            break
        end
    end
end

function CHuodong:AfterLoadWanfaCtrl(iPid, oWanfaCtrl, iPos, lNetTrial, iCnt)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    --异步，防止刷天 
    self:CheckLastDayReward(oPlayer)

    local lTrialList = oPlayer.m_oTodayMorning:Query(SAVE_KEY)
    if not lTrialList then
        if iCnt <= 3 then
            self:GetTrialMatchInfo(oPlayer, iCnt+1)
        end
        return
    end

    local iTarget = oWanfaCtrl:GetPid()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        oWanfaCtrl:SyncData(oTarget)
    end
    
    local oWarCtrl = oWanfaCtrl:GetWarData()
    local oRoPlayer = oWarCtrl.m_oRoFight
    if oRoPlayer then
        local mTrial = lTrialList[iPos] or {}
        local mBase, iScore = self:PackRoPlayerForKeep(oRoPlayer)
        mTrial.base_info = mBase
        mTrial.score = iScore
        oPlayer.m_oTodayMorning:Dirty()

        local mNet = {
            pid = mTrial.pid,
            base_info = mTrial.base_info,
            score = mTrial.score,
            status = mTrial.status,
        }
        lNetTrial[iPos] = mNet
        local iMaxTimes = self:GetConfig().max_times
        local sKey = "trial_times" .. iPos
        local iTimes = oPlayer.m_oTodayMorning:Query(sKey, 0)
        local mSend = {
            trial_list= lNetTrial,
            ret_time = iMaxTimes-iTimes,
            total = #lTrialList,
        }
        oPlayer:Send("GS2CTrialOpenUI", mSend)
    else
        record.info("can't load wardatactrl "..iTarget)
        table.remove(lTrialList, iPos)
        oPlayer.m_oTodayMorning:Dirty()
        self:TryOpenTrialUI(oPlayer, lTrialList, 1)
    end
end

function CHuodong:PackRoPlayerForKeep(oRoPlayer)
    local mBaseInfo = {
        pid = oRoPlayer.m_iPid,
        name = oRoPlayer.m_sName,
        grade = oRoPlayer.m_iGrade,
        model_info = oRoPlayer.m_mModel,
        icon = oRoPlayer.m_iIcon,
        school = oRoPlayer.m_iSchool,
    }
    return mBaseInfo, oRoPlayer.m_iScore
end

function CHuodong:C2GSTiralStartFight(oPlayer)
    self:CheckLastDayReward(oPlayer)
   
    local lTrialList = oPlayer.m_oTodayMorning:Query(SAVE_KEY)
    if not lTrialList then
        self:GetTrialMatchInfo(oPlayer, 1)
        return
    end
    
    local iPid = oPlayer:GetPid()
    local iTarget, iPos = self:ChooseTrialTarget(oPlayer, lTrialList)
    if not iTarget then
        self:Notify(iPid, 1007)
        return
    end
    local iRet = self:ValidStartFight(oPlayer, iPos)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    global.oWorldMgr:LoadWanfaCtrl(iTarget, function(oWanfaCtrl)
        self:StartFight(iPid, oWanfaCtrl, iPos)
    end)
end

function CHuodong:ChooseTrialTarget(oPlayer, lTrialList)
    for iPos, mTrial in pairs(lTrialList) do
        if not mTrial.status or mTrial.status == STATUS_NULL then
            return mTrial.pid, iPos
        end
    end
end

function CHuodong:ValidStartFight(oPlayer, iPos)
    if not global.oToolMgr:IsSysOpen("HEROTRIAL", oPlayer, true) then
        return 1001
    end
    if oPlayer:HasTeam() and not oPlayer:IsTeamShortLeave() then
        return 1002
    end
    local mConfig = self:GetConfig()
    local sKey = "trial_times" .. iPos
    if oPlayer.m_oTodayMorning:Query(sKey, 0) > mConfig.max_times then
        return 1008
    end
    local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
    if iWarStatus ~= gamedefines.WAR_STATUS.NO_WAR then
        return 1003
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene:ValidJJC() then
        return 1004
    end
    return 1
end

function CHuodong:StartFight(iPid, oWanfaCtrl, iPos)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oWarMgr = global.oWarMgr
    local oWarData = oWanfaCtrl:GetWarData()
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_TRIAL,
        {auto_start = gamedefines.WAR_AUTO_TYPE.FORBID_AUTO, GamePlay = self.m_sName}
    )
    local iWarId = oWar:GetWarId()
    oWarMgr:EnterWar(oPlayer, iWarId, {camp_id=gamedefines.WAR_WARRIOR_SIDE.FRIEND}, true)
    local mRoInfo = oWarData:PackWarInfo()
    local iKey, mRoSumm = self:PackSummonWarInfo4Wanfa(oWarData)
    local mRoKeepSum = self:PacketWarKeepSummon(oWarData, iKey)
    local mRoPartners = self:PackPartnerWarInfo4Wanfa(oWarData)
    local mFmtInfo = self:GetFormation(oWarData, mRoPartners)
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, {fmtinfo=mFmtInfo})
    oWar:EnterRoPlayer2(mRoInfo, mRoSumm, mRoKeepSum, {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY})
    oWar:EnterRoPartnerList2(mRoPartners, {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY})

    local iTarget = oWarData:GetPid()
    local iPid = oPlayer:GetPid()
    oWarMgr:SetCallback(iWarId, function(mArgs)
        self:OnTrialFightEnd(iPid, iTarget, iPos, mArgs)
    end)
    oWarMgr:StartWar(iWarId)

    oPlayer.m_oScheduleCtrl:FireTrialFightStart()
    analylog.LogWanFaInfo(oPlayer, self.m_sName, iPos, 1)
end

function CHuodong:OnTrialFightEnd(iPid, iTarget, iPos, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    self:CheckLastDayReward(oPlayer)
    oPlayer:MarkGrow(17)
    local lTrialList = oPlayer.m_oTodayMorning:Query(SAVE_KEY)
    if not lTrialList then return end

    if mArgs.win_side == gamedefines.WAR_WARRIOR_SIDE.ENEMY then
        local sKey = "trial_times" .. iPos
        oPlayer.m_oTodayMorning:Add(sKey, 1)
    else
        local mTrial = lTrialList[iPos]
        if mTrial then
            mTrial.status = STATUS_REWARD
        end
        oPlayer.m_oTodayMorning:Set(SAVE_KEY, lTrialList)
        self:AddSchedule(oPlayer)
        oPlayer.m_oScheduleCtrl:HandleRetrieve(self:ScheduleID(), 1)

        if iPos >= table_count(self:GetTrialMatchRule()) then
            self:SysAnnounce(1061, {name=oPlayer:GetName()})
        end
        analylog.LogWanFaInfo(oPlayer, self.m_sName, iPos, 2)
    end

    self:TryOpenTrialUI(oPlayer, lTrialList, 1)
end

function CHuodong:GetFormation(oWarData, lPartnerInfo)
    local iPid = oWarData:GetPid()
    local iFmt, iGrade = oWarData:GetFmtAndGrade()
    local mResult = {}
    mResult.grade = iGrade
    mResult.fmt_id = iFmt
    mResult.pid = iPid
    mResult.player_list = {iPid,}
    local lPSid = {}
    for _, mInfo in ipairs(lPartnerInfo) do
        table.insert(lPSid, mInfo.pid)
    end
    mResult.partner_list = lPSid
    if table_count(mResult.player_list) + table_count(mResult.partner_list) < 5 then
        mResult.fmt_id = 1
        mResult.grade = 1
    end
    return mResult
end

function CHuodong:PackPartnerWarInfo4Wanfa(oWarData)
    local iPlayerSchool = oWarData.m_oRoFight:GetSchool()
    local iAssistantLimit = gamedefines.ASSISTANT_SCHOOL[iPlayerSchool] and 2 or 3
    local lResult = {}
    local lSid = table_key_list(oWarData.m_mRoPartners)
    if #lSid > 4 then
        table.sort(lSid, function(x, y)
            local oPartner1 = oWarData.m_mRoPartners[x]
            local oPartner2 = oWarData.m_mRoPartners[y]
            return oPartner1:GetScore() > oPartner2:GetScore()
        end)
        local iAssistantNum = 0
        local lRet = {}
        for idx, iSid in ipairs(lSid) do
            local oPartner = oWarData.m_mRoPartners[iSid]
            if gamedefines.ASSISTANT_SCHOOL[oPartner:GetSchool()] then
                if iAssistantNum < iAssistantLimit then
                    iAssistantNum = iAssistantNum + 1
                    table.insert(lResult, iSid)
                else
                    table.insert(lRet, iSid)
                end
            else
                table.insert(lResult, iSid)
            end

            if #lResult >= 4 then break end
        end
        if #lResult < 4 and #lRet > 0 then
            for _, iSid in ipairs(lRet) do
                table.insert(lResult, iSid)
                if #lResult >= 4 then
                    break
                end
            end
        end
    else
        lResult = lSid
    end
    local lPartnerInfo = {}
    for _, iSid in ipairs(lResult) do
        table.insert(lPartnerInfo, oWarData.m_mRoPartners[iSid]:PackWarInfo())
    end
    return lPartnerInfo 
end

function CHuodong:PackSummonWarInfo4Wanfa(oWarData)
    local mSummon = {}
    local iGradeLimit = oWarData.m_oRoFight:GetGrade() + 10
    for iNo, oRoSummon in pairs(oWarData.m_mRoSummons or {}) do
        if oRoSummon:GetGrade() <= iGradeLimit then
            mSummon[iNo] = oRoSummon
        end
    end
    local lKeyList = table_key_list(mSummon)
    local iTotal = #lKeyList
    if iTotal <= 0 then return end
    if iTotal <= 2 then
        local iKey = lKeyList[math.random(iTotal)]
        return iKey, mSummon[iKey]:PackWarInfo()
    end
    table.sort(lKeyList, function(x, y)
        return mSummon[x]:GetScore() > mSummon[y]:GetScore()
    end)
    local iKey = lKeyList[math.random(2)]
    return iKey, mSummon[iKey]:PackWarInfo()
end

function CHuodong:PacketWarKeepSummon(oWarData, iIgnore)
    local mSummon, iTotal = {}, 4
    local iGradeLimit = oWarData.m_oRoFight:GetGrade() + 10
    for iNo, oRoSummon in pairs(oWarData.m_mRoSummons or {}) do
        if iNo ~= iIgnore and oRoSummon:GetGrade() <= iGradeLimit then
            mSummon[iNo] = oRoSummon:PackWarInfo()
            iTotal = iTotal - 1
        end
        if iTotal <= 0 then break end
    end
    return mSummon
end

function CHuodong:C2GSTrialGetReward(oPlayer, iPos)
    self:CheckLastDayReward(oPlayer)

    local lTrialList = oPlayer.m_oTodayMorning:Query(SAVE_KEY)
    if not lTrialList then
        self:GetTrialMatchInfo(oPlayer, 1)
        return
    end

    local mTrialList = lTrialList[iPos]
    if not mTrialList then return end

    local iPid = oPlayer:GetPid()
    if mTrialList.status == STATUS_NULL then
        self:Notify(iPid, 1005)
        return
    end
    if mTrialList.status == STATUS_REWARDED then
        self:Notify(iPid, 1006)
        return
    end
    
    mTrialList.status = STATUS_REWARDED
    oPlayer.m_oTodayMorning:Set(SAVE_KEY, lTrialList)

    local mMatchRule = self:GetTrialMatchRule()
    local iReward = table_get_depth(mMatchRule, {iPos, "reward_id"})
    if iReward then
        self:Reward(oPlayer:GetPid(), iReward)
        oPlayer:Send("GS2CTrialRefreshUnit", {trial_unit=mTrialList, pos=iPos})
    end
end

function CHuodong:GetMorningDayNo()
    return get_morningdayno(self.m_iTestTime)
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:SysAnnounce(iChat, mReplace)
    local mInfo = res["daobiao"]["chuanwen"][iChat]
    if not mInfo then return end

    local sMsg, iHorse = mInfo.content, mInfo.horse_race
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
end

function CHuodong:GetTrialMatchRule()
    return res["daobiao"]["huodong"]["trial"]["match_rule"]
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["trial"]["config"][1]
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 调整测试时间 {1} 往前推进1天
        102 - 进行下一环战斗
        103 - 领取奖励 {1}
        105 - 查看匹配列表
        ]])
    elseif iFlag == 101 then
        self.m_iTestTime = get_time() + mArgs[1]*24*3600
    elseif iFlag == 102 then
        self:C2GSTiralStartFight(oMaster)
    elseif iFlag == 103 then
        self:C2GSTrialGetReward(oMaster, mArgs[1])
    elseif iFlag == 104 then
        self:C2GSTrialOpenUI(oMaster)
    elseif iFlag == 105 then
        local sMsg = extend.Table.serialize(oMaster.m_oTodayMorning:Query(SAVE_KEY, {}))
        global.oNotifyMgr:Notify(iPid, sMsg)
    elseif iFlag == 106 then
        local iTarget = mArgs[1]
        global.oWorldMgr:LoadWanfaCtrl(iTarget, function(oWanfaCtrl)
            self:StartFight(iPid, oWanfaCtrl, 1)
        end)
    end
end

