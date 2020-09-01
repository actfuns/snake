local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

local GAME_START = 1
local GAME_NOSTART = 0

local STATE_REWARD = 1 --可领取
local STATE_REWARDED = 2 --已领取

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "七星宝箱"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iVersion = 0
    o.m_mRewardInfo = {}
    o.m_iOpenDay = 0
    o.m_iStartTime = 0
    return o
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.openday = self.m_iOpenDay
    mData.starttime = self.m_iStartTime
    mData.rewardinfo = table_to_db_key(self.m_mRewardInfo)
    return mData
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong sevenlogin without data"
    end
    self:Dirty()
    for iPid, mReward in pairs(table_to_int_key(mFromData.rewardinfo or {})) do
        self.m_mRewardInfo[iPid] = mReward
    end
    return true
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iOpenDay = mData.openday or 0
    self.m_iStartTime = mData.starttime or 0
    self.m_mRewardInfo = table_to_int_key(mData.rewardinfo or {})
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    self:AddUpgradeEvent(oPlayer)
    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        if not bReEnter then
            self:CheckReward(oPlayer)
        end
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:NewDay(mNow)
    if self:GetGameState(true) == GAME_START then
        self:CheckGiveReward(mNow)
        self:TryGameEnd(mNow)
    end
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade, iGrade)
    local iLimitGrade = global.oToolMgr:GetSysOpenPlayerGrade("SEVENDAY")
    if iLimitGrade <=iGrade and iFromGrade<iLimitGrade then
        self:CheckReward(oPlayer)
        self:GS2CGameReward(oPlayer)
        self:DelUpgradeEvent(oPlayer)
    end
end

function CHuodong:GetGameState(bNewDay)
    if self.m_iOpenDay ==0  then
        return GAME_NOSTART
    end
    local iCurDay = get_morningdayno()
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    assert(iGameDay>0,string.format("%s gameday error %s",self.m_sName,iGameDay))
    if iCurDay>=self.m_iOpenDay and iCurDay<=self.m_iOpenDay+iGameDay then
        return GAME_START 
    elseif iCurDay == self.m_iOpenDay+iGameDay +1 and bNewDay then
        return GAME_START
    end
    return GAME_NOSTART
end

function CHuodong:GetEndTime()
    if self:GetGameState() ~= GAME_START then
        return 0
    end
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    local iEndDay = self.m_iOpenDay + iGameDay
    local iCurDay = get_morningdayno()
    local iTime = get_time() + (iEndDay-iCurDay) * 3600 * 24
    local date = os.date("*t",iTime)
    local iEndTime=0
    if date.hour>=5 then
        iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=5,min=0,sec=0})
    else
        iTime = iTime - 5*60*60
        date = os.date("*t",iTime)
        iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=5,min=0,sec=0})
    end
    return iEndTime
end

--运营开启活动接口
function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:GameEnd()
        record.warning(string.format("%s force gameend", self.m_sName)) 
    else
        self:TryGameStart()
    end
    return true
end

function CHuodong:TryGameStart(oPlayer)
    if self:GetGameState() == GAME_START then
        if oPlayer then
            local sText = self:GetTextData(1001)
            global.oNotifyMgr:Notify(oPlayer:GetPid(),sText)
        end
        record.warning(string.format("%s gamestart error", self.m_sName)) 
        return
    end
    self:GameStart()
end

function CHuodong:GameStart()
    self:Dirty()
    self.m_iVersion = self.m_iVersion +1 
    self.m_mRewardInfo = {}
    self.m_iOpenDay = get_morningdayno()
    self.m_iStartTime = get_time()
    record.info(string.format("%s GameStart %s",self.m_sName,self.m_iOpenDay))
    local mLogData = {}
    mLogData.state = self:GetGameState()
    mLogData.version = self.m_iVersion
    record.log_db("huodong", "sevenlogin_state",mLogData)
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
            self:GS2CGameStart(oPlayer)
            self:CheckReward(oPlayer)
            self:GS2CGameReward(oPlayer)
    end
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:TryGameEnd(mNow)
    local iTime = mNow and mNow.time or get_time()
    local iCurDay = get_morningdayno(iTime)
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    assert(iGameDay>0,string.format("%s gameday error %s",self.m_sName,iGameDay))
    if iCurDay>=self.m_iOpenDay+iGameDay then
        self:GameEnd()
    end
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd",self.m_sName))
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self.m_mRewardInfo = {}
    self.m_iOpenDay = 0
    local mLogData = {}
    mLogData.state = self:GetGameState()
    mLogData.version = self.m_iVersion
    record.log_db("huodong", "sevenlogin_state",mLogData)
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        self:GS2CGameEnd(oPlayer)
    end
end

