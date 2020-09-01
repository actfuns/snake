--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local geometry = require "base.geometry"
local interactive = require "base.interactive"

local huodongbase = import(service_path("huodong.huodongbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local loaditem = import(service_path("item.loaditem"))
local handleteam = import(service_path("team.handleteam"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

function ScoreSort(mInfo1,mInfo2)
    if mInfo1.score>mInfo2.score then
        return true
    else
        return false
    end
end

function GetTeamGrade(oPlayer)
    local oTeam = oPlayer:HasTeam()
    local iGrade = 0
    if not oTeam then
        iGrade = oPlayer:GetGrade()
        return iGrade
    end
    for _,oMem in ipairs(oTeam:GetMember()) do
        iGrade = iGrade + oMem:GetGrade()
    end
    return iGrade
end

function GetTeamMatchGrade(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return oPlayer:GetGrade()
    end
    local iMaxGrade = 0
    local iAllGrade = 0
    local iCnt = 0
    for _,oMem in pairs(oTeam:GetMember()) do
        local iGrade = oMem:GetGrade()
        if iGrade>iMaxGrade then
            iMaxGrade = iGrade
        end
        iAllGrade = iAllGrade + iGrade
        iCnt = iCnt + 1
    end
    if iCnt<=0 then
        return oPlayer:GetGrade()
    end
    local iGrade = math.floor(iMaxGrade*6/10 + iAllGrade/iCnt*4/10)
    return iGrade
end

function MatchSort(oPlayer1,oPlayer2)
    local oHD = global.oHuodongMgr:GetHuodong("threebiwu")

    local pid1 = oPlayer1:GetPid()
    local pid2 = oPlayer2:GetPid()
    local iGrade1 = GetTeamMatchGrade(oPlayer1)
    local iGrade2 = GetTeamMatchGrade(oPlayer2)
    local mInfo1 = oHD.m_mPoint[pid1]
    local mInfo2 = oHD.m_mPoint[pid2]
    if iGrade1>iGrade2 then
        return true 
    elseif iGrade1<iGrade2 then
        return false
    else
        if mInfo1.win >  mInfo2.win then
            return true 
        elseif mInfo1.win < mInfo2.win then 
            return false 
        else
            if mInfo1.win + mInfo1.fail > mInfo2.win + mInfo2.fail then
                return true 
            else
                return false
            end
        end
    end
end

local GAME_NONE = 0
local GAME_PRESTART = 1
local GAME_START = 2
local GAME_END = 3

local FIRST_WIN = 1
local FIVE_WIN = 5

local PUSH_TEN = 10
local PUSH_THIRTY = 30

local REWARD_TITLE = {1035,1036,1037}

local GAME_NPCTYPE = {1001,1002,1003,1004}


CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "九州争霸"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1034
    o.m_iGameState = GAME_NONE
    o.m_iSceneID = nil
    o.m_mPoint = {}
    o.m_lPointRank = {}
    o.m_mTitlePlayer = {}
    o.m_iNextMatchTime = 0
    o.m_iMatchCnt = 0
    o.m_iEndTime = 0
    return o
end

function CHuodong:Init()
    if not global.oToolMgr:IsSysOpen("THREEBIWU",nil,true) then
        return
    end
    local iWeekDay = get_weekday()
    local tbl = get_hourtime({hour=0})
    local mOpenDay = self:GetOpenDay()
    local mOpenTime = self:GetOpenTime()
    if mOpenDay[iWeekDay] == 1 then
        if tbl.date.hour < mOpenTime[1] then
            self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
        end
    end
end

function CHuodong:NewHour(mNow)
    if not global.oToolMgr:IsSysOpen("THREEBIWU",nil,true) then
        return
    end
    local iWeekDay = mNow.date.wday
    local iHour = mNow.date.hour
    local mOpenDay = self:GetOpenDay()
    local mOpenTime = self:GetOpenTime()
    if mOpenDay[iWeekDay] == 1 then
        if iHour == mOpenTime[1] then
            self:AddTimeCb("PreGameStart",self:GetGameTime("PreGameStart"),function ()
                self:PreGameStart()
            end)
        end
    end
end

function CHuodong:NewDay(mNow)
    if not global.oToolMgr:IsSysOpen("THREEBIWU",nil,true) then
        return
    end
    local iWeekDay = mNow.date.wday
    local mOpenDay = self:GetOpenDay()
    if mOpenDay[iWeekDay] == 1 then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:OnLogin(oPlayer,reenter)
    local pid = oPlayer:GetPid()
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if self.m_iSceneID and self.m_iSceneID == oNowScene:GetSceneId() then
        self:RefreshMyPoint(oPlayer)
    end 
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.titleplayer = table_to_db_key(self.m_mTitlePlayer)
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_mTitlePlayer = table_to_int_key(mData.titleplayer or {})
end

function CHuodong:MergeFrom(mFromData)
    return true
end

--基础接口--

function CHuodong:IsOpenDay(iTime)   --限时活动接口
    local mOpenDay = self:GetOpenDay()
    if mOpenDay[get_weekday()] == 1 then
        return true
    end
    return false
end

function CHuodong:GetStartTime()
    local mOpenTime = self:GetOpenTime()
    return string.format("%d:%d",mOpenTime[1],mOpenTime[2])
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:GetOpenDay()
    return res["daobiao"]["huodong"][self.m_sName]["time_config"]["OPEN_DAY"]
end

function CHuodong:GetOpenTime()
    return res["daobiao"]["huodong"][self.m_sName]["time_config"]["OPEN_TIME"]
end

function CHuodong:GetGameTime(flag)
    return res["daobiao"]["huodong"][self.m_sName]["time_config"]["GAME_TIME"][flag]
end

function CHuodong:GetNPCMenu()
    return "参与争霸"
end

function CHuodong:ValidShow(oPlayer)
    if self.m_iGameState == GAME_PRESTART or self.m_iGameState == GAME_START then
        return true
    else
        return false
    end
end

function CHuodong:ValidEnterTeam(oPlayer,oLeader,iApply)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    oNotifyMgr:Notify(pid,self:GetTextData(1005))
    return false
end

function CHuodong:Announce(sMsg,iHorse)
    local oChatMgr = global.oChatMgr
    iHorse = iHorse or 0
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,iHorse)
end
--基础接口--


--准备阶段--
function CHuodong:PreGameStart()
    record.info(string.format("%s PreGameStart",self.m_sName))
    self:DelTimeCb("PreGameStart")
    self:DelTimeCb("GameOver1")
    self:DelTimeCb("GameOver2")
    self:DelTimeCb("CycleReward")
    self:AddTimeCb("CycleReward",self:GetGameTime("CycleReward"),function ()
        self:CycleReward()
    end)
    self:AddTimeCb("GameStart",self:GetGameTime("GameStart"),function ()
        self:GameStart()
    end)
    self:CreateScene()
    self:CreateNPC()
    self.m_mPoint = {}
    self.m_lPointRank = {}
    self.m_iGameState = GAME_PRESTART
    self.m_iStartTime = get_time() + math.floor(self:GetGameTime("GameStart")/1000)
    local mChuanwen = res["daobiao"]["chuanwen"][1081]
    self:Announce(mChuanwen.content,mChuanwen.horse_race)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
end

function CHuodong:CreateScene()
    local oSceneMgr = global.oSceneMgr
    local mRes = res["daobiao"]["huodong"][self.m_sName]["scene"]
    for iIndex , mInfo in pairs(mRes) do
        local mData ={
        map_id = mInfo.map_id,
        url = {"huodong", self.m_sName, "scene", iIndex},
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable =mInfo.is_durable==1,
        has_anlei = mInfo.has_anlei == 1,
        }
        local oScene = oSceneMgr:CreateVirtualScene(mData)
        oScene.m_HDName = self.m_sName
        self.m_iSceneID = oScene:GetSceneId()

        local fCbEnter 
        fCbEnter = function (iEvType,mData)
            local oPlayer = mData.player
            local oToScene = mData.scene
            self:OnPlayerEnterScene(oPlayer, oToScene)
        end
        oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, fCbEnter)
        local fCbLeave
        fCbEnter = function (iEvType,mData)
            local oPlayer = mData.player
            local oToScene = mData.scene
            self:OnPlayerLeaveScene(oPlayer, oToScene)
        end
        oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, fCbEnter)
        break
    end
end

function CHuodong:OnPlayerEnterScene(oPlayer,oScene)
    local pid = oPlayer:GetPid()
    self:SetInitInfo(oPlayer)
    self:RegisterEvents(oPlayer)
    self:RefreshMyPoint(oPlayer)
end

function CHuodong:OnPlayerLeaveScene(oPlayer, oToScene)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if mInfo then
        mInfo.match=0
    end
    self:UnRegisterEvents(oPlayer)
    self:RefreshMyPoint(oPlayer)
end

function CHuodong:RegisterEvents(oPlayer)
    oPlayer:AddEvent(self,gamedefines.EVENT.TEAM_CREATE,function (iEvType,mData)
        self:OnMatchChange(iEvType,mData)
    end)
    self:RegisterEvents2(oPlayer)
end
function CHuodong:RegisterEvents2(oPlayer)
    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        oTeam:AddEvent(self,gamedefines.EVENT.TEAM_ADD_MEMBER,function (iEvType,mData)
            self:OnMatchChange(iEvType,mData)
        end)
        oTeam:AddEvent(self,gamedefines.EVENT.TEAM_ADD_SHORT_LEAVE,function (iEvType,mData)
            self:OnMatchChange(iEvType,mData)
        end)
        oTeam:AddEvent(self,gamedefines.EVENT.TEAM_LEAVE,function (iEvType,mData)
            self:OnMatchChange(iEvType,mData)
        end)
        oTeam:AddEvent(self,gamedefines.EVENT.TEAM_SHORTLEAVE,function (iEvType,mData)
            self:OnMatchChange(iEvType,mData)
        end)
        oTeam:AddEvent(self,gamedefines.EVENT.TEAM_OFFLINE,function (iEvType,mData)
            self:OnMatchChange(iEvType,mData)
        end)
        oTeam:AddEvent(self,gamedefines.EVENT.TEAM_BACKTEAM,function (iEvType,mData)
            self:OnMatchChange(iEvType,mData)
        end)
    end
end

function CHuodong:UnRegisterEvents(oPlayer)
    oPlayer:DelEvent(self, gamedefines.EVENT.TEAM_CREATE)
    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        oTeam:DelEvent(self, gamedefines.EVENT.TEAM_ADD_MEMBER)
        oTeam:DelEvent(self, gamedefines.EVENT.TEAM_ADD_SHORT_LEAVE)
        oTeam:DelEvent(self, gamedefines.EVENT.TEAM_LEAVE)
        oTeam:DelEvent(self, gamedefines.EVENT.TEAM_SHORTLEAVE)
        oTeam:DelEvent(self, gamedefines.EVENT.TEAM_OFFLINE)
        oTeam:DelEvent(self, gamedefines.EVENT.TEAM_BACKTEAM)
    end
end

function CHuodong:OnMatchChange(iEvType,mData)
    if iEvType == gamedefines.EVENT.TEAM_CREATE then
        local oTeam = mData.team
        local oLeader = oTeam:GetLeaderObj()
        self:RegisterEvents2(oLeader)
    end
    if self.m_iGameState ~= GAME_START then
        return
    end
    local oTeam = mData.team 
    local mAllMember = oTeam:AllMember()
    
    for pid,_ in pairs(mAllMember) do
        local mInfo  = self.m_mPoint[pid] 
        if mInfo then
            mInfo.match=0
        end
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer and mInfo then
            self:RefreshMyPoint(oPlayer)
        end
    end
    oTeam:TeamNotify(self:GetTextData(1011))
    local iTarget = mData.pid
    local mTargetInfo = self.m_mPoint[iTarget]
    if mTargetInfo then
        mTargetInfo.match=0
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if oTarget then
            self:RefreshMyPoint(oTarget)
        end
    end
end

function CHuodong:SetInitInfo(oPlayer)
    local pid = oPlayer:GetPid()
    if self.m_mPoint[pid] then
        return
    end
    local sTitle = ""
    local mTitle = oPlayer:GetTitleInfo()
    if mTitle then
        sTitle = mTitle.name
    end
    self.m_mPoint[pid] = {school = oPlayer:GetSchool(),point = 0,grade = oPlayer:GetGrade(), model = oPlayer:GetChangedModelInfo(),name = oPlayer:GetName(),rank = 0,win = 0,fail = 0,match=0,lastwin=0,maxwin=0,firstwin=0,fivewin=0,pointtime=0,lastmatch={0,0}}
end

function CHuodong:GetScene()
    local oSceneMgr = global.oSceneMgr
    local oScene  = oSceneMgr:GetScene(self.m_iSceneID)
    return oScene
end

function CHuodong:CycleReward()
    self:DelTimeCb("CycleReward")
    self:AddTimeCb("CycleReward",self:GetGameTime("CycleReward"),function ()
        self:CycleReward()
    end)
    local oScene = self:GetScene()
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:Reward(pid,1010)
        end
    end
end

function CHuodong:CreateNPC()
    local oScene = self:GetScene()
    assert(oScene,"CreateNPC")
    for _,npctype in ipairs(GAME_NPCTYPE) do
        local npcobj  = self:CreateTempNpc(npctype)
        assert(npcobj,"CreateNPC")
        self:Npc_Enter_Scene(npcobj,oScene:GetSceneId())
    end
end
--准备阶段结束--

--活动开始--
function CHuodong:GameStart()
    self:DelTimeCb("GameStart")
    self:DelTimeCb("PreGameStart")
    if self.m_iGameState ~= GAME_PRESTART then
        record.warning(string.format("%s GameStart [no PreGameStart]",self.m_sName))
        return
    end
    record.info(string.format("%s GameStart",self.m_sName))
    self.m_iGameState = GAME_START
    self.m_iStartTime = get_time()
    self:AddTimeCb("GameOver1",self:GetGameTime("GameOver1"),function ()
        self:GameOver1()
    end)
    self:AddTimeCb("StopMatchBattle",self:GetGameTime("StopMatchBattle"),function ()
        self:StopMatchBattle()
    end)
    self.m_iMatchCnt = 0
    self.m_iEndTime = math.floor(self:GetGameTime("GameOver1")/1000 + get_time())
    self:MatchBattle(true)
    self.m_iNextMatchTime = get_time() + math.floor(self:GetGameTime("MatchBattle")/1000)
    local mChuanwen = res["daobiao"]["chuanwen"][1083]
    self:Announce(mChuanwen.content,mChuanwen.horse_race)
end

function CHuodong:StopMatchBattle()
    record.info(string.format("%s StopMatchBattle",self.m_sName))
    self:DelTimeCb("MatchBattle")
    self.m_iNextMatchTime  = 0
end

function CHuodong:GameOver1()
    record.info(string.format("%s GameOver1",self.m_sName))
    self:DelTimeCb("GameStart")
    self:DelTimeCb("GameOver1")
    self:DelTimeCb("MatchBattle")
    self:DelTimeCb("StopMatchBattle")
    self.m_iGameState = GAME_END
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    self:AddTimeCb("GameOver2",self:GetGameTime("GameOver2"),function ()
        self:GameOver2()
    end)
    self:PushRank()
    self:CleanPlayer()
    self:RewardTitle()
    local mChuanwen = res["daobiao"]["chuanwen"][1082]
    if self.m_lPointRank[1] then
        local pid = self.m_lPointRank[1]["pid"]
        local sName = self.m_mPoint[pid]["name"]
        local sContent = global.oToolMgr:FormatColorString(mChuanwen.content,{role = sName})
        self:Announce(sContent,mChuanwen.horse_race)
    end
end

function CHuodong:GameOver2()
    record.info(string.format("%s GameOver2",self.m_sName))
    self:DelTimeCb("GameOver1")
    self:DelTimeCb("GameOver2")
    self:DelTimeCb("MatchBattle")
    self:DelTimeCb("StopMatchBattle")
    self:DelTimeCb("CycleReward")
    self:RemoveNPC()
    self:RemoveScene()
    self.m_mPoint = {}
    self.m_lPointRank = {}
end

function CHuodong:CleanPlayer()
    local oSceneMgr = global.oSceneMgr
    local oWarMgr = global.oWarMgr
    local iMapId = 101000
    local oDesScene =  oSceneMgr:SelectDurableScene(iMapId)
    local oScene = self:GetScene()
    assert(oScene,"CleanPlayer")
    local oWorldMgr = global.oWorldMgr
    local mPlayer = extend.Table.deep_clone(oScene.m_mPlayers)
    for pid , _ in pairs(mPlayer) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
        if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
            goto continue
        end

        if oPlayer:IsSingle() then
            if iWarStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
                oWarMgr:LeaveWar(oPlayer,true)
            end
        elseif oPlayer:IsTeamLeader() then
            if iWarStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
                oWarMgr:TeamLeaveObserverWar(oPlayer,true)
            end
        end
        local mPos = self:RandomScenePos(oDesScene)
        global.oSceneMgr:DoTransfer(oPlayer, oDesScene:GetSceneId(), mPos)
        ::continue::
    end
end

function CHuodong:RemoveNPC()
    local lNpcIdxs = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc:Type() then
            if extend.Array.find(GAME_NPCTYPE,oNpc:Type()) then
                table.insert(lNpcIdxs, oNpc)
            end
        else
            record.debug(string.format("%s  remove npc error %s",self.m_sName,nid))
        end
    end
    for nid, oNpc in pairs(lNpcIdxs) do
        self:RemoveTempNpc(oNpc)
    end
end

function CHuodong:RemoveScene()
    if self.m_iSceneID then
        global.oSceneMgr:RemoveScene(self.m_iSceneID)
        self.m_iSceneID = nil
    end
end

function CHuodong:RandomScenePos(oScene,bFly)
    local iMapId = oScene:MapId()
    local oSceneMgr = global.oSceneMgr
    local iNewX
    local iNewY
    if bFly then
        iNewX,iNewY = oSceneMgr:GetFlyData(iMapId)
    else
        iNewX,iNewY = oSceneMgr:RandomPos2(iMapId)
    end
    local mPosInfo = {
        x = iNewX or 0,
        y = iNewY or 0,
    }
    return mPosInfo
end
--活动结束--

--匹配--
function CHuodong:ValidMatch(oPlayer,mArgs)
    mArgs = mArgs or {}
    local pid = oPlayer:GetPid()
    local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
    if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
        if mArgs.bNotify then
            global.oNotifyMgr:Notify(pid,"战斗中无法操作")
        end
        return false
    end
    local mInfo = self.m_mPoint[pid]
    if not  mArgs.bIngoreMatch then
        if mInfo.match ==0 then
            return false
        end
    end

    local oTeam = oPlayer:HasTeam()
    if oTeam and oTeam:Leader() ~= pid then
        if mArgs.bNotify then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1019))
        end
        return false
    end
    local iFightLimit = res["daobiao"]["huodong"][self.m_sName]["config"][1]["fight_limit"]
    local plist={pid}
    if oTeam then
        plist = oTeam:GetMemberPid()
    end
    local lName = {}
    local iJoinLimit =  res["daobiao"]["huodong"][self.m_sName]["config"][1]["join_limit"]
    if #plist > iJoinLimit then
        if mArgs.bNotify then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1003))
        end
        return false
    end
    local lGradeName = {}
    local LIMIT_GRADE = res["daobiao"]["open"]["THREEBIWU"]["p_level"]
    for _,iTarget in ipairs(plist) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
        local mTargetInfo = self.m_mPoint[iTarget]
        if mTargetInfo.win + mTargetInfo.fail >=iFightLimit then
            table.insert(lName,mTargetInfo.name)
        end
        if oTarget then
            if oTarget:GetGrade()<LIMIT_GRADE then
                table.insert(lGradeName,oTarget:GetName())
            end
        end
    end
    if #lGradeName >0 then
        local sText = global.oToolMgr:FormatColorString(self:GetTextData(1010),{playlist=table.concat(lGradeName,",")})
        if mArgs.bNotify then
            oTeam:TeamNotify(sText)
        end
        return false
    end
    if #lName >0 then
        if mArgs.bNotify then
            if not oTeam then
                global.oNotifyMgr:Notify(pid,self:GetTextData(1018))
            else
                local sName = table.concat(lName,",")
                local sText = global.oToolMgr:FormatColorString(self:GetTextData(1010),{playlist=sName})
                oTeam:TeamNotify(sText)
            end
        end
        return false
    end
    return true
