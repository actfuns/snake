local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local util = import(lualib_path("public.util"))
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

--状态
local STATUS = {
    NOBUY = 0, --没购买
    BUY = 1, --买了,没到返还时间
    REWARD = 2, --到了返还时间,可领取
    REWARDED = 3, --已领取
}

--类型
local TYPE = {
    EQUIP = 1, --豪华礼包
    GIFT = 2, --外观礼包
    HORSE = 3, --飞行坐骑
}

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "0元大礼包"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mInfo = {}
    return o
end

function CHuodong:Save()
    local mData = {}
    mData.info = self.m_mInfo
    return mData
end

function CHuodong:Load(mData)
    self:Dirty()
    mData = mData or {}
    self.m_mInfo = mData.info or {}
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong zeroyuan without data"
    end
    self:Dirty()
    for iPid, mData in pairs(mFromData.info or {}) do
        self.m_mInfo[iPid] = mData
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:AddUpgradeEvent(oPlayer)
    local bOpen = global.oToolMgr:IsSysOpen("ZEROYUAN", oPlayer, true)
    if not bOpen then return end

    --老玩家达到等级的,按第一次登录算活动时间
    self:TryInitInfo(oPlayer)

    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mInfo[iPid]

    local iCurTime = get_time()
    local iActEndTime = mInfo.activity_endtime
    if get_time() < iActEndTime then
        local iBackNum = 0
        for _, iType in pairs(TYPE) do
            local mTypeInfo = mInfo[iType]
            if mTypeInfo.status == STATUS.BUY then 
                if mTypeInfo.back_endtime > iCurTime then
                    local iTypeSub = mTypeInfo.back_endtime - iCurTime
                    self:AddBackCb(oPlayer, iType, iTypeSub)
                else
                    self:OnBack(iPid, iType)
                end
            elseif mTypeInfo.status == STATUS.REWARDED then
                iBackNum = iBackNum + 1
            end
        end
        
        if iBackNum < 3 then
            local iSub = iActEndTime - iCurTime
            self:AddActEndCb(oPlayer, iSub)

            self:GS2CZeroYuanInfo(oPlayer)
        end
    else
        if not mInfo.mail_tag then
            self:DealEndMail(iPid)
        end
    end
end

function CHuodong:TryInitInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    if self.m_mInfo[iPid] then return end

    self:Dirty()
    local mConfig = self:GetConfig()
    local iActEndTime = get_time() + mConfig.act_day*24*60*60
    self.m_mInfo[iPid] = {
        activity_endtime = iActEndTime,
        mail_tag = false,
    }

    for _, iType in pairs(TYPE) do
        local mData = self:GetActivityConfig(iType)
        local iLimitBuyTime = mData.limit_buy_time
        local iLimitBuyEndTime = get_time() + iLimitBuyTime * 60*60
        self.m_mInfo[iPid][iType] = {
            type = iType,
            status = STATUS.NOBUY,
            buy_endtime = iLimitBuyEndTime,
            back_endtime = 0,
        }
    end
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    local bOpen = global.oToolMgr:IsSysOpen("ZEROYUAN", oPlayer, true)
    if not bOpen then return end

    local iPid = oPlayer:GetPid()
    local iGrade = oPlayer:GetGrade()
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("ZEROYUAN")
    if iGrade >= iOpenGrade and not self.m_mInfo[iPid] then
        self:TryInitInfo(oPlayer)
        self:GS2CZeroYuanInfo(oPlayer)
    end
end

function CHuodong:AddActEndCb(oPlayer, iTime)
    local iPid = oPlayer:GetPid()
    local func = function()
        local oHd = global.oHuodongMgr:GetHuodong("zeroyuan")
        if oHd then
            oHd:OnActEnd(iPid)
        end
    end
    local sStr = "ZeroYuanEnd"
    oPlayer:DelTimeCb(sStr)
    oPlayer:AddTimeCb(sStr, iTime*1000, func)
end

