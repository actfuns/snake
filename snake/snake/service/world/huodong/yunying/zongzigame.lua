local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "粽子大赛"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_mExchange = {}
    self.m_mJoinList = {}
    self.m_iStartTime = 0
    self.m_iEndTime = 0
end

function CHuodong:Save()
    local mData = {}
    mData.exchange = self.m_mExchange
    mData.joinlist = self.m_mJoinList
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime
    return mData
end

function CHuodong:Load(mData)
    if not mData then return end

    self.m_mExchange = mData.exchange
    self.m_mJoinList = mData.joinlist
    self.m_iStartTime = mData.starttime
    self.m_iEndTime = mData.endtime
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:AfterLoad()
    self:CheckTimer()
end

function CHuodong:NewHour(mNow)
    self:CheckTimer()
end

function CHuodong:GetVoteKey()
    local mTime = get_timetbl()
    return "zongzi_vote"..mTime.date.year
end

function CHuodong:CheckTimer(bFirst)
    local iCurrTime = get_time()
    if iCurrTime >= self.m_iStartTime then
        if bFirst then
            self:GameStart()
        end
    else
        local iDelta = self.m_iStartTime - iCurrTime
        self:DelTimeCb("GameStart")
        self:AddTimeCb("GameStart", iDelta * 1000, function()
            self:GameStart()
        end)
    end
    if iCurrTime >= self.m_iEndTime then
        if bFirst then
            self:GameOver()
        end
    else
        local iDelta = self.m_iEndTime - iCurrTime
        self:DelTimeCb("GameOver")
        self:AddTimeCb("GameOver", iDelta * 1000, function()
            self:GameOver()
        end)
    end
end

function CHuodong:GameStart()
    self:TryStartRewardMonitor()

    local lPid = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    global.oToolMgr:ExecuteList(lPid, 500, 1000, 0, "ZongziGameStart", function(iPid)
        self:GameStartForPlayer(iPid)
    end,
    function()
        global.oNotifyMgr:WorldBroadcast("GS2CZongziGameState", {open=1})
    end)
end

function CHuodong:GameStartForPlayer(iPid)
    if not self:InHuodongTime() then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:CheckAddFirstVote(oPlayer)
        local mNet = self:PackZongziGame(oPlayer)
        oPlayer:Send("GS2CRefreshZongziGame", mNet)
    end
end

function CHuodong:GameOver()
    global.oNotifyMgr:WorldBroadcast("GS2CZongziGameState", {open=0})

    local mJoin = self.m_mJoinList
    local iReward = self:CheckWinner()
    local lPid = table_key_list(mJoin)
    global.oToolMgr:ExecuteList(lPid, 500, 1000, 0, "ZongziGameOver", function(iPid)
        self:GameOverForPlayer(iPid, mJoin, iReward)
    end)
    self:Dirty()
    self:Init()
end

function CHuodong:GameOverForPlayer(iPid, mJoin, iReward)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer.m_oScheduleCtrl:DelEvent(self, "addactive")
    end

    if mJoin[iPid] then
        self:AsyncReward(iPid, iReward, function(mReward)
            self:TrueReward(iPid, iReward, mReward)
        end)
    end
end

function CHuodong:TrueReward(iPid, iReward, mReward)
    if not self:CheckRewardMonitor(iPid, iReward, 1) then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        oPlayer = global.oWorldMgr:GetProfile(iPid)
    end
    assert(oPlayer)
    self:SendRewardContent(oPlayer, mReward)
end

function CHuodong:InHuodongTime()
    local iTime = get_time()
    return iTime >= self.m_iStartTime and iTime < self.m_iEndTime
end

function CHuodong:RegisterHD(mInfo, bClose)
    if not global.oToolMgr:IsSysOpen("ZONGZIGAME") then
        return false, "system is close"
    end

    if bClose then
        self:GameOver()
    else
        if self:InHuodongTime() then
            return false, self.m_sTempName .. "has started"
        end
        local iStartTime = mInfo.start_time
        local iEndTime = mInfo.end_time
        assert(iStartTime < iEndTime)

        self:SetGameTime(iStartTime, iEndTime)
    end
    return true