function CHuodong:CheckReward(oPlayer)
    local iLimitGrade= res["daobiao"]["open"]["SEVENDAY"]["p_level"]
    if oPlayer:GetGrade()<iLimitGrade then
        return
    end
    self:Dirty()
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    local pid = oPlayer:GetPid()
    if not self.m_mRewardInfo[pid] then
        self.m_mRewardInfo[pid] = {}
    end
    if self.m_iOpenDay == 0 then
        return
    end

    local iCurDay = get_morningdayno()
    local iDay = iCurDay-self.m_iOpenDay + 1
    if iDay > iGameDay then
        return
    end
    local mReward = self.m_mRewardInfo[pid]
    if not next(mReward) then
        mReward.day = iCurDay
        mReward.reward  = {STATE_REWARD}
    else
        local iLastDay = mReward.day 
        if iLastDay == iCurDay then
            return
        end
        if iLastDay +1 == iCurDay then
            table.insert(mReward.reward,STATE_REWARD)
            mReward.day = iCurDay
        else
            mReward.day = iCurDay
            mReward.reward  = {STATE_REWARD}
        end
    end

    local mLogData = {}
    mLogData.pid = pid
    mLogData.version = self.m_iVersion
    mLogData.reward = 0
    mLogData.day = iDay
    mLogData.op = STATE_REWARD
    record.log_db("huodong", "sevenlogin_reward",mLogData)
end

function CHuodong:CheckGiveReward(mNow)
    self:Dirty()
    local oWorldMgr = global.oWorldMgr
    local oPubMgr =global.oPubMgr
    local iTime = mNow and mNow.time or get_time()
    local iCurDay = get_morningdayno(iTime)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["reward"]
    for pid,mReward in pairs(self.m_mRewardInfo) do
        local iDay = #mReward["reward"]
        local iRewardState = mReward["reward"][iDay]
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if iRewardState == STATE_REWARD then
            mReward["reward"][iDay] = STATE_REWARDED
            local iReward = mRes[iDay]["mailrewardidx"]
            local mLogData = {}
            mLogData.pid = pid
            mLogData.version = self.m_iVersion
            mLogData.day = iDay
            mLogData.op = STATE_REWARDED
            mLogData.reward = iReward
            record.log_db("huodong", "sevenlogin_reward",mLogData)
            if oPlayer then
                self:Reward(pid,iReward)
            else
                oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iReward})
            end
        end
        if oPlayer then
            self:CheckReward(oPlayer)
            self:GS2CGameReward(oPlayer)
        end
    end
end

function CHuodong:GetReward(oPlayer,iDay)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        local sText = self:GetTextData(1002)
        oNotifyMgr:Notify(pid,sText)
        return
    end
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        --record.warning(string.format("%s %s no rewardinfo",self.m_sName,pid))
        return
    end
    if not iDay or not mReward["reward"][iDay] then
        --record.warning(string.format("%s %s no rewardinfo error %s day",self.m_sName,pid,iDay))
        return
    end
    if mReward["reward"][iDay] ==STATE_REWARDED then
        --oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return 
    end

    if mReward["reward"][iDay] == STATE_REWARD then
        local iReward = res["daobiao"]["huodong"][self.m_sName]["reward"][iDay]["rewardidx"]
        if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<global.oToolMgr:GetItemRewardCnt(self.m_sName,iReward) then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(3015))
            return false
        end
        self:Dirty()
        mReward["reward"][iDay] = STATE_REWARDED
        local mLogData = {}
        mLogData.pid = pid
        mLogData.version = self.m_iVersion
        mLogData.reward = iReward
        mLogData.day = iDay
        mLogData.op = STATE_REWARDED
        record.log_db("huodong", "sevenlogin_reward",mLogData)
        self:Reward(pid,iReward)
        self:GS2CGameReward(oPlayer)
    else
        record.warning(string.format("%s %s no rewardinfo error %s state",self.m_sName,pid,mReward["reward"][iDay]))
    end
end

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {}
    mNet.endtime = self:GetEndTime()
    mNet.starttime = self.m_iStartTime
    oPlayer:Send("GS2CSevenDayStart",mNet)
end

function CHuodong:GS2CGameEnd(oPlayer)
    oPlayer:Send("GS2CSevenDayEnd",{})
end

function CHuodong:GS2CGameReward(oPlayer)
    local mNet = {}
    local mReward = self.m_mRewardInfo[oPlayer:GetPid()] or {}
    mNet.rewardlist = mReward["reward"]
    oPlayer:Send("GS2CSevenDayReward",mNet)
end

function CHuodong:IsHuodongOpen()
    if self:GetGameState() == GAME_START then
        return true
    else
        return false
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 活动开始\nhuodongop sevenlogin 101",
        "102 活动结束\nhuodongop sevenlogin 102",
    }
    --sethdcontrol sevenlogin default 0 60
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        self:TryGameStart(oPlayer)
        if self:GetGameState() == GAME_START then
            oNotifyMgr:Notify(pid,"开启成功")
        else
            oNotifyMgr:Notify(pid,"开启失败")
        end
    elseif iFlag == 102 then
        self:GameEnd()
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 201 then
        self:GetRewrad(oPlayer,mArgs.day)
    elseif iFlag == 202 then
        print("cg_debug",self.m_mRewardInfo[pid])
    end
end
