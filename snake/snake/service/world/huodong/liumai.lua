local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local geometry = require "base.geometry"
local interactive = require "base.interactive"

local huodongbase = import(service_path("huodong.huodongbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

local GAME_NONE = 0 --活动之前
local GAME_POINT  = 1--积分赛
local GAME_TAOTAI = 2--淘汰赛
local GAME_END = 3--活动结束
local GAME_ENTER = 1--进场
local GAME_NOENTER = 0--不能进场

local WAR_TYPE = {"POINTWAR","TTWAR"}

local TT_NONT = 0 -- 淘汰赛没开始
local TT_SIXTEEN = 16 --淘汰赛十六强阶段
local TT_EIGHT = 8 --淘汰赛八强阶段
local TT_FOUR = 4 --淘汰赛四强阶段
local TT_TWO = 2 --淘汰赛二强阶段
local TT_ONE = 1 --淘汰赛结束阶段

local LM_TITLE = 926
local LIMIT_BOUT = 20
local LIMIT_FAIL = 3

local LIMIT_TEAM_COUNT = 3

local POINT_PROTECT = 60

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "六脉会武"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1023
    o.m_iGameState = GAME_NONE
    o.m_iEnterScene = GAME_NOENTER
    o.m_iSceneID = nil

    o.m_mPoint = {}
    o.m_lPointRank = {}
    o.m_mTTSixTeen = {}
    o.m_mTTEight = {}
    o.m_mTTFour = {}
    o.m_mTTTwo = {}
    o.m_iTaoTaiState = TT_NONT
    o.m_mTTBattle = {}
    o.m_iTTStartTime = 0
    o.m_lTTOrder = {}
    o.m_mThreeBattle={}

    o.m_mShouXi = {}
    o.m_mShouXimate = {}
    o.m_iStartTime = 0

    o.m_lNoMatch = {}
    o.m_iNextMatchTime = 0

    o.m_bSendRP = false
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

function CHuodong:OnLogin(oPlayer,reenter)
    local pid = oPlayer:GetPid()
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if reenter then
        if self.m_iSceneID and self.m_iSceneID == oNowScene:GetSceneId() then
            self:RefreshMyPoint(oPlayer)
            self:RefreshOneGameState(oPlayer)
            if self.m_iGameState == GAME_TAOTAI then
                oPlayer:Send("GS2CLMBatte",self:PackTTBattle())
            end
        end 
        local oTitleMgr = global.oTitleMgr
        local iSchool = oPlayer:GetSchool()
        local iTitle = gamedefines.SCHOOL_TITLE[iSchool]
        if oPlayer.m_oTitleCtrl:GetTitleByTid(iTitle) and (#self.m_mShouXi ==0 or self.m_mShouXi[iSchool] ~= pid) then
            oTitleMgr:RemoveOneTitle(pid,iTitle)
        end
        if oPlayer.m_oTitleCtrl:GetTitleByTid(LM_TITLE) then
            local bRemove = true
            for target,mInfo in pairs(self.m_mShouXimate) do
                if mInfo.mate and extend.Array.find(mInfo.mate,pid) then
                    bRemove = false
                end
            end
            if bRemove then
                oTitleMgr:RemoveOneTitle(pid,LM_TITLE)
            end
        end
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.shouxi = table_to_db_key(self.m_mShouXi)
    mData.shouximate = table_to_db_key(self.m_mShouXimate)
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_mShouXi = table_to_int_key(mData.shouxi or {})
    self.m_mShouXimate = table_to_int_key(mData.shouximate or {})
    self:SetSXNPCModel()
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:NewHour(mNow)
    if not self:IsSysOpen() then
        return
    end
    mNow = mNow or get_timetbl()
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
    local LIMIT_GRADE = res["daobiao"]["open"]["LIUMAI"]["p_level"]
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    if LIMIT_GRADE>iServerGrade then
        return false
    end
    return true
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:IsOpenDay(iTime)   --限时活动接口
    return true
end

function CHuodong:IsOpenDay(iTime)   --限时活动接口
    local mOpenDay = self:GetOpenDay()
    if mOpenDay[get_weekday()] == 1 then
        return true
    end
    return false
end

function CHuodong:GetOpenTime()
    local mOpenTime = res["daobiao"]["huodong"]["liumai"]["time_config"]["OPEN_TIME"]
    return mOpenTime
end

function CHuodong:GetOpenDay()
    local mOpenDay = res["daobiao"]["huodong"]["liumai"]["time_config"]["OPEN_DAY"]
    return mOpenDay
end

function CHuodong:GetStartTime()
    local mOpenTime = self:GetOpenTime()
    return string.format("%d:%d",mOpenTime[1],mOpenTime[2])
end

function CHuodong:GetGameTime(flag)
    return res["daobiao"]["huodong"]["liumai"]["time_config"]["GAME_TIME"][flag]
end



function CHuodong:Announce(sMsg,iHorse)
    local oChatMgr = global.oChatMgr
    iHorse = iHorse or 0
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,iHorse)
end

function CHuodong:PreGameStart()
    record.info(string.format("%s PreGameStart",self.m_sName))
    self:DelTimeCb("PreGameStart")
    self:CreateScene()
    self:CreateNPC()
    self:RemoveShouXi()
    self.m_iGameState = GAME_NONE
    self.m_iEnterScene = GAME_ENTER
    self.m_mPoint = {}
    self.m_lPointRank = {}
    self.m_mTTBattle = {}
    self.m_iTaoTaiState = TT_NONT
    self.m_iTTStartTime = 0
    self.m_lTTOrder = {}
    self.m_mThreeBattle = {}
    self.m_iStartTime = get_time() + math.floor(self:GetGameTime("GameStart1")/1000)
    self:AddTimeCb("GameStart1",self:GetGameTime("GameStart1"),function ()
        self:GameStart1()
    end)
    self:AddTimeCb("CycleReward",self:GetGameTime("CycleReward"),function ()
        self:CycleReward()
    end)
    local mChuanwen = res["daobiao"]["chuanwen"][1035]
    self:Announce(mChuanwen.content,mChuanwen.horse_race)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
end

function CHuodong:CreateScene()
    local oSceneMgr = global.oSceneMgr
    local mRes = res["daobiao"]["huodong"]["liumai"]["scene"]
    for iIndex , mInfo in pairs(mRes) do
        local mData ={
        map_id = mInfo.map_id,
        url = {"huodong", "liumai", "scene", iIndex},
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

function CHuodong:GetScene()
    local oSceneMgr = global.oSceneMgr
    local oScene  = oSceneMgr:GetScene(self.m_iSceneID)
    return oScene
end

function CHuodong:CreateNPC()
    local oScene = self:GetScene()
    local npcobj  = self:CreateTempNpc(1001)
    assert(npcobj,"CreateNPC")
    self:Npc_Enter_Scene(npcobj,oScene:GetSceneId())
end

function CHuodong:GameStart1()
    self:DelTimeCb("GameStart1")
    record.info(string.format("%s GameStart1",self.m_sName))
    self.m_iGameState = GAME_POINT
    self:AddTimeCb("CloseEnterScene",self:GetGameTime("CloseEnterScene"),function ()
        self:CloseEnterScene()
    end)
    self:AddTimeCb("GameStart2",self:GetGameTime("GameStart2"),function ()
        self:GameStart2()
    end)
    self.m_iNextMatchTime = get_time() + math.floor(self:GetGameTime("MatchPoint")/1000)
    self:AddTimeCb("PointAnnounce",self:GetGameTime("PointAnnounce"),function ()
        self:PointAnnounce()
    end)
    self:RefreshAllGameState()
    self:RefreshAllPoint()
    self:MatchPoint()
end

function CHuodong:PointAnnounce()
    self:DelTimeCb("PointAnnounce")
    local mChuanwen = res["daobiao"]["chuanwen"][1037]
    self:Announce(mChuanwen.content,mChuanwen.horse_race)
end

function CHuodong:CloseEnterScene()
    record.info(string.format("%s CloseEnterScene",self.m_sName))
    self:DelTimeCb("CloseEnterScene")
    self.m_iEnterScene = GAME_NOENTER
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

------淘汰赛--------
function CHuodong:GameStart2()
    record.info(string.format("%s GameStart2",self.m_sName))
    self:DelTimeCb("MatchPoint")
    self:DelTimeCb("EndPointWar")
    self:DelTimeCb("GameStart2")
    self.m_iGameState = GAME_TAOTAI
    self:AddTimeCb("EndPointWar",self:GetGameTime("EndPointWar"),function ()
        self:EndPointWar()
    end)
    self:TaoTaiStart()
    self:RefreshAllGameState()
end

function CHuodong:EndPointWar()
    self:DelTimeCb("EndPointWar")
    local oWarMgr = global.oWarMgr
    local oScene = self:GetScene()
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        local iWarStatue = oPlayer.m_oActiveCtrl:GetWarStatus()
        if iWarStatue == gamedefines.WAR_STATUS.NO_WAR then
            goto continue
        end
        local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
        if iWarStatue == gamedefines.WAR_STATUS.IN_OBSERVER then
            if oPlayer:IsSingle() then
                oWarMgr:LeaveWar(oPlayer,true)
            elseif oPlayer:IsTeamLeader() then
                oWarMgr:TeamLeaveObserverWar(oPlayer,true)
            end
        elseif iWarStatue == gamedefines.WAR_STATUS.IN_WAR and not oWar.m_ForceRelease then
            oWar:ForceWarEnd()
            oWar.m_ForceRelease = true
        end
        ::continue::
    end
end

function CHuodong:TaoTaiStart()
    self.m_bSendRP = false
    local oWorldMgr = global.oWorldMgr
    local mSchoolPoint = {}
    for pid, mInfo in pairs(self.m_mPoint) do
        local iSchool = mInfo.school
        if not mSchoolPoint[iSchool] then
            mSchoolPoint[iSchool] = {}
        end
        table.insert(mSchoolPoint[iSchool],{pid = pid,point = mInfo.point})
    end
    for iSchool,lSubInfo in pairs(mSchoolPoint) do
        table.sort(lSubInfo,function (mInfo1,mInfo2)
            if mInfo1.point>mInfo2.point then
                return true
            else
                return false
            end
        end)
    end

    local lSixTeen  = {}
    for iSchool,lSubInfo in pairs(mSchoolPoint) do
        local iSchoolCnt = 0
        for rank ,mInfo in ipairs(lSubInfo) do
            local pid = mInfo.pid 
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then
                goto continue1
            end
            if not oPlayer:IsTeamLeader() then
                goto continue1
            end
            local oTeam = oPlayer:HasTeam()
            if oTeam:MemberSize() ~= 3 then
                goto continue1
            end
            if #lSixTeen >= 16 then
                break
            end
            table.insert(lSixTeen,pid)
            iSchoolCnt = iSchoolCnt +1
            if iSchoolCnt>=2 then
                goto continue2
            end
            ::continue1::
        end
        if #lSixTeen >= 16 then
            break
        end
        ::continue2::
    end
    for rank,mInfo in pairs(self.m_lPointRank) do
        local pid = mInfo.pid
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue3
        end
        if not oPlayer:IsTeamLeader() then 
            goto continue3 
        end
        if extend.Array.find(lSixTeen,pid) then
            goto continue3
        end
        local oTeam = oPlayer:HasTeam()
        if oTeam:MemberSize() ~= 3 then
            goto continue3
        end
        if #lSixTeen >= 16 then
            break
        end
        table.insert(lSixTeen,pid)
        ::continue3::
    end
    self:MakeTTBattle(lSixTeen,{})
end

function CHuodong:MakeTTBattle(lPlayer,lFail1)
    local iCount = #lPlayer
    assert(iCount<=16 and iCount>=0,"MakeTTBattle")
    local lBattle
    local lFail2
    if iCount == 16 then
        self:PreStart(lPlayer,lPlayer,TT_SIXTEEN)
    elseif iCount<16 and iCount>=8 then
        lBattle,lFail2 = self:GetTTBattleByCnt(lPlayer,8)
        self:TTInsertFailOrder(lFail1,lFail2)
        self:PreStart(lBattle,lFail1,TT_EIGHT)
    elseif iCount<8 and iCount>=4 then
        lBattle,lFail2 = self:GetTTBattleByCnt(lPlayer,4)
        self:TTInsertFailOrder(lFail1,lFail2)
        self:PreStart(lBattle,lFail1,TT_FOUR)
    elseif iCount<4 and iCount >= 2 then
        lBattle,lFail2 = self:GetTTBattleByCnt(lPlayer,2)
        self:TTInsertFailOrder(lFail1,lFail2)
        self:PreStart(lBattle,lFail1,TT_TWO)
    elseif iCount == 1 then
        self:TTInsertFailOrder(lFail1,{})
        if not extend.Array.find(self.m_lTTOrder,lPlayer[1]) then
            table.insert(self.m_lTTOrder,lPlayer[1])
        end
        self.m_iTaoTaiState = TT_ONE
        self:SendTaoTaiRP()
        self:GameOver1()
    elseif iCount == 0 then
        self:TTInsertFailOrder(lFail1,{})
        self:GameOver1()
    end   
    self.m_bSendRP = true
end

function CHuodong:TTInsertFailOrder(lFail1,lFail2)
    local lFail = {}
    for _,pid in ipairs(lFail1) do
        local mInfo = self.m_mPoint[pid]
        table.insert(lFail,{pid = pid,point = mInfo.point})
    end
    for _,pid in ipairs(lFail2) do
        local mInfo = self.m_mPoint[pid]
        table.insert(lFail,{pid = pid,point = mInfo.point})
    end
    table.sort(lFail,function (mInfo1,mInfo2)
        if mInfo1.point>mInfo2.point then
            return true
        else
            return false
        end
    end)
    for index = #lFail , 1,-1 do
        local pid = lFail[index].pid
        if not extend.Array.find(self.m_lTTOrder,pid) then
            table.insert(self.m_lTTOrder,pid)
        end
    end
end

function CHuodong:GetTTBattleByCnt(lPlayer,iCount)
    local lData = {}
    local lFail = {}
    for _,pid in pairs(lPlayer) do
        local mInfo  = self.m_mPoint[pid]
        table.insert(lData,{pid = pid,point = mInfo.point})
    end
    table.sort(lData,function (mInfo1,mInfo2)
        if mInfo1.point>mInfo2.point then
            return true
        else
            return false
        end
    end)
    local lResult = {}
    for i=1 ,iCount do
        table.insert(lResult,lData[i].pid)
    end
    for i=iCount+1 ,#lData do
        table.insert(lFail,lData[i].pid)
    end
    return lResult,lFail
end

function CHuodong:GetTTBattleBySchool(lPlayer)
    local mBattle = {}
    local iCount = #lPlayer
    assert(iCount,string.format("GetTTBattleBySchool %s",lPlayer))
    assert(iCount%2 ~= 1,string.format("GetTTBattleBySchool %s",lPlayer))
    local lBakPlayer = extend.Table.deep_clone(lPlayer)
    for index ,pid in ipairs(lPlayer) do
        local mInfo = self.m_mPoint[pid]
        local iSchool = mInfo.school 
        local iBattle1 = pid
        local iBattle2
        if not extend.Array.find(lBakPlayer,iBattle1) then
            goto continue1
        end
        extend.Array.remove(lBakPlayer,iBattle1)
        for _,iBattle in ipairs(lBakPlayer) do
            local mBakInfo = self.m_mPoint[iBattle] 
            local iBakSchool = mBakInfo.school
            if iBattle == iBattle1 then
                assert(nil,string.format("GetTTBattleBySchool %s",lPlayer))
            end
            if iSchool == iBakSchool then
                goto continue2
            end
            iBattle2 = iBattle
            break
            ::continue2::
        end
        if not iBattle2 and #lBakPlayer then
            iBattle2 = extend.Random.random_choice(lBakPlayer)
        end
        assert(iBattle2,string.format("GetTTBattleBySchool %s",lPlayer))
        
        extend.Array.remove(lBakPlayer,iBattle2)
        table.insert(mBattle,{iBattle1,iBattle2})
        ::continue1::
    end
    return mBattle
end

function CHuodong:PreStart(lBattle,lFail,TT_STATE)
    local oWorldMgr = global.oWorldMgr
    record.info(string.format("%s tt_pretart step %s",self.m_sName,TT_STATE))
    record.info(string.format("%s tt_order %s",self.m_sName,extend.Table.serialize(self.m_lTTOrder)))
    self.m_iTTStartTime = get_time() + math.floor(self:GetGameTime("TTStart")/1000)
    self.m_iTaoTaiState = TT_STATE
    self.m_mTTBattle = self:GetTTBattleBySchool(lBattle)
    record.info(string.format("%s tt_battle %s",self.m_sName,extend.Table.serialize(self.m_mTTBattle)))
    self:AddTimeCb("TTStart",self:GetGameTime("TTStart"),function ()
        self:TTStart()
    end)
    if self.m_iTaoTaiState == TT_TWO then
        --第3名处理
        if #lFail ==2 then
            local iCount = #self.m_lTTOrder
            if  extend.Array.find(lFail, self.m_lTTOrder[iCount]) and extend.Array.find(lFail, self.m_lTTOrder[iCount-1]) then
                table.insert(self.m_mTTBattle,{lFail[1],lFail[2]})
                self.m_mThreeBattle = {lFail[1],lFail[2]}
                record.info(string.format("%s tt_battle add 3rd %s",self.m_sName,extend.Table.serialize(self.m_mTTBattle)))
            end
        end
    end
    local oScene = self:GetScene()
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CLMBatte",self:PackTTBattle(true))
        end
    end
    if self.m_bSendRP then
        self:SendTaoTaiRP()
    end
end

function CHuodong:TTStart()
    self:DelTimeCb("TTStart")
    record.info(string.format("%s tt_start %s",self.m_sName,self.m_iTaoTaiState))
    local oWorldMgr = global.oWorldMgr
    for _,mSubBattle in ipairs(self.m_mTTBattle) do
        local iBattle1 = mSubBattle[1]
        local iBattle2 = mSubBattle[2]
        local oBattle1 = oWorldMgr:GetOnlinePlayerByPid(iBattle1)
        local oBattle2 = oWorldMgr:GetOnlinePlayerByPid(iBattle2)
        if self:ValidTaoTai(oBattle1) and not self:ValidTaoTai(oBattle2) then
            mSubBattle[3] = iBattle1
        elseif not self:ValidTaoTai(oBattle1) and self:ValidTaoTai(oBattle2) then
            mSubBattle[3] = iBattle2
        elseif self:ValidTaoTai(oBattle1) and self:ValidTaoTai(oBattle2) then
            local oTeam1 = oBattle1:HasTeam()
            local oTeam2 = oBattle2:HasTeam()
            self:StartFight(oTeam1,oTeam2)
        elseif not self:ValidTaoTai(oBattle1) and not self:ValidTaoTai(oBattle2) then
            mSubBattle[3] = 0
        end
    end
    self:TriggerTTNextStep()
end

function CHuodong:ValidTaoTai(oPlayer)
    local oNowScene  = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:GetSceneId() ~= self.m_iSceneID then
        return false
    end
    if oPlayer and oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        if oTeam:MemberSize() == 3 then
            return true
        end
    end
    return false
end


function CHuodong:TTFightWarEnd(mBattleLeader,iWinSide)
    local oTeamMgr = global.oTeamMgr
    for _,mBattle in pairs(self.m_mTTBattle) do
        if iWinSide == 0 then
            mBattle[3] = 0
            record.info(string.format("%s tt_war_exception %s %s",self.m_sName,mBattleLeader[1][2],mBattleLeader[2][2]))
        else
            if mBattle[1] == mBattleLeader[1][2]  and mBattle[2] == mBattleLeader[2][2] then
                local iTeamID = mBattleLeader[iWinSide][1]
                local oTeam = oTeamMgr:GetTeam(iTeamID)
                if oTeam then
                    mBattle[3] = oTeam:Leader()
                else
                    mBattle[3] = 0
                end
            end
        end
    end
    self:TriggerTTNextStep()
end

function CHuodong:TriggerTTNextStep()
    local bFinish = true
    local lPlayer  = {}
    local lFail = {}
    local iThree
    for _,mBattle in pairs(self.m_mTTBattle) do 
        if not mBattle[3] then
            bFinish = false
        end
        if mBattle[3]~= 0 then
            if not extend.Array.find(self.m_lTTOrder,mBattle[3]) then
                table.insert(lPlayer,mBattle[3])
            end
            if mBattle[3] == mBattle[1] then
                if not extend.Array.find(self.m_lTTOrder,mBattle[2]) then
                    table.insert(lFail,mBattle[2])
                else
                    iThree = mBattle[1]
                end
            elseif mBattle[3] == mBattle[2] then
                if not extend.Array.find(self.m_lTTOrder,mBattle[1]) then
                    table.insert(lFail,mBattle[1])
                else
                    iThree = mBattle[2]
                end
            end
        else
            if not extend.Array.find(self.m_lTTOrder,mBattle[1]) then
                table.insert(lFail,mBattle[1])
            end
            if not extend.Array.find(self.m_lTTOrder,mBattle[2]) then
                table.insert(lFail,mBattle[2])
            end
        end
    end

    if iThree and self.m_iTaoTaiState == TT_TWO and extend.Array.find(self.m_mThreeBattle,iThree) then
         --第三名打完处理
        local pos1 = extend.Array.find(self.m_lTTOrder, self.m_mThreeBattle[1])
        local pos2 = extend.Array.find(self.m_lTTOrder, self.m_mThreeBattle[2])
        local winpos = extend.Array.find(self.m_lTTOrder, iThree)
        local failpos
        if winpos == pos2  then
            failpos = pos1
        else
            failpos = pos2
        end
        if winpos<failpos then
            local temp = self.m_lTTOrder[winpos]
            self.m_lTTOrder[winpos] = self.m_lTTOrder[failpos]
            self.m_lTTOrder[failpos] = temp
            record.info(string.format("%s tt_3rd finish %s %s",self.m_sName,self.m_lTTOrder[failpos],self.m_lTTOrder[winpos]))
        else
            record.info(string.format("%s tt_3rd finish %s %s",self.m_sName,self.m_lTTOrder[winpos],self.m_lTTOrder[failpos]))
        end
    end
    if bFinish  then
        self:MakeTTBattle(lPlayer,lFail)
    end
end

function CHuodong:PackTTBattle(bOpen)
    local oWorldMgr = global.oWorldMgr
    local mNet = {}
    mNet.step = self.m_iTaoTaiState
    mNet.time = math.max(1,self.m_iTTStartTime-get_time())
    local lBattle = {}
    for _,mBattle in ipairs(self.m_mTTBattle) do
        local mSubNet = {}
        local mInfo1 = self.m_mPoint[mBattle[1]]
        local mInfo2 = self.m_mPoint[mBattle[2]]
        local oFighter1 = oWorldMgr:GetOnlinePlayerByPid(mBattle[1])
        local oFighter2 = oWorldMgr:GetOnlinePlayerByPid(mBattle[2])
        if not oFighter1 then
            mSubNet.fighter1 = {name = mInfo1.name,pid = mBattle[1] ,icon = mInfo1.icon ,grade = mInfo1.grade,model_info = mInfo1.model}
        else
            mSubNet.fighter1 = {name = oFighter1:GetName(),pid = mBattle[1] ,icon = oFighter1:GetIcon() ,grade = oFighter1:GetGrade(),model_info = oFighter1:GetChangedModelInfo()}
        end
        if not oFighter2 then
            mSubNet.fighter2 = {name = mInfo2.name,pid = mBattle[2] ,icon = mInfo2.icon ,grade = mInfo2.grade,model_info = mInfo2.model}
        else
            mSubNet.fighter2 = {name = oFighter2:GetName(),pid = mBattle[2] ,icon = oFighter2:GetIcon() ,grade = oFighter2:GetGrade(),model_info = oFighter2:GetChangedModelInfo()}
        end
        mSubNet.win = mBattle[3] or 1
        mSubNet.jijun = 0
        if extend.Array.find(self.m_mThreeBattle,mBattle[1]) and extend.Array.find(self.m_mThreeBattle,mBattle[2]) then
            mSubNet.jijun = 1
        end
        table.insert(lBattle,mSubNet)
    end
    mNet.battlelist = lBattle
    if bOpen then
        mNet.open = 1
    else
        mNet.open = 0
    end
    return mNet
end

function CHuodong:RewardShouXi()
    local oWorldMgr = global.oWorldMgr
    local oTitleMgr = global.oTitleMgr
    local mShouxiMate = {}
    self:Dirty()
    local mShouXi = {}
    local iCount = #self.m_lTTOrder
    for _,pid in pairs(self.m_lTTOrder) do
        local mInfo  = self.m_mPoint[pid]
        if mInfo then
            mShouXi[mInfo.school] = pid
        end
    end

    for _,mRank in ipairs(self.m_lPointRank) do
        local pid = mRank.pid
        local mInfo = self.m_mPoint[pid]
        local iSchool = mInfo.school
        if mShouXi[iSchool] then
            goto continue
        end
         mShouXi[iSchool] = pid
        ::continue::
    end
    self.m_mShouXi = mShouXi
    local mNet = {}
    for iSchool,pid in pairs(self.m_mShouXi) do
        local mSubNet = {}
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local mInfo = self.m_mPoint[pid]
        mShouxiMate[pid] = {}
        mShouxiMate[pid]["model"] = {}
        mShouxiMate[pid]["mate"] = {}
        if oPlayer then
            mShouxiMate[pid]["model"] = oPlayer:GetChangedModelInfo()
            mShouxiMate[pid]["name"] = oPlayer:GetName()
            local mTitle = oPlayer:GetTitleInfo()
            if mTitle then
                mShouxiMate[pid]["title"] = mTitle.name
            else
                mShouxiMate[pid]["title"] = ""
            end
            mSubNet.pid = pid
            mSubNet.grade = oPlayer:GetGrade()
            mSubNet.name = oPlayer:GetName()
            mSubNet.school = iSchool
            mSubNet.point = mInfo.point
            if pid == self.m_lTTOrder[iCount] then
                mSubNet.first = 1
            end
        else
            mShouxiMate[pid]["model"] = mInfo.model
            mShouxiMate[pid]["name"] = mInfo.name
            mShouxiMate[pid]["title"] = mInfo.title

            mSubNet.pid = pid
            mSubNet.grade = mInfo.grade
            mSubNet.name = mInfo.name
            mSubNet.school = iSchool
            mSubNet.point = mInfo.point
            if pid == self.m_lTTOrder[iCount] then
                mSubNet.first = 1
            end
        end
        local iTitle = gamedefines.SCHOOL_TITLE[iSchool]
        if iTitle then
            oTitleMgr:AddTitle(pid,iTitle)
        end
        table.insert(mNet,mSubNet)
        if oPlayer and oPlayer:IsTeamLeader() then
            local oTeam = oPlayer:HasTeam()
            for _,oMem in pairs(oTeam:GetMember()) do
                if oMem.m_ID ~= pid then
                    oTitleMgr:AddTitle(oMem.m_ID,LM_TITLE)
                    table.insert(mShouxiMate[pid]["mate"],oMem.m_ID)
                end
            end
        end
    end
    self:GS2CShouXi(mNet)
    self.m_mShouXimate = mShouxiMate
    self:SetSXNPCModel()
end

function CHuodong:SetSXNPCModel(iTarget)
    local oWorldMgr = global.oWorldMgr
    local oNpcMgr = global.oNpcMgr
    for iSchool,pid in pairs(self.m_mShouXi) do
        if iTarget then
            if pid ~= iTarget then
                goto continue
            end
        end
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

        local npctype = gamedefines.SCHOOL_NPC[iSchool]

        local mModel = self.m_mShouXimate[pid]["model"]
        local sName = self.m_mShouXimate[pid]["name"]
        local sTitle = self.m_mShouXimate[pid]["title"]
        if oPlayer then
            mModel = oPlayer:GetChangedModelInfo()
            sName = oPlayer:GetName()
            local mTitle = oPlayer:GetTitleInfo()
            if mTitle then
                sTitle = mTitle.name
            else
                sTitle = ""
            end
            self:Dirty()
            self.m_mShouXimate[pid]["model"] = mModel
            self.m_mShouXimate[pid]["name"] = sName
            self.m_mShouXimate[pid]["title"] = sTitle
        end
        if not npctype then
            goto continue
        end
        local npcobj = oNpcMgr:GetGlobalNpc(npctype)
        if not npcobj then
            goto continue
        end

        local mNPCInfo = {
            name = sName,
            model_info = mModel,
            --title = sTitle
        }
        npcobj:SetChangeModelInfo(mModel)
        npcobj:SyncSceneInfo(mNPCInfo)
        ::continue::
    end
end

function CHuodong:RemoveShouXi()
    self:Dirty()
    local oTitleMgr = global.oTitleMgr
    for iShouxi,mData in pairs(self.m_mShouXimate) do
        local lMate = mData["mate"] or {}
        for _,mate in pairs(lMate) do
            oTitleMgr:RemoveOneTitle(mate,LM_TITLE)
        end
    end
    for iSchool,pid in pairs(self.m_mShouXi) do 
        local iTitle = gamedefines.SCHOOL_TITLE[iSchool]
        if iTitle then
            oTitleMgr:RemoveOneTitle(pid,iTitle)
        end
    end
    local oNpcMgr = global.oNpcMgr
    for iSchool,pid in pairs(self.m_mShouXi) do
        local npctype = gamedefines.SCHOOL_NPC[iSchool]
        if not npctype then
            goto continue
        end
        local npcobj = oNpcMgr:GetGlobalNpc(npctype)
        if not npcobj then
            goto continue
        end
        npcobj:ClearChangeModelInfo()
        local mNPCInfo = {
            name = npcobj:Name(),
            model_info = npcobj:ModelInfo(),
            --title = npcobj:GetTitle(),
        }
        npcobj:SyncSceneInfo(mNPCInfo)
        ::continue::
    end
    self.m_mShouXimate = {}
    self.m_mShouXi = {}
end

function CHuodong:GS2CShouXi(mNet)
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CLMShouXi",{sxlist = mNet})
        end
    end
end

------淘汰赛--------

function CHuodong:GameOver1()
    record.info(string.format("%s GameOver1",self.m_sName))
    self.m_iTaoTaiState = TT_NONT
    self.m_iTTStartTime = 0
    self.m_iGameState =GAME_END
    self:RefreshAllGameState()
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    self:DelTimeCb("GameOver2")
    self:AddTimeCb("GameOver2",self:GetGameTime("GameOver2"),function ()
        self:GameOver2()
    end)
    if #self.m_lTTOrder >0 then
        self:RewardShouXi()
        local pid = self.m_lTTOrder[#self.m_lTTOrder]
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local mChuanwen = res["daobiao"]["chuanwen"][1036]
        local sContent = mChuanwen.content
        local mInfo = self.m_mPoint[pid]
        local sName2 =""
        if oPlayer and oPlayer:IsTeamLeader() then
            local lName = {}
            local oTeam = oPlayer:HasTeam()
            for _,oMem in pairs(oTeam:GetMember()) do
                if oMem.m_ID ~= pid then
                    table.insert(lName,oMem:GetName())
                end
            end
            if #lName > 0 then
                sName2 = table.concat(lName,",")
            end
        end
        sContent = global.oToolMgr:FormatColorString(sContent,{role = {mInfo.name,sName2}})
        self:Announce(sContent,mChuanwen.horse_race)
    end
end

function CHuodong:GameOver2()
    record.info(string.format("%s GameOver2",self.m_sName))
    self.m_iGameState = GAME_END
    self.m_iEnterScene = GAME_NOENTER
    self.m_mPoint = {}
    self.m_lPointRank = {}
    self.m_lTTOrder = {}
    self.m_mTTBattle  = {}
    self:ClearTimer()
    self:CleanPlayer()
    global.oRedPacketMgr:DelTempRPByFlag(self.m_sName)
    self:RemoveNPC()
    self:RemoveScene()
end

function CHuodong:ClearTimer()
    self:DelTimeCb("PreGameStart")
    self:DelTimeCb("GameStart2")
    self:DelTimeCb("CloseEnterScene")
    self:DelTimeCb("GameOver2")
    self:DelTimeCb("CycleReward")
    self:DelTimeCb("MatchPoint")
    self:DelTimeCb("TTStart")
    self:DelTimeCb("PointAnnounce")
end

function CHuodong:CleanPlayer()
    if not self.m_iSceneID then 
        return
    end
    local oSceneMgr = global.oSceneMgr
    local iMapId = 101000
    local oDesScene =  oSceneMgr:SelectDurableScene(iMapId)
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    local mPlayer = extend.Table.deep_clone(oScene.m_mPlayers)
    for pid , _ in pairs(mPlayer) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        local mPos = self:RandomScenePos(oDesScene)
        global.oSceneMgr:DoTransfer(oPlayer, oDesScene:GetSceneId(), mPos)
        ::continue::
    end
end

function CHuodong:RemoveNPC()
    local npctype = 1001
    local lNpcIdxs = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc.Type then
            if oNpc:Type() == npctype then
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

function CHuodong:ValidEnterTeam(oPlayer,oLeader,iApply)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local iLeader = oLeader:GetPid()
    local LIMIT_GRADE = res["daobiao"]["open"]["LIUMAI"]["p_level"]
    -- if oPlayer:GetGrade() < LIMIT_GRADE then
    --     if iApply ==1 then
    --         oNotifyMgr:Notify(pid,self:GetTextData(1015))
    --     elseif iApply == 2 then
    --         oNotifyMgr:Notify(iLeader,self:GetTextData(1014))
    --     end
    --     return false
    -- elseif self.m_iEnterScene ~= GAME_ENTER then
    --     if iApply ==1 then
    --         oNotifyMgr:Notify(pid,self:GetTextData(1016))
    --     elseif iApply == 2 then
    --         oNotifyMgr:Notify(iLeader,self:GetTextData(1016))
    --     end
    --     return false
    -- end
    oNotifyMgr:Notify(pid,self:GetTextData(1045))
    return false
end

-----npc----
function CHuodong:ValidJoin(oPlayer,npcobj)
    local pid = oPlayer:GetPid()
    if oPlayer:IsSingle() then
        local LIMIT_GRADE = res["daobiao"]["open"]["LIUMAI"]["p_level"]
        if oPlayer:GetGrade() < LIMIT_GRADE then
            self:SayText(pid,npcobj,self:GetTextData(1001))
            return false
        end
        if self.m_iEnterScene ~= GAME_ENTER then
            self:SayText(pid,npcobj,self:GetTextData(1002))
            return false
        end
    elseif oPlayer:IsTeamLeader() then
        local oWorldMgr = global.oWorldMgr
        local oTeam = oPlayer:HasTeam()
        local LIMIT_GRADE = res["daobiao"]["open"]["LIUMAI"]["p_level"]
        for _, oMem in ipairs(oTeam:GetMember()) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            if oTarget then
                if oTarget:GetGrade() < LIMIT_GRADE then
                    local sText = string.gsub(self:GetTextData(1012),"#role",{["#role"]=oTarget:GetName()})
                    self:TeamSay(oTeam,npcobj,sText)
                    return false
                end
            end
        end
        if self.m_iEnterScene ~= GAME_ENTER then
            self:TeamSay(oTeam,npcobj,self:GetTextData(1002))
            return false
        end
    else
        return false
    end
    return true
end

function CHuodong:TeamSay(oTeam,npcobj,sText)
    for _, oMem in ipairs(oTeam:GetMember()) do
        npcobj:Say(oMem.m_ID,sText)
    end
end

function CHuodong:JoinGame(oPlayer,npcobj,bRobot)
    local bFly = false
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

function CHuodong:ValidShow(oPlayer)
    if self.m_iGameState == GAME_POINT then
        return true 
    elseif self.m_iGameState == GAME_TAOTAI then
        return true
    elseif self.m_iEnterScene == GAME_ENTER then
        return true
    else
        return false
    end
end

function CHuodong:GetNPCMenu()
    return "参与会武"
end

--对话--
function CHuodong:do_look(oPlayer, npcobj)
    local pid = oPlayer:GetPid()
    local nid = npcobj.m_ID
    local func = function (oPlayer,mData)
        self:Respond(oPlayer, nid, mData["answer"])
    end
    self:SayText(pid,npcobj,self:GetTextData(1004),func)
end

function CHuodong:Respond(oPlayer, nid, iAnswer)
    if iAnswer ~=1 then
        return
    end
    local oSceneMgr = global.oSceneMgr
    local oNotifyMgr = global.oNotifyMgr
    local oCbMgr = global.oCbMgr
    local pid = oPlayer:GetPid()
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        oNotifyMgr:Notify(pid,self:GetTextData(1013))
        return
    end
    local mNet = {}
    mNet.sContent = self:GetTextData(1017)
    mNet.sConfirm = "确认"
    mNet.sCancle = "取消"
    if oPlayer:IsSingle() then
        global.oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet, nil,function (oPlayer,mData)
            self:ComfirmRespond(oPlayer,mData)
        end)
    elseif oPlayer:IsTeamLeader() then
        oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet, nil,function (oPlayer,mData)
            self:ComfirmRespond(oPlayer,mData)
        end)
    end
end

function CHuodong:ComfirmRespond(oPlayer,mData)
    local iAnswer = mData.answer or 0
    if iAnswer ~=1 then
        return
    end
    local oSceneMgr = global.oSceneMgr
    if oPlayer:IsSingle() then
        oSceneMgr:EnterDurableScene(oPlayer)
    elseif oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam() 
        oSceneMgr:TeamEnterDurableScene(oPlayer)
    end
end

function CHuodong:OnPlayerEnterScene(oPlayer,oScene)
    local pid = oPlayer:GetPid()
    self:SetInitInfo(oPlayer)
    self:RefreshMyPoint(oPlayer)
    self:RefreshOneGameState(oPlayer)
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
    mNet.point = mInfo.point
    mNet.rank = mInfo.rank
    mNet.win = mInfo.win
    mNet.fail = mInfo.fail
    mNet.gamestate = self.m_iGameState
    mNet.starttime = math.max(0,self.m_iStartTime - get_time())
    mNet.matchtime = math.max(0,self.m_iNextMatchTime - get_time())
    oPlayer:Send("GS2CLMMyPoint",mNet)
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
    self.m_mPoint[pid] = {point = 0,grade = oPlayer:GetGrade(), name = oPlayer:GetName(),rank = 0,win = 0,fail = 0,school = oPlayer:GetSchool(),icon = oPlayer:GetIcon(),model = oPlayer:GetChangedModelInfo(),title = "",maxwin=0}
end

function CHuodong:MatchPoint()
    self:DelTimeCb("MatchPoint")
    self:AddTimeCb("MatchPoint",self:GetGameTime("MatchPoint"),function ()
        self:MatchPoint()
    end)
    self.m_iNextMatchTime = get_time() + math.floor(self:GetGameTime("MatchPoint")/1000)
    local oTeamMgr = global.oTeamMgr
    local lMatchTeamID = {}
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iValidTeamCnt = 0
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            goto continue
        end
        if oPlayer:IsSingle() then
            oNotifyMgr:Notify(pid,self:GetTextData(1005))
            goto continue 
        end
        if not oPlayer:IsTeamLeader() then
            goto continue 
        end
        local oTeam = oPlayer:HasTeam()
        if oTeam:MemberSize() <3 then
            oTeam:TeamNotify(self:GetTextData(1005))
            goto continue 
        end
        if oTeam:MemberSize()>3 then
            oTeam:TeamNotify(self:GetTextData(1006))
            goto continue 
        end

        local mFail = {}
        for _,oMem in ipairs(oTeam:GetMember()) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            local mInfo = self.m_mPoint[oMem.m_ID]
            if mInfo.fail>=LIMIT_FAIL then
                mFail[oMem.m_ID] =  oTarget:GetName()
            end
        end
        if table_count(mFail)>0 then
            local lFailName = table_value_list(mFail)
            local sRole = table.concat(lFailName,",")
            local sText = self:GetTextData(1008)
            sText = string.gsub(sText,"#role",{["#role"]=sRole})
            oTeam:TeamNotify(sText)
            goto continue 
        end

        if oPlayer.m_oActiveCtrl:GetWarStatus() ~= gamedefines.WAR_STATUS.NO_WAR then
            iValidTeamCnt = iValidTeamCnt +1
            goto continue 
        end
        local iProtectTime = oTeam.m_LMProtectTime or 0
        if iProtectTime>get_time() then
            iValidTeamCnt = iValidTeamCnt +1
            goto continue 
        end
        table.insert(lMatchTeamID,oTeam:TeamID())
        ::continue::
    end

    local lDelNoMatch  = {}
    for _,iTeamID in ipairs(self.m_lNoMatch) do
        if not extend.Array.find(lMatchTeamID,iTeamID) then
            table.insert(lDelNoMatch,iTeamID)
        end
    end
    for _,iTeamID in ipairs(lDelNoMatch) do
        extend.Array.remove(self.m_lNoMatch,iTeamID)
    end


    table.sort(lMatchTeamID,function (iTeamID1,iTeamID2)
        local oTeam1= oTeamMgr:GetTeam(iTeamID1)
        local oTeam2= oTeamMgr:GetTeam(iTeamID2)
        local iGrade1 = self:GetTeamGrade(oTeam1)
        local iGrade2 = self:GetTeamGrade(oTeam2)
        if iGrade1>iGrade2 then
            return true
        else
            return false
        end
    end)

    local iMaxCount = #lMatchTeamID
    local lNoMatch = extend.Table.deep_clone(self.m_lNoMatch)
    self.m_lNoMatch = {}
    -- print("=================")
    -- print("lNoMatch",iValidTeamCnt, lNoMatch)
    -- print("lMatchTeamID",lMatchTeamID)
    for index = 1 ,iMaxCount do
        local iCurCount = #lMatchTeamID
        if iCurCount<=0 then
            break
        end
        local iTeamPos1 = 1       
        local iNoMatchPos = self:GetNoMatchPos(lMatchTeamID,lNoMatch) 
        if iNoMatchPos then
            iTeamPos1 = iNoMatchPos
        end
        local iTeamPos2 = nil
        local iTeamID1 = lMatchTeamID[iTeamPos1]
        local iTeamID2 = nil
        local oTeam1 = oTeamMgr:GetTeam(iTeamID1)
        local oTeam2 = nil
        

        if iCurCount==1 then
            table.insert(self.m_lNoMatch,iTeamID1)
            break
        end

        if iCurCount == 2 then
            if iTeamPos1 == 1 then
                iTeamPos2 = 2
            else
                iTeamPos2 = 1
            end
            iTeamID2 = lMatchTeamID[iTeamPos2]
            oTeam2 = oTeamMgr:GetTeam(iTeamID2)
            if self:ValidMatch(oTeam1,oTeam2,iValidTeamCnt) then
                -- print("cnt2 ",iTeamID1,iTeamID2)
                extend.Array.remove(lMatchTeamID,iTeamID1)
                extend.Array.remove(lMatchTeamID,iTeamID2)
                if oTeam1 and oTeam2 and oTeam1 ~= oTeam2 then
                    safe_call(self.StartFight,self,oTeam1,oTeam2)
                end
            else
                table.insert(self.m_lNoMatch,iTeamID1)
                table.insert(self.m_lNoMatch,iTeamID2)
            end
            break
        end

        local iMinDiff = 5
        local lPos = {}
        for pos, iTeamID in ipairs(lMatchTeamID) do
            local obj = oTeamMgr:GetTeam(iTeamID)
            if pos ~= iTeamPos1 and self:ValidMatch(oTeam1,obj,iValidTeamCnt,true) and iMinDiff >= math.abs(pos - iTeamPos1) then
                table.insert(lPos,pos)
            end
        end
        if #lPos>0 then
            -- print("lPos",lPos)
            local pos  = extend.Random.random_choice(lPos)
            iTeamPos2 = pos
            iTeamID2 = lMatchTeamID[iTeamPos2]
            oTeam2 = oTeamMgr:GetTeam(iTeamID2)
        end
        if oTeam1 and oTeam2 then
            -- print("cnt3 ",iTeamID1,iTeamID2)
            extend.Array.remove(lMatchTeamID,iTeamID1)
            extend.Array.remove(lMatchTeamID,iTeamID2)
            
            if oTeam1 and oTeam2 and oTeam1 ~= oTeam2 then
                safe_call(self.StartFight,self,oTeam1,oTeam2)
            end
        end
    end
    for _,iTeamID in ipairs(self.m_lNoMatch) do
        local oTeam = oTeamMgr:GetTeam(iTeamID)
        if oTeam then
            oTeam:TeamNotify("本轮轮空，下轮将优先匹配")
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

function CHuodong:ValidMatch(oTeam1,oTeam2,iValidTeamCnt,bFailValid)
    local iLastFight1 = oTeam1.m_LMLastFight or 0
    local iLastFight2 = oTeam2.m_LMLastFight or 0
    if iLastFight1 == oTeam2:TeamID() and iLastFight2 == oTeam1:TeamID() then
        if bFailValid then
            return false
        end
        if iValidTeamCnt == 0 then
            oTeam1.m_LMNoMatch = nil
            oTeam2.m_LMNoMatch = nil
            oTeam1.m_LMLastFight = nil
            oTeam2.m_LMLastFight = nil 
            return true
        end
        if iValidTeamCnt <=3 then
            oTeam1.m_LMLastFight = nil
            oTeam2.m_LMLastFight = nil 
            return false
        end

        if oTeam1.m_LMNoMatch == true and oTeam2.m_LMNoMatch == true then
            oTeam1.m_LMNoMatch = nil
            oTeam2.m_LMNoMatch = nil
            oTeam1.m_LMLastFight = nil
            oTeam2.m_LMLastFight = nil 
            return false
        else
            oTeam1.m_LMNoMatch = true
            oTeam2.m_LMNoMatch = true
            return false
        end
    end
    oTeam1.m_LMNoMatch = nil
    oTeam2.m_LMNoMatch = nil
    oTeam1.m_LMLastFight = nil
    oTeam2.m_LMLastFight = nil 
    return true
end

function CHuodong:GetNoMatchPos(lMatchTeamID,lNoMatch)
    for _,iTeamID in ipairs(lNoMatch) do
        local pos = extend.Array.find(lMatchTeamID, iTeamID)
        if pos then
            return pos
        end
    end
end

function CHuodong:StartFight(oTeam1,oTeam2)
    oTeam1.m_LMLastFight = oTeam2:TeamID()
    oTeam2.m_LMLastFight = oTeam1:TeamID()

    local oWarMgr = global.oWarMgr
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["condition"][1]
    local iBarrageShow = mConfig.barrage_show or 0
    local iBarrageSend = mConfig.barrage_send or 0
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE, 
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_LIUMAI, 
        {bout_out={bout=LIMIT_BOUT,result=10},GamePlay=self.m_sName,barrage_show=iBarrageShow,barrage_send=iBarrageSend})
    local iWarID = oWar:GetWarId()
    local oFighter1 = oTeam1:GetLeaderObj()
    local oFighter2 = oTeam2:GetLeaderObj()
    oWarMgr:TeamEnterWar(oFighter1, iWarID, {camp_id = 1}, true,0)
    oWarMgr:TeamEnterWar(oFighter2, iWarID, {camp_id = 2}, true,0)
    local fCallback = function (mArgs)
        self:WarFightEnd(iWarID,mArgs)
    end
    oWar.m_LMType = WAR_TYPE[self.m_iGameState] or ""
    oWar.mBattleLeader = {{oTeam1:TeamID(),oFighter1:GetPid()},{oTeam2:TeamID(),oFighter2:GetPid()}}
    oWar.m_TeamGrade = {grade1 = oTeam1:GetTeamAveGrade(),grade2 = oTeam2:GetTeamAveGrade()}
    oWar:SetOtherCallback("OnLeave",_EscapeCallBack)
    oWarMgr:SetCallback(iWarID, fCallback)
    oWarMgr:StartWar(iWarID, {action_id = lAction})
end

function CHuodong:WarFightEnd(iWarID,mArgs)
    local oWar = global.oWarMgr:GetWar(iWarID)
    if not oWar then
        return
    end
    local iWinSide = mArgs.win_side or 0
    if oWar.m_ForceRelease then
        iWinSide = 10
    end
    local oSceneMgr = global.oSceneMgr
    local oWorldMgr = global.oWorldMgr
    local iSide1 = 1
    local iSide2 = 2
    
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

    local iLiveCount1 = #mLivePlayer[iSide1]
    if table_get_depth(mArgs, {"summon", iSide1, "live"}) then
        iLiveCount1 = iLiveCount1 + #mArgs.summon[iSide1]["live"]
    end
    local iLiveCount2 = #mLivePlayer[iSide2]
    if table_get_depth(mArgs, {"summon", iSide2, "live"}) then
        iLiveCount2 = iLiveCount2 + #mArgs.summon[iSide2]["live"]
    end
    if iWinSide == 10 then
        if iLiveCount1 > iLiveCount2  then
            iWinSide = iSide1
        elseif iLiveCount1 < iLiveCount2  then
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

    local mLogPlayerInfo = {}
    local iWinLeader = 0
    local iFailLeader = 0

    local mWinner = {}
    local mFailer  = {}
    if iWinSide == iSide1 then
        mWinner = mPlayer[iSide1]
        mFailer  = mPlayer[iSide2]
    elseif iWinSide == iSide2 then
        mWinner = mPlayer[iSide2]
        mFailer  = mPlayer[iSide1]
    end

    local oTeam1 = nil
    local oTeam2 = nil
    local oWorldMgr = global.oWorldMgr
    for _,pid in pairs(mWinner) do
        self:RewardWinner(pid)
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oTarget:IsTeamLeader() then
            oTeam1  = oTarget:HasTeam()
            oTarget:MarkGrow(33)
            iWinLeader = pid
        end
        local mInfo = self.m_mPoint[pid]
        mLogPlayerInfo[pid] = {}
        mLogPlayerInfo[pid].point = mInfo.point
        mLogPlayerInfo[pid].win = mInfo.win
        mLogPlayerInfo[pid].fail = mInfo.fail
    end

    for _,pid in pairs(mFailer) do
        self:RewardFailer(pid)
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oTarget:IsTeamLeader() then
            oTeam2  = oTarget:HasTeam()
            oTarget:MarkGrow(33)
            iFailLeader = pid
        end
        local mInfo = self.m_mPoint[pid]
        mLogPlayerInfo[pid] = {}
        mLogPlayerInfo[pid].point = mInfo.point
        mLogPlayerInfo[pid].win = mInfo.win
        mLogPlayerInfo[pid].fail = mInfo.fail
    end

    local mLogData={
        winside = iWinSide,
        gamestate = self.m_iGameState,
        ttstate = self.m_iTaoTaiState,
        player = extend.Table.serialize(mPlayer),
        winleader = iWinLeader,
        failleader = iFailLeader,
        playerinfo = extend.Table.serialize(mLogPlayerInfo),
    }
    record.log_db("huodong", "liumai_warend",mLogData)

    if self.m_iGameState == GAME_POINT and oWar.m_LMType == WAR_TYPE[self.m_iGameState] then
        if oTeam1 and oTeam2 then
            oTeam1.m_LMProtectTime = get_time() + POINT_PROTECT
            oTeam2.m_LMProtectTime = get_time() + POINT_PROTECT
        end
        self:SortPointRank()
    elseif self.m_iGameState == GAME_TAOTAI and oWar.m_LMType == WAR_TYPE[self.m_iGameState] then
        local mBattleLeader = oWar.mBattleLeader
        self:TTFightWarEnd(mBattleLeader,iWinSide)
    end
end

function CHuodong:RewardWinner(pid)
    local oWorldMgr = global.oWorldMgr
    local oTarget  = oWorldMgr:GetOnlinePlayerByPid(pid)
    if self.m_iGameState == GAME_POINT then
        self:Reward(pid,1002) 
        local mInfo = self.m_mPoint[pid]
        mInfo.win = mInfo.win +1
        mInfo.maxwin = mInfo.maxwin + 1
        if oTarget then
            if oTarget:IsTeamLeader() then
                local iGrade = oTarget:GetGrade()
                local iServerGrade = oWorldMgr:GetServerGrade() 
                local iPoint = math.floor(iGrade*0.1 + 10  + math.max(0,iGrade - iServerGrade)*5)
                mInfo.point = mInfo.point +iPoint
                local mRes = res["daobiao"]["huodong"][self.m_sName]["win_redpacket"]
                if mRes[mInfo.maxwin] then
                    self:SendRP(mRes[mInfo.maxwin]["redpacket"],{role = oTarget:GetName(),amount = mInfo.maxwin,bless_replace={role=oTarget:GetName()}})
                end
            end
            self:RefreshMyPoint(oTarget)
        end
    elseif self.m_iGameState == GAME_TAOTAI then
        self:Reward(pid,1002) 
    end
    if oTarget then
        self:AddSchedule(oTarget)
    end
end

function CHuodong:RewardFailer(pid)
    local oTarget  = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local oWorldMgr = global.oWorldMgr
    if self.m_iGameState == GAME_POINT then
        self:Reward(pid,1003) 
        local mInfo = self.m_mPoint[pid]
        mInfo.fail = mInfo.fail +1
        mInfo.maxwin = 0
        if oTarget then 
            self:RefreshMyPoint(oTarget)
        end
    elseif self.m_iGameState == GAME_TAOTAI then
        self:Reward(pid,1003) 
    end
    if oTarget then
        self:AddSchedule(oTarget)
    end
end

function CHuodong:Escape(oPlayer)
    self:RewardFailer(oPlayer:GetPid())
end

function CHuodong:SortPointRank()
    local lRank = {}
    for pid,mInfo in pairs(self.m_mPoint) do
        if mInfo.point>0 then
            table.insert(lRank,{pid = pid,point = mInfo.point})
        end
    end

    table.sort(lRank,function (mInfo1,mInfo2)
        if  mInfo1.point>mInfo2.point then
            return true
        else
            return false
        end
    end)
    self.m_lPointRank = lRank
    for rank,mRankInfo in pairs(lRank) do
        local mInfo = self.m_mPoint[mRankInfo.pid]
        mInfo.rank = rank
    end
    self:RefreshAllPoint()
end

function CHuodong:LookInfo(oPlayer,iSchool)
    local oWorldMgr = global.oWorldMgr
    local pid = oPlayer:GetPid()
    if self.m_iGameState == GAME_POINT then
        local iLimit
        if iSchool == 0 then 
            iLimit  = 100
        end
        local mNet = {}
        for rank ,mRankInfo in ipairs(self.m_lPointRank) do
            if iLimit  and rank>iLimit then
                break
            end
            local target = mRankInfo.pid
            local mInfo = self.m_mPoint[target]
            if iSchool ~=0 and mInfo.school ~= iSchool then
                goto continue
            end
            local oTarget =  oWorldMgr:GetOnlinePlayerByPid(target)
            local mData = {}
            mData.rank = rank
            if oTarget then
                mData.name = oTarget:GetName()
                mData.grade = oTarget:GetGrade()
            else
                mData.name = mInfo.name
                mData.grade = mInfo.grade
            end
            mData.point = mInfo.point
            mData.pid = target
            mData.school = mInfo.school
            if oTarget and oTarget.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.IN_WAR then
                mData.war  = 1
            end
            table.insert(mNet,mData)
            ::continue::
        end
        oPlayer:Send("GS2CLMPointRank",{ranklist = mNet})
    elseif self.m_iGameState == GAME_TAOTAI then
        oPlayer:Send("GS2CLMBatte",self:PackTTBattle())
    end
end

function CHuodong:RefreshOneGameState(oPlayer)
    oPlayer:Send("GS2CLMGameState",{state = self.m_iGameState})
end

function CHuodong:RefreshAllGameState()
    local oScene = self:GetScene()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    for pid , _ in pairs(oScene.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:RefreshOneGameState(oPlayer)
        end
    end
end

function CHuodong:SendTaoTaiRP()
    if not self.m_bSendRP then
        return
    end
    local mRes = res["daobiao"]["huodong"][self.m_sName]["jinji_redpacket"]
    if mRes[self.m_iTaoTaiState] then
        local mReplace = {}
        if self.m_iTaoTaiState == TT_FOUR then
            local mRole = {}
            for _,mBattle in ipairs(self.m_mTTBattle) do
                if extend.Array.find(self.m_mThreeBattle,mBattle[1]) or extend.Array.find(self.m_mThreeBattle,mBattle[2]) then
                    goto continue
                end
                local mInfo1 = self.m_mPoint[mBattle[1]]
                local mInfo2 = self.m_mPoint[mBattle[2]]
                table.insert(mRole,mInfo1.name)
                table.insert(mRole,mInfo2.name)
                ::continue::
            end
            mReplace.role = table.concat(mRole, "、")
        elseif self.m_iTaoTaiState == TT_TWO then
            local mRole = {}
            for _,mBattle in ipairs(self.m_mTTBattle) do
                if extend.Array.find(self.m_mThreeBattle,mBattle[1]) or extend.Array.find(self.m_mThreeBattle,mBattle[2]) then
                    goto continue
                end
                local mInfo1 = self.m_mPoint[mBattle[1]]
                local mInfo2 = self.m_mPoint[mBattle[2]]
                table.insert(mRole,mInfo1.name)
                table.insert(mRole,mInfo2.name)
                ::continue::
            end
            mReplace.role = mRole
        elseif self.m_iTaoTaiState == TT_ONE then
            local iLen = #self.m_lTTOrder
            local sResult = ""
            for i=1 ,3 do
                if i>iLen then
                    break
                end
                local pid = self.m_lTTOrder[iLen-i+1]
                local mInfo = self.m_mPoint[pid]
                if i==1 then
                    sResult = sResult .. string.format("冠军#G%s#n、",mInfo.name)
                elseif i ==2 then
                    sResult = sResult .. string.format("亚军#G%s#n、",mInfo.name)
                elseif i == 3 then
                    sResult = sResult .. string.format("季军#G%s#n",mInfo.name)
                end
            end
            mReplace.result = sResult
        end
        self:SendRP(mRes[self.m_iTaoTaiState]["redpacket"],mReplace)
    end
end

function CHuodong:SendRP(iRP,mReplace)
    local oRedPacketMgr = global.oRedPacketMgr
    local mArgs = {}
    mArgs.cw_replace =mReplace
    mArgs.bless_replace = mReplace.bless_replace
    oRedPacketMgr:SysAddRedPacket(iRP,nil,mArgs)
end

function CHuodong:OpenHDSchedule(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    if oPlayer:GetNowScene() == self:GetScene() then
        self:Notify(iPid, 1046)
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
        "101 开始进场\nhuodongop liumai 101",
        "102 积分赛开始\nhuodongop liumai 102",
        "103 淘汰赛开始\nhuodongop liumai 103",
        "104 淘汰赛结束\nhuodongop liumai 104",
        "105 活动结束\nhuodongop liumai 105",
        "106 清空失败次数\nhuodongop liumai 106",
        "107 清空胜利次数\nhuodongop liumai 107",
        "108 设置积分赛积分\nhuodongop liumai 108 {point = 10}",
        "109 设置门派首席为自己造型\nhuodongop liumai 109",
        "110 恢复门派首席造型\nhuodongop liumai 110",
        "111 清除保护时间\nhuodongop liumai 111",
        "112 积分赛立刻匹配\nhuodongop liumai 112",
        "113 以刷时开始积分赛（可以通过open_time调整时间）\nhuodongop liumai 113",
        "201 控制机器人参加六脉\nhuodongop liumai 201",
        "204 场景战斗结束\nhuodongop liumai 204",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        if self.m_iGameState == GAME_POINT then
            oNotifyMgr:Notify(pid,"积分赛进行中")
            return
        elseif self.m_iGameState == GAME_TAOTAI then
            oNotifyMgr:Notify(pid,"淘汰赛进行中")
            return 
        end
        if self.m_iEnterScene == GAME_ENTER then
            oNotifyMgr:Notify(pid,"活动正在进场阶段")
            return 
        end
        self:PreGameStart()
        oNotifyMgr:Notify(pid,"进场阶段开始")
    elseif iFlag == 102 then
        if self.m_iGameState == GAME_POINT then
            oNotifyMgr:Notify(pid,"积分赛进行中")
            return
        elseif self.m_iGameState == GAME_TAOTAI then
            oNotifyMgr:Notify(pid,"淘汰赛进行中")
            return 
        end
        if self.m_iEnterScene ~= GAME_ENTER then
            oNotifyMgr:Notify(pid,"活动不在进场阶段")
            return 
        end
        self:GameStart1()
        oNotifyMgr:Notify(pid,"积分赛开始")
    elseif iFlag == 103 then
        if self.m_iGameState ~= GAME_POINT then
            oNotifyMgr:Notify(pid,"积分赛中执行才有效")
            return
        end
        self:GameStart2()
        oNotifyMgr:Notify(pid,"淘汰赛开始")
    elseif iFlag == 104 then
        if self.m_iGameState ~= GAME_TAOTAI then
            oNotifyMgr:Notify(pid,"淘汰赛中执行才有效")
            return
        end
        self:GameOver1()
        oNotifyMgr:Notify(pid,"淘汰赛结束")
    elseif iFlag == 105 then
        self:GameOver1()
        self:GameOver2()
        oNotifyMgr:Notify(pid,"活动结束")
    elseif iFlag == 106 then
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"活动场景在执行")
            return
        end
        mInfo.fail = 0
        self:RefreshMyPoint(oPlayer)
    elseif iFlag == 107 then
        local mInfo = self.m_mPoint[pid]
        if not mInfo then
            oNotifyMgr:Notify(pid,"活动场景在执行")
            return
        end
        mInfo.win = 0
        self:RefreshMyPoint(oPlayer)
    elseif iFlag == 108 then
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
    elseif iFlag == 109 then
        local oNpcMgr = global.oNpcMgr
        local mModel = oPlayer:GetChangedModelInfo()
        local sName = oPlayer:GetName()
        local mTitle = oPlayer:GetTitleInfo()
        local sTitle = ""
        if mTitle then
            sTitle = mTitle.name
        else
            sTitle = ""
        end
        local npctype = gamedefines.SCHOOL_NPC[oPlayer:GetSchool()]
        local npcobj = oNpcMgr:GetGlobalNpc(npctype)
        local mNPCInfo = {
            name = sName,
            model_info = mModel,
            --title = sTitle,
        }
        npcobj:SetChangeModelInfo(mModel)
        npcobj:SyncSceneInfo(mNPCInfo)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 110 then
        local oNpcMgr = global.oNpcMgr
        local npctype = gamedefines.SCHOOL_NPC[oPlayer:GetSchool()]
        local npcobj = oNpcMgr:GetGlobalNpc(npctype)
        npcobj:ClearChangeModelInfo()
        local mNPCInfo = {
            name = npcobj:Name(),
            model_info = npcobj:ModelInfo(),
            --title = npcobj:GetTitle(),
        }
        npcobj:SyncSceneInfo(mNPCInfo)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 111 then
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            oTeam.m_LMProtectTime = nil 
        end
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 112 then
        if self.m_iGameState == GAME_POINT then
            self:MatchPoint()
        end
    elseif iFlag == 113 then
        local mNow = get_timetbl()
        self:NewHour(mNow)
    elseif iFlag == 200 then
        self:LookInfo(oPlayer)
    elseif iFlag == 201 then
        local all = mArgs.all or 0
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

        for target ,oTarget in pairs(oWorldMgr.m_mOnlinePlayers) do
            local sAccount = oTarget:GetAccount()
            if string.find(sAccount,"Robotliumai") or all == 1 then
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
        for target ,oTarget in pairs(oWorldMgr.m_mOnlinePlayers) do
            local oWar = oTarget.m_oActiveCtrl:GetNowWar()
            if oWar then
                oWar:TestCmd("warfail",oTarget:GetPid(),{})
            end
        end
    elseif iFlag == 203 then
        for target,mInfo in pairs(self.m_mPoint) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(target)
            mInfo.point = math.random(100)
            if oTarget then
                self:RefreshMyPoint(oTarget)
            end
        end
        self:SortPointRank()
        oNotifyMgr:Notify(pid,"设置完毕")
    elseif iFlag == 204 then
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
    elseif iFlag == 205 then
        self:SendRP(4101,{role = "test",amount = 5})
    end
end


function _EscapeCallBack(oPlayer)
    local oHD = global.oHuodongMgr:GetHuodong("liumai")
    if not oHD then return end
    oHD:Escape(oPlayer)
end