end

function CHuodong:SetGameTime(iStartTime, iEndTime)
    self.m_iStartTime = iStartTime
    self.m_iEndTime = iEndTime
    self:Dirty()
    self:CheckTimer(true)

    record.info("set huodong time start:" .. get_format_time(iStartTime) .. ",end:" .. get_format_time(iEndTime))
end

function CHuodong:AddExchange(iType, iAmount)
    if not self.m_mExchange[iType] then
        self.m_mExchange[iType] = 0
    end
    self.m_mExchange[iType] = self.m_mExchange[iType] + iAmount
    self:Dirty()
end

function CHuodong:GetExchange(iType)
    return self.m_mExchange[iType] or 0
end

function CHuodong:CheckWinner()
    local mConfig = self:GetConfig()
    if self:GetExchange(1) > self:GetExchange(2) then
        return mConfig.sweet_reward
    end
    if self:GetExchange(1) < self:GetExchange(2) then
        return mConfig.salty_reward
    end
    --如果打平， 咸的加10票获胜
    self:AddExchange(2, 10)
    return mConfig.salty_reward
end

function CHuodong:AddJoinPid(iPid, iAmount)
    if not self.m_mJoinList[iPid] then
        self.m_mJoinList[iPid] = 0
    end
    self.m_mJoinList[iPid] = self.m_mJoinList[iPid] + iAmount
    self:Dirty()
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if self:InHuodongTime() then
        self:CheckAddFirstVote(oPlayer)
        self:AddEventTrigger(oPlayer)
        oPlayer:Send("GS2CZongziGameState", {open=1})
    end
end

function CHuodong:CheckAddFirstVote(oPlayer)
    local sKey = "zongzi_game"..db_key(self.m_iStartTime)
    if not oPlayer:Query(sKey) then
        oPlayer:Set(sKey, 1)
        local mConfig = self:GetConfig()
        local sKey = self:GetVoteKey()
        oPlayer:Add(sKey, mConfig.auto_add_vote)
    end
end

function CHuodong:AddEventTrigger(oPlayer)
    if not oPlayer then return end

    local func = function(sEvent, mData)
        self:CheckAddVote(mData)
    end
    oPlayer.m_oScheduleCtrl:AddEvent(self, "addactive", func)
end

function CHuodong:CheckAddVote(mData)
    if not self:InHuodongTime() then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(mData.pid)
    if not oPlayer then return end

    if not global.oToolMgr:IsSysOpen("ZONGZIGAME", oPlayer) then
        return
    end

    if mData.addpoint and mData.addpoint <= 0 then
        return
    end
  
    local mConfig = self:GetConfig()
    local iTotalPoint = mData.totalpoint 
    if iTotalPoint < mConfig.activepoint then
        return
    end
    local iAddPoint = mData.addpoint
    if iTotalPoint - iAddPoint >= mConfig.activepoint then
        return
    end

    local iAddVote = mConfig.add_vote 
    self:TryAddExchange(oPlayer, iAddVote, "addvote")
end

