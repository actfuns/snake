local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local roplayer = import(service_path("rofighter.roplayer"))

local ARENA_TEAM = 1
local ARENA_SINGLE =2
local BOSS_SCORE = 50

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "擂台"
CHuodong.m_iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_ARENA
inherit(CHuodong, huodongbase.CHuodong)

local function SortFighterList(obj1,obj2)
    return obj1[2]>obj2[2]
end

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_sName = sHuodongName

    o.m_mGameTime = {
        protect =  10 ,
    }
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1011
    self.m_oRoFight = nil
    self.m_mViewFight = {}
    self.m_mBossPid = nil
    self.m_FirstBeatBoss = nil
    self.m_iNpcId = 0

    self.m_oTodayRoFight = nil
    self.m_mTodayBossPid = nil
end

function CHuodong:NewDay(mNow)
    self:Reset()
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    if self.m_mBossPid and self.m_oRoFight then
        mData["rofighter"]  = {}
        mData["rofighter"]["fight"] = self.m_mBossPid
        mData["rofighter"]["fightinfo"] = self.m_oRoFight:Save()
    end
    if self.m_mTodayBossPid and self.m_oTodayRoFight then
        mData["today_rofighter"]  = {}
        mData["today_rofighter"]["fight"] = self.m_mTodayBossPid
        mData["today_rofighter"]["fightinfo"] = self.m_oTodayRoFight:Save()
    end
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    if mData["rofighter"] then
        self.m_mBossPid = mData["rofighter"]["fight"]
        local oRoPlayer = roplayer.NewRoPlayer(self.m_mBossPid["pid"])
        oRoPlayer:Load(mData["rofighter"]["fightinfo"])
        self.m_oRoFight = oRoPlayer
    end
    if mData["today_rofighter"] then
        self.m_mTodayBossPid = mData["today_rofighter"]["fight"]
        local oRoPlayer = roplayer.NewRoPlayer(self.m_mTodayBossPid["pid"])
        oRoPlayer:Load(mData["today_rofighter"]["fightinfo"])
        self.m_oTodayRoFight = oRoPlayer
    end
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:GetGameTime(flag)
    return self.m_mGameTime[flag]
end

function CHuodong:GetFlag(sFlag)
    return string.format("%s_%s",self.m_sName,sFlag)
end

function CHuodong:CheckConpetation(oFighter, iEnemy)
    local iFighter = oFighter:GetPid()
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("LEITAI", oFighter) then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oSceneMgr = global.oSceneMgr
    local oEnemy = oWorldMgr:GetOnlinePlayerByPid(iEnemy)
    if not oEnemy then return end
    local iScene = oFighter.m_oActiveCtrl:GetNowScene():GetSceneId()
    local mPos = oFighter:GetNowPos()
    if false == oSceneMgr:IsInLeiTai(iScene, mPos.x, mPos.y) then
        self:_Notify(iFighter, 1005)
        return
    end
    iScene = oEnemy.m_oActiveCtrl:GetNowScene():GetSceneId()
    mPos = oEnemy:GetNowPos()
    if  false == oSceneMgr:IsInLeiTai(iScene, mPos.x, mPos.y) then
        self:_Notify(iFighter, 1004, {role = oEnemy:GetName()})
        self:GS2CArenaFightEnd(oFighter, iEnemy)
        return
    end

    local oFightTeam
    oFightTeam = oFighter:HasTeam()
    if oFightTeam then
        if  not oFighter:IsTeamLeader() then
            if not oFightTeam:IsShortLeave(iFighter) then
                self:_Notify(iFighter,1015)
                return
            end
        else
            if oFightTeam:IsTeamMember(iEnemy) then
                if not oFightTeam:IsShortLeave(iEnemy) then
                    self:_Notify(iFighter,1015)
                    return
                end
            end
        end
    end

    local iWarStatus = oEnemy.m_oActiveCtrl:GetWarStatus()
    if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
        self:_Notify(iFighter, 1006)
        self:GS2CArenaFightEnd(oFighter, iEnemy)
        return
    end

    if oFighter:GetGrade() >= oEnemy:GetGrade() + 11 then
        self:_Notify(iFighter, 1007)
        self:GS2CArenaFightEnd(oFighter, iEnemy)
        return
    end

    if oFighter:GetGrade() + 11 <= oEnemy:GetGrade() then
        self:_Notify(iFighter, 1008)
        self:GS2CArenaFightEnd(oFighter, iEnemy)
        return
    end

    local iEndTime = oEnemy.m_oThisTemp:QuerySecond(self:GetFlag("protect"))
    local iLeftTime = math.max(0,iEndTime-get_time())
    if iLeftTime>0 then
        self:_Notify(iFighter, 1009, {role = oEnemy:GetName(), amount = iLeftTime})
        self:GS2CArenaFightEnd(oFighter, iEnemy)
        return
    end

    if iWarStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
        global.oWarMgr:TeamLeaveObserverWar(oEnemy)
    end
    self:Conpetation(oFighter, oEnemy)