function CHuodong:OnActEnd(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:GS2CZeroYuanInfo(oPlayer, true)
        self:DealEndMail(iPid)
    end
end

function CHuodong:DealEndMail(iPid)
    local mConfig = self:GetConfig()
    local iMailId = mConfig.mail_id

    local iBackGoldCoin = 0
    for _, iType in pairs(TYPE) do
        local iStatus = self.m_mInfo[iPid][iType].status
        local mActConfig = self:GetActivityConfig(iType)
        if iStatus == STATUS.BUY or iStatus == STATUS.REWARD then
            iBackGoldCoin = iBackGoldCoin + mActConfig.back_pay
        end
    end

    if iBackGoldCoin > 0 then
        local sSid = string.format("1004(Value=%d)", iBackGoldCoin)
        local oItem = global.oItemLoader:ExtCreate(sSid)
        oItem:Bind(iPid)
        self:SendMail(iPid, iMailId, {items = {oItem}}, {num=iBackGoldCoin})    
    end
    self:Dirty()
    self.m_mInfo[iPid].mail_tag = true
end

function CHuodong:AddBackCb(oPlayer, iType, iTime)
    local iPid = oPlayer:GetPid()
    local func = function()
        local oHd = global.oHuodongMgr:GetHuodong("zeroyuan")
        if oHd then
            oHd:OnBack(iPid, iType)
        end
    end
    local sStr = string.format("ZeroYuanType%d", iType)
    oPlayer:DelTimeCb(sStr)
    oPlayer:AddTimeCb(sStr, iTime*1000, func)
end

function CHuodong:OnBack(iPid, iType)
    local mInfo = self.m_mInfo[iPid]
    if mInfo and mInfo[iType].status == STATUS.BUY then
        self:Dirty()
        mInfo[iType].status = STATUS.REWARD
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:GS2CZeroYuanInfoUnit(oPlayer, iType)
    end
end

function CHuodong:C2GSZeroYuanBuy(oPlayer, iType)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetActivityConfig(iType)
    if not self:ValidStatus(oPlayer, iType, true) then
        return 
    end

    if iType == TYPE.EQUIP and oPlayer:GetGrade() < mConfig.limit_level then
        local sMsg = self:GetTextData(1001)
        global.oNotifyMgr:Notify(iPid, sMsg)
        return
    end

    local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    local iNeedSize = get_time() <= self.m_mInfo[iPid][iType].buy_endtime and 7 or 6
    if iSize < iNeedSize then
        local sMsg = self:GetTextData(1007)
        global.oNotifyMgr:Notify(iPid, sMsg)
        return
    end

    self:Dirty()
    local iPayGoldCoin = mConfig.pay
    if not oPlayer:ValidTrueGoldCoin(iPayGoldCoin) then return end

    if iPayGoldCoin > 0 then
        oPlayer:ResumeTrueGoldCoin(iPayGoldCoin, "0元大礼包", {cancel_rank=1})
    end
    local iBackDay = mConfig.back_day
    local iBackEndTime = get_time() + iBackDay * 24*60*60
    self.m_mInfo[iPid][iType].status = STATUS.BUY
    self.m_mInfo[iPid][iType].back_endtime = iBackEndTime
    self:AddBackCb(oPlayer, iType, iBackEndTime - get_time())

    local iRewardId = mConfig.reward_id
    self:Reward(iPid, iRewardId)

    local iLimitReard = mConfig.limit_buy_reward_id
    if get_time() <= self.m_mInfo[iPid][iType].buy_endtime and iLimitReard > 0 then
        self:Reward(iPid, iLimitReard)
    end

    local sMsg = self:GetTextData(1006)
    sMsg = util.FormatColorString(sMsg, {day = iBackDay})
    global.oNotifyMgr:Notify(iPid, sMsg)

    self:GS2CZeroYuanInfoUnit(oPlayer, iType)
end

function CHuodong:C2GSZeroYuanReward(oPlayer, iType)
    if not self:ValidStatus(oPlayer, iType, false) then
        local bOpen = global.oToolMgr:IsSysOpen("ZEROYUAN")
        if bOpen then
            local sMsg = self:GetTextData(1002)
            global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
        end
        return
    end

    local mConfig = self:GetActivityConfig(iType)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mInfo[iPid][iType]
    if mInfo.status == STATUS.REWARD then
        self:Dirty()
        local iBackGoldCoin = mConfig.back_pay
        oPlayer:RewardGoldCoin(iBackGoldCoin, "0元大礼包返还")
        self.m_mInfo[iPid][iType].status = STATUS.REWARDED
        self:GS2CZeroYuanInfoUnit(oPlayer, iType)

        local sMsg = self:GetTextData(1003)
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CHuodong:ValidStatus(oPlayer, iType, bBuy)
    local bOpen = global.oToolMgr:IsSysOpen("ZEROYUAN")
    if not bOpen then return end

    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mInfo[iPid]
    if not mInfo or not mInfo[iType] then return end

    local bIsNoBuy = mInfo[iType].status == STATUS.NOBUY
    local bIsReward = mInfo[iType].status == STATUS.REWARD
    local bStatus = bBuy and bIsNoBuy or bIsReward
    return bStatus
end

function CHuodong:GS2CZeroYuanInfo(oPlayer, bEnd)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mInfo[iPid]
    local mTmpInfo = {}
    for _, iType in pairs(TYPE) do
        table.insert(mTmpInfo, mInfo[iType])
    end

    local iEndTime = bEnd and 0 or mInfo.activity_endtime
    local mData = {
        activity_endtime = iEndTime,
        info = mTmpInfo,
    }
    oPlayer:Send("GS2CZeroYuanInfo", mData)
end

function CHuodong:GS2CZeroYuanInfoUnit(oPlayer, iType)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mInfo[iPid][iType]
    local mData = {
        unit_info = mInfo
    }
    oPlayer:Send("GS2CZeroYuanInfoUnit", mData)
end

function CHuodong:GetConfig()
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    assert(mConfig, string.format("CHuodong %s GetConfig error", self.m_sName))
    return mConfig
end

function CHuodong:GetActivityConfig(iType)
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["activity"][iType]
    assert(mConfig, string.format("CHuodong %s GetActivityConfig error", self.m_sName))
    return mConfig
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 购买\nhuodongop zeroyuan 101 {type=1}",
        "102 n秒后可领\nhuodongop zeroyuan 102 {type=1, time=3}",
        "103 领取\nhuodongop zeroyuan 103 {type=1}",
        "104 n秒后活动结束\nhuodongop zeroyuan 104",
        "105 清除玩家信息\nhuodongop zeroyuan 105",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        local iType = mArgs.type or 1
        local mInfo = self.m_mInfo[pid][iType]
        if mInfo.status == STATUS.NOBUY then
            self:C2GSZeroYuanBuy(oPlayer, iType)
        else
           oNotifyMgr:Notify(pid,"已购买过了") 
        end
    elseif iFlag == 102 then
        local iType = mArgs.type or 1
        local iTime = mArgs.time or 3
        local mInfo = self.m_mInfo[pid][iType]
        if mInfo.status == STATUS.BUY then
            local iBackEndTime = get_time() + iTime
            mInfo.back_endtime = iBackEndTime
            self:AddBackCb(oPlayer, iType, iTime)
            local sMsg = string.format("%d秒后可领取返还", iTime)
            oNotifyMgr:Notify(pid, sMsg)
        else
           oNotifyMgr:Notify(pid,"状态不是已购买") 
        end
    elseif iFlag == 103 then
        local iType = mArgs.type or 1
        self:C2GSZeroYuanReward(oPlayer, iType)
    elseif iFlag == 104 then
        local iTime = mArgs.time or 3
        local mInfo = self.m_mInfo[pid]
        local iActEndTime = get_time()  + iTime
        mInfo.activity_endtime = iActEndTime
        self:AddActEndCb(oPlayer, iTime)
        local sMsg = string.format("%d秒后活动结束", iTime)
        oNotifyMgr:Notify(pid, sMsg)
    elseif iFlag == 105 then
        self.m_mInfo[pid] = nil
        self:TryInitInfo(oPlayer)
        self:GS2CZeroYuanInfo(oPlayer)
        oNotifyMgr:Notify(pid,"清空玩家数据")
    elseif iFlag == 106 then
        self:GS2CZeroYuanInfo(oPlayer) 
    elseif iFlag == 107 then
        local iRewardId = mArgs.reward
        if iRewardId then
            self:Reward(pid, iRewardId)
        end
    end
end