end

function CHuodong:MatchBattle(bStart)
    self:DelTimeCb("MatchBattle")
    self:AddTimeCb("MatchBattle",self:GetGameTime("MatchBattle"),function ()
        self:MatchBattle()
    end)
    self.m_iMatchCnt = self.m_iMatchCnt + 1
    self.m_iNextMatchTime = get_time() + math.floor(self:GetGameTime("MatchBattle")/1000)
    local oTeamMgr = global.oTeamMgr
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local lMatch = {}
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end

        if not self:ValidMatch(oPlayer,{bIngoreMatch=bStart}) then
            if bStart then
                self:RefreshMyPoint(oPlayer)
            end
            goto continue
        end
        table.insert(lMatch,oPlayer)

        if bStart then
            local oTeam = oPlayer:HasTeam()
            if oTeam then
                for _,oMem in pairs(oTeam:GetMember()) do
                    local mInfo = self.m_mPoint[oMem.m_ID]
                    if mInfo then
                        local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                        mInfo.match = 1
                        self:RefreshMyPoint(oTarget)
                    end
                end
            else
                local mInfo = self.m_mPoint[pid]
                if mInfo then
                    mInfo.match = 1
                    self:RefreshMyPoint(oPlayer)
                end
            end
        end
        ::continue::
    end
    table.sort(lMatch,MatchSort)
    local mRuleRes = res["daobiao"]["huodong"][self.m_sName]["match"]
    local lNextMatch  = {}
    local lWarPlayer = {}
    for iRule ,mRuleInfo in pairs(mRuleRes) do
        lNextMatch  = {}
        local iMatchLen = #lMatch
        if iMatchLen<=1 then
            break
        end
        for iIndex1,oFighter1 in ipairs(lMatch) do
            if extend.Array.find(lNextMatch,oFighter1) then
                goto continue1
            end
            if extend.Array.find(lWarPlayer,oFighter1) then
                goto continue1
            end
            local iFighter1 = oFighter1:GetPid()
            local mInfo1 = self.m_mPoint[iFighter1]
            local iGrade1 =  GetTeamMatchGrade(oFighter1)
            local iWin1 = mInfo1.win 
            local iFight1 = mInfo1.win + mInfo1.fail 
            local oFighter2 = nil 
            for i=1,2 do
                local oFighter = lMatch[iIndex1+i]
                if not oFighter then
                    goto continue2 
                end
                if extend.Array.find(lWarPlayer,oFighter) then
                    goto continue2
                    end
                if extend.Array.find(lNextMatch,oFighter) then
                    goto continue2
                end
                local iFighter = oFighter:GetPid()
                local mInfo = self.m_mPoint[iFighter]
                local iGrade = GetTeamMatchGrade(oFighter)
                local iWin = mInfo.win
                local iFight = mInfo.win + mInfo.fail 
                if math.abs(iGrade1-iGrade)<=mRuleInfo.grade and math.abs(iWin1-iWin)<=mRuleInfo.win and math.abs(iFight1-iFight)<=mRuleInfo.fight  then
                    if mInfo1.lastmatch[2] ==iFighter and mInfo.lastmatch[2] ==iFighter1 and mInfo.lastmatch[1] +1 == self.m_iMatchCnt and mInfo1.lastmatch[1] +1 == self.m_iMatchCnt then
                        goto continue2
                    end
                    oFighter2 = oFighter
                    break
                end
                ::continue2::
            end
            if oFighter2 then
                self:StartFight(oFighter1:GetPid(),oFighter2:GetPid())
                table.insert(lWarPlayer,oFighter1)
                table.insert(lWarPlayer,oFighter2)
            else
                table.insert(lNextMatch,oFighter1)
            end
            ::continue1::
        end
        lMatch = lNextMatch
    end
