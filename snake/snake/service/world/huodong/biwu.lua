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

local GAME_NONE = 0
local GAME_PRESTART = 1
local GAME_START = 2
local GAME_END = 3

local GAME_ENTER = 1
local GAME_NOENTER  = 0

local LIMIT_FAIL = 5
local LIMIT_REWARD = 10
local LIMIT_RANK = 50
local LIMIT_BOUT = 50

local BW_PROTECT = 60
local REWARD_POINT = "math.max(mygrade-SLV,0)*2+(100+math.max(0,math.floor((enemygrade-mygrade)/2.0))*(1+math.max(0,math.floor(time/600)-1)))*(20/100+16/100*enemycnt)"

local WIN_TEN = 10
local WIN_FIVE = 5
local FIRST_TEN = 10
local FIRST_THREE = 3

local BW_TITLE = {927,928,929}

local GAME_NPCTYPE = {1001,1002,1003,1004}
local RANK_NPCTYPE = {1005,1006,1007,1008,1009}

local MATCH_THREE = 3
local MATCH_FOUR = 4
local MATCH_FIVE = 5

local ANNOUNCT_ORG  = 3

local MODEL_OPEN = false

function MatchSort (pid1,pid2)
        local oWorldMgr = global.oWorldMgr
        local oHd = global.oHuodongMgr:GetHuodong("biwu")
        local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(pid1)
        local oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(pid2)
        local iGrade1 = oPlayer1:GetGrade()
        local iGrade2 = oPlayer2:GetGrade()

        local oTeam1= oPlayer1:HasTeam()
        if oTeam1 then
            iGrade1 = oHd:GetTeamGrade(oTeam1)
        else
            iGrade1 = math.floor((iGrade1*60 + iGrade1*40)/100)
        end
        local oTeam2= oPlayer2:HasTeam()
        if oTeam2 then
            iGrade2 = oHd:GetTeamGrade(oTeam2)
        else
            iGrade2 = math.floor((iGrade2*60 + iGrade2*40)/100)
        end
        if iGrade1>iGrade2 then
            return true
        else
            return false
        end
    end


CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "三界斗法"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1012
    o.m_iGameState = GAME_NONE
    o.m_iSceneID = nil
    o.m_bOrgAnnounce = false
    o.m_iStartTime = 0
    o.m_mPoint = {}
    o.m_lPointRank = {}
    o.m_mTitlePlayer = {}
    o.m_mModelPlayer = {}
    o.m_lNoMatch = {}
    o.m_iNextMatchTime = 0
    o.m_mPreStartWar = {}
    return o
end

function CHuodong:Init()
    if not self:IsSysOpen() then
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
    if not self:IsSysOpen() then
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
    if not self:IsSysOpen() then
        return
    end
    local iWeekDay = mNow.date.wday
    local mOpenDay = self:GetOpenDay()
    if mOpenDay[iWeekDay] == 1 then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:IsSysOpen()
    return true
    -- local LIMIT_GRADE = res["daobiao"]["open"]["BIWU"]["p_level"]
    -- local iServerGrade = global.oWorldMgr:GetServerGrade()
    -- if LIMIT_GRADE>iServerGrade then
    --     return false
    -- end
    -- return true
end

function CHuodong:OnLogin(oPlayer,reenter)
    local pid = oPlayer:GetPid()
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if self.m_iSceneID and self.m_iSceneID == oNowScene:GetSceneId() then
        self:RefreshMyPoint(oPlayer)
    end 
    if not reenter then
        local oTitleMgr = global.oTitleMgr
        for _,iTitle in pairs(BW_TITLE) do
            if oPlayer.m_oTitleCtrl:GetTitleByTid(iTitle)  and not self.m_mTitlePlayer[pid] then
                oTitleMgr:RemoveOneTitle(pid,iTitle)
            end
        end
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.titleplayer = table_to_db_key(self.m_mTitlePlayer)
    mData.modelplayer = table_to_db_key(self.m_mModelPlayer)
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_mTitlePlayer = table_to_int_key(mData.titleplayer or {})
    self.m_mModelPlayer = table_to_int_key(mData.modelplayer or {})
    self:CreateModelNPC()
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

function CHuodong:Announce(sMsg,iHorse)
    local oChatMgr = global.oChatMgr
    iHorse = iHorse or 0
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,iHorse)
end

function CHuodong:GetNPCMenu()
    return "参与斗法"
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
    local mInfo = self.m_mPoint[pid]
    local iLeader = oLeader:GetPid()
    local LIMIT_GRADE = res["daobiao"]["open"]["BIWU"]["p_level"]
    -- if oPlayer:GetGrade() < LIMIT_GRADE then
    --     if iApply ==1 then
    --         oNotifyMgr:Notify(pid,self:GetTextData(1023))
    --     elseif iApply == 2 then
    --         oNotifyMgr:Notify(iLeader,self:GetTextData(1022))
    --     end
    --     return false
    -- elseif mInfo and mInfo.fail >= LIMIT_FAIL then
    --     if iApply ==1 then
    --         oNotifyMgr:Notify(pid,self:GetTextData(1025))
    --     elseif iApply == 2 then
    --         oNotifyMgr:Notify(iLeader,self:GetTextData(1024))
    --     end
    --     return false
    -- end
    oNotifyMgr:Notify(pid,self:GetTextData(1031))
    return false
end


--基础接口--

--准备阶段--
function CHuodong:PreGameStart()
    record.info(string.format("%s PreGameStart",self.m_sName))
    self:DelTimeCb("PreGameStart")
    self:DelTimeCb("GameOver1")
    self:DelTimeCb("GameOver2")
    self:AddTimeCb("CycleReward",self:GetGameTime("CycleReward"),function ()
        self:CycleReward()
    end)
    self:AddTimeCb("PushMakeTeamUI",self:GetGameTime("PushMakeTeamUI")-1000,function ()
        self:PushMakeTeamUI()
    end)
    self:AddTimeCb("GameStart",self:GetGameTime("GameStart"),function ()
        self:GameStart()
    end)
    self:CreateScene()
    self:CreateNPC()
    self.m_mPoint = {}
    self.m_lPointRank = {}
    self.m_iGameState = GAME_PRESTART
    self.m_bOrgAnnounce = false
    self.m_iStartTime = get_time() + math.floor(self:GetGameTime("GameStart")/1000)
    local mChuanwen = res["daobiao"]["chuanwen"][1046]
    self:Announce(mChuanwen.content,mChuanwen.horse_race)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
