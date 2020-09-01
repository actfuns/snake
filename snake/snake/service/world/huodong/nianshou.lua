--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"

local huodongbase = import(service_path("huodong.huodongbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

local GAME_NONE = 0
local GAME_START = 1
local GAME_END = 2

local lDATE = {"year","month","day","hour","min","sec"}
local KILL_MONSTER = {2001,2002,2003}
local KILL_FIGHT_MONSTER = {20001,20002,20003}
local NORMAL_MONSTER = 1001
local REFRESH_HOUR = {10,24}
local BIAN_PAO = 10174

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "年兽活动"
CHuodong.m_iSysType= gamedefines.GAME_SYS_TYPE.SYS_TYPE_NIANSHOU
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iGameState = GAME_NONE
    o.m_iKillNum = 0
    o.m_iScheduleID = 1036
    o.m_mNPCINfo = {}
    return o
end

function CHuodong:Init()
    self:TryGameStart()
    self:TryGameEnd()
end

function CHuodong:NewHour(mNow)
    local iHour = mNow.date.hour
    local mConfig = self:GetConfigData()
    local mStartTime = self:TransTime(mConfig.starttime)
    local iStartTime = os.time(mStartTime)

    self:TryGameStart(mNow)
    self:TryGameEnd(mNow)
    if iStartTime ~= mNow.time then
        self:TryRefreshNormal(iHour)
    end
    if self.m_iGameState == GAME_START then
        self:CHAnnounce(1089)
        if iHour == REFRESH_HOUR[1] then
            self:CheckRefreshKing(true)
        end
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData["npcinfo"] = self.m_mNPCINfo
    mData["kill"] =  self.m_iKillNum
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iKillNum =mData["kill"] or 0
    self.m_mNPCINfo = mData["npcinfo"] or {}
    self:CreatePlayerMonster()
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self.m_iGameState ~=GAME_START then
        return
    end
    self:GS2CNSGetPlayerNPC(oPlayer)
end

function CHuodong:GetConfigData()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    return mRes
end

function CHuodong:IsInHDTime()
    local mConfig = self:GetConfigData()
    local mStartTime = self:TransTime(mConfig.starttime)
    local mEndTime = self:TransTime(mConfig.endtime)
    local iStartTime = os.time(mStartTime)
    local iEndTime = os.time(mEndTime)
    local iCurTime = get_time()
    if iCurTime>iStartTime and iCurTime<iEndTime then
        return true 
    end
    return false
end

function CHuodong:NewDay(mNow)
    if not global.oToolMgr:IsSysOpen("NIAN_SHOU",nil,true) then
        return
    end
    local mConfig = self:GetConfigData()
    local mStartTime = self:TransTime(mConfig.starttime)
    if self.m_iGameState ~= GAME_START then
        if self:IsOpenDay(mNow.time) then
            self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
        end
    end
end

function CHuodong:IsOpenDay(iTime)   --限时活动接口
    local mConfig = self:GetConfigData()
    local mStartTime = self:TransTime(mConfig.starttime)
    local date = os.date("*t",iTime)
    if date.year==mStartTime.year and date.month == mStartTime.month and date.day == mStartTime.day then
        return true
    end
    return false
end

function CHuodong:GetStartTime()
    local mConfig = self:GetConfigData()
    local mStartTime = self:TransTime(mConfig.starttime)
    local sHour = "" .. mStartTime.hour
    local sMin = "" .. mStartTime.min
    if #sHour<=1 then
        sHour = "0" .. sHour
    end
    if  #sMin<=1 then
        sMin = "0" .. sMin
    end
    return string.format("%s:%s",sHour,sMin)
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:CHAnnounce(iCW,mReplace)
    mReplace = mReplace or {}
    local mChuanwen = res["daobiao"]["chuanwen"][iCW]
    local sContent =  global.oToolMgr:FormatColorString(mChuanwen.content,mReplace)
    global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
end

function CHuodong:LogData(sSubType,mLogData)
    record.log_db("huodong", sSubType,mLogData)
end

function CHuodong:TransTime(mData)
    local mTime = {}
    for k,mInfo in pairs(mData) do
        mTime[k] = mInfo.value
    end
    return mTime
end

function CHuodong:TryGameStart(mNow)
    if not global.oToolMgr:IsSysOpen("NIAN_SHOU",nil,true) then
        return
    end
    if self.m_iGameState == GAME_START then
        return
    end
    local mConfig = self:GetConfigData()
    local mStartTime = self:TransTime(mConfig.starttime)
    local iStartTime = os.time(mStartTime)
    local mEndTime = self:TransTime(mConfig.endtime)
    local iEndTime = os.time(mEndTime)
    local iCurTime = mNow and mNow.time or get_time()
    assert(iEndTime>iStartTime,string.format("%s time error %s %s ",self.m_sName,iStartTime,iEndTime))
    if iCurTime>=iEndTime then
        return 
    end
    local iDelayTime = iStartTime - iCurTime 
    if iDelayTime>=60*60 then
        return 
    end
    if iDelayTime<=0 then
        self:GameStart()
    else
        self:AddTimeCb("GameStart",iDelayTime*1000,function ()
            self:GameStart(iStartTime)
        end)
    end
end

function CHuodong:GameStart(iStartTime)
    iStartTime = iStartTime or get_time()
    local date = os.date("*t",iStartTime)
    self:DelTimeCb("GameStart")
    record.info(string.format("%s GameStart %s %s",self.m_sName,iStartTime,date.hour))
    self.m_iGameState = GAME_START
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:Dirty()
    self.m_mNPCINfo = {}
    self.m_iKillNum = 0
    self:CreateShiZhe()
    self:CheckRefreshKing(true)
    self:TryRefreshNormal(date.hour)
end

function CHuodong:CreateShiZhe()
    local oNpc = self:CreateTempNpc(10001)
    self:Npc_Enter_Map(oNpc)
end

function CHuodong:TryGameEnd(mNow)
    if self.m_iGameState ~= GAME_START then
        return
    end
    local mConfig = self:GetConfigData()
    local mEndTime = self:TransTime(mConfig.endtime)
    local iEndTime = os.time(mEndTime)
    local iCurTime = mNow and mNow.time or get_time()
    local iDelayTime = iEndTime - iCurTime 
    if iDelayTime>=60*60  then
        return
    end
    if iDelayTime <=0 then
        self:GameEnd()
    else
        self:AddTimeCb("GameEnd",iDelayTime*1000,function ()
            self:GameEnd()
        end)
    end
end

function CHuodong:GameEnd()
    self:DelTimeCb("GameEnd")
    self:DelTimeCb("_TryRefreshKing")
    self:DelTimeCb("RefreshNormalMonsterBySys")
    record.info(string.format("%s GameEnd",self.m_sName))
    self:Dirty()
    self.m_iGameState = GAME_END
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    self:RemoveNPC()
    self.m_mNPCINfo = {}
end

function CHuodong:RemoveNPC()
    local lNpcIdxs = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if not oNpc:InWar() then
            table.insert(lNpcIdxs, oNpc)
        else
            oNpc.m_bRemove=true
        end
    end
    for nid, oNpc in pairs(lNpcIdxs) do
        self:RemoveTempNpc(oNpc)
    end
end

function CHuodong:RemoveNPCByID(pid,npcid)
    local lnpc = table_key_list(self.m_mNpcList)
    if pid then
        local mData = self.m_mNPCINfo[pid] or {}
        for index,mInfo in ipairs(mData) do
            if mInfo.npcid and mInfo.npcid == npcid then
                table.remove(mData,index)
                self.m_mNPCINfo[pid] = mData
                if #mData<=0 then
                    self.m_mNPCINfo[pid] = nil 
                end
                local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(pid)
                if oOwner then
                    self:GS2CNSRemovePlayerNPC(oOwner,npcid)
                end
                break
            end
        end
    end
    local oNpc = self:GetNpcObj(npcid)
    if not oNpc then
        return
    end
    local sTimer = string.format("%s_RemoveSelf",self.m_sName)
    oNpc:DelTimeCb(sTimer)
    if not oNpc:InWar() then
        self:RemoveTempNpc(oNpc) 
    else
        oNpc.m_bRemove = true
    end
end

function CHuodong:CreatePlayerMonster()
    self:Dirty()
    local mNpcInfo = self.m_mNPCINfo
    self.m_mNPCINfo = {}
    if self.m_iGameState ~= GAME_START then
        return 
    end
    local iNowTime = get_time()
    local mConfig = self:GetConfigData()
    for pid,mData  in pairs(mNpcInfo) do
        for _,mInfo in pairs(mData) do
            local iCreateTime = mInfo.createtime
            local iLeftTime = iNowTime - iCreateTime
            if iLeftTime>0 and iLeftTime < mConfig.normal_show_time then
                self:RefreshMonster(pid,NORMAL_MONSTER)
            end
        end
    end
end

function CHuodong:TryRefreshNormalByPlayer(oPlayer)
    local pid = oPlayer:GetPid()
    local oNowScene = oPlayer:GetNowScene()
    local mNowPos = oPlayer:GetNowPos()
    local mConfig = self:GetConfigData()
    local iRatio= mConfig.bianpao_ratio
    iRatio=100
    if oNowScene:MapId() ~= 101000 then
        iRatio =-1
    end
    oPlayer:RemoveItemAmount(BIAN_PAO,1,self.m_sName)

    oNowScene:BroadcastMessage("GS2CNSYanHua",{x=math.floor(mNowPos.x),y=math.floor(mNowPos.y)})
    local sFlag = string.format("%s_refreshmonster",self.m_sName)
    oPlayer.m_oTodayMorning:Add(sFlag,1)
    if oPlayer.m_oTodayMorning:Query(sFlag,0) <= 10 then
        self:Reward(pid,3001)
    end
    
    if math.random(100)>iRatio then
        return 
    end
    if self.m_iGameState ~= GAME_START then
        return
    end
    local mInfo = self.m_mNPCINfo[pid]
    if mInfo  then
        --global.oNotifyMgr:Notify(pid,self:GetTextData(1011))
        return 
    end
    self:RefreshMonster(pid,NORMAL_MONSTER)
    self:GS2CNSGetPlayerNPC(oPlayer)
end

function CHuodong:TryRefreshNormal(iHour)
    if self.m_iGameState ~= GAME_START then
        return 
    end
    if iHour>=REFRESH_HOUR[1] and iHour<REFRESH_HOUR[2] then
        self:RefreshNormalMonsterBySys()
        local mConfig = self:GetConfigData()
        local iDelayTime = mConfig.refresh_time
        local lnpc = table_key_list(self.m_mNpcList)
        self:AddTimeCb("RefreshNormalMonsterBySys",iDelayTime*1000,function ()
            self:RefreshNormalMonsterBySys()
        end)
    end
end

function CHuodong:RefreshNormalMonsterBySys()
    self:DelTimeCb("RefreshNormalMonsterBySys")
    local mConfig = self:GetConfigData()
    local iRefreshCnt = mConfig.normal_refresh_cnt
    local mLogData = {}
    mLogData.pid = 0
    mLogData.flag = "normal"
    mLogData.cnt = iRefreshCnt
    self:LogData("nianshou_monster",mLogData)
    for i=1,iRefreshCnt do 
        self:RefreshMonster(nil,NORMAL_MONSTER)
    end
end

function CHuodong:RefreshMonster(pid,npctype)
    local oNpc
    if not pid then
        oNpc = self:CreateTempNpc(npctype)
        local  mNpcPos = oNpc:PosInfo()
        local x,y = global.oSceneMgr:RandomPos2(oNpc:MapId())
        mNpcPos.x = x
        mNpcPos.y = y
        self:Npc_Enter_Map(oNpc)
    else
        self:Dirty()
        local mLogData = {}
        mLogData.pid = pid
        mLogData.flag = "normal"
        mLogData.cnt = 1
        self:LogData("nianshou_monster",mLogData)
        oNpc = self:CreateTempNpc(npctype)
        oNpc.m_NSOwner = pid
        if not self.m_mNPCINfo[pid] then
            self.m_mNPCINfo[pid] = {}
        end
        local mInfo  = {}
        mInfo.createtime = get_time()
        mInfo.npcid = oNpc:ID()
        table.insert(self.m_mNPCINfo[pid],mInfo)
        local  mNpcPos = oNpc:PosInfo()
        local x,y = global.oSceneMgr:RandomPos2(oNpc:MapId())
        mNpcPos.x = x
        mNpcPos.y = y
        oNpc.m_bEnterScene  = true
        local sText = self:GetTextData(1005)
        sText = global.oToolMgr:FormatColorString(sText,{x = math.floor(mNpcPos.x),y=math.floor(mNpcPos.y)})
        global.oNotifyMgr:Notify(pid,sText)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer, sText)
        end
    end
    local mConfig = self:GetConfigData()
    local iDelayTime = mConfig.normal_show_time
    if oNpc:Type() ~= NORMAL_MONSTER then
        iDelayTime = mConfig.king_show_time 
    end
    local sFlag = string.format("%s_RemoveSelf",self.m_sName)
    local npcid = oNpc:ID()
    oNpc:AddTimeCb(sFlag,iDelayTime*1000,function ()
        _RemoveNPC(pid,npcid)
    end)
end

function CHuodong:RefreshKingMonsterBySys(bSys)
    local sTimer = "_TryRefreshKing"
    self:DelTimeCb(sTimer)
    if self.m_iGameState ~= GAME_START then
        return 
    end
    if bSys then
        local date = os.date("*t",get_time())
        if date.hour <REFRESH_HOUR[1] or  date.hour>=REFRESH_HOUR[2] then
            return 
        end
    end
    local mConfig = self:GetConfigData()
    local iRefreshCnt = mConfig.king_refresh_cnt

    local mLogData = {}
    mLogData.pid = 1
    mLogData.flag = "king"
    mLogData.cnt = iRefreshCnt
    if bSys then
        mLogData.pid = 0
    end
    self:LogData("nianshou_monster",mLogData)

    for i=1,iRefreshCnt do
        local npctype = extend.Random.random_choice(KILL_MONSTER)
        self:RefreshMonster(nil,npctype)
    end
    self:CHAnnounce(1090)
end

function CHuodong:CheckRefreshKing(bInit)
    local sTimer = "_TryRefreshKing"
    self:DelTimeCb(sTimer)
    if self.m_iGameState ~= GAME_START then
        return 
    end
    local mConfig = self:GetConfigData()
    local iDelayTime = mConfig.king_refresh_time
    if not bInit then
        self:RefreshKingMonsterBySys(true)
    end
    self:AddTimeCb(sTimer,iDelayTime*1000,function ()
        self:CheckRefreshKing()
    end)
end

function CHuodong:ValidFight(pid,npcobj,iFight)
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return false
    end
    if not global.oToolMgr:IsSysOpen("NIAN_SHOU",oPlayer) then
        return
    end
    local mConfig = self:GetConfigData()
    local oTeam = oPlayer:HasTeam()
    if oTeam and pid ~= oTeam:Leader() then
        oNotifyMgr:Notify(pid,self:GetTextData(1008))
        return false 
    end
    if not oTeam or oTeam:MemberSize()< mConfig.join_size then
        oNotifyMgr:Notify(pid,self:GetTextData(1008))
        return false
    end
    local iLimitGrade = 0
    if npcobj:Type() == NORMAL_MONSTER then
        iLimitGrade = mConfig.limit_grade_normal
    else
        iLimitGrade = mConfig.limit_grade_king
    end
    local lName = {}
    for _,oMem in pairs(oTeam:GetMember()) do
        if oMem:GetGrade()<iLimitGrade then
            table.insert(lName,oMem:GetName())
        end
    end
    if #lName>0 then
        local mReplace = {role=table.concat(lName, "、"),grade = iLimitGrade}
        local sText = self:GetTextData(1007)
        sText = global.oToolMgr:FormatColorString(sText,mReplace)
        oTeam:TeamNotify(sText)
        return false
    end
    if npcobj:InWar() then
        oNotifyMgr:Notify(pid,self:GetTextData(1006))
        return false
    end
    if oPlayer:InWar() then
        return false
    end
    return true
end

function CHuodong:OnWarWin(oWar, pid, npcobj, mArgs)
    super(CHuodong).OnWarWin(self, oWar, pid, npcobj, mArgs)
    if npcobj:Type() == NORMAL_MONSTER then
        self:Dirty()
        local mConfig = self:GetConfigData()
        self.m_iKillNum = self.m_iKillNum + 1
        local iRefreshKillNum = mConfig.kill_num
        if self.m_iKillNum>= iRefreshKillNum then
            self.m_iKillNum = 0
            self:RefreshKingMonsterBySys()
        end
        if npcobj.m_NSOwner then 
            local iOwner = npcobj.m_NSOwner
            self:RemoveNPCByID(iOwner,npcobj:ID())
        end
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:AddSchedule(oPlayer)
            local oTeam = oPlayer:HasTeam()
            if oTeam then
                for _,oMem in pairs(oTeam:GetMember()) do
                    local iTarget = oMem:MemberID()
                    if iTarget ~= pid then
                        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
                        if oTarget then
                            self:AddSchedule(oTarget)
                        end
                    end
                end
            end
        end
    end
end

function CHuodong:OnWarFail(oWar, pid, npcobj, mArgs)
    super(CHuodong).OnWarFail(self, oWar, pid, npcobj, mArgs)
    if npcobj and npcobj.m_bRemove then
        if npcobj.m_NSOwner then
            self:RemoveNPCByID(npcobj.m_NSOwner,npcobj:ID())
        else
            self:RemoveTempNpc(npcobj)
        end
    end
end

function CHuodong:Reward(pid, sIdx, mArgs)
    mArgs = mArgs or {}
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local npctype = mArgs.npctype
    local sFlag
    local mConfig = self:GetConfigData()
    if npctype == 1001 then
        local iLimitCount = mConfig.limit_reward_normal
        sFlag = string.format("%s_normal_reward",self.m_sName)
        if oPlayer.m_oTodayMorning:Query(sFlag,0)>=iLimitCount then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1009))
            return
        end
    elseif extend.Array.find(KILL_MONSTER,npctype) then
        local iLimitCount = mConfig.limit_reward_king
        sFlag = string.format("%s_king_reward",self.m_sName)
        if oPlayer.m_oTodayMorning:Query(sFlag,0)>=iLimitCount then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1010))
            return
        end
    end
    if sFlag then
        oPlayer.m_oTodayMorning:Add(sFlag,1)
    end
    super(CHuodong).Reward(self, pid, sIdx, mArgs)