end

function CHuodong:Conpetation(oFighter, oEnemy)
    local oWarMgr = global.oWarMgr
    local oWorldMgr = global.oWorldMgr
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["condition"][1]
    local iBarrageShow = mConfig.barrage_show or 0
    local iBarrageSend = mConfig.barrage_send or 0
    local lAction = mConfig.action_id or {}
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_ARENA,
        {GamePlay=self.m_sName,barrage_show=iBarrageShow,barrage_send=iBarrageSend})
    if not oWar then
        return
    end
    local iWarId = oWar:GetWarId()
    local mFightInfo = {camp_id = 1}
    local mEnemyInfo = {camp_id = 2}
    local ret
    local iLimit = self:GetPartnerLimit(oWar)
    if oFighter:IsSingle() then
        ret = oWarMgr:EnterWar(oFighter, iWarId, mFightInfo, true, iLimit)
    else
        ret = oWarMgr:TeamEnterWar(oFighter, iWarId, mFightInfo, true, iLimit)
    end
    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end
    if oEnemy:IsSingle() then
        ret = oWarMgr:EnterWar(oEnemy, iWarId, mEnemyInfo, true, iLimit)
    else
        ret = oWarMgr:TeamEnterWar(oEnemy, iWarId, mEnemyInfo, true, iLimit)
    end
    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end
    local mFightInfo = {}
    mFightInfo["fighter"] = {pid = oFighter:GetPid(),grade = oFighter:GetGrade(),single = oFighter:IsSingle()}
    mFightInfo["enemy"] = {pid = oEnemy:GetPid(),grade = oEnemy:GetGrade(),single = oEnemy:IsSingle()}
    self.m_mViewFight[oWar:GetWarId()] = {info = self:PackViewInfo(oFighter,oEnemy),time = get_time()}
    local lPlist1={}
    local lPlist2 = {}
    if oFighter:IsSingle() then
        table.insert(lPlist1,oFighter:GetPid())
    elseif oFighter:HasTeam() then
        local oTeam = oFighter:HasTeam()
        for _,oMem in ipairs(oTeam:GetMember()) do
            table.insert(lPlist1,oMem.m_ID)
        end
    end
    if oEnemy:IsSingle() then
        table.insert(lPlist2,oEnemy:GetPid())
    elseif oFighter:HasTeam() then
        local oTeam = oEnemy:HasTeam()
        for _,oMem in ipairs(oTeam:GetMember()) do
            table.insert(lPlist2,oMem.m_ID)
        end
    end
    for _,iPlayer1 in ipairs(lPlist1) do
        for _,iPlayer2 in ipairs(lPlist2) do
            local oPlayer1 = global.oWorldMgr:GetOnlinePlayerByPid(iPlayer1)
            local oPlayer2 = global.oWorldMgr:GetOnlinePlayerByPid(iPlayer2)
            local mBattleInfo = oPlayer1.m_oToday:Query(self:GetFlag("battle"),{})
            local iBattleCnt = mBattleInfo[iPlayer2] or 0
            mBattleInfo[iPlayer2]=iBattleCnt+1
            oPlayer1.m_oToday:Set(self:GetFlag("battle"),mBattleInfo)

            local mBattleInfo = oPlayer2.m_oToday:Query(self:GetFlag("battle"),{})
            local iBattleCnt = mBattleInfo[iPlayer1] or 0
            mBattleInfo[iPlayer1]=iBattleCnt+1
            oPlayer2.m_oToday:Set(self:GetFlag("battle"),mBattleInfo)
        end
    end

    local fCallback = function (mArgs)
        self:OnFightEnd(mArgs)
    end
    oWar.m_mFightInfo = mFightInfo
    oWarMgr:SetCallback(iWarId, fCallback)
    oWarMgr:StartWar(iWarId, {action_id = lAction})
    return oWar
