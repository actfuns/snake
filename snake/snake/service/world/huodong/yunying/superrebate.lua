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

local GAME_START = 1
local GAME_NOSTART = 0
local RECORD_LIMIT = 8

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "超级返利"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iVersion = 0
    o.m_mRewardInfo = {}
    o.m_iOpenDay = 0
    o.m_lRewardRecord = {}
    o.m_iGameDay = 0
    return o
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.openday = self.m_iOpenDay
    mData.gameday = self.m_iGameDay 
    mData.rewardinfo = table_to_db_key(self.m_mRewardInfo)
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iOpenDay = mData.openday or 0
    self.m_iGameDay = mData.gameday or 0
    self.m_mRewardInfo = table_to_int_key(mData.rewardinfo or {})
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong superrebate without data"
    end
    if self.m_iOpenDay == mFromData.openday and self.m_iGameDay == mFromData.gameday then
        table_combine(self.m_mRewardInfo, table_to_int_key(mFromData.rewardinfo or {}))
        self:Drity()
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:NewDay(mNow)
    if self:GetGameState(true) == GAME_START then
        self:CheckGiveReward()
        self:TryGameEnd(mNow)
    end
end

function CHuodong:GetEndTime()
    if self:GetGameState() ~= GAME_START then
        return 0
    end
    local iGameDay = self:GetGameDay()
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

function CHuodong:GetGameState(bNewDay)
    if self.m_iOpenDay ==0  then
        return GAME_NOSTART
    end
    local iCurDay = get_morningdayno()
    local iGameDay = self:GetGameDay()
    assert(iGameDay>0,string.format("%s gameday error %s",self.m_sName,iGameDay))
    if iCurDay>=self.m_iOpenDay and iCurDay<=self.m_iOpenDay+iGameDay then
        return GAME_START 
    elseif iCurDay == self.m_iOpenDay+iGameDay +1 and bNewDay then
        return GAME_START
    end
    return GAME_NOSTART
end

--运营开启活动接口
function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:GameEnd()
        record.warning(string.format("%s force gameend", self.m_sName)) 
    else
        local iEndTime = mInfo.end_time
        if iEndTime>0 then
            local iStartTime = get_time()
            local iEndTime = mInfo.end_time
            local iStartDay = get_morningdayno(iStartTime)
            local iEndDay = get_morningdayno(iEndTime)
            local iGameDay = 1
            iGameDay = math.max(iGameDay,iEndDay-iStartDay+1)
            self:TryGameStart(nil,iGameDay)
        end
    end
    return true
end

function CHuodong:TryGameStart(oPlayer,iGameDay)
    if self:GetGameState() == GAME_START then
        if oPlayer then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1001))
        end
        record.warning(string.format("%s gamestart error %s", self.m_sName,iGameDay)) 
        return
    end
    self:GameStart(iGameDay)
end

function CHuodong:GameStart(iGameDay)
    self:Dirty()
    self.m_iVersion = self.m_iVersion +1 
    self.m_mRewardInfo = {}
    self.m_iOpenDay = get_morningdayno()
    self.m_iGameDay = iGameDay or 0
    record.info(string.format("%s GameStart %s %s",self.m_sName,self.m_iOpenDay,iGameDay))
    local mLogData = {}
    mLogData.state = self:GetGameState()
    mLogData.version = self.m_iVersion
    record.log_db("huodong", "superrebate_state",mLogData)
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
            self:GS2CGameStart(oPlayer)
            self:GS2CGameReward(oPlayer)
    end
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:GetGameDay()
    if self.m_iGameDay >0 then
        return self.m_iGameDay
    end
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    return iGameDay
end

