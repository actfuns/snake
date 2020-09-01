--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analy = import(lualib_path("public.dataanaly"))

local MONSTER_SCENE_MAP = 106

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "天魔"
CHuodong.m_iAutoFightOnStart = 0
CHuodong.m_sStatisticsName = "hd_tianmo"
CHuodong.m_iSysType= gamedefines.GAME_SYS_TYPE.SYS_TYPE_DEVIL
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    self.m_sName = sHuodongName
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1009
    self.m_iExtRewardRand = 1000
    self.m_iExtRewardLevel = 10
    self.m_mFirstBlood = {}
    self.m_lRankDataList = {}
    self.m_mDelayRemoveNpc = {}
    self:TryStartRewardMonitor()
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:NewHour(mNow)
    local iHour = mNow.date.hour
    if 5 == iHour then
        self:Reset()
    end
    if self:IsRefreshHour(iHour) then
        self:Schedule()
        self:_RefreshMonster()
    end
end

function CHuodong:IsRefreshHour(iHour)
    if iHour == 0 then return true end

    if iHour >= 10 then return true end

    return false
end

function CHuodong:Schedule()
    local f
    f = function()
        self:DelTimeCb("_RemoveNpc")
        self:AddTimeCb("_RemoveNpc", 45*60*1000, f)
        self:_RemoveNpc()
    end
    f()
end

function CHuodong:Reset()
    self.m_mFirstBlood = {}
    self:_RemoveNpc()
end

function CHuodong:GetNpcInWarText(npcobj)
    local sText = self:GetTextData(1005)
    sText = global.oToolMgr:FormatColorString(sText,{name = npcobj:Name()})
    return sText
end

function CHuodong:SayText(pid,npcobj,sText,func)
    local sName =  npcobj.m_sName
    npcobj.m_sName = npcobj.m_sShowName
    super(CHuodong).SayText(self, pid,npcobj,sText,func)
    npcobj.m_sName = sName
end

function CHuodong:SayNotifyText(pid,npcobj,sText)
    if npcobj then
        npcobj:Say(pid,sText,nil,nil,true)
    end
end

function CHuodong:GetPlayer2NpcConfig(npcobj)
    if  not self.m_lRankDataList or  0 == table_count(self.m_lRankDataList) then
        return super(CHuodong).GetPlayer2NpcConfig(self, npcobj)
    end
    local sName
    local mModel
    local mData =  extend.Random.random_choice(self.m_lRankDataList)
     sName = mData["name"] .. "心魔"
     mModel = mData["modelinfo"]
     return sName, mModel
end

function CHuodong:_CheckTeamLevel(npcobj, oTeam)
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local lName = {}
    local iOpenLevel = oToolMgr:GetSysOpenPlayerGrade("TIANMO")

    local function FilterCannotFightMember(oMember)
        if oMember:GetGrade() < iOpenLevel then
            return oMember:GetName()
        end
    end

    local lName = oTeam:FilterTeamMember(FilterCannotFightMember)
    if next(lName) then
        local sText = self:GetTextData(1003)
        sText = oToolMgr:FormatColorString(sText, {role = table.concat(lName, "、"), level = iOpenLevel})
        for _, pid in ipairs(oTeam:GetTeamMember()) do
            self:SayNotifyText(pid, npcobj, sText)
        end
        return false
    end
    return true
end

function CHuodong:CheckAnswer(oPlayer, npcobj, iAnswer)
    if iAnswer ~= 1 then
        return false
    end

    local oWar = npcobj:InWar()
    if oWar then
        local mArgs = {camp_flag = 1,npc_id = npcobj:NpcID()}
        if oPlayer:IsSingle() then
            global.oWarMgr:ObserverEnterWar(oPlayer,oWar:GetWarId(),mArgs)
        else
            global.oWarMgr:TeamObserverEnterWar(oPlayer,oWar:GetWarId(),mArgs)
        end
        return false
    end

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("TIANMO", oPlayer) then
        return false
    end

    if oPlayer.m_oActiveCtrl:GetNowWar() then
        return false
    end
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        self:_Say(oPlayer:GetPid(), 1002, npcobj, {})
        return false
    end
    if  3 > oPlayer:GetMemberSize() then
        self:_Say(oPlayer:GetPid(), 1002, npcobj, {})
        return false
    end
    if not self:_CheckTeamLevel(npcobj, oTeam) then 
        return false
    end
    return true