end

function CHuodong:OnFightEnd(mArgs)
    local iWarID = mArgs.warid
    if self.m_mViewFight[iWarID] then
        self.m_mViewFight[iWarID] = nil 
    end
    local win_side = mArgs.win_side
    local mPlayer = extend.Table.deep_clone(mArgs.player)
    local oWar = global.oWarMgr:GetWar(iWarID)
    local mFightInfo = oWar.m_mFightInfo
    local bChangeBoss = false
    for side,mDie in ipairs(mArgs.die) do
        if not mPlayer[side] then
            mPlayer[side] = {}
        end
        for _,pid in ipairs(mDie) do
            table.insert(mPlayer[side],pid)
        end
    end

    for iSide,lPlayer in pairs(mPlayer) do
        for _,pid in ipairs(lPlayer) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            oPlayer.m_oThisTemp:Set(self:GetFlag("protect"),1,self:GetGameTime("protect"))
            if iSide == win_side then
                if oPlayer:GetGrade() >= oPlayer:GetServerGrade() - 5  and mFightInfo["fighter"]["pid"] == pid and mFightInfo["fighter"]["single"] then
                    local mBattleInfo = oPlayer.m_oToday:Query(self:GetFlag("battle"),{})
                    local iBattleCnt = mBattleInfo[mFightInfo["enemy"]["pid"]] or 0
                    if iBattleCnt<=3 then
                        local iScore = math.max(0 , math.abs(mFightInfo["fighter"]["grade"]-mFightInfo["enemy"]["grade"])* 0.6 + 5)
                        if not is_production_env() then
                            global.oChatMgr:HandleMsgChat(oPlayer,string.format("获得积分 %s",iScore))
                        end
                        oPlayer.m_oToday:Add(self:GetFlag("score"),math.floor(iScore))
                    end
                end
            end
            local iScore =oPlayer.m_oToday:Query(self:GetFlag("score"),0)
            local iBossMaxScore = BOSS_SCORE
            if not is_production_env() and self.m_mTestMacScore then
                iBossMaxScore = self.m_mTestMacScore
            end
            if iScore>iBossMaxScore then
                self:Dirty()
                self.m_mBossPid = {pid = pid,score =iScore, name = oPlayer:GetName(),  model = oPlayer:GetModelInfo()}
                bChangeBoss = true
            end
        end
    end
    if bChangeBoss then
        self:Dirty()
        local pid =self.m_mBossPid["pid"]
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local oRoPlayer = roplayer.NewRoPlayer(pid)
        oRoPlayer:Init(oPlayer:PackRoData())
        self.m_oRoFight = oRoPlayer
    end
end