function CHuodong:TryGameEnd(mNow)
    local iTime = mNow and mNow.time or get_time()
    local iCurDay = get_morningdayno(iTime)
    local iGameDay = self:GetGameDay()
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
    self.m_lRewardRecord = {}
    self.m_iOpenDay = 0
    self.m_iGameDay = 0
    local mLogData = {}
    mLogData.state = self:GetGameState()
    mLogData.version = self.m_iVersion
    record.log_db("huodong", "superrebate_state",mLogData)
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        self:GS2CGameEnd(oPlayer)
    end
end

function CHuodong:CheckReward(oPlayer,sKey)
    if self:GetGameState() ~= GAME_START then
        return
    end
    local iLimitGrade= res["daobiao"]["open"]["SUPERREBATE"]["p_level"]
    if oPlayer:GetGrade()<iLimitGrade then
        return
    end
    local pid = oPlayer:GetPid()
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return
    end
    if not mReward.rebate then
        return
    end
    if mReward.value then
        return 
    end
    local mPayRes = res["daobiao"]["huodong"][self.m_sName]["pay"]
    if not mPayRes[sKey] then
        return 
    end
    if not res["daobiao"]["pay"][sKey] then
        return
    end
    self:Dirty()
    local mRebateRes = res["daobiao"]["huodong"][self.m_sName]["rebate"]
    local iValue = math.floor(res["daobiao"]["pay"][sKey]["value"]/10)

    local iRatio = mRebateRes[mReward.rebate]["trueratio"]
    iValue = math.floor(iValue*iRatio)
    mReward.value = iValue
    mReward.lastrebate = mReward.rebate
    mReward.rebate = nil 
    self.m_mRewardInfo[pid] = mReward
    self:GS2CGameReward(oPlayer)


    local mLogData = {}
    mLogData.pid = pid
    mLogData.version = self.m_iVersion
    mLogData.reward = iValue
    record.log_db("huodong", "superrebate_reward",mLogData)
end

function CHuodong:CheckGiveReward()
    self:Dirty()
    local sLotteryFlag = self:GetLotteryFlag()
    local mRewardInfo = self.m_mRewardInfo
    self.m_mRewardInfo = {}
    local oWorldMgr = global.oWorldMgr
    local oMailMgr = global.oMailMgr
    for pid,mReward in pairs(mRewardInfo) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer.m_oTodayMorning:Delete(sLotteryFlag)
            self:GS2CGameReward(oPlayer)
        end
        if not mReward.value or mReward.value<=0 then
            goto continue
        end
        local mMail, sMailName = oMailMgr:GetMailInfo(2036)
        local iValue = mReward.value
        local mLogData = {}
        mLogData.pid = pid
        mLogData.version = self.m_iVersion
        mLogData.reward = -iValue
        record.log_db("huodong", "superrebate_reward",mLogData)

        oMailMgr:SendMailNew(0, sMailName, pid, mMail, {goldcoin=iValue})
        ::continue::
    end
end

function CHuodong:GetReward(oPlayer)
    if self:GetGameState() ~= GAME_START then 
        global.oNotifyMgr:Notify(pid,self:GetTextData(1002))
        return
    end
    local pid = oPlayer:GetPid()
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return
    end
    if not mReward.value or mReward.value<=0 then
        return
    end
    local iValue = mReward.value

    local mLogData = {}
    mLogData.pid = pid
    mLogData.version = self.m_iVersion
    mLogData.reward = -iValue
    record.log_db("huodong", "superrebate_reward",mLogData)
    if mReward.lastrebate then
        self:AddRewardRecord(oPlayer:GetName(),mReward.lastrebate)
    end
    self:GS2CSuperRebateRecord(oPlayer)
    self.m_mRewardInfo[pid] = nil
    oPlayer:RewardGoldCoin(iValue,self.m_sName)
    self:GS2CGameReward(oPlayer)
end

function CHuodong:GetLotteryFlag()
    local sLotteryFlag = string.format("%s_lottery",self.m_sName)
    return sLotteryFlag
end