end

function CHuodong:OnCreateWar(oPlayer, oNpc, iFight)
    if not oPlayer or not oNpc then return end

    if oNpc.m_sTitle == "地煞精英" then
        local mChuanwen = table_get_depth(res, {"daobiao", "chuanwen", 1021})
        local sContent = mChuanwen.content
        local iHorse = mChuanwen.horse_race
        local mReplace = {
            role = oPlayer:GetName(),
            amount = oNpc.m_iStarLv,
            npc_name = oNpc.m_sName,
            camp_id = 1,
            npc_id = oNpc:ID(),
            target_id = "",
        }
        local sMsg = global.oToolMgr:FormatColorString(sContent, mReplace)
        global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
    end
end

function CHuodong:SingleFight(pid,npcobj,iFight, mConfig)
    local iStarLv = npcobj.m_iStarLv or 0

    self:Fight(pid,npcobj,iFight, mConfig, true)
end

function CHuodong:CreateWar(iPid, oNpc, iFight)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    oNpc.m_sFightName = oPlayer:GetName()
    local oWar = super(CHuodong).CreateWar(self, iPid, oNpc, iFight)
    self:OnCreateWar(oPlayer, oNpc, iFight)
    return oWar
end

function CHuodong:PackWarriorsAttr(oWar, mMonsterData, oNpc)
    local mWarriors = {}
    for _, iGroup in pairs(mMonsterData) do
        local mData = res["daobiao"]["fight"][self.m_sName]["group"]
        local mGroup = self:GetFightMonsterGroup(iGroup)
        local iMonsterIdx = extend.Random.random_choice(mGroup["monster"])
        local oMonster = self:CreateMonster(oWar, iMonsterIdx, oNpc)
        assert(oMonster,string.format("%s %s",self.m_sName, iMonsterIdx))
        table.insert(mWarriors, self:PackMonster(oMonster))
    end
    return mWarriors
end

function CHuodong:MonsterCreateExt(oWar, iMonsterIdx, oNpc)
    if not oNpc then return {} end

    return {
        env = {star = oNpc.m_iStarLv or 0}    
    }
end