end

function CHuodong:StartFight(iFighter1,iFighter2)
    local oWorldMgr  = global.oWorldMgr
    local oWarMgr = global.oWarMgr
    local oFighter1 = oWorldMgr:GetOnlinePlayerByPid(iFighter1)
    local oFighter2 = oWorldMgr:GetOnlinePlayerByPid(iFighter2)
    local iWarStatus = oFighter1.m_oActiveCtrl:GetWarStatus()
    if iWarStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
        if oFighter1:IsSingle() then
            oWarMgr:LeaveWar(oFighter1,true)
        else
            oWarMgr:TeamLeaveObserverWar(oFighter1,true)
        end
    end

    local iWarStatus = oFighter2.m_oActiveCtrl:GetWarStatus()
    if iWarStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
        if oFighter2:IsSingle() then
            oWarMgr:LeaveWar(oFighter2,true)
        else
            oWarMgr:TeamLeaveObserverWar(oFighter2,true)
        end
    end

    local mNet = {}
    mNet.match1 = self:PackFighter(iFighter1)
    mNet.match2 = self:PackFighter(iFighter2)
    local mInfo1 = self.m_mPoint[iFighter1]
    local mInfo2 = self.m_mPoint[iFighter2]
    mInfo1.lastmatch = {self.m_iMatchCnt,iFighter2}
    mInfo2.lastmatch = {self.m_iMatchCnt,iFighter1}
    mNet.time = math.floor(self:GetGameTime("TrueStartFight")/1000)
    self:ShowBattle(iFighter1,iFighter2,mNet)
    local sTrueStartFight = string.format("TrueStartFight_%s_%s",iFighter1,iFighter2)
    self:AddTimeCb(sTrueStartFight,self:GetGameTime("TrueStartFight"),function ()
        self:TrueStartFight(iFighter1,iFighter2)
    end)