function CHuodong:_Notify(iPid, iText, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sTip = self:GetTextData(iText)
    local sMsg = oToolMgr:FormatColorString(sTip, mArgs)
    oNotifyMgr:Notify(iPid, sMsg)
end


function CHuodong:GS2CArenaFightEnd(oPlayer, pid)
    local mNet = {}
    mNet["pid"] = pid
    oPlayer:Send("GS2CArenaFightEnd", mNet)
end

function CHuodong:PackViewInfo(oFighter,oEnemy)
    local mData = {}
    for index,oPlayer in ipairs({oFighter,oEnemy}) do
        local oTeam = oPlayer:HasTeam()
        local mNet  = {}
        if oTeam then
            mNet.pid = oPlayer:GetPid()
            mNet.name = oPlayer:GetName()
            mNet.school = oPlayer:GetSchool()
            mNet.icon = oPlayer:GetIcon()
            mNet.grade = oPlayer:GetGrade()
            mNet.count = #oTeam.m_lMember
        else
            mNet.pid = oPlayer:GetPid()
            mNet.name = oPlayer:GetName()
            mNet.school = oPlayer:GetSchool()
            mNet.icon = oPlayer:GetIcon()
            mNet.grade = oPlayer:GetGrade()
            mNet.count = 0
        end
        if index == 1 then
            mData.fight = mNet
        else
            mData.enemy = mNet
        end
    end
    return mData
end

function CHuodong:ProcessFightList(oTarget, lPidLst,bTeam)
    if bTeam ~=ARENA_TEAM and bTeam ~=ARENA_SINGLE then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local lFight = {}
    local iTargetGrade = oTarget:GetGrade()
    for _, pid in ipairs(lPidLst) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        if math.abs(oPlayer:GetGrade() - iTargetGrade)>10 then
            goto continue
        end
        local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
        if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
            goto continue
        end
        if oPlayer:IsSingle() and ARENA_SINGLE == bTeam then
            local mNet = {}
            mNet.pid = oPlayer:GetPid()
            mNet.name = oPlayer:GetName()
            mNet.grade = oPlayer:GetGrade()
            mNet.icon = oPlayer:GetIcon()
            mNet.school = oPlayer:GetSchool()
            mNet.score = oPlayer:GetScore()
            table.insert(lFight,{mNet,oPlayer:GetGrade()})
        elseif bTeam == ARENA_TEAM then
            local oTeam = oPlayer:HasTeam()
            if not oTeam then goto continue end
            if oTeam:Leader() ~= pid then goto continue end
            local mNet = self:PackTeamInfo(oTeam) 
            table.insert(lFight,{mNet,oPlayer:GetGrade()})
        end
        ::continue::
    end
    table.sort(lFight,SortFighterList)
    local lNetFight = {}
    for _,mFight in  ipairs(lFight) do
        table.insert(lNetFight,mFight[1])
    end
    local mNet = {}
    mNet.team=bTeam
    if bTeam==ARENA_TEAM then
        mNet.teamlist = lNetFight
    else
        mNet.singlelist = lNetFight
    end
    oTarget:Send("GS2CArenaFighterList",mNet)
end

function CHuodong:PackTeamInfo(oTeam)
    local mNet = {}
    mNet["teamid"] = oTeam.m_ID
    mNet["leader"] = oTeam.m_iLeader
    local mMem = {}
    for _,oMem in ipairs(oTeam.m_lMember) do
        table.insert(mMem,self:PackMemInfo(oMem))
    end
    for _,oMem in pairs(oTeam.m_mShortLeave) do
        table.insert(mMem,self:PackMemInfo(oMem))
    end
    for _,oMem in pairs(oTeam.m_mOffline) do
        table.insert(mMem,self:PackMemInfo(oMem))
    end
    mNet.member = mMem
    return mNet
end

function CHuodong:PackMemInfo(oMem)
    local mNet = {}
    mNet.pid = oMem.m_ID
    mNet.name  = oMem:GetName()
    mNet.icon = oMem:GetIcon()
    mNet.school = oMem:GetSchool()
    mNet.grade = oMem:GetGrade()
    mNet.status = oMem:Status()
    return mNet
end

function CHuodong:SendViewFightList(oPlayer)
    local mNet = {}
    for iWarID ,mInfo in pairs(self.m_mViewFight) do
        table.insert(mNet,mInfo.info)
    end
    oPlayer:Send("GS2CArenaNameList",{lst = mNet})
end

--boss--
function CHuodong:Reset()
    local oNpc = self:GetNpcObj(self.m_iNpcId)
    if oNpc then
        if oNpc:InWar() then
            self.m_RemoveNpc = self.m_iNpcId
        else
            self:RemoveTempNpc(oNpc)
            self.m_iNpcId = 0
        end
    end
    self:Dirty()
    

    self.m_oTodayRoFight = self.m_oRoFight
    self.m_mTodayBossPid = self.m_mBossPid
    self.m_mBossPid = nil
    self.m_oRoFight = nil
    if not self.m_mTodayBossPid then
        return
    end
    local pid = self.m_mTodayBossPid["pid"]
    local oWorldMgr = global.oWorldMgr
    local oMailMgr = global.oMailMgr
    local oToolMgr = global.oToolMgr
    local mData, name = oMailMgr:GetMailInfo(1004)
    local sMsg = oToolMgr:FormatColorString(mData.context)
    mData.context = sMsg
    oMailMgr:SendMail(0, name, pid, mData,0)

    local oNpc = self:CreateTempNpc(1001)
    local sName = self.m_mTodayBossPid["name"]
    local mModel = self.m_mTodayBossPid["model"]
    if oNpc.m_sName == "$player" then
        oNpc.m_sName = sName
    end
    oNpc.m_mModel = mModel
    oNpc.m_iPid = pid     
    self:Npc_Enter_Map(oNpc)
    self.m_iNpcId = oNpc.m_ID
    self.m_FirstBeatBoss = nil
end

function CHuodong:CheckAnswer(oPlayer, npcobj, iAnswer)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("LEITAI", oPlayer) then
        return false
    end

    local oWorldMgr = global.oWorldMgr
    if iAnswer ~= 1 then
        return false
    end

    if npcobj:InWar() then
        local oWarMgr = global.oWarMgr
        local oWar = npcobj:InWar()
        local mArgs = {camp_id=oWar:GetCamp()}
        if oPlayer:HasTeam() then
            oWarMgr:TeamObserverEnterWar(oPlayer,oWar:GetWarId(),mArgs)
        else
            oWarMgr:ObserverEnterWar(oPlayer,oWar:GetWarId(),mArgs)
        end
        return false
    end

    if npcobj.m_iPid == oPlayer:GetPid() then
        if oPlayer:IsSingle() then
            self:_Notify(oPlayer:GetPid(), 1012)
            return false
        else
            local oTeam = oPlayer:HasTeam()
            for _,oMem in ipairs(oTeam:GetMember()) do
                if oMem.m_ID == oPlayer:GetPid() then
                    self:_Notify(oPlayer:GetPid(), 1012)
                    return false 
                end
            end
        end
    end
    return true
end

function CHuodong:TrueFight(iPid, npcobj, iFight, mConfig, bSingle)
    if tonumber(iFight) ~= 1001 then
        return super(CHuodong).TrueFight(self, iPid, npcobj, iFight, mConfig, bSingle)
    else
        if not self.m_oTodayRoFight then return end

        local iTarget = self.m_oTodayRoFight.m_iPid
    	local iNpc = self.m_iNpcId
        global.oWorldMgr:LoadWanfaCtrl(iTarget, function(oWanfaCtrl)
            self:TrueStartFight(iPid, oWanfaCtrl, iNpc, iFight, mConfig, bSingle)
        end)
    end
end

function CHuodong:TrueStartFight(iPid, oWanfaCtrl, iNpc, iFight, mConfig, bSingle)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if not self.m_oTodayRoFight then return end

    local oNpc = self:GetNpcObj(self.m_iNpcId)
    if not oNpc then return end
 
    if bSingle and oNpc:InWar() then return end

    if oPlayer.m_oActiveCtrl:GetWarStatus() ~= gamedefines.WAR_STATUS.NO_WAR then
        return
    end

    local iTarget = oWanfaCtrl:GetPid()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        oWanfaCtrl:SyncData(oTarget)
    end

    local mInfo = res["daobiao"]["huodong"][self.m_sName]
    local oWar = global.oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_ARENA, 
        {
            GamePlay = self.m_sName,
            barrage_show = mInfo["condition"][1].barrage_show or 0,
            barrage_send = mInfo["condition"][1].barrage_send or 0,
        }
    )

    local iWarId = oWar:GetWarId()
    local ret
    if oPlayer:IsSingle() then
        ret = global.oWarMgr:EnterWar(oPlayer, iWarId, {camp_id = 1}, true)
    else
        ret = global.oWarMgr:TeamEnterWar(oPlayer, iWarId, {camp_id = 1}, true)
    end

    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end

    local oWarData = oWanfaCtrl:GetWarData()
    oWar:EnterRoPlayer(oWarData, {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY})
    oWar:EnterRoPartnerList(oWarData, {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY})

    if bSingle and oNpc then
        local oSceneMgr = global.oSceneMgr
        oNpc:SetNowWar(oWar.m_iWarId)
        oSceneMgr:NpcEnterWar(oNpc)
    end

    local npcid = self.m_iNpcId
    local fCallback = function(mArgs)
        self:OnBossWarEnd(mArgs, npcid)
    end
    global.oWarMgr:SetCallback(iWarId, fCallback)
    global.oWarMgr:StartWar(iWarId)
