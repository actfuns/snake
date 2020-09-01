local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local huodongbase = import(service_path("huodong.huodongbase"))
local analylog = import(lualib_path("public.analylog"))

local LIMIT_CNT = 30
local FIRSTMONTH_SPECIAL = 5
local LOTTERY_CNT = 7

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "每日签到"
inherit(CHuodong,huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_sName = sHuodongName
    return o
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:AddTrigger(oPlayer)
        self:InitSignin(oPlayer)
    end
    self:CheckSigninData()
    self:CheckKSData(oPlayer)
    if global.oToolMgr:IsSysOpen("SIGN", oPlayer,true) then 
        if oPlayer.m_oTodayMorning:Query("signin",0) == 0 then
            self:GS2CSignInOpenUI(oPlayer)
        end
    end
end

function CHuodong:NewHour(mNow)
    local iHour = mNow.date.hour
    if 5 == iHour then
        self:CheckSigninData()
    end
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade,iGrade)
    -- local LIMIT_GRADE = res["daobiao"]["open"]["SIGN"]["p_level"]
    -- if global.oToolMgr:IsSysOpen("SIGN", oPlayer,true) and iGrade == LIMIT_GRADE then 
    --     self:GS2CSignInOpenUI(oPlayer)
    -- end
end

function CHuodong:CheckSigninData(oPlayer)
    if not global.oToolMgr:IsSysOpen("SIGN", oPlayer,true) then 
        return
    end
    local mPlayer  = {}
    if oPlayer then
        mPlayer[oPlayer:GetPid()] = oPlayer
    else
        mPlayer = global.oWorldMgr:GetOnlinePlayerList()
    end
    local mTimeData = self:GetHuodongTimeData() 
    for pid,oPlayer in pairs(mPlayer) do
        local mSigninInfo = oPlayer:Query("signin_Info",{})
        if not mSigninInfo.signincnt or not mSigninInfo.curday then
            -- oPlayer:Set("signin_Info",{})
            -- self:InitSignin(oPlayer)
            record.warning(string.format("signin_info error %s %s %s",oPlayer:GetName(),pid,extend.Table.serialize(mSigninInfo)))
            goto continue
        end
        mSigninInfo = oPlayer:Query("signin_Info",{})
        if  mSigninInfo.signincnt>=LIMIT_CNT and mTimeData.day>mSigninInfo.curday then
            if oPlayer:Query("firstmonth", 1) == 1 then
                oPlayer:Set("firstmonth", 0)
            end
            oPlayer:Set("signin_Info",{})
            self:InitSignin(oPlayer)
        end
        ::continue::
    end
end

function CHuodong:OnLogout(oPlayer)
    oPlayer.m_oScheduleCtrl:DelEvent(self, "addactive")
end

function CHuodong:InitSignin(oPlayer)
    local mSigninInfo = oPlayer:Query("signin_Info",{})
    if not next(mSigninInfo) then
        local mTimeData = self:GetHuodongTimeData()
        mSigninInfo.rewardset = self:GetSigninRewardSet(oPlayer)
        mSigninInfo.signincnt = 0 --已经签到次数
        mSigninInfo.createday = mTimeData.day
        mSigninInfo.curday = 0
        mSigninInfo.firstmonth = mSigninInfo.firstmonth or 1
        mSigninInfo.extrasignincnt = 0  --可补签次数
        oPlayer:Set("signin_Info",mSigninInfo)
        --print("mSigninInfo",mSigninInfo)
    end
end

function CHuodong:AddTrigger(oPlayer)
    if not oPlayer then return end
    local func = function(sEvent, mData)
        self:DealActiveAddReplenish(mData)
    end
    oPlayer.m_oScheduleCtrl:AddEvent(self, "addactive", func)
end

function CHuodong:CheckKSData(oPlayer)
    local mKSSchedule = oPlayer.m_oTodayMorning:Query("ks_schedule")
    if not mKSSchedule then return end

    oPlayer.m_oTodayMorning:Set("ks_schedule", nil)
    local iAdd = mKSSchedule.addpoint
    local iTotal = mKSSchedule.total
    
    if not iAdd or not iTotal then return end

    local mData = {
        pid = oPlayer:GetPid(),
        addpoint = iAdd,
        totalpoint = iTotal,
    }
    self:DealActiveAddReplenish(mData)