end

function CHuodong:TrueStartFight(iFighter1,iFighter2)
    local sTrueStartFight = string.format("TrueStartFight_%s_%s",iFighter1,iFighter2)
    self:DelTimeCb(sTrueStartFight)
    local oWorldMgr  = global.oWorldMgr
    local oFighter1 = oWorldMgr:GetOnlinePlayerByPid(iFighter1)
    local oFighter2 = oWorldMgr:GetOnlinePlayerByPid(iFighter2)
    if not oFighter1 or not oFighter2 then
        record.warning(string.format("%s  TrueStartFight fail %s",self.m_sName,iFighter1,iFighter2))
        return
    end

    if oFighter1:HasTeam() and oFighter2:HasTeam() then
        local oTeam1 = oFighter1:HasTeam()
        local oTeam2 = oFighter2:HasTeam()
        if oTeam1 == oTeam2 then
            if oTeam1:GetMember(iFighter1) and oTeam2:GetMember(iFighter2) then
                record.warning(string.format("%s  TrueStartFight fail sameteam %s",self.m_sName,iFighter1,iFighter2))
                return
            end
        end
    end
    local mLogData={}
    local lFighter1 = {}
    local lFighter2 = {}
    if oFighter1:IsSingle() then
        table.insert(lFighter1,iFighter1)
    else
        local oTeam = oFighter1:HasTeam()
        lFighter1 = oTeam:GetMemberPid()
    end
    if oFighter2:IsSingle() then
        table.insert(lFighter2,iFighter2)
    else
        local oTeam = oFighter2:HasTeam()
        lFighter2 = oTeam:GetMemberPid()
    end
    mLogData.battle1 = table.concat(lFighter1,",")
    mLogData.battle2 = table.concat(lFighter2,",")
    record.log_db("huodong", "threebiwu_battle",mLogData)
    for _,pid in pairs(lFighter1) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local mInfo = self.m_mPoint[pid]
        mInfo.match = 0
        if oTarget then
            self:RefreshMyPoint(oTarget)
            oTarget:MarkGrow(50)
        end
    end
    for _,pid in pairs(lFighter2) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local mInfo = self.m_mPoint[pid]
        mInfo.match = 0
        if oTarget then
            self:RefreshMyPoint(oTarget)
            oTarget:MarkGrow(50)
        end
    end
    local oWarMgr = global.oWarMgr
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["condition"][1]
    local iBarrageShow = mConfig.barrage_show or 0
    local iBarrageSend = mConfig.barrage_send or 0
    local LIMIT_BOUT = res["daobiao"]["huodong"][self.m_sName]["config"][1]["limit_bout"]
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE, 
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_BIWU, 
        {bout_out={bout=LIMIT_BOUT,result=10},GamePlay=self.m_sName,barrage_show=iBarrageShow,barrage_send=iBarrageSend})
    local iWarID = oWar:GetWarId()
    local fCallback = function (mArgs)
        self:WarFightEnd(iWarID,mArgs)
    end
    if oFighter1:IsSingle() then
        oWarMgr:EnterWar(oFighter1, iWarID, {camp_id = 1}, true,0)
    else
        oWarMgr:TeamEnterWar(oFighter1, iWarID, {camp_id = 1}, true,0)
    end
    if oFighter2:IsSingle() then
        oWarMgr:EnterWar(oFighter2, iWarID, {camp_id = 2}, true,0)
    else
        oWarMgr:TeamEnterWar(oFighter2, iWarID, {camp_id = 2}, true,0)
    end
    oWar.m_TeamGrade = {grade1 = self:GetFighterAvgGrade(oFighter1),grade2 = self:GetFighterAvgGrade(oFighter2)}
    oWar:SetOtherCallback("OnLeave",_EscapeCallBack)
    oWarMgr:SetCallback(iWarID, fCallback)
    oWarMgr:StartWar(iWarID)
end

function CHuodong:GetFighterAvgGrade(oFighter)
    if oFighter:IsSingle() then
        return oFighter:GetGrade()
    else
        local oTeam = oFighter:HasTeam()
        return oTeam:GetTeamAveGrade()
    end