end

function CHuodong:RespondLook(oPlayer, nid, iAnswer)
    local pid = oPlayer:GetPid()
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        return
    end
    local npctype = npcobj:Type()
    if npctype ~=  10001 then
        super(CHuodong).RespondLook(self, oPlayer, nid, iAnswer)
        return 
    end
    if iAnswer ==1 then
        local mConfig = self:GetConfigData()
        if oPlayer:GetGrade()<mConfig.limit_grade_normal then
            local sText = self:GetTextData(1002)
            sText = global.oToolMgr:FormatColorString(sText,{grade =mConfig.limit_grade_normal })
            global.oNotifyMgr:Notify(pid,sText)
            return 
        end
        
        local iSilver ,iAmount = mConfig.bianpao[1],mConfig.bianpao[2]
        if iSilver<=0 or iAmount <0 then
            return 
        end
        if not oPlayer:ValidSilver(iSilver) then
            local iMoneyValue = iSilver - oPlayer:GetSilver()
            local mExchange,mCopyExchange = global.oToolMgr:PackExchangeData(gamedefines.MONEY_TYPE.SILVER,iMoneyValue)
            global.oCbMgr:SetCallBack(pid, "GS2CExecAfterExchange", mCopyExchange,
            function (oPlayer,mData)
                local bResult = global.oToolMgr:TryExchange(oPlayer,mExchange,mData)
                return bResult
            end , 
            function (oPlayer,mData)
                _RespondLook(oPlayer,nid,mData)
            end)
            return 
        end
        if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<1 then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1004))
            return
        end
        local sShape = string.format("%s",BIAN_PAO)
        local oItem = global.oItemLoader:ExtCreate(sShape)
        oItem:SetAmount(iAmount)
        oPlayer:RewardItem(oItem,self.m_sName)
        oPlayer:ResumeSilver(iSilver,self.m_sName)
    elseif iAnswer == 2 then
        oPlayer:Send("GS2CShowIntruction",{id = 15000 })
    end