end

function CHuodong:DealActiveAddReplenish(mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(mData.pid)
    if not oPlayer then
        return
    end
    if not global.oToolMgr:IsSysOpen("SIGN", oPlayer,true) then 
        return
    end
    local mTimeData = self:GetHuodongTimeData()
    local mSigninInfo = oPlayer:Query("signin_Info")
    if oPlayer.m_oTodayMorning:Query("extrasignincnt",0) ~=0 then
        return
    end
    if mSigninInfo.signincnt >=LIMIT_CNT then
        return
    end
    local iSigninCnt = mSigninInfo.signincnt
    if oPlayer.m_oTodayMorning:Query("signin", 0) == 0 then
        iSigninCnt = iSigninCnt + 1
    end
    if mTimeData.day - mSigninInfo.createday + 1<=iSigninCnt  + mSigninInfo.extrasignincnt then
        return
    end
    if mData.totalpoint<100 then
        return
    end
    if mData.addpoint<0 then
        return
    end
    oPlayer.m_oTodayMorning:Set("extrasignincnt",1)
    mSigninInfo.extrasignincnt = mSigninInfo.extrasignincnt +1
    oPlayer:Set("signin_Info",mSigninInfo)
    self:GS2CSignInMainInfo(oPlayer)
end
function CHuodong:BaseLogData(oPlayer)
    local mLogData = {}
    mLogData.pid = oPlayer:GetPid()
    mLogData.show_id = oPlayer:GetShowId()
    return mLogData
end

function CHuodong:GetHuodongTimeData()
    local mTimeData = {}
    mTimeData.day = get_morningdayno()
    return mTimeData
end

function CHuodong:GetRewardSetData()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["signin_reward_set"]
    return mRes
end

function CHuodong:GetFirstMonthSpecialData()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["signin_firstmonth_special"][1]["reward"]
    return mRes
end

function CHuodong:GetSigninRewardSet(oPlayer,iExcludeSet)
    local mRes = self:GetRewardSetData()
    local lRewardSetKey = table_key_list(mRes)
    if iExcludeSet then
        extend.Array.remove(lRewardSetKey,iExcludeSet)
    end
    assert(#lRewardSetKey>0,"error signinrewardset")
    local iRewardSet = extend.Random.random_choice(lRewardSetKey)
    --print("iRewardSet",iRewardSet)
    return iRewardSet
end

function CHuodong:ValidSignIn(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    if not oPlayer then
        return false
    elseif not global.oToolMgr:IsSysOpen("SIGN", oPlayer, true) then
        return false
    elseif oPlayer.m_oTodayMorning:Query("signin", 0) > 0 then
        oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return false
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<=0 then
        oNotifyMgr:Notify(pid,self:GetTextData(1002))
        return false
    end
    return true
end

function CHuodong:DoSignIn(oPlayer) --签到
    if not self:ValidSignIn(oPlayer) then
        return
    end
    local pid = oPlayer:GetPid()
    local mSigninInfo = oPlayer:Query("signin_Info",{})
    local iRewardSet = mSigninInfo.rewardset
    local iSigninCnt  = mSigninInfo.signincnt
    if iSigninCnt>= LIMIT_CNT then
        return
    end
    local mRewardSet = self:GetRewardSetData()
    mRewardSet = mRewardSet[iRewardSet]
    assert(mRewardSet,string.format("signinrewardset setindex error %s",iRewardSet))
    iSigninCnt = iSigninCnt +1 
    local iReward = mRewardSet["reward"][iSigninCnt]
    assert(iReward,string.format("signinrewardset rewardindex error %s %s",iRewardSet,iSigninCnt))
    local mTimeData = self:GetHuodongTimeData()
    mSigninInfo.signincnt = iSigninCnt
    mSigninInfo.curday = mTimeData.day
    if mSigninInfo.signincnt%LOTTERY_CNT ==0 then
        local iLottery = oPlayer:Query("signinlottery", 0)
        iLottery = iLottery +1 
        oPlayer:Set("signinlottery", iLottery)
    end
    if oPlayer:Query("firstmonth", 1) == 1 then
        if mSigninInfo.signincnt % FIRSTMONTH_SPECIAL == 0 then
            local iRemaninder = mSigninInfo.signincnt // FIRSTMONTH_SPECIAL
            local mSpecialData = self:GetFirstMonthSpecialData()
            iReward = mSpecialData[iRemaninder]
        end
    end
    if mSigninInfo.signincnt == LIMIT_CNT then
        mSigninInfo.extrasignincnt = 0
    end
    oPlayer.m_oTodayMorning:Set("signin", 1) 
    oPlayer:Set("signin_Info",mSigninInfo)
    self:Reward(pid,iReward)
    self:RefreshFortune(oPlayer)
    self:GS2CSignInMainInfo(oPlayer)
    
    analylog.LogSystemInfo(oPlayer, "signin", nil, {})
end


function CHuodong:ValidExtraSignIn(oPlayer)
    local mSigninInfo = oPlayer:Query("signin_Info",{})
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    if not oPlayer then
        return false
    elseif not global.oToolMgr:IsSysOpen("SIGN", oPlayer, true) then
        return false
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<=0 then
        oNotifyMgr:Notify(pid,self:GetTextData(1002))
        return false
    end
    if mSigninInfo.extrasignincnt<=0 then
        oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return false
    end
    return true
end

function CHuodong:DoExtraSign(oPlayer) --补签
    if not self:ValidExtraSignIn(oPlayer) then
        return
    end
    local pid = oPlayer:GetPid()
    local mSigninInfo = oPlayer:Query("signin_Info",{})
    local iRewardSet = mSigninInfo.rewardset
    local iSigninCnt  = mSigninInfo.signincnt
    local mTimeData = self:GetHuodongTimeData()
    if iSigninCnt>= LIMIT_CNT then
        return
    end
    local mRewardSet = self:GetRewardSetData()
    mRewardSet = mRewardSet[iRewardSet]
    assert(mRewardSet,string.format("signinrewardset setindex error %s",iRewardSet))
    iSigninCnt = iSigninCnt +1 
    local iReward = mRewardSet["reward"][iSigninCnt]
    assert(iReward,string.format("signinrewardset rewardindex error %s %s",iRewardSet,iSigninCnt))
    
    mSigninInfo.curday = mTimeData.day
    mSigninInfo.signincnt = iSigninCnt
    mSigninInfo.extrasignincnt = mSigninInfo.extrasignincnt -1
    if mSigninInfo.signincnt == LIMIT_CNT then
        mSigninInfo.extrasignincnt = 0
    end
    oPlayer:Set("signin_Info",mSigninInfo)
    if mSigninInfo.signincnt%LOTTERY_CNT ==0 then
        local iLottery = oPlayer:Query("signinlottery", 0)
        iLottery = iLottery +1 
        oPlayer:Set("signinlottery", iLottery)
    end
    if oPlayer:Query("firstmonth", 1) == 1 then
        if mSigninInfo.signincnt % FIRSTMONTH_SPECIAL == 0 then
            local iRemaninder = mSigninInfo.signincnt // FIRSTMONTH_SPECIAL
            local mSpecialData = self:GetFirstMonthSpecialData()
            iReward = mSpecialData[iRemaninder]
        end
    end

    self:RefreshFortune(oPlayer)
    self:Reward(pid,iReward)
    self:GS2CSignInMainInfo(oPlayer)
end


--抽奖
function CHuodong:Lottery(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<=0 then
        oNotifyMgr:Notify(pid,self:GetTextData(1002))
        return false
    end
    local iOldLottery = oPlayer:Query("signinlottery", 0)
    if iOldLottery <= 0 then return end
    local iNowLottery = iOldLottery - 1
    local mLogData = self:BaseLogData(oPlayer)
    mLogData.before = iOldLottery
    mLogData.after = iNowLottery
    record.user("huodong", "signin_lottery", mLogData)
    oPlayer:Set("signinlottery", iNowLottery)

    local iLottery = 1001
    local func = function (oPlayer)
        self:GS2CSignInMainInfo(oPlayer)
    end
    local oLotteryMgr = global.oLotteryMgr
    oLotteryMgr:Lottery(oPlayer, iLottery, nil, func)
end

function CHuodong:GS2CSignInOpenUI(oPlayer)
    oPlayer:Send("GS2CSignInOpenUI", {})
end

function CHuodong:RefreshFortune(oPlayer)
    if oPlayer.m_oTodayMorning:Query("signfortune", 0)>0 then
        return
    end
    local mFortune = res["daobiao"]["huodong"]["signin"]["fortune"]
    local lFortune = {}
    for _, mInfo in pairs(mFortune) do
        table.insert(lFortune, mInfo["fortuneid"])
    end
    local iFortune = extend.Random.random_choice(lFortune)
    local mLogData = self:BaseLogData(oPlayer)
    mLogData.fortune = iFortune
    record.user("huodong", "signin_fortune", mLogData)
    oPlayer.m_oTodayMorning:Set("signfortune", iFortune)
end

function CHuodong:GS2CSignInMainInfo(oPlayer)
    local mSigninInfo = oPlayer:Query("signin_Info",{}) 
    local mData = {}
    mData.extrasignincnt = mSigninInfo.extrasignincnt
    mData.rewardset = mSigninInfo.rewardset
    mData.fortune = oPlayer.m_oTodayMorning:Query("signfortune", 0)
    mData.lottery = oPlayer:Query("signinlottery", 0)
    mData.today = oPlayer.m_oTodayMorning:Query("signin", 0)
    mData.signincnt = mSigninInfo.signincnt
    mData.firstmonth = oPlayer:Query("firstmonth", 1)
    --print("GS2CSignInMainInfo",mData)
    oPlayer:Send("GS2CSignInMainInfo", mData)
end

function CHuodong:TestOp(iFlag, mArgs)
    local pid = mArgs[#mArgs]
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mSigninInfo = oPlayer:Query("signin_Info")
    local mCommand={
        "100 指令查看",
        "101 清除当日签到标记\nhuodongop signin 101",
        "102 增加补签次数\nhuodongop signin 102",
        "103 清除当日获得补签标记\nhuodongop signin 103",
        "104 增加抽奖次数\nhuodongop signin 104",
        "105 随机运势\nhuodongop signin 105",
        "106 清除所有签到进度\nhuodongop signin 106",
        "107清空首月登录\nhuodongop signin 107",
        "108设置本月签到天数3天\nhuodongop signin 108 {3}"
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            global.oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        oPlayer.m_oTodayMorning:Delete("signin") 
        self:GS2CSignInMainInfo(oPlayer)
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 102 then
        local mData = {}
        mData.pid = pid
        mData.totalpoint = 101
        mData.addpoint = 10
        self:DealActiveAddReplenish(mData)
    elseif iFlag == 103 then
        oPlayer.m_oTodayMorning:Delete("extrasignincnt")
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 104 then
        local iLottery = oPlayer:Query("signinlottery", 0)
        iLottery = iLottery +1 
        oPlayer:Set("signinlottery", iLottery)
        self:GS2CSignInMainInfo(oPlayer)
        oNotifyMgr:Notify(pid,"增加成功")
    elseif iFlag == 105 then
        oPlayer.m_oTodayMorning:Delete("signfortune")
        self:RefreshFortune(oPlayer)
        self:GS2CSignInMainInfo(oPlayer)
    elseif iFlag == 106 then
        oPlayer:Set("signin_Info",{})
        self:InitSignin(oPlayer)
        oNotifyMgr:Notify(pid,"清除成功")
        self:GS2CSignInMainInfo(oPlayer)
    elseif iFlag == 107 then
        oPlayer:Set("firstmonth",nil)
        self:GS2CSignInMainInfo(oPlayer)
    elseif iFlag == 108 then
        local mSigninInfo = oPlayer:Query("signin_Info", {})
        local iSetCnt = math.min(mArgs[1], 30)
        mSigninInfo.signincnt = math.max(0, iSetCnt)
        oPlayer:Set("signin_Info", mSigninInfo)
        self:GS2CSignInMainInfo(oPlayer)
    elseif iFlag ==201 then
        self:DoSignIn(oPlayer)
    elseif iFlag == 202 then
        self:DoExtraSign(oPlayer)
    elseif iFlag == 203 then
        self:Lottery(oPlayer)
    end
end