end

function CHuodong:PackFighter(pid)
    local oWorldMgr  = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mNet = {}
    if oPlayer:IsSingle() then
        local mInfo = self.m_mPoint[pid]
        local mData = {}
        mData.icon = oPlayer:GetIcon()
        mData.point = mInfo.point
        mData.name = oPlayer:GetName()
        mData.school = oPlayer:GetSchool()
        mData.grade = oPlayer:GetGrade()
        mData.score = oPlayer:GetScore()
        table.insert(mNet,mData)
    else
        local oTeam = oPlayer:HasTeam()
        for _,oMem in pairs(oTeam:GetMember()) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            local mInfo = self.m_mPoint[oMem.m_ID]
            local mData = {}
            mData.icon = oTarget:GetIcon()
            mData.point = mInfo.point
            mData.name = oTarget:GetName()
            mData.school = oTarget:GetSchool()
            mData.grade = oTarget:GetGrade()
            mData.score = oTarget:GetScore()
            table.insert(mNet,mData)
        end
    end
    return mNet
end

function CHuodong:ShowBattle(iFighter1,iFighter2,mNet)
    local oWorldMgr  = global.oWorldMgr
    for _,pid in ipairs({iFighter1,iFighter2}) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer:IsSingle() then
            oPlayer:Send("GS2CThreeBWBattle",mNet)
        else
            local oTeam = oPlayer:HasTeam()
            for _,oMem in pairs(oTeam:GetMember()) do
                local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                oTarget:Send("GS2CThreeBWBattle",mNet)
            end
        end
    end
end

function CHuodong:WarFightEnd(iWarID,mArgs)
    local oWar = global.oWarMgr:GetWar(iWarID)
    if not oWar then
        return
    end
    local oSceneMgr = global.oSceneMgr
    local oWorldMgr = global.oWorldMgr
    local iSide1 = 1
    local iSide2 = 2
    local iWinSide = mArgs.win_side or 0
    local mEscape = mArgs.escape
    local mLivePlayer = extend.Table.deep_clone(mArgs.player)
    local mPlayer = extend.Table.deep_clone(mArgs.player)
    for side,mDie in ipairs(mArgs.die) do
        if not mPlayer[side] then
            mPlayer[side] = {}
        end
        for _,pid in ipairs(mDie) do
            table.insert(mPlayer[side],pid)
        end
    end
    if iWinSide == 10 then
        if #mLivePlayer[iSide1] > #mLivePlayer[iSide2]  then
            iWinSide = iSide1
        elseif #mLivePlayer[iSide1] < #mLivePlayer[iSide2]  then
            iWinSide = iSide2
        else
            local mDamageInfo = mArgs.damage_info
            local mDamage  = mDamageInfo.damage_info
            local iDamage1 = 0
            local iDamage2 = 0
            for pid,iDamage in pairs(mDamage) do
                if extend.Array.find(mPlayer[iSide1],pid) then
                    iDamage1 = iDamage1 + iDamage
                elseif extend.Array.find(mPlayer[iSide2],pid) then
                    iDamage2 = iDamage2 + iDamage
                elseif extend.Array.find(mArgs.escape[iSide1],pid) then
                    iDamage1 = iDamage1 + iDamage
                elseif extend.Array.find(mArgs.escape[iSide2],pid) then
                    iDamage2 = iDamage2 + iDamage
                end
            end 
            if iDamage1>iDamage2 then
                iWinSide = iSide1
            elseif iDamage1<iDamage2 then
                iWinSide = iSide2
            else
                local mGrade = oWar.m_TeamGrade
                if mGrade.grade1>=mGrade.grade2 then
                    iWinSide = iSide1
                else
                    iWinSide = iSide2
                end
            end
        end
    end
    local mLogData={
        winside = iWinSide,
        player = extend.Table.serialize(mPlayer),
    }
    record.log_db("huodong", "threebiwu_warend",mLogData)

    local mWinner = {}
    local mFailer  = {}
    local mFailEscape = {}
    if iWinSide == iSide1 then
        mWinner = mPlayer[iSide1]
        mFailer  = mPlayer[iSide2]
        mFailEscape = mEscape[iSide2]
    elseif iWinSide == iSide2 then
        mWinner = mPlayer[iSide2]
        mFailer  = mPlayer[iSide1]
        mFailEscape = mEscape[iSide1]
    end

    local  mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    local lWinOrderScore = {}
    local lFailOrderScore = {}
    local iWinAllPoint=0
    local iFailAllPoint = 0
    for _,pid in pairs(mWinner) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            table.insert(lWinOrderScore,{pid = pid,score = oPlayer:GetScore()})
            for _,mData in ipairs(mConfig.grade_point) do
                if mData.grade>=oPlayer:GetGrade() then
                    iWinAllPoint = iWinAllPoint + mData.point
                    break
                end
            end
        end
    end

    if iWinAllPoint>0 and table_count(mWinner)>0 then
        iWinAllPoint = math.floor(iWinAllPoint/table_count(mWinner))
    end
    table.sort(lWinOrderScore,ScoreSort)
    
    for _,pid in pairs(mFailer) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            table.insert(lFailOrderScore,{pid = pid,score = oPlayer:GetScore()})
            for _,mData in ipairs(mConfig.grade_point) do
                if mData.grade>=oPlayer:GetGrade() then
                    iFailAllPoint = iFailAllPoint + mData.point
                    break
                end
            end
        end
    end
    for _,pid in pairs(mFailEscape) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            for _,mData in ipairs(mConfig.grade_point) do
                if mData.grade>=oPlayer:GetGrade() then
                    iFailAllPoint = iFailAllPoint + mData.point
                    break
                end
            end
        end
    end
    local iFailCount = table_count(mFailer) + table_count(mFailEscape)
    if iFailAllPoint>0 and iFailCount>0 then
        iFailAllPoint = math.floor(iFailAllPoint/iFailCount)
    end
    table.sort(lFailOrderScore,ScoreSort)

    for _,pid in pairs(mWinner) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local iOrder = self:GetScoreOrder(lWinOrderScore,pid)
            self:RewardWinner(oPlayer,{order=iOrder,point = iFailAllPoint})
            if self.m_iGameState == GAME_END then
                self:TransferOut(oPlayer)
            end
        end
    end


    for _,pid in pairs(mFailer) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local iOrder = self:GetScoreOrder(lFailOrderScore,oPlayer)
            self:RewardFailer(oPlayer,{order=iOrder,point = iWinAllPoint})
            if self.m_iGameState == GAME_END then
                self:TransferOut(oPlayer)
            end
        end
    end
    if self.m_iGameState == GAME_START then
        self:SortPointRank()
    elseif self.m_iGameState == GAME_END then
        for _,pid in pairs(mWinner) do
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                if not oPlayer:HasTeam() then
                    self:TransferOut(oPlayer)
                elseif oPlayer:IsTeamLeader() then
                    self:TransferOut(oPlayer)
                end
            end
        end
        for _,pid in pairs(mFailer) do
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                if not oPlayer:HasTeam() then
                    self:TransferOut(oPlayer)
                elseif oPlayer:IsTeamLeader() then
                    self:TransferOut(oPlayer)
                end
            end
        end
    end
end

function CHuodong:GetScoreOrder(lOrderScore,pid)
    local iOrder = 3
    for index,mInfo in pairs(lOrderScore) do
        if mInfo.pid == pid then
            iOrder = index
            break
        end
    end
    iOrder = math.min(3,iOrder)
    iOrder = math.max(1,iOrder)
    return iOrder
end