end

function CHuodong:PushMakeTeamUI()
    self:DelTimeCb("PushMakeTeamUI")
    local oCbMgr = global.oCbMgr
    local oUIMgr = global.oUIMgr
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oTeamMgr = global.oTeamMgr
    local mData = {
        sContent = self:GetTextData(1027),
        sConfirm = "确认",
        sCancle = "取消",
        default = 1,
        time = 60,
    }
    local mData = oCbMgr:PackConfirmData(nil, mData)
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
        if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
            goto continue
        end
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            goto continue
        end
        if mInfo.fail >=LIMIT_FAIL then
            goto continue
        end
        if mInfo.maketeam == 1 then
            goto continue
        end
        if oPlayer:IsTeamLeader() then
            local oTeam = oPlayer:HasTeam()
            if oTeam:TeamSize()<5 then
                oCbMgr:SetCallBack(pid, "GS2CConfirmUI",mData,nil,function (oPlayer,mData)
                    local iAnswer = mData["answer"]
                    if iAnswer == 1 then
                        self:SetMakeTeam(oPlayer,1)
                    end
                end)
            end
        elseif not oPlayer:HasTeam() then
                oCbMgr:SetCallBack(pid, "GS2CConfirmUI",mData,nil,function (oPlayer,mData)
                    local iAnswer = mData["answer"]
                    if iAnswer == 1 then
                        self:SetMakeTeam(oPlayer,1)
                    end
                end)
        end
        ::continue::
    end
end