function CHuodong:OnWarWin(oWar, pid, npcobj, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oWinner = oWorldMgr:GetOnlinePlayerByPid(pid)
    npcobj.m_sFightName = nil
    local oTeam = oWinner:HasTeam()
    if oTeam then
        local iTeamID = oTeam:TeamID()
        if not self.m_mFirstBlood[npcobj.m_iStarLv] then
            self.m_mFirstBlood[npcobj.m_iStarLv] = true
            if true == oWinner:IsTeamLeader() then
                self:_SendTeamFirstBloodChuanwen(oTeam, npcobj)
            end
        end
    end

    local lPlayers = self:GetFighterList(oWinner, mArgs)
    for _, pid in ipairs(lPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:AddSchedule(oPlayer)
            oPlayer:MarkGrow(34)
        end
    end
    super(CHuodong).OnWarWin(self, oWar, pid, npcobj, mArgs)        
    safe_call(self.RecordPlayerCnt, self, {[pid]=true})
    safe_call(self.LogDevilAnalyInfo, self, oWinner, true)

    local oMentoring = global.oMentoring
    safe_call(oMentoring.AddTaskCnt, oMentoring, oWinner, 4, 1, "师徒地煞")
end

function CHuodong:OnWarFail(oWar, pid, npcobj, mArgs)
    super(CHuodong).OnWarFail(self, oWar, pid, npcobj, mArgs)
    npcobj.m_sFightName = nil
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    self:_SendWarFailedChuanwen(oPlayer, npcobj)

    local iStarLv = npcobj.m_iStarLv
    iStarLv = math.max(1, math.min(iStarLv + math.random(1,4) - 2, 20))
    npcobj.m_iStarLv = iStarLv
    if npcobj:GetTitle() ~="" then
        npcobj.m_sTitle = self:_ChangeNpcShowTitle(npcobj.m_iStarLv, npcobj)
    end
    npcobj:SyncSceneInfo({title = npcobj:GetTitle()})
    local sShowName = self:_ChangeNpcShowName(iStarLv, npcobj.m_sName)
    npcobj.m_sShowName = sShowName
    if self.m_mDelayRemoveNpc[npcobj.m_ID] then
        self:RemoveTempNpc(npcobj)
        self.m_mDelayRemoveNpc[npcobj.m_ID] = nil
    end

    safe_call(self.RecordPlayerCnt, self, {[pid]=true})
    safe_call(self.LogDevilAnalyInfo, self, oPlayer, false)
end

function CHuodong:TeamReward(pid,sIdx,mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local lPlayers = self:GetFighterList(oPlayer,mArgs)
    self:RewardLeaderPoint(oPlayer,"disha","地煞星",#lPlayers)
    self:TryRewardFighterXiayiPoint(pid, lPlayers, nil)
    for _,pid in ipairs(lPlayers) do
        self:Reward(pid,sIdx,mArgs)
    end
end

function CHuodong:Reward(pid, sIdx, mArgs)
    super(CHuodong).Reward(self, pid, sIdx, mArgs)
    self:_AddDevilCnt(pid)
    local iCnt = self:_GetDevilCnt(pid)
    if iCnt >= 5 then
        self:Notify(pid, 1006, {count = iCnt})
    end
end

function CHuodong:LogDevilAnalyInfo(oPlayer, isWin)
    if not oPlayer then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local sTeam_detail = ""
    local oWorldMgr = global.oWorldMgr
    local lMember = oTeam:GetTeamMember()
    for _,iPid in pairs(lMember or {}) do
        local oMem = oTeam:GetMember(iPid)
        if oMem then
            if #sTeam_detail > 0 then
                sTeam_detail = sTeam_detail.."&"
            end
            sTeam_detail = sTeam_detail..iPid.."+"..oMem:GetSchool().."+"..oMem:GetGrade()
        end
    end

    for _,iPid in pairs(lMember or {}) do
        local o = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if o then
            local mAnalyLog = o:BaseAnalyInfo()
            mAnalyLog["team_detail"] = sTeam_detail
            mAnalyLog["team_leader"] = oTeam:IsLeader(iPid)
            mAnalyLog["turn_times"] = o.m_oScheduleCtrl:GetDoneTimes(self.m_iScheduleID)
            mAnalyLog["win_mark"] = isWin
            mAnalyLog["reward_detail"] = ""
            local mReward = o:GetTemp("reward_content", {})
            mAnalyLog["reward_detail"] = analy.table_concat(mReward)
            if table_count(mReward) then
                analy.log_data("DemonStrike", mAnalyLog)
            end
        end
    end
end

function CHuodong:GetMsgAdditon(sMsg, mArgs)
    local sHyperLink = string.format("{link8,%s,%d}", self.m_sName, self.m_iScheduleID)
    local sNpcName = "$npc"
    if mArgs then
        sNpcName = mArgs["warresult"]["custom"]["npcname"]
    end
    local oToolMgr = global.oToolMgr
    sMsg = oToolMgr:FormatColorString(sMsg, {npc = sNpcName, hyperlink = sHyperLink})
    return sMsg
end

function CHuodong:GetCustomArgs(mArgs, npcobj, mAddition)
    mAddition = mAddition or {}
    mAddition["npcname"] = npcobj.m_sName
    mAddition["npclv"] = npcobj.m_iStarLv
    return super(CHuodong).GetCustomArgs(self, mArgs, npcobj, mAddition)
end

function CHuodong:_PackNpcPosInfo(iMapId)
    local oSceneMgr = global.oSceneMgr
    local x, y = oSceneMgr:RandomPos2(iMapId)
    local mPosInfo = {
        x = x or 0,
        y = y or 0,
        z = 0,
        face_x = 0,
        face_y = 0,
        face_z = 0,
    }
    return mPosInfo
end

function CHuodong:_RefreshMonster()
    local oWorldMgr = global.oWorldMgr
    local oSceneMgr = global.oSceneMgr
    local mRes = res["daobiao"]["open"]["TIANMO"]
    if mRes.g_level > oWorldMgr:GetServerGrade() then
        return
    end

    local lPlayerList = oWorldMgr:GetOnlinePlayerList()
    local mStarData = self:GetStarLevelData()
    local iMinLv = mStarData["min"]
    local iMaxlv = mStarData["max"]
    local iRefreshCnt = formula_string(mStarData["refcnt"], {amount = #lPlayerList})
    local lMapIdx = self:GetMapList()
    local lNames = self:GetNpcNamelist()

    local lMapNpcList = {}
    local sDefaultTitle = ""
    local lSceneName = {}
    for i = 1, 2 do
        local iRereshMapCnt=0
        if i~=2 then
            iRereshMapCnt = math.random(1, math.max(1, iRefreshCnt - 1))
            iRefreshCnt = math.max(0, iRefreshCnt - iRereshMapCnt)
        else
            iRereshMapCnt = iRefreshCnt
        end

        
        local iMapId = extend.Random.random_choice(lMapIdx)
        local mScene = oSceneMgr:GetSceneListByMap(iMapId)
        local sSceneName = oSceneMgr:GetSceneName(iMapId)
        if not table_in_list(lSceneName, sSceneName) then
            table.insert(lSceneName, sSceneName)
        end
        for _, oScene in pairs(mScene) do
            local iScene = oScene:GetSceneId()
            for i = 1, iRereshMapCnt do
                local iLv = math.random(iMinLv, iMaxlv)
                local lNpcIdx = self:GetNpcMapList()

                local mPosInfo = self:_PackNpcPosInfo(iMapId)
                local idx = extend.Random.random_choice(lNpcIdx)
                local oNpc = self:CreateTempNpc(idx)
                local sDefaultTitle = oNpc.m_sTitle
                oNpc.m_iStarLv = iLv
                if table_count(lNames) ~= 0 then 
                    local sName = extend.Random.random_choice(lNames)
                    oNpc.m_sName = sName
                    oNpc.m_sShowName =  self:_ChangeNpcShowName(oNpc.m_iStarLv, sName)
                    if oNpc:GetTitle() ~="" then
                        oNpc.m_sTitle = self:_ChangeNpcShowTitle(oNpc.m_iStarLv, oNpc)
                    end
                end
                local mNpc = {["npc"] = oNpc, ["scene"] = iScene, ["posinfo"] = mPosInfo}
                table.insert(lMapNpcList, mNpc)
            end
        end
    end
    self:_SetLeaderNpcTitle(lMapNpcList, sDefaultTitle)
    self:_SendRefreshNpcChuanwen(lSceneName)
    local func = function (mData)
        _LoadRankPidList(mData)
    end
    global.oRankMgr:RequestRankShowData("grade", 20, func)
end

function CHuodong:_RemoveNpc()
    local lMapIdx = self:GetMapList()
    for _, iMapId in ipairs(lMapIdx) do 
        local lNpcList = self:GetNpcListByMap(iMapId)
        for _, oNpc in pairs(lNpcList) do 
            if not oNpc:InWar() then 
                self:RemoveTempNpc(oNpc)
            else
                self.m_mDelayRemoveNpc[oNpc.m_ID] = true
            end
        end
    end
end

function CHuodong:_SetLeaderNpcTitle(lMapNpcList, sDefaultTitle)
    local oSceneMgr = global.oSceneMgr
    local iLv =0
    for _, mNpc in ipairs(lMapNpcList) do
        local oNpc = mNpc["npc"]
        if iLv < oNpc.m_iStarLv then
            iLv = oNpc.m_iStarLv
        end
    end
    local mRefresh ={}
    for _, mNpc in ipairs(lMapNpcList) do
        local iScene = mNpc["scene"]
        local oScene = oSceneMgr:GetScene(iScene)
        local iMapId = oScene:MapId()
        local oNpc = mNpc["npc"]
        local mPosInfo = mNpc["posinfo"]
        if oNpc.m_iStarLv > 10 and oNpc.m_iStarLv == iLv then
            oNpc.m_sTitle = "地煞精英"
        end
        oNpc.m_mPosInfo = mPosInfo
        self:Npc_Enter_Scene(oNpc, iScene)
        if not mRefresh[iMapId] then
            mRefresh[iMapId] = 0
        end
        mRefresh[iMapId] = mRefresh[iMapId] + 1
    end
    local mLogData={
        refresh = extend.Table.serialize(mRefresh)
    }
    record.log_db("huodong", "devil_refresh",mLogData)
end

function CHuodong:_ChangeNpcShowName(iStarLv, sName)
    sName = sName .. string.format("(%s#w4)",iStarLv)
    return sName
end

function CHuodong:_ChangeNpcShowTitle(iStarLv, npcobj)
    local mData = self:GetTempNpcData(npcobj:NpcID())
    local sTitle = mData["title"] or ""
    sTitle = sTitle .. string.format("(%s#w4)",iStarLv)
    return sTitle
end

function CHuodong:_Say(pid, iNo, npcobj, mArgs)
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:FormatColorString(self:GetTextData(iNo), mArgs)
    self:SayNotifyText(pid, npcobj, sText)
end 

function CHuodong:RewardExp(oPlayer, iExp)
    local pid = oPlayer:GetPid()
    if 4 < self:_GetExpCnt(pid) then return end
    self:_AddExpCnt(pid)

    local mArgs =  {}
    if oPlayer:IsTeamLeader() then
        local iRatio = oPlayer.m_oStateCtrl:GetLeaderExpRaito(self.m_sName, oPlayer:GetMemberSize())
        mArgs.iLeaderRatio = iRatio
        mArgs.iAddexpRatio = iRatio
    end
    super(CHuodong).RewardExp(self, oPlayer, iExp, mArgs)
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    local pid = oPlayer:GetPid()
    local iCnt = self:_GetItemCnt(pid)
    if 2 < iCnt then return end
    self:_AddItemCnt(pid)
    super(CHuodong).RewardItems(self, oPlayer, mAllItems, mArgs)
end

function CHuodong:RewardSummonExp(oPlayer, sSummExp, mArgs)
    local pid = oPlayer:GetPid()
    if 4 < self:_GetSummonExpCnt(pid) then return end
    self:_AddSummonExpCnt(pid)
    super(CHuodong).RewardSummonExp(self, oPlayer, sSummExp, mArgs)
end

function CHuodong:RewardPartnerExp(oPlayer, sPartnerExp, mArgs)
    local pid = oPlayer:GetPid()
    if 4 < self:_GetPartnerExpCnt(pid) then return end
    self:_AddPartnerExpCnt(pid)
    super(CHuodong).RewardPartnerExp(self, oPlayer, sPartnerExp, mArgs)
end

function CHuodong:TryRewardFighterXiayiPoint(iLeaderPid, lFighterPid, mArgs)
    local function FilterFighter(iLeaderPid, lFighterPid)
        local lRetPid = {}
        for _, pid in pairs(lFighterPid) do
            if self:_GetDevilCnt(pid) >= 5 then
                table.insert(lRetPid, pid)
            end
        end
        return lRetPid
    end
    local lRewardPid = self:RewardFighterFilter(iLeaderPid, lFighterPid, FilterFighter)
    for _, pid in pairs(lRewardPid) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:RewardXiayiPoint(oPlayer, "disha", "地煞星")
        end
    end
end

function CHuodong:RewardGold(oPlayer, iGold, mArgs)
    local pid = oPlayer:GetPid()
    if 4 < self:_GetGoldCnt(pid) then return end
    self:_AddGoldCnt(pid)
    if iGold <= 0 then return end
    mArgs = mArgs or {}
    mArgs.fortune = true
    oPlayer:RewardGold(iGold, self.m_sName, mArgs)
end

function CHuodong:RewardSilver(oPlayer, iSilver, mArgs)
    local pid = oPlayer:GetPid()
    if 4 < self:_GetSilverCnt(pid) then return end
    self:_AddSilverCnt(pid)
    if iSilver <= 0 then return end
    mArgs = mArgs or {}
    mArgs.fortune = true
    oPlayer:RewardSilver(iSilver, self.m_sName, mArgs)
end

--奖励控制
function CHuodong:_AddItemCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["item"] or 0
    iCnt = iCnt +1
    mData["item"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetItemCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["item"] or 0
    return iCnt
end

function CHuodong:_AddExpCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["exp"] or 0
    iCnt = iCnt +1
    mData["exp"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetExpCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["exp"] or 0
    return iCnt
end

function CHuodong:_AddSummonExpCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["sumexp"] or 0
    iCnt = iCnt +1
    mData["sumexp"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetSummonExpCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["sumexp"] or 0
    return iCnt
end

function CHuodong:_AddPartnerExpCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["partnerexp"] or 0
    iCnt = iCnt +1
    mData["partnerexp"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetPartnerExpCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["partnerexp"] or 0
    return iCnt
end

function CHuodong:_AddDevilCnt(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["devilcnt"] or 0
    iCnt = iCnt + 1
    mData["devilcnt"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetDevilCnt(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["devilcnt"] or 0
    return iCnt
end

function CHuodong:_AddGoldCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["gold"] or 0
    iCnt = iCnt +1
    mData["gold"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetGoldCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["gold"] or 0
    return iCnt
end

function CHuodong:_AddSilverCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["silver"] or 0
    iCnt = iCnt +1
    mData["silver"] = iCnt
    oPlayer.m_oTodayMorning:Set("devil",mData)
end

function CHuodong:_GetSilverCnt(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mData = oPlayer.m_oTodayMorning:Query("devil",{})
    local iCnt = mData["silver"] or 0
    return iCnt
end

--资源获取--
function CHuodong:GetMapList()
    local mData = res["daobiao"]["scenegroup"][MONSTER_SCENE_MAP]
    assert(mData, string.format("%s get map list failed, scenegroup : %d", self.m_sName, MONSTER_SCENE_MAP))
    return mData["maplist"]
end


function CHuodong:GetStarLevelData()
    local oWorldMgr = global.oWorldMgr
    local iServerGrade = oWorldMgr:GetServerGrade()
    local mInfo = res["daobiao"]["huodong"][self.m_sName]["starlv"]
    local lKey = table_key_list(mInfo)
    table.sort(lKey)
    local iDesIndex
    if iServerGrade>=lKey[#lKey] then
        iDesIndex = lKey[#lKey] 
    end
    for index,key in ipairs(lKey) do
        if key>iServerGrade then
            iDesIndex = lKey[index-1]
            break
        end
    end
    local mData = res["daobiao"]["huodong"][self.m_sName]["starlv"][iDesIndex]
    assert(mData, string.format("%s star level config %d %s not exist !\n", self.m_sName, iServerGrade,iDesIndex))
    return mData
end

function CHuodong:GetNpcMapList()
    local mData = res["daobiao"]["huodong"][self.m_sName]["npcmap"]
    local lKey = table_key_list(mData)
    local iStarLv = extend.Random.random_choice(lKey)
    mData = mData[iStarLv]
    assert(mData, string.format("%s npcmap list config not exist!starlv : %d \n", self.m_sName, iStarLv))
    return mData["npclist"]
end

function CHuodong:GetNpcNamelist()
    local mData = res["daobiao"]["huodong"][self.m_sName]["npcname"]
    local mNames = {}
    for _, name in pairs(mData) do 
        table.insert(mNames, name["name"])
    end
    return mNames
end

function CHuodong:DoScript2(pid,npcobj,s,mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if not sCmd then return end
    local sArgs = string.sub(s, #sCmd + 1, -1)
    if not mArgs then
        mArgs = {}
    end
    if string.find(s,"SF_STAR") then
        local iStarLv = npcobj.m_iStarLv or 0
        local mRes = res["daobiao"]["huodong"][self.m_sName]["fight"]
        assert(mRes[iStarLv],string.format("%s %s fight error",self.m_sName,iStarLv))
        local iFight = mRes[iStarLv]["fight"]
        self:SingleFight(pid,npcobj,iFight)
        return true
    end
    super(CHuodong).DoScript2(self,pid,npcobj,s,mArgs)
end

--传闻--
function CHuodong:_SendTeamFirstBloodChuanwen(oTeam, npcobj)
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local lName = {}
    for _, pid in ipairs(oTeam:GetTeamMember()) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        table.insert(lName, oPlayer:GetName())
    end

    local mChuanwen = res["daobiao"]["chuanwen"][1022]
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = table.concat(lName, "、"), amount = npcobj.m_iStarLv, npc = npcobj.m_sName})
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
end

function CHuodong:_SendRefreshNpcChuanwen(lSceneNname)
    local oChatMgr = global.oChatMgr
    if next(lSceneNname) then
        local mChuanwen = res["daobiao"]["chuanwen"][1020]
        local oToolMgr = global.oToolMgr
        local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {submitscene = table.concat(lSceneNname, "、")})
        oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end
end

function CHuodong:_SendWarFailedChuanwen(oPlayer, npcobj)
    local oChatMgr = global.oChatMgr
    local sHyperLink = string.format("{link15,%d, %f, %f, %d}", npcobj.m_iMapid, npcobj.m_mPosInfo.x, npcobj.m_mPosInfo.y, npcobj.m_ID)
    local mChuanwen = res["daobiao"]["chuanwen"][1024]
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = oPlayer:GetName(), hyperlink = sHyperLink, npc = npcobj.m_sName})
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
end

function CHuodong:GetFightMonsterGroup(iGroup)
    local mData = res["daobiao"]["fight"][self.m_sName]["group"][iGroup]
    assert(mData, string.format("devil not find fight group : %d", iGroup))
    return mData
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看\nhuodongop devil 100",
        "101 天魔触发刷天\nhuodongop devil 101",
        "102 整点刷天魔\nhuodongop devil 102",
        "103 清除奖励限制\nhuodongop devil 103",
        "104 设置额外奖励随机范围\nhuodongop devil 104 {rand = 1000}",
        "105 查看天魔分布\nhuodongop devil 105",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        self:Reset()
        oNotifyMgr:Notify(pid,"刷天完毕")
    elseif iFlag == 102 then
        self:Schedule()
        self:_RefreshMonster()
        oNotifyMgr:Notify(pid,"刷新完毕")
    elseif iFlag == 103 then
        oPlayer.m_oTodayMorning:Delete("devil")
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 104 then
        local iRand = mArgs.rand or 1000
        self.m_iExtRewardRand = iRand
        oNotifyMgr:Notify(pid,string.format("设置额外奖励随机范围:%s",iRand))
    elseif iFlag == 105 then
        local sMsg = ""
        local lMapId = self:GetMapList()
        for _,iMapId in ipairs(lMapId) do
            local mScene = global.oSceneMgr:GetSceneListByMap(iMapId)
            for _, oScene in ipairs(mScene) do
                local iScene = oScene:GetSceneId()
                local lNpcList = self:GetNpcListByScene(iScene)
                for _, oNpc in pairs(lNpcList) do 
                    local mPos = oNpc:PosInfo()
                    sMsg = sMsg ..  string.format("%s %s %s\n",oScene:GetName(),math.floor(mPos.x),math.floor(mPos.y))
                end
            end
        end
        if sMsg == "" then
            sMsg = "暂无天魔"
        end
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
        oNotifyMgr:Notify(pid,"执行完毕")
    end
end

function _LoadRankPidList(mData)
    local oWorldMgr = global.oWorldMgr
    local oHD = global.oHuodongMgr:GetHuodong("devil")
    oHD.m_lRankDataList = {}
    for _, data in ipairs(mData) do 
        local pid = data[4]
        oWorldMgr:LoadProfile(pid, function(oPlayer)
            if oPlayer then
                local mRandInfo = {}
                mRandInfo["pid"] = pid
                mRandInfo["name"] = oPlayer:GetName()
                local mModeInfo = oPlayer:GetModelInfo()
                mModeInfo["horse"] = nil
                mRandInfo["modelinfo"] = mModeInfo
                table.insert(oHD.m_lRankDataList, mRandInfo)
            else
                record.error(string.format("%s load rank %s fail",oHD.m_sName,pid))
            end
        end)
    end
end
