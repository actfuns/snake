--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"

local huodongbase = import(service_path("huodong.huodongbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

local MONSTER_MAX_LEVEL = 81
local MONSTER_SCENE_MAP = 105
local FENGYAOLIMIT = 15
local FENGYAOWANGLIMIT = 3
local TREASUREFENGYAO = 10
local TREASUREFENGYAOWANG = 3
local REFRESHYAO = 0
local REFRESHYAOWANG = 1
local NPCLIMIT = 30
local REWARDFENGYAO = 10
local REWARDFENGYAOWANG = 5
local sFengyao = "fengyao"
local sFengyaoWang = "fengyaowang"

local REWARD_LIMIT = 10

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "封妖"
CHuodong.m_sStatisticsName = "hd_fengyao"
CHuodong.m_iSysType= gamedefines.GAME_SYS_TYPE.SYS_TYPE_FENGYAO
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1003
    self:RefeshMonsterSchedule()
    self.m_iKillNum = 0
    self:TryStartRewardMonitor()
    self.m_iKillLimit = 200
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}

    mData["kill"] =  self.m_iKillNum
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iKillNum =mData["kill"] or 0
end

function CHuodong:MergeFrom(mFromData)
    return true
end


function CHuodong:NewHour(mNow)
    local iHour = mNow.date.hour
    if 5 == iHour then
        self:Reset()
    end
    if iHour>=10 and iHour<=21 then
        self:CheckRefreshYaoWang(true)
    end
    if iHour == 22 then
        self:RemoveYaoWang()
    end
end

function CHuodong:Reset()
    self:Dirty()
    self.m_iKillNum = 0
end

function CHuodong:AddCnt(pid, sType)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local mCnt = oPlayer.m_oTodayMorning:Query("fengyao",{})
        mCnt[sType] = mCnt[sType] or 0
        mCnt[sType]=mCnt[sType]+1
        oPlayer.m_oTodayMorning:Set("fengyao",mCnt)
    end
end

function CHuodong:GetCnt(pid, sType)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local mCnt = oPlayer.m_oTodayMorning:Query("fengyao",{})
        return mCnt[sType] or 0
    end
    return 0
end

function CHuodong:RefeshMonsterSchedule()
    local f2
    f2 = function ()
        self:DelTimeCb("RefeshMonster")
        self:AddTimeCb("RefeshMonster", 5*60*1000, f2)
        self:RefeshMonster()
    end
    self:DelTimeCb("RefeshMonster")
    self:AddTimeCb("RefeshMonster", 3*1000, f2)
end

function CHuodong:ValidFight(pid,npcobj,iFight)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer and oPlayer:InWar() then
        return false
    end
    if npcobj.m_bIsKing then
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            for _,oMem in ipairs(oTeam:GetMember()) do
                local iTarget = oMem.m_ID
                local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
                if oTarget then
                    if REWARDFENGYAOWANG <= self:GetCnt(iTarget, sFengyaoWang) then
                        oNotifyMgr:Notify(iTarget,"今日挑战次数＞5次，不能获得奖励")
                    end
                end
            end
        end
    end
    return true
end

function CHuodong:GetNpcInWarText(npcobj)
    local sText = self:GetTextData(1007)
    sText = global.oToolMgr:FormatColorString(sText,{name = npcobj:Name()})
    return sText
end

function CHuodong:SayText(pid,npcobj,sText,func,iTime,sCmd)
    local oToolMgr = global.oToolMgr
    local iMapId = npcobj:MapId()
    local iLevel = self:GetGradeByMap(iMapId)
    sText = global.oToolMgr:FormatColorString(sText, {mapgrade = iLevel})
    super(CHuodong).SayText(self, pid,npcobj,sText,func,iTime,sCmd)
end

function CHuodong:SayNotifyText(pid,npcobj,sText)
    if npcobj then
        npcobj:Say(pid,sText,nil,nil,true)
    end
end

function CHuodong:CheckAnswer(oPlayer, npcobj, iAnswer)
    if iAnswer ~= 1 then
        return false
    end

    local oWar = npcobj:InWar()
    if oWar then
        local mArgs = {camp_flag = 1, npc_id = npcobj:NpcID()}
        if oPlayer:IsSingle() then
            global.oWarMgr:ObserverEnterWar(oPlayer,oWar:GetWarId(),mArgs)
        else
            global.oWarMgr:TeamObserverEnterWar(oPlayer,oWar:GetWarId(),mArgs)
        end
        return false
    end
    
    local oToolMgr = global.oToolMgr
    if not npcobj.m_bIsKing then
        if not oToolMgr:IsSysOpen("FENGYAO", oPlayer) then return end
    else
        if not oToolMgr:IsSysOpen("YAOWANG", oPlayer) then return end
    end

    if oPlayer.m_oActiveCtrl:GetNowWar() then
        return false
    end

    local oTeam = oPlayer:HasTeam()
    local iOpenLevel
    if npcobj.m_bIsKing then
        iOpenLevel = oToolMgr:GetSysOpenPlayerGrade("YAOWANG")
    else  
        iOpenLevel = oToolMgr:GetSysOpenPlayerGrade("FENGYAO")
    end

    if not oTeam then
        if npcobj.m_bIsKing then
            local sText = self:GetTextData(1004)
            self:SayNotifyText(oPlayer:GetPid(),npcobj, sText)
            return false
        end

        if oPlayer:GetGrade() < iOpenLevel then
            local sText = self:GetTextData(1002)
            local oToolMgr = global.oToolMgr
            sText = oToolMgr:FormatColorString(sText, {role = oPlayer:GetName(), level = iOpenLevel})
            self:SayNotifyText(oPlayer:GetPid(),npcobj,sText)
            return false
        end
    else
        local oWorldMgr = global.oWorldMgr
        if npcobj.m_bIsKing then
            if 3 > oPlayer:GetMemberSize() then
                local sText = self:GetTextData(1004)
                if oTeam:IsShortLeave(oPlayer:GetPid()) then 
                    self:SayNotifyText(oPlayer:GetPid(),npcobj, sText)
                else    
                    for _,pid in ipairs(oTeam:GetTeamMember()) do
                        self:SayNotifyText(pid,npcobj, sText)
                    end
                end
                return false
            end
        end

        local function FilterCannotFightMember(oMember)
            if oMember:GetGrade() < iOpenLevel then
                return oMember:GetName()
            end
        end

        local lName = oTeam:FilterTeamMember(FilterCannotFightMember)
        if next(lName) then
            local sText = self:GetTextData(1002)
            local oToolMgr = global.oToolMgr
            sText = oToolMgr:FormatColorString(sText, {role = table.concat(lName, "、"), level = iOpenLevel})
            for _,pid in ipairs(oTeam:GetTeamMember()) do
                self:SayNotifyText(pid,npcobj, sText)
            end
            return false
        end
    end
    return true
end

function CHuodong:CreateWar(pid,npcobj,iFight)
    
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer and not npcobj.m_bIsKing then
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            for _,oMem in ipairs(oTeam:GetMember()) do
                local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                if oTarget and REWARDFENGYAO <= self:GetCnt(oMem.m_ID, sFengyao) then
                    local sText = self:GetTextData(1006)
                    sText = global.oToolMgr:FormatColorString(sText,{amount=REWARDFENGYAO})
                    global.oNotifyMgr:Notify(oMem.m_ID,sText)
                end
            end
        else
            if oPlayer and REWARDFENGYAO <= self:GetCnt(pid, sFengyao) then
                local sText = self:GetTextData(1006)
                sText = global.oToolMgr:FormatColorString(sText,{amount=REWARDFENGYAO})
                global.oNotifyMgr:Notify(pid,sText)
            end
        end
    end
    local oWar = super(CHuodong).CreateWar(self, pid,npcobj,iFight)
    return oWar
end

function CHuodong:GetMapList()
    local mData = res["daobiao"]["scenegroup"][MONSTER_SCENE_MAP]
    assert(mData, "Fengyao GetMapList err")
    local lMapList = mData["maplist"]
    local lMap = {}
    local iCurServerGrade = global.oWorldMgr:GetServerGrade()
    for _,iMapId in ipairs(lMapList) do
        if self:GetGradeByMap(iMapId)<=iCurServerGrade  then
            table.insert(lMap,iMapId)
        end
    end
    return lMap
end

function CHuodong:GetGradeByMap(iMapId)
    local mData =  res["daobiao"]["huodong"]["fengyao"]["npcmap"][iMapId]
    assert(mData,string.format("Fengyao GetNpcMapList err: %d", iMapId))
    return mData["level"]
end

function CHuodong:GetNpcMapList(iMapId)
    local mData =  res["daobiao"]["huodong"]["fengyao"]["npcmap"][iMapId]
    assert(mData,string.format("Fengyao GetNpcMapList err: %d", iMapId))
    return mData["npc_list"]
end

function CHuodong:GetNpcKingMapList(iMapId)
    local mData =  res["daobiao"]["huodong"]["fengyao"]["npcmap"][iMapId]
    assert(mData,string.format("Fengyao GetNpcMapList err: %d", iMapId))
    return mData["king_list"]
end

function CHuodong:RefeshMonster()
    local lMapId = self:GetMapList()
    for _, iMapId  in ipairs(lMapId) do
        self:RefreshSceneMonster(0, iMapId, REFRESHYAO, FENGYAOLIMIT)
    end
end

function CHuodong:RefreshSceneMonster(pid, iMapId, iTrigger, iNum)
    local oWorldMgr = global.oWorldMgr

    local iCurServerGrade = oWorldMgr:GetServerGrade()
    local oSceneMgr = global.oSceneMgr
    local lNpcIdx = self:GetNpcMapList(iMapId)
    local lKingIdx = self:GetNpcKingMapList(iMapId)
    local mScene = oSceneMgr:GetSceneListByMap(iMapId)

    for _, oScene in ipairs(mScene) do
        local iScene = oScene:GetSceneId()
        local lNpcList = self:GetNpcListByScene(iScene)

        local num = 0
        local iNpcNum = 0
        for _, oNpc in pairs(lNpcList) do 
            if not oNpc.m_bIsKing then
                iNpcNum = iNpcNum + 1
            end
        end

        if 0 < pid then
            num = iNum
        elseif 0 == pid then
            if REFRESHYAO == iTrigger then

                if iNpcNum > NPCLIMIT then
                    return 
                end
                num = math.min(math.abs(iNum - #lNpcList), 7 + math.random(0, 8))
            else
                if iNum > 0 then
                    num = iNum
                end
            end
        else
            assert(false, string.format("fengyao refreash monster pid :%d < 0 ", pid))
        end
        local mLogData={
        pid = pid,
        trigger = iTrigger,
        amount = num,
        }
        record.log_db("huodong", "fenyao_refresh",mLogData)
        for i=1,num do
            local x, y = oSceneMgr:RandomPos2(iMapId)
            local mPosInfo = {
                x = x or 0,
                y = y or 0,
                z = 0,
                face_x = 0,
                face_y = 0,
                face_z = 0,
            }

            local idx = extend.Random.random_choice(lNpcIdx)
            if REFRESHYAOWANG == iTrigger then 
                idx = extend.Random.random_choice(lKingIdx)
            end 
            local iMonsterLevel = self:GetTempNpcData(idx)["grade"] 
            if iMonsterLevel <= iCurServerGrade and iMonsterLevel <= MONSTER_MAX_LEVEL then
                local oNpc = self:CreateTempNpc(idx)
                if REFRESHYAOWANG == iTrigger then
                    oNpc.m_bIsKing = true
                else
                    oNpc.m_iPostPid = pid
                end
                oNpc.m_mPosInfo = mPosInfo
                self:Npc_Enter_Scene(oNpc, iScene)
            end
        end
        iNpcNum = iNpcNum + num
        if iNpcNum > NPCLIMIT then
            lNpcList = self:GetNpcListByScene(iScene)
            self:_RefreshClearNpc(lNpcList, NPCLIMIT)
            self:SendSceneChuanwenMsg("", iMapId, 1014)
        end
    end
end

function CHuodong:_RefreshClearNpc(lNpcList, iCount)
    if type(lNpcList) ~= "table" or 0 == #lNpcList then 
        return
    end

    local iNpcNum = 1
    local mTempNpc = {}
    iCount = #lNpcList - iCount
    if iCount < 0 then 
        return
    end

    for _, oNpc in pairs(lNpcList) do 
        if not oNpc:InWar() then
            if not oNpc.m_bIsKing then
                if iNpcNum <= iCount then 
                    if oNpc.m_iPostPid == 0 then
                        self:RemoveTempNpc(oNpc)
                    else
                        table.insert(mTempNpc, oNpc)
                    end
                    iNpcNum = iNpcNum + 1
                end
            end
        end
    end

    if #mTempNpc ~= 0 then 
        local iRandomCount = math.random(1, #mTempNpc)
        iNpcNum = 1
        for _, oNpc in pairs(mTempNpc) do 
            if iNpcNum <= iRandomCount then
                self:RemoveTempNpc(oNpc)
                iNpcNum = iNpcNum + 1
            end
        end
    end
end

function CHuodong:RefreshNpcForClientTest(iNum)
    local lFigure = table_key_list(res["daobiao"]["modelfigure"])
    local lMapId = self:GetMapList()
    for _, iMapId in ipairs(lMapId) do
        local mScene = global.oSceneMgr:GetSceneListByMap(iMapId)
        for _, oScene in ipairs(mScene) do
            local iScene = oScene:GetSceneId()
            local lNpcList = self:GetNpcListByScene(iScene)
            for _, oNpc in ipairs(lNpcList) do
                self:RemoveTempNpc(oNpc)
            end

            for i = 1, iNum do
                local x, y = global.oSceneMgr:RandomPos2(iMapId)
                local mPosInfo = {
                    x = x or 0,
                    y = y or 0,
                    z = 0,
                    face_x = 0,
                    face_y = 0,
                    face_z = 0,
                }
                local mArgs = self:PacketNpcInfo(1001, nil)
                local iFigure = lFigure[math.random(#lFigure)]
                mArgs.model_info = global.oToolMgr:GetFigureModelData(iFigure)
                local oNpc = huodongbase.NewHDNpc(mArgs)
                global.oNpcMgr:AddObject(oNpc)
                oNpc.m_sHuodong = self.m_sName
                self.m_mNpcList[oNpc.m_ID] = oNpc
                oNpc.m_mPosInfo = mPosInfo
                self:Npc_Enter_Scene(oNpc, iScene)
            end
        end
    end
end

function CHuodong:WarFightEnd(oWar, pid, npcobj, mArgs)
    mArgs["fightnpcobj"] = npcobj

    local iNpcId, sType = 0, sFengyao
    if npcobj then
        iNpcId = npcobj:NpcID()
        if npcobj.m_bIsKing then
            sType = sFengyaoWang
            mArgs.fengyaowang = true
        end
    end
    super(CHuodong).WarFightEnd(self, oWar, pid, npcobj, mArgs)

    -- 记录统计次数
    safe_call(self.RecordPlayerCnt, self, {[pid]=true})
    safe_call(self.LogFengYaoAnalyInfo, self, pid, iNpcId, sType, mArgs.win_side==1, mArgs)
end

function CHuodong:OnWarWin(oWar, pid, npcobj, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oWinner = oWorldMgr:GetOnlinePlayerByPid(pid)
    oWinner:MarkGrow(13)
    super(CHuodong).OnWarWin(self,oWar,pid,npcobj,mArgs)
    self:Dirty()
    if self.m_iKillLimit <= self.m_iKillNum then
        self:RefreshSysYaoWang()
    end
    self.m_iKillNum = self.m_iKillNum + 1
    local lPlayers = self:GetFighterList(oWinner, mArgs)
    for _,pid in ipairs(lPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            if not npcobj.m_bIsKing then
                self:AddSchedule(oPlayer)
                oPlayer.m_oScheduleCtrl:HandleRetrieve(self:ScheduleID(), 1)
                oPlayer.m_oScheduleCtrl:FireFengyaoDone()
            else
                oPlayer.m_oScheduleCtrl:Add(1014)
            end
        end
    end
end

function CHuodong:CheckRefreshYaoWang(bFirst)
    self:DelTimeCb("CheckRefreshYaoWang")
    if not bFirst then
        return
    end
    self:AddTimeCb("CheckRefreshYaoWang",3*60*1000,function ()
        self:CheckRefreshYaoWang()
    end)
    local bRefresh = true
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc.m_bIsKing then 
            bRefresh  = false
            break
        end
    end
    if not bRefresh then return end
    self:RefreshSysYaoWang()
end

function CHuodong:RemoveYaoWang()
    local lNpcList = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc.m_bIsKing and not oNpc:InWar() then 
            table.insert(lNpcList, oNpc)
        end
    end
    for _,oNpc in ipairs(lNpcList) do
        self:RemoveTempNpc(oNpc)
    end
end

function CHuodong:RefreshSysYaoWang()
    local lMapList = self:GetMapList()
    local iMapId = extend.Random.random_choice(lMapList)
    self:RefreshSceneMonster(0, iMapId, REFRESHYAOWANG, FENGYAOWANGLIMIT)
    self:SendSceneChuanwenMsg("", iMapId, 1015)
    self.m_iKillNum = 0
    local mLogData={
    pid = 0,
    mapid = iMapId,
    flag = 3,
    }
    record.log_db("huodong", "fenyao_player",mLogData)
end

function CHuodong:TriggerFengYao(oPlayer,mArgs)
    if mArgs["from_who"] == "treasure" then
        local lMapId = self:GetMapList()
        local iMapId = extend.Random.random_choice(lMapId)
        self:RefreshSceneMonster(oPlayer:GetPid(), iMapId, REFRESHYAO, TREASUREFENGYAO)
        local mLogData={
        pid = oPlayer:GetPid(),
        mapid = iMapId,
        flag = 1,
        }
        record.log_db("huodong", "fenyao_player",mLogData)
        return iMapId
    end
end

function CHuodong:TriggerFengYaoWang(oPlayer,mArgs)
    if mArgs["from_who"] == "treasure" then
        local lMapId = self:GetMapList()
        local iMapId = extend.Random.random_choice(lMapId)
        self:RefreshSceneMonster(oPlayer:GetPid(), iMapId, REFRESHYAOWANG, TREASUREFENGYAOWANG)
        local mLogData={
        pid = oPlayer:GetPid(),
        mapid = iMapId,
        flag = 2,
        }
        record.log_db("huodong", "fenyao_player",mLogData)
        return iMapId
    end
end


--收益--
function CHuodong:GetCustomArgs(mArgs, npcobj, mAddition)
    mAddition = mAddition or {}
    mAddition["bIsKing"] = npcobj.m_bIsKing
    return super(CHuodong).GetCustomArgs(self, mArgs, npcobj, mAddition)
end

function CHuodong:TeamReward(pid,sIdx,mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local lPlayers = self:GetFighterList(oPlayer,mArgs)
    local bIsKing = mArgs["warresult"]["custom"]["bIsKing"]
    if bIsKing then
        self:RewardLeaderPoint(oPlayer, "yaowang", "妖王", #lPlayers)
        local oMentoring = global.oMentoring
        safe_call(oMentoring.AddTaskCnt, oMentoring, oPlayer, 5, 1, "师徒妖王")
    else
        self:RewardLeaderPoint(oPlayer, "fengyao", "封妖", #lPlayers)
        local oMentoring = global.oMentoring
        safe_call(oMentoring.AddTaskCnt, oMentoring, oPlayer, 2, 1, "师徒封妖")
    end
    for _, pid in ipairs(lPlayers) do
        self:Reward(pid,sIdx,mArgs)
    end
end

function CHuodong:Reward(pid, sIdx, mArgs)
    local bIsKing = mArgs["warresult"]["custom"]["bIsKing"]
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    if bIsKing then
        if REWARDFENGYAOWANG <= self:GetCnt(pid, sFengyaoWang) then
            return
        end
        self:AddCnt(pid, sFengyaoWang)
        local iCnt = self:GetCnt(pid, sFengyaoWang)
        if REWARDFENGYAOWANG == iCnt then
            local sMsg = oToolMgr:FormatColorString(self:GetTextData(2027), {count = iCnt})
            oNotifyMgr:Notify(pid, sMsg)
        end
    else
        if REWARDFENGYAO <= self:GetCnt(pid, sFengyao) then
            return
        end
        self:AddCnt(pid, sFengyao)
        local iCnt = self:GetCnt(pid, sFengyao)
        if REWARDFENGYAO == iCnt then
            local sMsg = oToolMgr:FormatColorString(self:GetTextData(2028), {count = iCnt})
            oNotifyMgr:Notify(pid, sMsg)
        end
    end
    self:Dirty()
    super(CHuodong).Reward(self, pid, sIdx, mArgs)
end

function CHuodong:InitRewardExp(oPlayer, sExp, mArgs)
    local iExp = super(CHuodong).InitRewardExp(self,oPlayer, sExp, mArgs)
    local npcobj = mArgs["warresult"]["fightnpcobj"]
    if npcobj  and npcobj.m_iPostPid then 
        local iGiverPid = npcobj.m_iPostPid
        local oWorldMgr = global.oWorldMgr
        local oGiver = oWorldMgr:GetOnlinePlayerByPid(iGiverPid)
        if oGiver then
            local iGiveExp = math.floor(iExp / 3)
            if iGiveExp > 0 then
                self:RewardExp(oGiver, iGiveExp, mArgs)
                local mLogData={
                pid = oPlayer:GetPid(),
                owner = iGiverPid,
                money = 1,
                value = iGiveExp,
                }
                record.log_db("huodong", "fenyao_ownerreward",mLogData)
            end
        end
    end
    return iExp
end

function CHuodong:InitRewardSilver(oPlayer, sSliver, mArgs)
    local iSilver = super(CHuodong).InitRewardSilver(self,oPlayer, sSliver, mArgs)
    local npcobj = mArgs["warresult"]["fightnpcobj"]
    if npcobj  and npcobj.m_iPostPid then 
        local iGiverPid = npcobj.m_iPostPid
        local oWorldMgr = global.oWorldMgr
        local oGiver = oWorldMgr:GetOnlinePlayerByPid(iGiverPid)
        if oGiver then 
            local iGiveSilver = math.floor(iSilver / 3)
            if iGiveSilver > 0 then  
                if iGiverPid ~= oPlayer:GetPid() then
                    local oNotifyMgr = global.oNotifyMgr
                    local oChatMgr = global.oChatMgr
                    local sMsg = self:GetTextData(2007)
                    oNotifyMgr:Notify(iGiverPid,sMsg)
                    oChatMgr:HandleMsgChat(oGiver,sMsg)
                end
                self:RewardSilver(oGiver, iGiveSilver)
                local mLogData={
                pid = oPlayer:GetPid(),
                owner = iGiverPid,
                money = 2,
                value = iGiveSilver,
                }
                record.log_db("huodong", "fenyao_ownerreward",mLogData)
            end
        end
    end
    return iSilver
end

function CHuodong:RewardGold(oPlayer, iGold, mArgs)
    mArgs = mArgs or {}
    super(CHuodong).RewardGold(self, oPlayer, iGold, mArgs)
end

function CHuodong:RewardSilver(oPlayer, iSliver, mArgs)
    mArgs = mArgs or {}
    super(CHuodong).RewardSilver(self, oPlayer, iSliver, mArgs)
end

function CHuodong:RewardExp(oPlayer, iExp,mArgs)
    mArgs = mArgs or {}
    mArgs.iLeaderRatio = nil
    mArgs.iAddexpRatio = nil
    local iStateRatio, iLeaderRatio  = 0, 0
    local oState = oPlayer.m_oStateCtrl:HasState(1009)
    local iStateRatio = oState and oState:GetExpRatioByName(sFengyao) or 0
    if oPlayer:IsTeamLeader() then
        if mArgs["warresult"] and mArgs["warresult"]["fengyaowang"] then
            iLeaderRatio = oPlayer.m_oStateCtrl:GetLeaderExpRaito(sFengyaoWang, oPlayer:GetMemberSize())
        else
            iLeaderRatio = oPlayer.m_oStateCtrl:GetLeaderExpRaito(sFengyao, oPlayer:GetMemberSize())
        end

        if iLeaderRatio > 0 then
            mArgs.iLeaderRatio = iLeaderRatio 
        end
    end
    mArgs.iAddexpRatio = iStateRatio + iLeaderRatio
    super(CHuodong).RewardExp(self, oPlayer, iExp, mArgs)
end

function CHuodong:LogFengYaoAnalyInfo(iPid, iNpcId, sType, isWin, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local sLogType = "SealMonster"
    if sType == sFengyaoWang then
        sLogType = "LichKing"
    end

    local oTeam = oPlayer:HasTeam()
    if oTeam then
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
                mAnalyLog["team_single"] = "team"
                mAnalyLog["team_leader"] = oTeam:IsLeader(iPid)
                mAnalyLog["turn_times"] = self:GetCnt(iPid, sType)
                mAnalyLog["win_mark"] = isWin
                mAnalyLog["npc_id"] = iNpcId
                local mReward = o:GetTemp("reward_content", {})
                mAnalyLog["reward_detail"] = analy.table_concat(mReward)

                if table_count(mReward) > 0 then
                    analy.log_data(sLogType, mAnalyLog)
                end
            end
        end
    else
        local mAnalyLog = oPlayer:BaseAnalyInfo()
        mAnalyLog["team_detail"] = ""
        mAnalyLog["team_single"] = "single"
        mAnalyLog["team_leader"] = ""
        mAnalyLog["turn_times"] = self:GetCnt(iPid, sType)
        mAnalyLog["win_mark"] = isWin
        mAnalyLog["npc_id"] = iNpcId or 0
        local mReward = oPlayer:GetTemp("reward_content", {})
        mAnalyLog["reward_detail"] = analy.table_concat(mReward)
        analy.log_data(sLogType, mAnalyLog)
    end

end

function CHuodong:ChooseRewardKey(oPlayer, mRewardInfo, itemidx, mArgs)
    local mItemUnit = super(CHuodong).ChooseRewardKey(self, oPlayer, mRewardInfo, itemidx, mArgs)
    if not mItemUnit then return mItemUnit end
    local iFortune = oPlayer.m_oTodayMorning:Query("signfortune",0)
    if iFortune == gamedefines.SIGNIN_FORTUNE.YYJH then
        local iEffect = res["daobiao"]["huodong"]["signin"]["fortune"][iFortune]["effect"]
        if math.random(100) < iEffect then
            mItemUnit = table_deep_copy(mItemUnit)
            mItemUnit["amount"] = mItemUnit["amount"] * 2
        end
    end
    return mItemUnit
end

function CHuodong:GetRewardEnv(oAwardee)
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local iCnt = 1
    if oAwardee.HasTeam then
        local oTeam = oAwardee:HasTeam()
        if oTeam  then
            iCnt = oTeam:TeamSize()
        end
    end
    return {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
        cnt = iCnt,
    }
end

function CHuodong:PackWarriorsAttr(oWar, mMonsterData, npcobj,mArgs)
    local iFight = mArgs.fight
    local pid = mArgs.pid
    local iAddCnt=0
    if mArgs.bEnemy then
        iAddCnt = 3
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            if oPlayer:HasTeam() then
                local oTeam = oPlayer:HasTeam()
                iAddCnt =  iAddCnt+ oTeam:TeamSize()
            else
                iAddCnt = iAddCnt + 1
            end
        end
    end

    local mWarriors = {}
    for _,mData in pairs(mMonsterData) do
        local iMonsterIdx = mData["monsterid"]
        local iCnt = mData["count"]
        for i=1,iCnt do
            local oMonster = self:CreateMonster(oWar, iMonsterIdx, npcobj)
            if oMonster then
                table.insert(mWarriors, self:PackMonster(oMonster))
                baseobj_delay_release(oMonster)
            else
                record.warning("monster table err:"..self.m_sName..iMonsterIdx)
            end
        end
    end
    local mFightGroup = res["daobiao"]["fight"][self.m_sName]["group"]
    if mFightGroup[iFight] and iAddCnt>0 and #mFightGroup[iFight]["monster"]>0 then
        local monsterlist = mFightGroup[iFight]["monster"]
        for i=1,iAddCnt do
            local iMonsterIdx = extend.Random.random_choice(monsterlist)
            local oMonster = self:CreateMonster(oWar, iMonsterIdx, npcobj)
            if oMonster then
                table.insert(mWarriors, self:PackMonster(oMonster))
                baseobj_delay_release(oMonster)
            else
                record.warning("monster table err:"..self.m_sName..iMonsterIdx)
            end
        end
    end
    return mWarriors
end

function CHuodong:AutoFindNPC(oPlayer)
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    local iGrade = oPlayer:GetGrade()
    local npcobj = nil 
    local oTargetScene = nil 
    local lMapId = self:GetMapList()
    for _,iMapId in ipairs(lMapId) do
        local iMapGrade = self:GetGradeByMap(iMapId)
        if iGrade<iMapGrade then
            goto continue
        end
        local mScene = global.oSceneMgr:GetSceneListByMap(iMapId)
        for _, oScene in ipairs(mScene) do
            local iScene = oScene:GetSceneId()
            local lNpcList = self:GetNpcListByScene(iScene)
            for _, oNpc in pairs(lNpcList) do 
                if not oNpc.m_bIsKing then
                    npcobj = oNpc
                    oTargetScene = oScene
                    break 
                end
            end
        end
        ::continue::
    end

    if npcobj and oTargetScene then
        local mPos = npcobj:PosInfo()
        local bSuc  = global.oSceneMgr:TargetSceneAutoFindPath(oPlayer,oTargetScene,mPos.x,mPos.y,npcobj:ID())
        if bSuc then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(2008))
        end
    elseif #lMapId>0 then
        local iMapID = lMapId[1]
        local x, y = global.oSceneMgr:RandomPos2(iMapID)
        local bSuc  = global.oSceneMgr:SceneAutoFindPath(oPlayer,iMapID,x,y)
        if bSuc then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(2008))
        end
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 系统刷新封妖\nhuodongop fengyao 101",
        "102 系统刷新妖王\nhuodongop fengyao 102",
        "103 设置系统刷妖王数量限制\nhuodongop fengyao 103 {limit = 数量}",
        "104 清除封妖奖励限制\nhuodongop fengyao 104",
        "105 查看封妖分布\nhuodongop fengyao 105",
        "106 检测触发刷妖王\nhuodongop fengyao 106",
        "107 删除未在战斗中的妖王\nhuodongop fengyao 107",
        "108 清空奖励个数限制\nhuodongop fengyao 108",
        "109 触发玩家挖宝放出的普妖 \nhuodongop fengyao 109",
        "110 客户端测试使用 \nhuodongop fengyao 110 {500}",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        self:RefeshMonster()
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 102 then
        self:RefreshSysYaoWang()
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 103 then
        local iKillLimit = mArgs.limit or 1000
        self.m_iKillLimit = iKillLimit
        oNotifyMgr:Notify(pid,string.format("设置妖王触发上限为:%s",self.m_iKillLimit))
    elseif iFlag == 104 then
        oPlayer.m_oTodayMorning:Delete("fengyao")
        oNotifyMgr:Notify(pid,"清除成功")
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
                    local sSubMsg = ""
                    if oNpc.m_bIsKing then
                        sSubMsg = string.format("%s 妖王 %s %s\n",oScene:GetName(),math.floor(mPos.x),math.floor(mPos.y))
                    elseif oNpc.m_iPostPid>0 then
                        sSubMsg = string.format("%s 非妖王(玩家) %s %s\n",oScene:GetName(),math.floor(mPos.x),math.floor(mPos.y))
                    else
                        sSubMsg = string.format("%s 非妖王(系统) %s %s\n",oScene:GetName(),math.floor(mPos.x),math.floor(mPos.y))
                    end
                    sMsg = sMsg ..  sSubMsg
                end
            end
        end
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
    elseif iFlag == 106 then
        self:CheckRefreshYaoWang()
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 107 then
        self:RemoveYaoWang()
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 109  then
        local iMapId  = self:TriggerFengYao(oPlayer,{["from_who"] = "treasure"})
        local mScene = global.oSceneMgr:GetSceneListByMap(iMapId)
        local sMsg = "挖宝释放妖怪消息"
        local sNpcName = global.oToolMgr:FormatColorString("#playerid挖宝释放",{playerid = pid})
        for _,oScene in ipairs(mScene) do
            local iScene = oScene:GetSceneId()
            local  lNpcList = self:GetNpcListByScene(iScene)
            for _,oNpc in pairs(lNpcList) do
                local sSubMsg = ""
                -- 标记玩家放出的妖怪(这么做并不好)
                local mPos = oNpc:PosInfo()
                if oNpc.m_iPostPid == oPlayer:GetPid() then
                    sSubMsg = string.format("%s  触发 %s 普通 %s %s\n",tostring(oNpc.m_iPostPid),oScene:GetName(),math.floor(mPos.x),math.floor(mPos.y))
                    oNpc:SyncSceneInfo({name = sNpcName})
                end
                sMsg = sMsg .. sSubMsg
            end
        end
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
        oNotifyMgr:Notify(pid,"执行完毕")
    elseif iFlag == 110 then
        self:RefreshNpcForClientTest(mArgs[1])
    elseif iFlag == 201 then
        self:AutoFindNPC(oPlayer)
    end
end