end

function CHuodong:CreateWar(pid,npcobj,iFight)
    local oWarMgr = global.oWarMgr
    local oWorldMgr = global.oWorldMgr
    local mRes = res["daobiao"]["huodong"][self.m_sName]
    local iBarrageShow = mRes["condition"][1].barrage_show or 0
    local iBarrageSend = mRes["condition"][1].barrage_send or 0
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_ARENA, 
        {GamePlay=self.m_sName,barrage_show=iBarrageShow,barrage_send=iBarrageSend})
    if not oWar then
        return
    end

    if not self.m_oTodayRoFight then
        return
    end

    local iWarID = oWar:GetWarId()

    local oFighter = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oFighter then
        return
    end

    local ret
    if oFighter:IsSingle() then
        ret = oWarMgr:EnterWar(oFighter, iWarID, {camp_id = 1}, true)
    else
        ret = oWarMgr:TeamEnterWar(oFighter, iWarID, {camp_id = 1}, true)
    end
    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end

    oWar:EnterRoPlayer(self.m_oTodayRoFight, {camp_id = 2},true)
    local npcid = self.m_iNpcId
    local fCallback = function (mArgs)
        self:OnBossWarEnd(mArgs,npcid)
    end
    oWarMgr:SetCallback(iWarID, fCallback)
    oWarMgr:StartWar(iWarID)
    return oWar