function CHuodong:GetRewardPoint(oPlayer,mArgs)
    local iOrder = mArgs.order or 0
    local iBasicPoint = mArgs.point  or 0
    local pid = oPlayer:GetPid()
    local iPoint = 0
    local  mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    local sMsg = ""
    iPoint = iPoint + iBasicPoint
    sMsg = sMsg .. string.format("敌方积分=%s,",iBasicPoint)

    local mInfo = self.m_mPoint[pid]
    local iLastWin = mInfo.lastwin
    if mConfig["win_point"][iLastWin] then
        iPoint = iPoint + mConfig["win_point"][iLastWin]["point"]
        sMsg = sMsg .. string.format("连胜积分=%s,",mConfig["win_point"][iLastWin]["point"])
    end
    local sFormula-- = formula_string(sFormula, {level=iLevel}) 
    if  iOrder == 1 then
        sFormula = mConfig["first_point"]
    elseif iOrder == 2 then
        sFormula = mConfig["second_point"]
    elseif iOrder == 3 then
        sFormula = mConfig["third_point"]
    end
    if sFormula then
        iPoint  = iPoint + formula_string(sFormula, {}) 
        sMsg = sMsg .. string.format("队伍排名积分=%s",formula_string(sFormula, {}) )
    end
    if not is_production_env() then
        global.oChatMgr:HandleMsgChat(oPlayer,sMsg)
    end
    return iPoint
end

function CHuodong:RewardWinner(oPlayer,mArgs)
    local pid = oPlayer:GetPid()
    self:Reward(pid,1003)
    local mInfo = self.m_mPoint[pid]
    mInfo.win = mInfo.win+1
    mInfo.lastwin = mInfo.lastwin + 1
    
    if mInfo.win == FIRST_WIN then
        mInfo.firstwin = 1
    end
    if mInfo.win+mInfo.fail  == FIVE_WIN and mInfo.fivewin == 0 then
        mInfo.fivewin = 1
    end
    if self:ValidMatch(oPlayer,{bIngoreMatch=true}) then
        self:SetMatch(oPlayer,1)
    end
    if mInfo.lastwin>mInfo.maxwin then
        mInfo.maxwin = mInfo.lastwin
    end
    local iPoint = self:GetRewardPoint(oPlayer,mArgs)
    mInfo.point = mInfo.point + iPoint
    mInfo.pointtime = get_time()
    mInfo.lastmatch[1] = self.m_iMatchCnt
    local iFightLimit = res["daobiao"]["huodong"][self.m_sName]["config"][1]["fight_limit"]
    if mInfo.win + mInfo.fail >=iFightLimit then
        mInfo.match = 0
    end
    if self.m_iGameState == GAME_START then
        self:RefreshMyPoint(oPlayer)
    end
end

function CHuodong:RewardFailer(oPlayer,mArgs)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    mInfo.fail = mInfo.fail + 1
    mInfo.lastwin = 0
    if not mArgs.escape then
        self:Reward(pid,1004)
        local iPoint = self:GetRewardPoint(oPlayer,mArgs)
        iPoint = math.floor(iPoint/2)
        mInfo.point = mInfo.point + iPoint
    end
    if mInfo.win+mInfo.fail  == FIVE_WIN and mInfo.fivewin == 0 then
        mInfo.fivewin = 1
    end
    mInfo.lastmatch[1] = self.m_iMatchCnt
    mInfo.match = 0
    if self.m_iGameState == GAME_START then
        self:RefreshMyPoint(oPlayer)
    end
end


function CHuodong:GetFirstReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if not mInfo then
        return
    end
    if mInfo.firstwin ~=1 then
        if mInfo.firstwin ==0  then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1020))
        elseif mInfo.firstwin == 2 then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1009))
        end
        return
    end
    mInfo.firstwin = 2 
    self:Reward(pid,1001)
    self:PushNomalRank(oPlayer)
end

function CHuodong:GetFiveReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if not mInfo then
        return
    end
    if mInfo.fivewin ~=1 then
        if mInfo.fivewin ==0 then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1021))
        elseif mInfo.fivewin == 2 then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1009))
        end
        return
    end
    mInfo.fivewin = 2 
    self:Reward(pid,1002)
    self:PushNomalRank(oPlayer)
end

function CHuodong:RewardTitle()
    self:Dirty()
    local oWorldMgr = global.oWorldMgr
    local oTitleMgr = global.oTitleMgr
    local mRewardPid = {}
    for rank,mSortInfo in ipairs(self.m_lPointRank) do
        local pid = mSortInfo.pid
        local mInfo = self.m_mPoint[pid]
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if rank<=10 then
            local iRewardIdx = nil
            local iNotify = 1014
            if rank == 1 then
                iRewardIdx = 1005
                iNotify = 1013
            elseif rank == 2 then
                iRewardIdx = 1006
            elseif rank ==3 then
                iRewardIdx = 1007
            elseif rank <=5 then
                iRewardIdx = 1008
            elseif rank <=10 then
                iRewardIdx = 1009
            end
            if not iRewardIdx then
                goto continue
            end
            if oPlayer then
                self:Reward(pid,iRewardIdx)
                local sNotify = self:GetTextData(iNotify)
                sNotify  = global.oToolMgr:FormatColorString(sNotify,{rank = rank})
                global.oNotifyMgr:Notify(pid,sNotify)
                self:PushEndRank(oPlayer)
            else
                global.oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iRewardIdx})
            end
            if REWARD_TITLE[rank] then
                global.oTitleMgr:AddTitle(pid,REWARD_TITLE[rank])
            end
            mRewardPid[pid] = {reward=iRewardIdx,rank=rank,point = mInfo.point}
            ::continue::
        else
            if oPlayer then
                global.oNotifyMgr:Notify(pid,self:GetTextData(1015))
                self:PushEndRank(oPlayer)
            end
        end
    end
    local mFirstReward = res["daobiao"]["reward"][self.m_sName]["reward"][1001]
    local mFiveReward = res["daobiao"]["reward"][self.m_sName]["reward"][1002]
    for pid,mInfo in pairs(self.m_mPoint) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if mInfo.firstwin ==1 then
            local itemlist = {}
            for _,itemreward in pairs(mFirstReward.item) do
                local mRewardInfo = self:GetItemRewardData(itemreward)
                if mRewardInfo then
                    local mItemInfo = self:ChooseRewardKey(oTarget, mRewardInfo, itemreward, {})
                    if mItemInfo then
                        local iteminfo = self:InitRewardByItemUnitOffline(pid,itemreward,mItemInfo)
                        list_combine(itemlist,iteminfo["items"])
                    end
                end
            end
            if #itemlist>0 then
                local mMailReward = {}
                mMailReward["items"] = itemlist
                self:SendMail(pid,2044,mMailReward)
            end
            mInfo.firstwin = 2
        end
        if mInfo.fivewin == 1 then
            local itemlist = {}
            for _,itemreward in pairs(mFiveReward.item) do
                local mRewardInfo = self:GetItemRewardData(itemreward)
                if mRewardInfo then
                    local mItemInfo = self:ChooseRewardKey(oTarget, mRewardInfo, itemreward, {})
                    if mItemInfo then
                        local iteminfo = self:InitRewardByItemUnitOffline(pid,itemreward,mItemInfo)
                        list_combine(itemlist,iteminfo["items"])
                    end
                end
            end
            if #itemlist>0 then
                local mMailReward = {}
                mMailReward["items"] = itemlist
                self:SendMail(pid,2045,mMailReward)
            end
            mInfo.fivewin = 2
        end
    end

    local mLogData = {}
    mLogData.sort = extend.Table.serialize(mRewardPid)
    record.log_db("huodong", "threebiwu_sort",mLogData)