function CHuodong:ZongziExchange(oPlayer, iType, bGoldCoin)
    if not global.oToolMgr:IsSysOpen("ZONGZIGAME", oPlayer) then
        return  
    end

    local iPid = oPlayer:GetPid()
    if not self:InHuodongTime() then
        self:Notify(iPid, 1002)
        return
    end

    local sType = self:GetTypeDesc(iType)
    if not sType then
        self:Notify(iPid, 1003)
        return
    end
  
    local mConfig = self:GetConfig() 
    local iAddAmount = 0
    local sReason = "兑换粽子-"..sType 
    local iExchangeSid = mConfig[sType]
    local iGoldCoin = 0
    local iCostVote = 0
    local sKey = self:GetVoteKey()

    if not bGoldCoin then
        local iHasAmount = oPlayer:Query(sKey, 0)
        local iCostAmount = 1
        if iHasAmount < iCostAmount then
            self:Notify(iPid, 1004)
            return
        end
    
        iAddAmount = iHasAmount // iCostAmount
        iCostVote = iAddAmount * iCostAmount
        if not oPlayer:ValidGive({[iExchangeSid] = iAddAmount}) then
            self:Notify(iPid, 1005)
            return
        end
      
    else
        local iBuyCnt = oPlayer.m_oTodayMorning:Query("zongzi_buy", 0)
        if iBuyCnt >= mConfig.buy_limit then
            self:Notify(iPid, 1006)
            return
        end
        iGoldCoin = formula_string(mConfig.goldcoin_cost, {num=iBuyCnt+1})
        if not oPlayer:ValidGoldCoin(iGoldCoin) then
            return
        end
        iAddAmount = 1
    end

    if iAddAmount <= 0 then return end

    if not oPlayer:ValidGive({[iExchangeSid] = iAddAmount}) then
        self:Notify(iPid, 1005)
        return
    end

    if iGoldCoin > 0 then
        oPlayer:ResumeGoldCoin(iGoldCoin, sReason)
        oPlayer.m_oTodayMorning:Add("zongzi_buy", 1)
    end
    if iCostVote > 0 then
        oPlayer:Add(sKey, -iCostVote)
    end

    oPlayer:RewardItems(iExchangeSid, iAddAmount, sReason)
    self:AddExchange(iType, iAddAmount)
    self:AddJoinPid(iPid, iAddAmount)
    self:RefreshZongziGame(oPlayer)
    
    local mLogData = oPlayer:LogData()
    mLogData.action = "exchange"
    mLogData.amount = iAddAmount
    mLogData.reason = sReason
    mLogData.goldcoin = iGoldCoin
    mLogData.costvote = iCostVote
    record.log_db("huodong", "zongzigame", {info = mLogData})
end

function CHuodong:TryAddExchange(oPlayer, iAddVote, sReason)
    local sKey = self:GetVoteKey()
    oPlayer:Add(sKey, iAddVote)
    self:RefreshZongziGame(oPlayer)
    self:Notify(oPlayer:GetPid(), 1001, {amount = iAddVote})

    local mLogData = oPlayer:LogData()
    mLogData.action = sReason
    mLogData.amount = iAddVote
    record.log_db("huodong", "zongzigame", {info = mLogData})
end

function CHuodong:RefreshZongziGame(oPlayer)
    local mNet = self:PackZongziGame(oPlayer)
    oPlayer:Send("GS2CRefreshZongziGame", mNet)
end

function CHuodong:PackZongziGame(oPlayer)
    local mNet = {
        zongzi1 = self.m_mExchange[1],
        zongzi2 = self.m_mExchange[2],
        starttime = self.m_iStartTime,
        endtime = self.m_iEndTime,
    }
    if oPlayer then
        local sKey = self:GetVoteKey()
        mNet.vote_num = oPlayer:Query(sKey, 0)
        mNet.vote_buy = oPlayer.m_oTodayMorning:Query("zongzi_buy", 0)
    end
    return mNet
end

function CHuodong:GetTypeDesc(iType)
    local mType = {
        [1] = "sweet",
        [2] = "salty",
    }
    return mType[iType]
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["zongzigame"]["config"][1]
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 开游戏
        102 - 关游戏
        103 - 加票数 {1}
        ]])
    elseif iFlag == 101 then
        self:SetGameTime(get_time(), get_time() + 3600)
    elseif iFlag == 102 then
        self:GameOver()
    elseif iFlag == 103 then
        local sKey = self:GetVoteKey()
        oMaster:Add(sKey, mArgs[1] or 1)
        self:RefreshZongziGame(oMaster)
    elseif iFlag == 104 then
        self:ZongziExchange(oMaster, 1, true)
    elseif iFlag == 105 then
        local sKey = self:GetVoteKey()
        oMaster:Set(sKey, 1)
        self:RefreshZongziGame(oMaster)
    end
end