function CHuodong:Lottery(oPlayer)
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        global.oNotifyMgr:Notify(pid,self:GetTextData(1002))
        return
    end
    local sLotteryFlag = self:GetLotteryFlag()
    local iLotteryLimit = res["daobiao"]["huodong"][self.m_sName]["config"][1]["lotterycnt"]
    local iLotteryCnt = oPlayer.m_oTodayMorning:Query(sLotteryFlag,0)
    if iLotteryCnt>=iLotteryLimit then
        global.oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return
    end
    local mReward = self.m_mRewardInfo[pid]
    if mReward then
        if mReward.value and mReward.value>0 then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1004))
        end
        return
    end
    local mLotteryRes = res["daobiao"]["huodong"][self.m_sName]["lottery"]
    iLotteryCnt  = iLotteryCnt +1 
    if not mLotteryRes[iLotteryCnt] then
        return
    end
    local mRatio = {}
    for _,mInfo in pairs(mLotteryRes[iLotteryCnt]["ratio"]) do
        mRatio[mInfo.id] = mInfo.ratio
    end
    local iRebateIndex = extend.Random.choosekey(mRatio)
    local mRebateRes = res["daobiao"]["huodong"][self.m_sName]["rebate"]
    if not mRebateRes[iRebateIndex] then
        return
    end

    local mLogData = {}
    mLogData.pid = pid
    mLogData.version = self.m_iVersion
    mLogData.lotterycnt = iLotteryLimit - iLotteryCnt
    mLogData.rebate = iRebateIndex
    record.log_db("huodong", "superrebate_lottery",mLogData)

    oPlayer.m_oTodayMorning:Set(sLotteryFlag,iLotteryCnt)

    self:Dirty()
    mReward = {}
    mReward.rebate = iRebateIndex
    self.m_mRewardInfo[pid] = mReward
    self:GS2CGameReward(oPlayer)
end

function CHuodong:AddRewardRecord(sName,iValue)
    table.insert(self.m_lRewardRecord,1,{name=sName,value=iValue})
    if self.m_lRewardRecord[RECORD_LIMIT] then
        self.m_mRewardInfo[RECORD_LIMIT]=nil
    end
end

function CHuodong:GS2CSuperRebateRecord(oPlayer)
    local mNet = {}
    mNet.recordlist = self.m_lRewardRecord
    oPlayer:Send("GS2CSuperRebateRecord",mNet)
end

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {}
    mNet.endtime = self:GetEndTime()
    oPlayer:Send("GS2CSuperRebateStart",mNet)
end

function CHuodong:GS2CGameEnd(oPlayer)
    oPlayer:Send("GS2CSuperRebateEnd",{})
end

function CHuodong:GS2CGameReward(oPlayer)
    local mReward = self.m_mRewardInfo[oPlayer:GetPid()] or {}
    local sLotteryFlag = self:GetLotteryFlag()
    local mNet = {}
    mNet.lotterycnt = oPlayer.m_oTodayMorning:Query(sLotteryFlag,0)
    mNet.value = mReward.value or 0
    mNet.rebate = mReward.rebate or 0
    oPlayer:Send("GS2CSuperRebateReward",mNet)
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
        "101 活动开始\nhuodongop superrebate 101",
        "102 活动结束\nhuodongop superrebate 102",
        "103 清空抽奖次数\nhuodongop superrebate 103",
    }
    --sethdcontrol superrebate default 0 60
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        self:TryGameStart(oPlayer,mArgs.day)
        if self:GetGameState() == GAME_START then
            oNotifyMgr:Notify(pid,"开启成功")
        else
            oNotifyMgr:Notify(pid,"开启失败")
        end
    elseif iFlag == 102 then
        self:GameEnd()
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 103 then
        local sLotteryFlag = self:GetLotteryFlag()
        oPlayer.m_oTodayMorning:Delete(sLotteryFlag)
        self:GS2CGameReward(oPlayer)
        oNotifyMgr:Notify(pid,"清空成功")
    end
end