end

function CHuodong:InitRewardByItemUnitOffline(pid, itemidx, mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback(""))
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

function CHuodong:Escape(oPlayer)
    self:RewardFailer(oPlayer,{escape=true})
    if self.m_iGameState == GAME_END then
        self:TransferOut(oPlayer)
    end
end

function CHuodong:TransferOut(oPlayer)
    local oSceneMgr = global.oSceneMgr
    local pid = oPlayer:GetPid()
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:GetSceneId() ~= self.m_iSceneID then
        return
    end
    if oPlayer:IsSingle() then
        oSceneMgr:EnterDurableScene(oPlayer)
    else
        local oTeam = oPlayer:HasTeam()
        oTeam:Leave(pid,true)
        oSceneMgr:EnterDurableScene(oPlayer)
    end
end

function CHuodong:SortPointRank()
    local oWorldMgr = global.oWorldMgr
    local lRank = {}
    for pid,mInfo in pairs(self.m_mPoint) do
        if mInfo.point>0 then
            table.insert(lRank,{pid = pid,point = mInfo.point})
        end
    end

    table.sort(lRank,function (mInfo1,mInfo2)
        if  mInfo1.point>mInfo2.point then
            return true
        elseif mInfo1.point<mInfo2.point then
            return false
        else
            local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(mInfo1.pid)
            local oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(mInfo2.pid)
            local mPoint1  = self.m_mPoint[mInfo1.pid]
            local mPoint2  = self.m_mPoint[mInfo2.pid]
            if mPoint1.pointtime < mPoint2.pointtime then
                return true 
            elseif mPoint1.pointtime > mPoint2.pointtime then
                return false 
            else
                local iGrade1 = mPoint1.grade
                if oPlayer1 then
                    iGrade1 = oPlayer1:GetGrade()
                end
                local iGrade2 = mPoint2.grade
                if oPlayer2 then
                    iGrade2 = oPlayer2:GetGrade()
                end
                if iGrade1>iGrade2 then
                    return true
                elseif iGrade1<iGrade2 then
                    return false
                else
                    if mInfo1.pid<mInfo2.pid then
                        return true 
                    else
                        return false
                    end
                end
            end
        end
    end)
    self.m_lPointRank = lRank
    local iCurRank = 0
    local iCurPoint = 0
    for rank,mRankInfo in ipairs(lRank) do
        local mInfo = self.m_mPoint[mRankInfo.pid]
        local iPoint = mInfo.point
        if iPoint ~= iCurPoint then
            iCurRank =  iCurRank+1
            iCurPoint = iPoint
        end
        mInfo.rank = iCurRank
    end
    self:RefreshAllPoint()
end

function CHuodong:RefreshAllPoint()
    local oWorldMgr = global.oWorldMgr
    for pid,mInfo in pairs(self.m_mPoint) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
            if oNowScene:GetSceneId() == self.m_iSceneID then
                self:RefreshMyPoint(oPlayer)
            end
        end
        ::continue::
    end
end

function CHuodong:RefreshMyPoint(oPlayer)
    local pid = oPlayer:GetPid()
    
    local mInfo = self.m_mPoint[pid]
    local mNet = {}
    mNet.rank = mInfo.rank 
    mNet.point = mInfo.point
    mNet.lastwin = mInfo.lastwin
    mNet.win = mInfo.win 
    mNet.fight = mInfo.win + mInfo.fail
    if self.m_iGameState == GAME_PRESTART then
        mNet.starttime =self.m_iStartTime
    else
        mNet.starttime =0
    end
    mNet.match = mInfo.match
    mNet.matchendtime = self.m_iStartTime + self:GetGameTime("StopMatchBattle")//1000
    mNet.endtime = self.m_iEndTime
    oPlayer:Send("GS2CThreeBWMyRank",mNet)
end

function CHuodong:SetMatch(oPlayer,iMatch,mArgs)
    mArgs = mArgs or {}
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if not mInfo then return end
    local iCurMatch = mInfo.match
    if iMatch ~=0 and iMatch ~= 1 then
        global.oNotifyMgr:Notify(pid,"数据错误")
        return
    end
    if iCurMatch == iMatch then
        if iCurMatch == 1 then
            global.oNotifyMgr:Notify(pid,"正处于非匹配中")
        else
            global.oNotifyMgr:Notify(pid,"正处于匹配中")
        end
        return
    end
    if iMatch == 1 and iCurMatch ==0 then
        local mArgsMatch = {bIngoreMatch=true,bNotify=true}
        if mArgs.silent then
            mArgsMatch.bNotify=false
        end
        if not self:ValidMatch(oPlayer,mArgsMatch) then
            return
        end
        mInfo.match = iMatch
    elseif iMatch ==0 and iCurMatch ==1 then
        mInfo.match = iMatch
    else
        return
    end
    local oTeam  = oPlayer:HasTeam()
    if oTeam then
        for _,oMem in pairs(oTeam:GetMember()) do
            local mInfo = self.m_mPoint[ oMem.m_ID]
            local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            if mInfo then
                mInfo.match = iMatch
                if oTarget then
                    self:RefreshMyPoint(oTarget)
                end
            end
        end
    else
        self:RefreshMyPoint(oPlayer)
    end
end

function CHuodong:PushEndRank(oPlayer)
    local mNet = {}
    local mData = self:PackRank(PUSH_TEN)
    mNet.rankdata = mData
    oPlayer:Send("GS2CThreeBWEndRank",mNet)
end

function CHuodong:PushNomalRank(oPlayer)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if not mInfo then
        return
    end
    local mNet = {}
    local mData = self:PackRank(PUSH_THIRTY)
    mNet.rankdata = mData
    mNet.point = mInfo.point
    mNet.rank = mInfo.rank
    mNet.win = mInfo.win 
    mNet.lastwin = mInfo.lastwin
    mNet.fivewin = mInfo.fivewin
    mNet.firstwin = mInfo.firstwin
    mNet.endtime = self.m_iEndTime
    oPlayer:Send("GS2CThreeBWNomalRank",mNet)
end

function CHuodong:PackRank(iLimit)
    local mNet ={}
    for rank ,mRankInfo in ipairs(self.m_lPointRank) do
        if rank>iLimit then
            break
        end
        local target = mRankInfo.pid
        local mInfo = self.m_mPoint[target]
        local oTarget =  global.oWorldMgr:GetOnlinePlayerByPid(target)
        local mData = {}
        if oTarget then
            mData.name = oTarget:GetName()
        else
            mData.name = mInfo.name
        end
        mData.point = mInfo.point
        mData.maxwin = mInfo.maxwin
        mData.rank = mInfo.rank
        table.insert(mNet,mData)
    end
    return mNet
end
--对话--
function CHuodong:ValidJoin(oPlayer,npcobj)
    local pid = oPlayer:GetPid()
    if oPlayer:IsSingle() then
        if self.m_iGameState ~= GAME_START and self.m_iGameState ~= GAME_PRESTART then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1017))
            return false
        end

        local LIMIT_GRADE = res["daobiao"]["open"]["THREEBIWU"]["p_level"]
        if oPlayer:GetGrade() < LIMIT_GRADE then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1016))
            return false
        end

    elseif oPlayer:IsTeamLeader() then
        local oWorldMgr = global.oWorldMgr
        local oTeam = oPlayer:HasTeam()
        local lGradeName = {}
        if self.m_iGameState ~= GAME_START and self.m_iGameState ~= GAME_PRESTART  then
            oTeam:TeamNotify(self:GetTextData(1017))
            return false
        end
        local iJoinLimit = res["daobiao"]["huodong"][self.m_sName]["config"][1]["join_limit"]
        if oTeam:TeamSize()>iJoinLimit then
            oTeam:TeamNotify(self:GetTextData(1003))
            return false
        end
        for _, oMem in ipairs(oTeam:GetMember()) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            local LIMIT_GRADE = res["daobiao"]["open"]["THREEBIWU"]["p_level"]
            if oTarget:GetGrade() < LIMIT_GRADE then
                table.insert(lGradeName,oMem:GetName())
            end
        end
        if #lGradeName >0 then
            local sText = global.oToolMgr:FormatColorString(self:GetTextData(1004),{playlist=table.concat(lGradeName,",")})
            oTeam:TeamNotify(sText)
            return false
        end
    else
        return false
    end
    return true