end

function CHuodong:GS2CNSGetPlayerNPC(oPlayer)
        local pid = oPlayer:GetPid()
        local mData = self.m_mNPCINfo[pid] or {}
        if #mData<=0 then
            return 
        end
        local npclist = {}
        for index ,mInfo in pairs(mData) do
            local npcid = mInfo.npcid
            local npcobj = self:GetNpcObj(npcid)
            if npcobj then
                table.insert(npclist,self:PackPlayerNPCInfo(npcobj))
            end
        end
        oPlayer:Send("GS2CNSGetPlayerNPC",{npclist=npclist})
end

function CHuodong:PackPlayerNPCInfo(npcobj)
    local mInfo = {}
    mInfo.npctype = npcobj:Type()
    mInfo.npcid = npcobj:ID()
    mInfo.name = npcobj:Name()
    mInfo.title = npcobj:GetTitle()
    mInfo.map_id = npcobj:MapId()
    mInfo.pos_info = npcobj:PosInfo()
    mInfo.model_info = npcobj:ModelInfo()
    return mInfo
end

function CHuodong:GS2CNSRemovePlayerNPC(oPlayer,npcid)
    oPlayer:Send("GS2CNSRemovePlayerNPC",{npcid=npcid})
end

function CHuodong:OnPackWarriorsAttr(mFriend,mEnemy,oWar,npcobj)
    local lWarrior = {}
    for _,oEnemy in ipairs(mEnemy) do
        if  extend.Array.find(KILL_FIGHT_MONSTER,oEnemy.type) then
            table.insert(lWarrior,oEnemy)
        end
        if oEnemy.type == 10001 then
            oEnemy.specialnpc = gamedefines.WAR_SPECIAL_NPC["nianshou"]
        end
    end
    if #lWarrior>0 then
        for _,oWarrior in pairs(lWarrior) do
            local mAllMonster = {}
            for iMonsterID=20010,20016 do
                local oMonster = self:CreateMonster(oWar, iMonsterID, npcobj) 
                assert(oMonster,self.m_sName)
                oMonster = self:PackMonster(oMonster)
                mAllMonster[oMonster.type] = oMonster
            end
            oWarrior.all_monster = mAllMonster
        end
    end
    return mFriend,mEnemy