function CHuodong:CreateScene()
    local oSceneMgr = global.oSceneMgr
    local mRes = res["daobiao"]["huodong"]["biwu"]["scene"]
    for iIndex , mInfo in pairs(mRes) do
        local mData ={
        map_id = mInfo.map_id,
        url = {"huodong", "biwu", "scene", iIndex},
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
        break
    end
end

function CHuodong:OnPlayerEnterScene(oPlayer,oScene)
    local pid = oPlayer:GetPid()
    self:SetInitInfo(oPlayer)
    self:RefreshMyPoint(oPlayer)
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
    self.m_mPoint[pid] = {point = 0,grade = oPlayer:GetGrade(), name = oPlayer:GetName(),rank = 0,win = 0,fail = 0,school = oPlayer:GetSchool(),icon = oPlayer:GetIcon(),model = oPlayer:GetChangedModelInfo(),title = sTitle,reward = 0,maxwin = 0,maketeam = 0,firstten = 0,firstthree = 0,fivewin = 0,tenwin = 0,war = 0,lastwin = 0,pointtime = 0}
end

function CHuodong:GetScene()
    local oSceneMgr = global.oSceneMgr
    local oScene  = oSceneMgr:GetScene(self.m_iSceneID)
    return oScene
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
    self:DelTimeCb("PushMakeTeamUI")
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
    self:MatchBattle()
    self.m_iNextMatchTime = get_time() + math.floor(self:GetGameTime("MatchBattle")/1000)
    self:AddTimeCb("SetOrgAnnounce",self:GetGameTime("SetOrgAnnounce"),function ()
        self:SetOrgAnnounce()
    end)
    self:MakeTeam()
    self:RemoveModelNPC()
    self:RefreshAllPoint()
end

function CHuodong:StopMatchBattle()
    record.info(string.format("%s StopMatchBattle",self.m_sName))
    self:DelTimeCb("MatchBattle")
    self:DelTimeCb("MakeTeam")
end

function CHuodong:SetOrgAnnounce()
    record.info(string.format("%s SetOrgAnnounce",self.m_sName))
    self:DelTimeCb("SetOrgAnnounce")
    self.m_bOrgAnnounce = true
end

function CHuodong:GameOver1()
    record.info(string.format("%s GameOver1",self.m_sName))
    self:DelTimeCb("GameStart")
    self:DelTimeCb("GameOver1")
    self:DelTimeCb("CycleReward")
    self:DelTimeCb("MatchBattle")
    self:DelTimeCb("StopMatchBattle")
    self:DelTimeCb("TrueStartFight")
    self:DelTimeCb("SetOrgAnnounce")
    self:DelTimeCb("MakeTeam")

    self.m_iGameState = GAME_END
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    self:AddTimeCb("GameOver2",self:GetGameTime("GameOver2"),function ()
        self:GameOver2()
    end)
    local mChuanwen = res["daobiao"]["chuanwen"][1049]
    local sContent = mChuanwen.content
    local iRank = 0
    if self.m_lPointRank[1] then
        sContent = sContent .. "，积分前#G#rank#n名分别是:"
        local pid = self.m_lPointRank[1]["pid"]
        local mInfo = self.m_mPoint[pid]
        sContent = sContent .. string.format("#G%s#n",mInfo.name)
        iRank = iRank+1
    end
    if self.m_lPointRank[2] then
        local pid = self.m_lPointRank[2]["pid"]
        local mInfo = self.m_mPoint[pid]
        sContent = sContent .. string.format("#G、%s#n",mInfo.name)
        iRank = iRank+1
    end
    if self.m_lPointRank[3] then
        local pid = self.m_lPointRank[2]["pid"]
        local mInfo = self.m_mPoint[pid]
        sContent = sContent .. string.format("#G、%s#n",mInfo.name)
        iRank = iRank+1
    end
    if self.m_lPointRank[4] then
        local pid = self.m_lPointRank[4]["pid"]
        local mInfo = self.m_mPoint[pid]
        sContent = sContent .. string.format("#G、%s#n",mInfo.name)
        iRank = iRank+1
    end
    if self.m_lPointRank[5] then
        local pid = self.m_lPointRank[5]["pid"]
        local mInfo = self.m_mPoint[pid]
        sContent = sContent .. string.format("#G、%s#n",mInfo.name)
        iRank = iRank+1
    end

    sContent = global.oToolMgr:FormatColorString(sContent,{rank = iRank})
    self:Announce(sContent,mChuanwen.horse_race)


    self:CleanPlayer()
    self:RewardTitle()
    self:PushBiwuRank()
end

function CHuodong:GameOver2()
    record.info(string.format("%s GameOver2",self.m_sName))
    self:DelTimeCb("GameOver1")
    self:DelTimeCb("GameOver2")
    self:DelTimeCb("CycleReward")
    self:DelTimeCb("MatchBattle")
    self:DelTimeCb("StopMatchBattle")
    self:DelTimeCb("TrueStartFight")
    self:DelTimeCb("SetOrgAnnounce")
    self:DelTimeCb("MakeTeam")
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

function CHuodong:MatchBattle()
    self:DelTimeCb("MatchBattle")
    self:AddTimeCb("MatchBattle",self:GetGameTime("MatchBattle"),function ()
        self:MatchBattle()
    end)
    self.m_iNextMatchTime = get_time() + math.floor(self:GetGameTime("MatchBattle")/1000)
    local oTeamMgr = global.oTeamMgr
    local lWinMatchUnit = {}
    local lFailMatchUnit = {}
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iValidUnitCnt = 0
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end

        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            goto continue
        end
        if mInfo.fail >=LIMIT_FAIL then
            goto continue
        end
        local iProtectTime = oPlayer.m_BWProtectTime or 0
        if iProtectTime>get_time() then
            iValidUnitCnt = iValidUnitCnt +1
            if oPlayer:IsSingle() and not oPlayer:HasTeam() then
                oNotifyMgr:Notify(pid,"您正处于修整状态无法进行匹配")
            elseif oPlayer:IsTeamLeader() then
                local oTeam = oPlayer:HasTeam()
                oTeam:TeamNotify("您正处于修整状态无法进行匹配")
            end
            goto continue 
        end
        if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
            goto continue
        end
        if oPlayer:HasTeam() and oPlayer:IsSingle() then
            goto continue
        end
        local iWarStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
        if iWarStatus == gamedefines.WAR_STATUS.IN_WAR then
            iValidUnitCnt = iValidUnitCnt +1
            goto continue
        end
        local iLastWin = mInfo.lastwin or 0
        if iLastWin == 0 then
            table.insert(lFailMatchUnit,pid)
        elseif iLastWin == 1 then
            table.insert(lWinMatchUnit,pid)
        end
        ::continue::
    end

    local lDelNoMatch  = {}
    for _,pid in ipairs(self.m_lNoMatch) do
        if not extend.Array.find(lWinMatchUnit,pid) and not extend.Array.find(lFailMatchUnit,pid) then
            table.insert(lDelNoMatch,pid)
        end
    end
    for _,pid in ipairs(lDelNoMatch) do
        extend.Array.remove(self.m_lNoMatch,pid)
    end
    table.sort(lWinMatchUnit,MatchSort)
    table.sort(lFailMatchUnit,MatchSort)
    local lNoMatch = extend.Table.deep_clone(self.m_lNoMatch)
    -- print("=================")
    -- print("lNoMatch",iValidUnitCnt, lNoMatch)
    self.m_lNoMatch = {}

    for iFlag,lMatchUnit in ipairs({lWinMatchUnit,lFailMatchUnit}) do
        local iMaxCount = #lMatchUnit
        -- print("lMatchUnit",iFlag,lMatchUnit)
        for index = 1 , iMaxCount do
            local iCurCount = #lMatchUnit
            if iCurCount<=0 then
                break
            end
            local pos1 = 1

            local iNoMatchPos = self:GetNoMatchPos(lMatchUnit,lNoMatch) 
            if iNoMatchPos then
                pos1 = iNoMatchPos
            end

            local pos2 = nil
            local pid1 = lMatchUnit[pos1]
            local pid2 = nil 
            local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(pid1)
            local oPlayer2 = nil
            if iCurCount==1 then
                if iFlag == 1 then
                    table.insert(lFailMatchUnit,1,lMatchUnit[1])
                else
                    table.insert(self.m_lNoMatch,pid1)
                end
                
                break
            end
            if iCurCount == 2 then
                if pos1 == 1 then
                    pos2 = 2
                else
                    pos2 = 1
                end
                pid2 = lMatchUnit[pos2]
                oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(pid2)
                if self:ValidMatch(oPlayer1,oPlayer2,iValidUnitCnt) then
                    -- print("cnt2 ",pid1,pid2)
                    extend.Array.remove(lMatchUnit,pid1)
                    extend.Array.remove(lMatchUnit,pid2)
                    extend.Array.remove(lNoMatch,pid1)
                    extend.Array.remove(lNoMatch,pid2)
                    if oPlayer1 and oPlayer2 and oPlayer1 ~= oPlayer2 then
                        safe_call(self.StartFight,self,oPlayer1:GetPid(),oPlayer2:GetPid())
                    end
                else
                    if iFlag == 1 then
                        if #lFailMatchUnit<=0 then
                            table.insert(self.m_lNoMatch,pid1)
                            table.insert(self.m_lNoMatch,pid2)
                        else
                            table.insert(lFailMatchUnit,1,lMatchUnit[pos1])
                            table.insert(lFailMatchUnit,1,lMatchUnit[pos2])
                        end
                    else
                            table.insert(self.m_lNoMatch,pid1)
                            table.insert(self.m_lNoMatch,pid2)
                    end
                end
                break
            end 
            local iMinDiff = 5
            local lPos = {}
            for pos, pid in ipairs(lMatchUnit) do
                local obj = oWorldMgr:GetOnlinePlayerByPid(pid)
                if pos ~= pos1 and self:ValidMatch(oPlayer1,obj,iValidUnitCnt,true) and iMinDiff >= math.abs(pos - pos1) then
                    table.insert(lPos,pos)
                end
            end      
            if #lPos>0 then
                -- print("lPos",lPos)
                local pos  = extend.Random.random_choice(lPos)
                pid2 = lMatchUnit[pos]
                oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(pid2)
                pos2 = pos
            end
            if oPlayer1 and oPlayer2 then
                -- print("cnt3 ",pid1,pid2)
                extend.Array.remove(lNoMatch,pid1)
                extend.Array.remove(lNoMatch,pid2)
                extend.Array.remove(lMatchUnit,pid1)
                extend.Array.remove(lMatchUnit,pid2)
                
                if oPlayer1 and oPlayer2 and oPlayer1 ~= oPlayer2 then
                    safe_call(self.StartFight,self,oPlayer1:GetPid(),oPlayer2:GetPid())
                end
            end
        end
    end


    local sNoMatchMsg = "本轮轮空，下轮优先匹配"
    for _,pid in ipairs(self.m_lNoMatch) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            oTeam:TeamNotify(sNoMatchMsg)
        else
            oNotifyMgr:Notify(pid,sNoMatchMsg)
        end
    end
    self:RefreshAllPoint()
end

function CHuodong:GetTeamGrade(oTeam)
    local iAveGrade = oTeam:GetTeamAveGrade()
    local iMaxGrade = oTeam:GetTeamMaxGrade()
    local iGrade = math.floor((iMaxGrade*60 + iAveGrade*40)/100)
    return iGrade
end

function CHuodong:GetNoMatchPos(lMatchUnit,lNoMatch)
    for _,pid in ipairs(lNoMatch) do
        local pos = extend.Array.find(lMatchUnit, pid)
        if pos then
            return pos
        end
    end
end

function CHuodong:ValidMatch(oFighter1,oFighter2,iValidUnitCnt,bFailValid)
    local iLastFight1 = oFighter1.m_BWLastFight or 0
    local iLastFight2 = oFighter2.m_BWLastFight or 0
    local iFightID1 = oFighter1:GetPid()
    local iFightID2 = oFighter2:GetPid()
    if iLastFight1 == iFightID2 and iLastFight2 == iFightID1 then
        if bFailValid then
            return false
        end
        if iValidUnitCnt == 0 then
            oFighter1.m_BWNoMatch = nil
            oFighter2.m_BWNoMatch = nil
            oFighter1.m_BWLastFight = nil
            oFighter2.m_BWLastFight = nil 
            return true
        end
        if iValidUnitCnt <=3 then
            oFighter1.m_BWLastFight = nil
            oFighter2.m_BWLastFight = nil 
            return false
        end

        if oFighter1.m_BWNoMatch == true and oFighter2.m_BWNoMatch == true then
            oFighter1.m_BWNoMatch = nil
            oFighter2.m_BWNoMatch = nil
            oFighter1.m_BWLastFight = nil
            oFighter2.m_BWLastFight = nil 
            return false
        else
            oFighter1.m_BWNoMatch = true
            oFighter2.m_BWNoMatch = true
            return false
        end
    end
    oFighter1.m_BWNoMatch = nil
    oFighter2.m_BWNoMatch = nil
    oFighter1.m_BWLastFight = nil
    oFighter2.m_BWLastFight = nil 
    return true
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
    mNet.time = math.floor(self:GetGameTime("TrueStartFight")/1000)
    self.m_mPreStartWar[iFighter1] = 1
    self.m_mPreStartWar[iFighter2] = 1
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
    self.m_mPreStartWar[iFighter1] = nil
    self.m_mPreStartWar[iFighter2] = nil
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
    oFighter1.m_BWLastFight = iFighter2
    oFighter2.m_BWLastFight = iFighter1
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
    record.log_db("huodong", "biwu_battle",mLogData)

    for _,pid in ipairs(lFighter1) do
        local mInfo = self.m_mPoint[pid]
        mInfo.war  = mInfo.war +1 
    end
    for _,pid in ipairs(lFighter2) do
        local mInfo = self.m_mPoint[pid]
        mInfo.war  = mInfo.war +1 
    end

    local oWarMgr = global.oWarMgr
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["condition"][1]
    local iBarrageShow = mConfig.barrage_show or 0
    local iBarrageSend = mConfig.barrage_send or 0
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

    oWar:SetOtherCallback("OnLeave",_EscapeCallBack)
    oWarMgr:SetCallback(iWarID, fCallback)
    oWar.m_TeamGrade = {grade1 = self:GetFighterAvgGrade(oFighter1),grade2 = self:GetFighterAvgGrade(oFighter2)}
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local mPoint1Env = {enemygrade = oWar.m_TeamGrade.grade2,mygrade = oWar.m_TeamGrade.grade1,enemycnt = #lFighter2,SLV = iServerGrade,time=0}
    local mPoint2Env = {enemygrade = oWar.m_TeamGrade.grade1,mygrade = oWar.m_TeamGrade.grade2,enemycnt = #lFighter1,SLV = iServerGrade,time=0}
    oWar.m_RewardPoint={point1 = mPoint1Env,point2 = mPoint2Env}
    oWar.biwu_starttime = get_time()
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
            oPlayer:Send("GS2CBWBattle",mNet)
        else
            local oTeam = oPlayer:HasTeam()
            for _,oMem in pairs(oTeam:GetMember()) do
                local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                oTarget:Send("GS2CBWBattle",mNet)
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
    record.log_db("huodong", "biwu_warend",mLogData)

    local mWinner = {}
    local mFailer  = {}
    if iWinSide == iSide1 then
        mWinner = mPlayer[iSide1]
        mFailer  = mPlayer[iSide2]
    elseif iWinSide == iSide2 then
        mWinner = mPlayer[iSide2]
        mFailer  = mPlayer[iSide1]
    end

    local mRewardPoint = oWar.m_RewardPoint
    local iRewardPoint = 0
    local mPointEnv
    if iWinSide == 1 then
        mPointEnv = mRewardPoint.point1
        mPointEnv.time = get_time() - (oWar.biwu_starttime or get_time())
        iRewardPoint = formula_string(REWARD_POINT,mPointEnv)
        iRewardPoint = math.floor(iRewardPoint)
    else
        mPointEnv = mRewardPoint.point2
        mPointEnv.time = get_time() - (oWar.biwu_starttime or get_time())
        iRewardPoint = formula_string(REWARD_POINT,mPointEnv)
        iRewardPoint = math.floor(iRewardPoint)
    end

    local iWinTeamSize = #mWinner
    for _,pid in pairs(mWinner) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:MarkGrow(27)
            self:RewardWinner(oPlayer,iRewardPoint)
            self:RewardLeaderPoint(oPlayer,"biwu","三界斗法",iWinTeamSize)
            if self.m_iGameState == GAME_END then
                self:TransferOut(oPlayer)
            else
                if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
                    oPlayer.m_BWProtectTime = get_time() + BW_PROTECT
                end
            end
            if not is_production_env() and oPlayer then
                global.oChatMgr:HandleMsgChat(oPlayer,extend.Table.serialize(mPointEnv))
            end
        end
    end

    local iFailTeamSize = #mFailer
    for _,pid in pairs(mFailer) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:MarkGrow(27)
            self:RewardFailer(oPlayer)
            self:RewardLeaderPoint(oPlayer,"biwu","三界斗法",iFailTeamSize)
            if self.m_iGameState == GAME_END then
                self:TransferOut(oPlayer)
            else
                if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
                    oPlayer.m_BWProtectTime = get_time() + BW_PROTECT
                end
            end
        end
    end
    if self.m_iGameState == GAME_START then
        self:SortPointRank()
        self:OrgAnnounce(mWinner)
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

function CHuodong:OrgAnnounce(mWinner)
    local oWorldMgr = global.oWorldMgr
    if not self.m_bOrgAnnounce then
        return false
    end
    local mOrg = {}
    local mOrgName = {}
    for _,pid in pairs(mWinner) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local orgid = oPlayer:GetOrgID()
            if orgid == 0 then
                goto continue
            end
            if not  mOrg[orgid] then
                mOrg[orgid] = {}
            end
            if not  mOrgName[orgid] then
                mOrgName[orgid] = {}
            end
            table.insert(mOrg[orgid],pid)
            table.insert(mOrgName[orgid],oPlayer:GetName())
            ::continue::
        end
    end
    for _,pid in pairs(mWinner) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local orgid   = oPlayer:GetOrgID()
        if orgid == 0 then
            goto continue
        end
        local mInfo = self.m_mPoint[pid]
        if oPlayer and mInfo then
            if mInfo.win >= WIN_TEN and mInfo.tenwin == 0 then
                local mChuanwen = res["daobiao"]["chuanwen"][1047]
                local sContent = mChuanwen.content
                sContent = global.oToolMgr:FormatColorString(sContent,{role = table.concat(mOrgName[orgid],","),amount = WIN_TEN})
                global.oChatMgr:SendMsg2Org(sContent,orgid)
                for _,target in ipairs(mOrg[orgid]) do
                    local mTargetInfo = self.m_mPoint[target]
                    if mTargetInfo.win > WIN_TEN and mTargetInfo.tenwin == 0 then
                        mTargetInfo.tenwin = 1 
                    end
                end
            end

            if mInfo.win >= WIN_FIVE and mInfo.fivewin == 0 and mInfo.tenwin == 0 then
                local mChuanwen = res["daobiao"]["chuanwen"][1047]
                local sContent = mChuanwen.content
                sContent = global.oToolMgr:FormatColorString(sContent,{role = table.concat(mOrgName[orgid],","),amount = WIN_FIVE})
                global.oChatMgr:SendMsg2Org(sContent,orgid)
                for _,target in ipairs(mOrg[orgid]) do
                    local mTargetInfo = self.m_mPoint[target]
                    if mTargetInfo.win > WIN_FIVE and mTargetInfo.fivewin == 0 then
                        mTargetInfo.fivewin = 1 
                    end
                end
            end
            if mInfo.rank<=FIRST_THREE and mInfo.firstthree == 0 then
                local mChuanwen = res["daobiao"]["chuanwen"][1048]
                local sContent = mChuanwen.content
                sContent = global.oToolMgr:FormatColorString(sContent,{role = table.concat(mOrgName[orgid],","),amount = FIRST_THREE})
                global.oChatMgr:SendMsg2Org(sContent,orgid)
                for _,target in ipairs(mOrg[orgid]) do
                    local mTargetInfo = self.m_mPoint[target]
                    if mTargetInfo.rank <= FIRST_THREE and mTargetInfo.firstthree == 0 then
                        mTargetInfo.firstthree = 1 
                    end
                end
            end
            if mInfo.rank<= FIRST_TEN and mInfo.firstten == 0 and mInfo.firstthree == 0 then
                local mChuanwen = res["daobiao"]["chuanwen"][1048]
                local sContent = mChuanwen.content
                sContent = global.oToolMgr:FormatColorString(sContent,{role = table.concat(mOrgName[orgid],","),amount = FIRST_TEN})
                global.oChatMgr:SendMsg2Org(sContent,orgid)
                for _,target in ipairs(mOrg[orgid]) do
                    local mTargetInfo = self.m_mPoint[target]
                    if mTargetInfo.rank <= FIRST_TEN and mTargetInfo.firstten == 0 then
                        mTargetInfo.firstten = 1 
                    end
                end
            end
        end
        ::continue::
    end
end

function CHuodong:RewardWinner(oPlayer,iRewardPoint)
    local pid = oPlayer:GetPid()
    self:Reward(pid,1002)
    local mInfo = self.m_mPoint[pid]
    mInfo.win = mInfo.win+1
    mInfo.lastwin = 1

    if mInfo.win>mInfo.maxwin then
        mInfo.maxwin = mInfo.win
    end
    mInfo.reward = mInfo.reward + 1
    mInfo.point  = mInfo.point + iRewardPoint
    mInfo.pointtime = get_time()
    if self.m_iGameState == GAME_START then
        self:RefreshMyPoint(oPlayer)
    end
    self:AddSchedule(oPlayer)
end

function CHuodong:RewardFailer(oPlayer)
    local pid = oPlayer:GetPid()
    self:Reward(pid,1003)
    local mInfo = self.m_mPoint[pid]
    mInfo.win = 0
    mInfo.fail = mInfo.fail + 1
    mInfo.lastwin = 0
    mInfo.reward = mInfo.reward + 1
    if self.m_iGameState == GAME_START then
        self:RefreshMyPoint(oPlayer)
    end
    if mInfo.fail>=LIMIT_FAIL then
        self:TransferOut(oPlayer)
    end
    self:AddSchedule(oPlayer)
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if mInfo.reward>LIMIT_REWARD then 
        return
    end
    super(CHuodong).RewardItems(self, oPlayer, mAllItems, mArgs)
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

function CHuodong:Escape(oPlayer)
    self:RewardFailer(oPlayer)
    if self.m_iGameState == GAME_END then
        self:TransferOut(oPlayer)
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

function CHuodong:CycleReward()
    self:DelTimeCb("CycleReward")
    self:AddTimeCb("CycleReward",self:GetGameTime("CycleReward"),function ()
        self:CycleReward()
    end)
    local oScene = self:GetScene()
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:Reward(pid,1001)
        end
    end
end


function CHuodong:MakeTeam()
    self:DelTimeCb("MakeTeam")
    self:AddTimeCb("MakeTeam",self:GetGameTime("MakeTeam"),function ()
        self:MakeTeam()
    end)
    local lMatchTeam = {}
    local lSingle = {}
    local oScene = self:GetScene()
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
            goto continue
        end
        if self.m_mPreStartWar[pid] then
            goto continue
        end
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            goto continue
        end
        if mInfo.fail >=LIMIT_FAIL then
            goto continue
        end
        if mInfo.maketeam ~= 1 then
            goto continue
        end
        if not oPlayer:IsTeamLeader() then
            if not oPlayer:HasTeam() then
                table.insert(lSingle,{pid,oPlayer:GetGrade()})
            end
            goto continue
        end
        local oTeam = oPlayer:HasTeam()
        if oTeam:TeamSize() >= 5 then
            goto continue
        end
        table.insert(lMatchTeam,{pid,oTeam:TeamSize(),oTeam:GetTeamAveGrade()})
        ::continue::
    end
    -- print("lMatchTeam",lMatchTeam)
    -- print("lSingle",lSingle)
    table.sort(lMatchTeam,function (mInfo1,mInfo2)
        if mInfo1[2]>mInfo2[2] then
            return true
        else
            if mInfo1[3]>mInfo2[3] then
                return true 
            end
        end
        return false
    end)
    table.sort(lSingle,function (mInfo1,mInfo2)
        if mInfo1[2]>mInfo2[2] then
            return true
        end
        return false
    end)

    for _,mLeader in ipairs(lMatchTeam) do
        local leader = mLeader[1]
        local oLeader = oWorldMgr:GetOnlinePlayerByPid(leader)
        if not  oLeader or not oLeader:IsTeamLeader() then
            goto continue
        end
        local oTeam = oLeader:HasTeam()
        local iSingleCnt = #lSingle
        if iSingleCnt<=0 then
            break
        end
        for index = 1 ,iSingleCnt do
            if #lSingle <= 0 then
                break
            end
            if oTeam:TeamSize()>=5 then
                break
            end
            local pid = lSingle[1][1]
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer and not oPlayer:HasTeam() then
                oTeamMgr:AddTeamMember(oTeam:TeamID(),pid)
            else
            end
            table.remove(lSingle, 1)
        end
        ::continue::
    end
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
        if oPlayer then
            if rank<=5 then
                self:Reward(pid,1004)
                oTitleMgr:AddTitle(pid,BW_TITLE[1])
                mRewardPid[pid] = {reward=1004,rank=rank,point = mInfo.point}
                self.m_mTitlePlayer[pid] = BW_TITLE[1]
            elseif rank<=10 then
                self:Reward(pid,1005)
                mRewardPid[pid] = {reward=1005,rank=rank,point = mInfo.point}
                oTitleMgr:AddTitle(pid,BW_TITLE[2])
                self.m_mTitlePlayer[pid] = BW_TITLE[2]
            elseif rank<=15 then
                self:Reward(pid,1006)
                oTitleMgr:AddTitle(pid,BW_TITLE[3])
                self.m_mTitlePlayer[pid] = BW_TITLE[3]
                mRewardPid[pid] = {reward=1006,rank=rank,point = mInfo.point}
            elseif rank>15 and mInfo.reward >= 5 then
                self:Reward(pid,1007)
                mRewardPid[pid] = {reward=1007,rank=rank,point = mInfo.point}
            end
            if rank <= 5 then
                local mModel = oPlayer:GetChangedModelInfo()
                local sName = oPlayer:GetName()
                local mTitle = oPlayer:GetTitleInfo()
                local sTitle
                if mTitle then
                    sTitle = mTitle.name
                else
                    sTitle = ""
                end
                local mNPCInfo = {}
                mNPCInfo["name"] = sName
                --mNPCInfo["title"] = sTitle
                mNPCInfo["model_info"] = mModel
                mNPCInfo["rank"] = rank
                self.m_mModelPlayer[pid] = mNPCInfo
            end
        else
            if rank <= 5 then
                local mNPCInfo = {}
                mNPCInfo["name"] = mInfo.name
                --mNPCInfo["title"] = mInfo.title
                mNPCInfo["model_info"] = mInfo.model
                mNPCInfo["rank"] = rank
                self.m_mModelPlayer[pid] = mNPCInfo
            end
        end
        ::continue::
    end

    local mLogData = {}
    mLogData.sort = extend.Table.serialize(mRewardPid)
    record.log_db("huodong", "biwu_sort",mLogData)
    self:CreateModelNPC()
end

function CHuodong:RemoveModelNPC()
    self:Dirty()
    local oTitleMgr = global.oTitleMgr
    for pid,title in pairs(self.m_mTitlePlayer) do
        oTitleMgr:RemoveOneTitle(pid,title)
    end
    self.m_mTitlePlayer = {}
    self.m_mModelPlayer = {}
    local lNpcIdxs = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc:Type() then
            if extend.Array.find(RANK_NPCTYPE,oNpc:Type()) then
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

function CHuodong:CreateModelNPC()
    if  not MODEL_OPEN then
        return
    end
    local index = 0
    local oScene = global.oSceneMgr:SelectDurableScene(101000)
    assert(oScene,"CreateModelNPC")
    for pid,mNPCInfo in pairs(self.m_mModelPlayer) do
        index = mNPCInfo.rank or 0
        if not RANK_NPCTYPE[index] then
            goto continue
        end
        local npctype = RANK_NPCTYPE[index]
        local npcobj  = self:CreateTempNpc(npctype)
        self:Npc_Enter_Scene(npcobj,oScene:GetSceneId())
        npcobj.m_iBWOwner = pid
        npcobj:SetChangeModelInfo(mNPCInfo.model_info)
        npcobj:SyncSceneInfo({model_info = mNPCInfo.model_info,name = mNPCInfo.name})
        ::continue::
    end
end

function CHuodong:SyncModelNPC(oPlayer,npcobj)
    local pid = oPlayer:GetPid()
    if not self.m_mModelPlayer[pid] then
        return
    end
    if not npcobj then
        return
    end
    if not npcobj.m_iBWOwner then
        return
    end
    if npcobj.m_iBWOwner ~= pid then
        return
    end
    local mModel = oPlayer:GetChangedModelInfo()
    local sName = oPlayer:GetName()
    local mTitle = oPlayer:GetTitleInfo()
    local sTitle
    if mTitle then
        sTitle = mTitle.name
    else
        sTitle = ""
    end
    local mNPCInfo = {}
    mNPCInfo["name"] = sName
    --mNPCInfo["title"] = sTitle
    mNPCInfo["model_info"] = mModel
    self:Dirty()
    self.m_mModelPlayer[pid] = mNPCInfo
    npcobj:SetChangeModelInfo(mModel)
    npcobj:SyncSceneInfo({model_info = mNPCInfo.model_info,name = mNPCInfo.name})
end

--对话--
function CHuodong:ValidJoin(oPlayer,npcobj)

    local pid = oPlayer:GetPid()
    if oPlayer:IsSingle() then
        local LIMIT_GRADE = res["daobiao"]["open"]["BIWU"]["p_level"]
        if oPlayer:GetGrade() < LIMIT_GRADE then
            self:SayText(pid,npcobj,self:GetTextData(1006))
            return false
        end
        local mInfo = self.m_mPoint[pid]
        if mInfo then
            if mInfo.fail >=LIMIT_FAIL then
                self:SayText(pid,npcobj,self:GetTextData(1008))
                return false
            end
        end
        if self.m_iGameState ~= GAME_START and self.m_iGameState ~= GAME_PRESTART then
            self:SayText(pid,npcobj,self:GetTextData(1021))
            return false
        end
    elseif oPlayer:IsTeamLeader() then
        local oWorldMgr = global.oWorldMgr
        local oTeam = oPlayer:HasTeam()
        local lGradeName = {}
        local lFailName  = {}
        if self.m_iGameState ~= GAME_START and self.m_iGameState ~= GAME_PRESTART  then
            self:TeamSay(oTeam,npcobj,self:GetTextData(1021))
            return false
        end
        for _, oMem in ipairs(oTeam:GetMember()) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            local LIMIT_GRADE = res["daobiao"]["open"]["BIWU"]["p_level"]
            if oTarget:GetGrade() < LIMIT_GRADE then
                table.insert(lGradeName,oMem:GetName())
            end
            local mInfo = self.m_mPoint[oMem.m_ID]
            if mInfo then
                if mInfo.fail >=LIMIT_FAIL then
                    table.insert(lFailName,oMem:GetName())
                end
            end
        end
        if #lGradeName >0 then
            local sText = string.gsub(self:GetTextData(1007),"$playlist",{["$playlist"]=table.concat(lGradeName,",")})
            self:TeamSay(oTeam,npcobj,sText)
            return false
        end
        if #lFailName >0 then
            local sText = string.gsub(self:GetTextData(1009),"$playlist",{["$playlist"]=table.concat(lFailName,",")})
            self:TeamSay(oTeam,npcobj,sText)
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
    local oScene = self:GetScene()
    local mPos = self:RandomScenePos(oScene, bFly)
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), mPos)
end

function CHuodong:do_look(oPlayer, npcobj)
    local pid = oPlayer:GetPid()
    local nid = npcobj.m_ID
    if extend.Array.find(GAME_NPCTYPE,npcobj:Type()) then
        local func = function (oPlayer,mData)
            self:Respond(oPlayer, nid, mData["answer"])
        end
        self:SayText(pid,npcobj,self:GetTextData(1020),func)
    elseif extend.Array.find(RANK_NPCTYPE,npcobj:Type()) then
        local func = function (oPlayer,mData)
            self:Respond(oPlayer, nid, mData["answer"])
        end
        local sText = self:GetTextData(1026)
        if npcobj.m_iBWOwner and npcobj.m_iBWOwner == pid and self.m_mModelPlayer[pid] then
            sText = sText .. "#Q改变造型"
        end
        self:SayText(pid,npcobj,sText,func)
    end
end

function CHuodong:Respond(oPlayer, nid, iAnswer)
    if iAnswer ~=1 then
        return
    end
    local oSceneMgr = global.oSceneMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        oNotifyMgr:Notify(pid,self:GetTextData(1013))
        return
    end
    if extend.Array.find(GAME_NPCTYPE,npcobj:Type()) then
        if oPlayer:IsSingle() then
            oSceneMgr:EnterDurableScene(oPlayer)
        elseif oPlayer:IsTeamLeader() then
            local oTeam = oPlayer:HasTeam() 
            oSceneMgr:TeamEnterDurableScene(oPlayer)
        end
    elseif extend.Array.find(RANK_NPCTYPE,npcobj:Type()) then
        self:SyncModelNPC(oPlayer,npcobj)
    end
end

function CHuodong:TeamSay(oTeam,npcobj,sText)
    for _, oMem in ipairs(oTeam:GetMember()) do
        npcobj:Say(oMem.m_ID,sText)
    end
end
--对话--

--协议--
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
    mNet.maxwin = mInfo.maxwin
    mNet.fail = mInfo.fail
    mNet.starttime =math.max(0,self.m_iStartTime - get_time())
    mNet.matchtime = math.max(0,self.m_iNextMatchTime - get_time())
    mNet.matchendtime = self.m_iStartTime + self:GetGameTime("StopMatchBattle")//1000
    oPlayer:Send("GS2CBWMyRank",mNet)
end

function CHuodong:GetAllRankInfo(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local pid = oPlayer:GetPid()
    local mNet = {}
    for rank ,mRankInfo in ipairs(self.m_lPointRank) do
        if rank>LIMIT_RANK then
            break
        end
        local target = mRankInfo.pid
        local mInfo = self.m_mPoint[target]
        local oTarget =  oWorldMgr:GetOnlinePlayerByPid(target)
        local mData = {}
        mData.rank = mInfo.rank
        if oTarget then
            mData.name = oTarget:GetName()
            mData.grade = oTarget:GetGrade()
            mData.school = oTarget:GetSchool()
        else
            mData.name = mInfo.name
            mData.grade = mInfo.grade
            mData.school = mInfo.school
        end

        mData.point = mInfo.point
        mData.maxwin = mInfo.maxwin
        mData.pid = target
        
        if oTarget and oTarget.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.IN_WAR then
            mData.war  = 1
        end
        table.insert(mNet,mData)
        ::continue::
    end
    local mInfo = self.m_mPoint[pid]
    oPlayer:Send("GS2CBWRank",{ranklist = mNet,maketeam = mInfo.maketeam})
end
--协议--

function CHuodong:SetMakeTeam(oPlayer,iOp)
    local pid = oPlayer:GetPid()
    local mInfo = self.m_mPoint[pid]
    if iOp == 1 then
        mInfo.maketeam = 1
    else
        mInfo.maketeam = 0
    end
    oPlayer:Send("GS2CBWMakeTeam" , {op = mInfo.maketeam})
end

function CHuodong:PushBiwuRank()
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
    global.oRankMgr:PushDataToRank("biwu",mNet)
end

function CHuodong:OpenHDSchedule(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    if oPlayer:GetNowScene() == self:GetScene() then
        self:Notify(iPid, 1032)
        return true
    end
    super(CHuodong).OpenHDSchedule(self, iPid)
end


function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 开始进场\nhuodongop biwu 101",
        "102 活动开始\nhuodongop biwu 102",
        "103 活动结束(104+105)\nhuodongop biwu 103",
        "104 活动结束(不清场景)\nhuodongop biwu 104",
        "105 活动结束(清场景)\nhuodongop biwu 105",
        "106 设置积分\nhuodongop biwu 106 {point = 10}",
        "107 清除最大连胜次数\nhuodongop biwu 107",
        "108 设置最大连胜次数\nhuodongop biwu 108 {maxwin = 3}",
        "109 清除失败次数\nhuodongop biwu 109",
        "110 设置失败次数\nhuodongop biwu 110 {fail = 2}",
        "111 清除保护时间\nhuodongop biwu 111",
        "112 弹确认组队UI\nhuodongop biwu 112",
        "113 立刻组队\nhuodongop biwu 113",
        "114 立刻匹配战斗\nhuodongop biwu 114",
        "201 控制机器人参加比武\nhuodongop biwu 201",
        "202 场上战斗立刻结束\nhuodongop biwu 202",
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
        local point  = mArgs.point
        if not point then
            oNotifyMgr:Notify(pid,"参数错误")
            return
        end
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"游戏场景中执行")
            return
        end
        mInfo.point = point
        self:RefreshMyPoint(oPlayer)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 107 then
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"游戏场景中执行")
            return
        end
        mInfo.maxwin   = 0 
        self:RefreshMyPoint(oPlayer)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 108 then
        local maxwin = mArgs.maxwin
        if not maxwin then
            oNotifyMgr:Notify(pid,"参数错误")
            return
        end
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"游戏场景中执行")
            return
        end
        mInfo.maxwin   = maxwin 
        self:RefreshMyPoint(oPlayer)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 109 then 
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"游戏场景中执行")
            return
        end
        mInfo.fail   = 0 
        self:RefreshMyPoint(oPlayer)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 110 then
        local fail = mArgs.fail
        if not fail then
            oNotifyMgr:Notify(pid,"参数错误")
            return
        end
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"游戏场景中执行")
            return
        end
        mInfo.fail   = fail 
        self:RefreshMyPoint(oPlayer)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 111 then
        oPlayer.m_BWProtectTime = nil 
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 112 then
        self:PushMakeTeamUI()
    elseif iFlag == 113 then
        self:MakeTeam()
    elseif iFlag == 114 then
        self:MatchBattle()
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
            if string.find(sAccount,"Robotbiwu")  or all == 1 then
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
            -- oTeamMgr:CreateTeam(target)
            -- local oTeam = oTarget:HasTeam()
            -- oTeam.m_TestSize = 3
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
        self:Reward(pid,1007)
    end
end

function _EscapeCallBack(oPlayer)
    local oHD = global.oHuodongMgr:GetHuodong("biwu")
    if not oHD then return end
    oHD:Escape(oPlayer)
end