end

function CHuodong:JoinGame(oPlayer,npcobj,bRobot)
    local bFly = true
    if bRobot then
        bFly = false
    end
    if not self:ValidJoin(oPlayer,npcobj) then
        return 
    end
    local oSceneMgr = global.oSceneMgr
    local oScene = self:GetScene()
    local mPos = self:RandomScenePos(oScene, bFly)
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), mPos)
end

function CHuodong:do_look(oPlayer, npcobj)
    local pid = oPlayer:GetPid()
    local nid = npcobj.m_ID
    local func = function (oPlayer,mData)
        self:Respond(oPlayer, nid, mData["answer"])
    end
    self:SayText(pid,npcobj,self:GetTextData(1007),func)
end

function CHuodong:Respond(oPlayer, nid, iAnswer)
    if iAnswer ~=1 then
        return
    end
    local oSceneMgr = global.oSceneMgr
    local pid = oPlayer:GetPid()
    if oPlayer:IsSingle() then
        oSceneMgr:EnterDurableScene(oPlayer)
    elseif oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam() 
        oSceneMgr:TeamEnterDurableScene(oPlayer)
    end
end

function CHuodong:TeamSay(oTeam,npcobj,sText)
    for _, oMem in ipairs(oTeam:GetMember()) do
        npcobj:Say(oMem.m_ID,sText)
    end
end
--对话--

function CHuodong:PushRank()
    local oWorldMgr = global.oWorldMgr
    local mNet = {}
    for rank ,mRankInfo in ipairs(self.m_lPointRank) do
        if rank>100 then
            break
        end
        local target = mRankInfo.pid
        local mInfo = self.m_mPoint[target]
        local oTarget =  oWorldMgr:GetOnlinePlayerByPid(target)
        local mData = {}
        if oTarget then
            mData.name = oTarget:GetName()
            mData.grade = oTarget:GetGrade()
            mData.school = oTarget:GetSchool()
            mData.model = oTarget:GetChangedModelInfo()
        else
            mData.name = mInfo.name
            mData.grade = mInfo.grade
            mData.school = mInfo.school
            mData.model = mInfo.model
        end

        mData.point = mInfo.point
        mData.rank = rank
        mData.pid = target
        table.insert(mNet,mData)
        ::continue::
    end
    global.oRankMgr:PushDataToRank("threebiwu",mNet)
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 开始进场\nhuodongop threebiwu 101",
        "102 活动开始\nhuodongop threebiwu 102",
        "103 活动结束(104+105)\nhuodongop threebiwu 103",
        "104 活动结束(不清场景)\nhuodongop threebiwu 104",
        "105 活动结束(清场景)\nhuodongop threebiwu 105",
        "106 清除胜利次数和失败次数\n huodongop threebiwu 106",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        if self.m_iGameState == GAME_PRESTART then
            oNotifyMgr:Notify(pid,"活动正在准备阶段")
            return
        end
        if self.m_iGameState == GAME_START then
            oNotifyMgr:Notify(pid,"活动进行中")
            return
        end
        self:PreGameStart()
        oNotifyMgr:Notify(pid,"准备阶段开启")
    elseif iFlag == 102 then
        if self.m_iGameState ~= GAME_PRESTART then
            oNotifyMgr:Notify(pid,"活动不在准备阶段")
            return
        end
        self:GameStart()
        oNotifyMgr:Notify(pid,"活动开启")
    elseif iFlag == 103 then
        if self.m_iGameState ~= GAME_START  then
            oNotifyMgr:Notify(pid,"活动不在准备阶段")
            return
        end
        self:GameOver1()
        self:GameOver2()
        oNotifyMgr:Notify(pid,"活动结束")
    elseif iFlag == 104 then
        self:GameOver1()
    elseif iFlag == 105 then
        self:GameOver1()
        self:GameOver2()
    elseif iFlag == 106 then
        local mInfo = self.m_mPoint[pid]
        if mInfo then
            mInfo.fail = 0
            mInfo.win=0
            self:RefreshMyPoint(oPlayer)
            oNotifyMgr:Notify(pid,"清除成功")
        end
    elseif iFlag == 201 then
        if not self.m_iSceneID then
            oNotifyMgr:Notify(pid,"活动场景未创建")
            return
        end
        local npclist = self:GetNpcListByScene(self.m_iSceneID)
        local npcobj = npclist[1]
        if not npcobj then
            oNotifyMgr:Notify(pid,"活动npc未创建")
            return
        end
        local oTeamMgr = global.oTeamMgr 
        local mRobot = {}
        local all = mArgs.all or 0
        for target ,oTarget in pairs(oWorldMgr.m_mOnlinePlayers) do
            local sAccount = oTarget:GetAccount()
            if string.find(sAccount,"Robotthreebiwu")  or all == 1 then
                mRobot[target] = oTarget
            end
        end
        if table_count(mRobot) == 0 then
            oNotifyMgr:Notify(pid,"暂无机器人，请程序生成")
            return
        end
        local playertest = import(service_path("playerctrl/test"))
        
        for target ,oTarget in pairs(mRobot) do
            playertest.TestOP(oTarget,101,{grade = 60})
            if oTarget:HasTeam() then
                local oTeam = oTarget:HasTeam()
                oTeam:ReleaseTeam()
            end
        end
        for target ,oTarget in pairs(mRobot) do
            oTeamMgr:CreateTeam(target)
            local oTeam = oTarget:HasTeam()
            oTeam.m_TestSize = 3
            self:JoinGame(oTarget,npcobj,true)
        end
        oNotifyMgr:Notify(pid,"机器人都进场了")
    elseif iFlag == 202 then
        local oScene = self:GetScene()
        if not oScene then
            oNotifyMgr:Notify(pid,"活动未开")
            return
        end
        local oWorldMgr = global.oWorldMgr
        local oNotifyMgr = global.oNotifyMgr
        local oTeamMgr = global.oTeamMgr
        for pid , _ in pairs(oScene.m_mPlayers) do
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then
                goto continue
            end
            local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
            if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
                local oWar = oPlayer:InWar()
                if oWar then
                    oWar:TestCmd("warend",pid,{})
                end
            end
            ::continue::
        end
    elseif iFlag == 203 then
        self:MatchBattle()
    elseif iFlag == 204 then
        self:GetFiveReward(oPlayer)
    elseif iFlag == 205 then
        self:GetFirstReward(oPlayer)
    elseif iFlag == 206 then
        self:PushNomalRank(oPlayer)
    elseif iFlag == 207 then
        self:SetMatch(oPlayer,mArgs.match)
    elseif iFlag == 208 then
        print(pid,self.m_mPoint[pid])
    end
end

function _EscapeCallBack(oPlayer)
    local oHD = global.oHuodongMgr:GetHuodong("threebiwu")
    if not oHD then return end
    oHD:Escape(oPlayer)
end