end

function CHuodong:FindNPC(oPlayer)
    local npcobj = nil 
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc:Type() == 10001 then
            npcobj = oNpc
            break
        end
    end
    if not npcobj then
        return 
    end
    local mPos = npcobj:PosInfo()
    local oScene = global.oSceneMgr:GetScene(npcobj:GetScene())
    if not global.oSceneMgr:TargetSceneAutoFindPath(oPlayer,oScene,mPos.x,mPos.y,npcobj:ID()) then
        self:OpenHDSchedule(oPlayer:GetPid())
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 开启活动\nhuodongop nianshou 101",
        "102 关闭活动\nhuodongop nianshou 102",
        "103 刷新年兽王\nhuodongop nianshou 103",
        "104 刷新年兽\nhuodongop nianshou 104",
        "105 设置击杀年兽王数量\nhuodongop nianshou 105 {kill=数量}",
        "106 清除奖励限制\nhuodongop nianshou 106",
        "107 清除自己刷的年兽\nhuodongop nianshou 107",
        "108 年兽分布\nhuodongop nianshou 108",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        if self.m_iGameState ==GAME_START then
            oNotifyMgr:Notify(pid,"活动进行中")
            return 
        end
        self:GameStart()
        oNotifyMgr:Notify(pid,"开启成功")
    elseif iFlag == 102 then
        self:GameEnd()
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 103 then
        self:RefreshKingMonsterBySys()
        oNotifyMgr:Notify(pid,"刷新成功")
    elseif iFlag == 104 then
        self:RefreshNormalMonsterBySys()
        oNotifyMgr:Notify(pid,"刷新成功")
    elseif iFlag == 105 then
        self.m_iKillNum = mArgs.kill or 0
        oNotifyMgr:Notify(pid,"设置成功")
    elseif iFlag == 106 then
        local sFlag = string.format("%s_normal_reward",self.m_sName)
        oPlayer.m_oTodayMorning:Delete(sFlag)
        sFlag = string.format("%s_king_reward",self.m_sName)
        oPlayer.m_oTodayMorning:Delete(sFlag)
        sFlag = string.format("%s_refreshmonster",self.m_sName)
        oPlayer.m_oTodayMorning:Delete(sFlag)
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 107 then
        local mData = self.m_mNPCINfo[pid]
        if not mData then
            return 
        end
        for _,mInfo in pairs(mData) do
            self:RemoveNPCByID(pid,mInfo.npcid)
        end
        self.m_mNPCINfo[pid] = nil
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 108 then
        local sMsg = ""
        local lMapId = {101000}
        for _,iMapId in ipairs(lMapId) do
            local mScene = global.oSceneMgr:GetSceneListByMap(iMapId)
            for _, oScene in ipairs(mScene) do
                local iScene = oScene:GetSceneId()
                local lNpcList = self:GetNpcListByScene(iScene)
                for _, oNpc in pairs(lNpcList) do 
                    local mPos = oNpc:PosInfo()
                    local sSubMsg = ""
                    local npctype = oNpc:Type()
                    local npcid = oNpc:ID()
                    if extend.Array.find(KILL_MONSTER,npctype) then
                        sSubMsg = string.format("%s 年兽王 %s id=%s %s\n",oScene:GetName(),npcid,math.floor(mPos.x),math.floor(mPos.y))
                    elseif npctype == NORMAL_MONSTER and oNpc.m_NSOwner then
                        sSubMsg = string.format("%s 年兽(玩家%s) id=%s %s %s\n",oScene:GetName(),npcid,oNpc.m_NSOwner,math.floor(mPos.x),math.floor(mPos.y))
                    elseif npctype == NORMAL_MONSTER then
                        sSubMsg = string.format("%s 年兽(系统) id=%s %s %s\n",oScene:GetName(),npcid,math.floor(mPos.x),math.floor(mPos.y))
                    end
                    sMsg = sMsg ..  sSubMsg
                end
            end
        end
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 201 then
        print("m_mNPCINfo",get_time(),self.m_mNPCINfo)
    elseif iFlag == 202 then
        local mData = self.m_mNPCINfo[pid] or {}
        for _,mInfo in pairs(mData) do
            local npcid = mInfo.npcid
            local npcobj = self:GetNpcObj(npcid)
            if npcobj then
                npcobj:do_look(oPlayer)
                return 
            end
        end
    elseif iFlag == 203 then
        self:FindNPC(oPlayer)
    end
end

function _RemoveNPC(pid,npcid)
    local oHD = global.oHuodongMgr:GetHuodong("nianshou")
    if not oHD then return end 
    oHD:RemoveNPCByID(pid,npcid)
end

function _RespondLook(oPlayer,nid,mData)
    
    local oHD = global.oHuodongMgr:GetHuodong("nianshou")
    if not oHD then return end 
    local iAnswer = mData.answer
    iAnswer = iAnswer == 1 and 1 or 0
    oHD:RespondLook(oPlayer,nid,iAnswer)
end