end

function CHuodong:OnBossWarEnd(mArgs,npcid)
    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oSceneMgr = global.oSceneMgr
    local iWinSide = mArgs.win_side
    if npcid == self.m_iNpcId then
        local npcobj  = self:GetNpcObj(npcid)
        npcobj:ClearNowWar()
        oSceneMgr:NpcLeaveWar(npcobj)
    end
    if not self.m_FirstBeatBoss and iWinSide == 1 and npcid == self.m_iNpcId then
        local npcobj  = self:GetNpcObj(npcid)
        self.m_FirstBeatBoss = {} 
        for _,pid in ipairs(mArgs.player[iWinSide]) do
            table.insert(self.m_FirstBeatBoss,pid)
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                local sTip = self:GetTextData(1013)
                local sMsg = oToolMgr:FormatColorString(sTip, {role = oPlayer:GetName(), npc = npcobj.m_sName})
                oChatMgr:HandleOrgChat(oPlayer, sMsg)
            end
        end
    end

    if self.m_RemoveNpc then
        local npcobj  = self:GetNpcObj(self.m_RemoveNpc)
        npcobj:ClearNowWar()
        oSceneMgr:NpcLeaveWar(npcobj)
        self:RemoveTempNpc(npcobj)
        self.m_RemoveNpc = false
    end
end

function CHuodong:GetNpcInWarText(npcobj)
    local sText = self:GetTextData(1016)
    return sText
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 清除前3次对战信息\nhuodongop arena 101",
        "102 刷天刷boss\nhuodongop arena 102",
        "103 查看积分\nhuodongop arena 103",
        "104 查看当前boss信息\nhuodongop arena 104",
        "105 查看昨天boss信息\nhuodongop arena 105",
        "106 设置刷榜积分最大值\nhuodongop arena 106 {score = 5}" ,
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        oPlayer.m_oToday:Delete(self:GetFlag("battle"))
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 102 then
        self:NewDay(get_daytime({}))
    elseif iFlag == 103 then
        local iScore = oPlayer.m_oToday:Query(self:GetFlag("score"),0)
        oChatMgr:HandleMsgChat(oPlayer,string.format("当前积分:%s",iScore))
    elseif iFlag == 104 then
        if self.m_mBossPid then
            local sMsg = extend.Table.serialize(self.m_mBossPid)
            oChatMgr:HandleMsgChat(oPlayer,string.format("目前boss信息:\n%s",sMsg))
        else
            oChatMgr:HandleMsgChat(oPlayer,string.format("目前boss信息:无"))
        end
    elseif iFlag == 105 then
        if self.m_mTodayBossPid then
            local sMsg = extend.Table.serialize(self.m_mTodayBossPid)
            oChatMgr:HandleMsgChat(oPlayer,string.format("昨天boss信息:\n%s",sMsg))
        else
            oChatMgr:HandleMsgChat(oPlayer,string.format("昨天boss信息:无"))
        end
    elseif iFlag == 106 then
        local iScore = mArgs.score or 5
        self.m_mTestMacScore = iScore
        oChatMgr:HandleMsgChat(oPlayer,string.format("设置最大刷榜积分:%s",self.m_mTestMacScore))
    end
end

