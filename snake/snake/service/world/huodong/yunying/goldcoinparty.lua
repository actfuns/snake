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

local STATE_REWARD = 1
local STATE_REWARDED = 2


local LOTTERY_GOLDCOIN = 1
local LOTTERY_ITEM = 2
local LOTTERY_FLAG = {
    [LOTTERY_GOLDCOIN] = {
            [1] = "goldcoin_cost1",
            [10] = "goldcoin_cost10",
        },
    [LOTTERY_ITEM] = {
            [1] = "item_cost1",
            [10] = "item_cost10",
    },
}

local RARE_REWARD = 100

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "元宝狂欢"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mRewardInfo = {}
    o.m_mRecordInfo = {}
    o.m_iAllGoldCoin = 0
    o.m_iOpenDay = 0
    o.m_iGameDay = 0
    return o
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:Save()
    local mData = {}
    mData.openday = self.m_iOpenDay
    mData.rewardinfo = self.m_mRewardInfo
    mData.gameday = self.m_iGameDay
    mData.recordinfo = self.m_mRecordInfo
    mData.allgoldcoin = self.m_iAllGoldCoin
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iOpenDay = mData.openday or 0
    self.m_mRewardInfo = mData.rewardinfo or {}
    self.m_iGameDay = mData.gameday or 0
    self.m_iAllGoldCoin = mData.allgoldcoin or 0
    self.m_mRecordInfo = mData.recordinfo or {}
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong goldcoinparty without data"
    end
    self:Dirty()
    for iPid, mReward in pairs(mFromData.rewardinfo or {}) do
        self.m_mRewardInfo[iPid] = mReward
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
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

function CHuodong:GetConfig()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    return mRes
end

function CHuodong:GetGameDay()
    if self.m_iGameDay>0 then
        return self.m_iGameDay
    end
    local mConfig = self:GetConfig()
    local iGameDay = mConfig.gameday
    return  iGameDay
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
            local sHDKey = mInfo.hd_key
            self:TryGameStart(nil,iGameDay)
        end
    end
    return true
end

function CHuodong:TryGameStart(oPlayer,iGameDay)
    if self:GetGameState() == GAME_START then
        record.warning(string.format("%s gamestart error1 %s", self.m_sName,iGameDay)) 
        return
    end
    self:GameStart(iGameDay)
end

function CHuodong:GameStart(iGameDay)
    self:Dirty()
    local mConfig = self:GetConfig()
    self.m_mRewardInfo = {}
    self.m_mRecordInfo = {}
    self.m_iOpenDay = get_morningdayno()
    self.m_iGameDay = iGameDay
    self.m_iAllGoldCoin = mConfig.goldcoin_init
    record.info(string.format("%s GameStart %s %s",self.m_sName,self.m_iOpenDay,iGameDay))
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CGoldCoinPartyStart",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {},
        exclude = {},
    })
    global.oHotTopicMgr:Register(self.m_sName)
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
    record.info(string.format("%s GameEnd %s",self.m_sName,self.m_iOpenDay))
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self:CheckGiveReward()
    self.m_mRewardInfo = {}
    self.m_iOpenDay = 0
    self.m_iGameDay = 0
    self.m_iAllGoldCoin = 0
    self.m_mRecordInfo = {}
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CGoldCoinPartyEnd",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {},
        exclude = {},
    })
end

function CHuodong:GetDegreeReward(oPlayer,iDegree)
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        return
    end
    local mReward = self.m_mRewardInfo[pid] 
    if not mReward then
        return
    end
    if not mReward.rewardlist then
        return
    end
    if not mReward.rewardlist[iDegree] then
        return
    end
    if mReward.rewardlist[iDegree] ~= STATE_REWARD then
        return
    end
    local mDegreeRes = res["daobiao"]["huodong"][self.m_sName]["degree_reward"]
    if not mDegreeRes[iDegree] then
        return
    end
    local iReward = mDegreeRes[iDegree]["reward"]
    if global.oToolMgr:GetItemRewardCnt(self.m_sName,iReward) > oPlayer.m_oItemCtrl:GetCanUseSpaceSize() then
        global.oNotifyMgr:Notify(pid,"你的背包已满，请清理后再领取")
        return 
    end
    local mLogData = {}
    mLogData.pid = pid
    mLogData.degree = iDegree
    record.log_db("huodong", "goldcoinparty_degree",mLogData)
    self:Dirty()
    mReward.rewardlist[iDegree] = STATE_REWARDED
    self.m_mRewardInfo[pid] = mReward
    
    self:Reward(pid,iReward)
    self:GS2CGameReward(oPlayer)
end

function CHuodong:ValidLottery(oPlayer,iLottery,iFlag)
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        global.oNotifyMgr:Notify(pid,"活动已结束")
        return false
    end
    local mCostFlag = LOTTERY_FLAG[iFlag]
    if not mCostFlag then
        return false
    end
    if not mCostFlag[iLottery] then
        return false
    end
    local mConfig = self:GetConfig()
    local iNeedValue = mConfig[mCostFlag[iLottery]]
    assert(iNeedValue>0,string.format("%s lottery %s",self.m_sName,iNeedValue))
    if iFlag == LOTTERY_GOLDCOIN then
        if oPlayer:GetProfile():TrueGoldCoin() < iNeedValue then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1004))
            return
        end
    else
        if oPlayer:GetItemAmount(mConfig.hditem)<iNeedValue then
            if  iLottery == 10 then
                global.oNotifyMgr:Notify(pid,self:GetTextData(1002))
            end
            return false
        end
    end

    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<iLottery then
        global.oNotifyMgr:Notify(pid,self:GetTextData(1001))
        return false
    end
    return true
end

function CHuodong:GetLotteryReward(oPlayer,iLottery,iFlag)
    if not self:ValidLottery(oPlayer,iLottery,iFlag) then
        return 
    end
    local oChatMgr = global.oChatMgr
    self:Dirty()
    local pid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iNeedValue = mConfig[LOTTERY_FLAG[iFlag][iLottery]]
    local iRewardPoint = mConfig.point
    local mLogData = {}
    mLogData.pid = pid
    mLogData.flag = iFlag
    mLogData.lottery = iLottery
    record.log_db("huodong", "goldcoinparty_lottery",mLogData)
    local iAddGoldCoin = 0
    if iFlag == LOTTERY_GOLDCOIN then
        oPlayer:GetProfile():ResumeTrueGoldCoin(iNeedValue, self.m_sName)
        iAddGoldCoin =  formula_string(mConfig.goldcoin_ratio,{value = iNeedValue})
    else
        oPlayer:RemoveItemAmount(mConfig.hditem,iNeedValue,self.m_sName)
        iAddGoldCoin =  formula_string(mConfig.item_ratio,{amount = iNeedValue})
    end
    local iPreAllGoldCoin = self.m_iAllGoldCoin
    self.m_iAllGoldCoin = self.m_iAllGoldCoin + iAddGoldCoin
    if not is_production_env() then
        oChatMgr:HandleMsgChat(oPlayer,string.format("奖金池变化%d = %d + %d",self.m_iAllGoldCoin,iPreAllGoldCoin,iAddGoldCoin))
    end
    self:TriggerAllGoldCoinChuanWen(iPreAllGoldCoin,self.m_iAllGoldCoin)
    local itemlist = {}
    local mNet = {}
    local iAmount = 0
    for i=1,iLottery do
        local mResult = self:LotteryReward(pid,iLottery,iFlag)
        local itemobj = mResult.itemobj
        table.insert(itemlist,mResult.itemobj)
        iAmount = iAmount + itemobj:GetAmount()
        local mSubNet = {pos = mResult.pos,amount = itemobj:GetAmount()}
        if itemobj:ItemType() == "virtual" then
            mSubNet.amount=itemobj:GetData("Value",0)
        end
        table.insert(mNet,mSubNet)
        self:ItemAnnounce(oPlayer,itemobj,mResult)
        if mResult.rare>0 then
            local iRecordLen = #self.m_mRecordInfo
            if iRecordLen==mConfig.record_limit then
                self.m_mRecordInfo[iRecordLen] = nil
            end
            table.insert(self.m_mRecordInfo,1,{name = oPlayer:GetName(),pos = mResult.pos,goldcoin = itemobj:GetData("Value",0)})
        end
    end
    local mArgs = {cancel_tip=true,cancel_chat=true,refresh=1}
    oPlayer:GiveItemobj(itemlist,self.m_sName,mArgs)
    oPlayer:Send("GS2CGoldCoinPartyLottery",{rewardlist=mNet})
    local mReward = self.m_mRewardInfo[pid] or {}
    if not mReward.point then
        mReward.point = 0
    end
    mReward.point = mReward.point + iLottery*iRewardPoint
    local lDegreeReward = mReward.rewardlist or {}
    local mDegreeRes = res["daobiao"]["huodong"][self.m_sName]["degree_reward"]
    for iIndex,mInfo in ipairs(mDegreeRes) do
        if not lDegreeReward[iIndex] then
            lDegreeReward[iIndex]  = 0
        end
        if mReward.point>=mInfo.degree and lDegreeReward[iIndex] == 0 then
            lDegreeReward[iIndex] =STATE_REWARD
        end
    end
    mReward.rewardlist = lDegreeReward
    self.m_mRewardInfo[pid] = mReward
    self:GS2CGameReward(oPlayer)
    self:BroadCastInfo()
end

function CHuodong:GetLotteryLevel()
    local mLotteryLevel = res["daobiao"]["huodong"][self.m_sName]["lottery_level"]
    local iLevel = 0
    local lKey = table_key_list(mLotteryLevel)
    table.sort(lKey,function (a,b)
        if a>b then return true end
    end)
    for _,iGoldCoin in ipairs(lKey) do
        if self.m_iAllGoldCoin>=iGoldCoin then
            iLevel = mLotteryLevel[iGoldCoin]["level"]
            break
        end
    end
    return iLevel
end

function CHuodong:LotteryReward(pid,iLottery,iFlag)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local mConfig = self:GetConfig()
    local mLotteryReward = res["daobiao"]["huodong"][self.m_sName]["lottery_reward"]
    local mLotteryLevel = res["daobiao"]["huodong"][self.m_sName]["lottery_level"]
    local mLotteryBonusPool = res["daobiao"]["huodong"][self.m_sName]["lottery_bonuspool"]
    local mRatio = {}
    local iLotteryLevel = self:GetLotteryLevel()
    for iIndex,mInfo in pairs(mLotteryReward) do
        local iRatio = math.max(0,math.floor(formula_string(mInfo.ratio,{level = iLotteryLevel})))
        if iFlag == LOTTERY_ITEM and mInfo.rare>0 and mInfo.rare<RARE_REWARD then
            iRatio = 0 
        elseif mInfo.rare>0 and mInfo.rare<RARE_REWARD then
            local mBonusPool = mLotteryBonusPool[mInfo.rare]
            if not mBonusPool then
                iRatio = 0
                record.info("yunying huodong goldcoinparty lotteryreward rate config error")
            else
                for _, mData in ipairs(mBonusPool) do
                    if mData.max_bonus >= self.m_iAllGoldCoin then
                        iRatio = mData.ratio
                        break
                    end
                end
            end
        end
        mRatio[iIndex] = iRatio
    end

    local iKey = extend.Random.choosekey(mRatio)
    local mItemInfo = mLotteryReward[iKey]
    local itemobj = global.oItemLoader:ExtCreate(mItemInfo.itemsid)
    if itemobj:ItemType() == "virtual" then
        local iValue = itemobj:GetData("Value",0)
        assert(iValue<100 and iValue>0,string.format("%s",iValue))
        local iRewardValue = math.floor(self.m_iAllGoldCoin*iValue/100)
        itemobj:SetData("Value",iRewardValue)
        local iPreAllGoldCoin = self.m_iAllGoldCoin
        self.m_iAllGoldCoin = iPreAllGoldCoin - iRewardValue
        if oPlayer and not is_production_env() then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("抽取奖金池 %d=%d-%d，比重:%d",self.m_iAllGoldCoin,iPreAllGoldCoin,iRewardValue,iValue))
        end
    else
        itemobj:SetAmount(mItemInfo.amount)
    end
    if mItemInfo.bind == 1 then
        itemobj:Bind(pid)
    end
    local mResult = {}
    mResult.itemobj = itemobj
    if mItemInfo.chuanwen ~= 0 then
        mResult.chuanwen = mItemInfo.chuanwen
    end
    mResult.rare = mItemInfo.rare
    mResult.pos = mItemInfo.pos
    return mResult
end

function CHuodong:ItemAnnounce(oPlayer,itemobj,mResult)
    local iChuanwen = mResult.chuanwen 
    if not iChuanwen then
        return 
    end
    local mChuanwen = res["daobiao"]["chuanwen"][iChuanwen]
    local sContent = global.oToolMgr:FormatColorString(mChuanwen.content,{role=oPlayer:GetName(),sid = itemobj:SID(),amount = itemobj:GetAmount(),goldcoin = itemobj:GetData("Value",0)})
    global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
end

function CHuodong:TriggerAllGoldCoinChuanWen(iPreGoldCoin ,iNowGoldCoin)
    local mLotteryLevel = res["daobiao"]["huodong"][self.m_sName]["lottery_level"]
    local iLevel = 0
    local lKey = table_key_list(mLotteryLevel)
    table.sort(lKey,function (a,b)
        if a>b then return true end
    end)
    for _,iGoldCoin in ipairs(lKey) do
        if iPreGoldCoin<iGoldCoin and iGoldCoin<=iNowGoldCoin then
            local iChuanwen = mLotteryLevel[iGoldCoin]["chuanwen"]
            local mChuanwen = res["daobiao"]["chuanwen"][iChuanwen]
            local sContent = global.oToolMgr:FormatColorString(mChuanwen.content,{goldcoin = iGoldCoin})
            global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
            break
        end
    end
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

function CHuodong:CheckGiveReward()
    self:Dirty()
    local mConfig = self:GetConfig()
    local iMailID = mConfig.mail
    local mDegreeRes = res["daobiao"]["huodong"][self.m_sName]["degree_reward"]
    local mRewardInfo = self.m_mRewardInfo
    self.m_mRewardInfo = {}
    local oWorldMgr = global.oWorldMgr
    local oMailMgr = global.oMailMgr
    for pid,mReward in pairs(mRewardInfo) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local itemlist = {}
        local rewardlist = {}
        local degreerewardlist = mReward.rewardlist or {}
        for iIndex , iRewardState in ipairs(degreerewardlist) do 
            if mDegreeRes[iIndex] and iRewardState == STATE_REWARD then
                local mRewardData = self:GetRewardData(mDegreeRes[iIndex]["reward"])
                for _,iItemReward in ipairs(mRewardData.item) do
                    table.insert(rewardlist,iItemReward)
                end
            end
        end 
        for _,iItemRewardIdx in ipairs(rewardlist) do
            local mRewardInfo = self:GetItemRewardData(iItemRewardIdx)
            if not mRewardInfo then
                goto continue2
            end
            local mItemInfo = self:ChooseRewardKey(oPlayer, mRewardInfo, iItemRewardIdx, {})
            if not mItemInfo then
                goto continue2
            end
            local iteminfo = self:InitRewardByItemUnitOffline(pid,iItemRewardIdx,mItemInfo)
            list_combine(itemlist,iteminfo["items"])
            ::continue2::
        end
        if #itemlist>0 then
            local mMailReward = {}
            mMailReward["items"] = itemlist
            self:SendMail(pid,iMailID,mMailReward)
        end
        if oPlayer then
            self:GS2CGameReward(oPlayer)
        end
    end 
end

function CHuodong:BroadCastInfo()
    local mNet = {}
    mNet.allgoldcoin = self.m_iAllGoldCoin
    mNet.recordlist = self.m_mRecordInfo
    global.oInterfaceMgr:RefreshInterface(gamedefines.INTERFACE_TYPE.GOLDCOIN_PARTY,"GS2CGoldCoinPartyUpdateInfo",mNet)
end

function CHuodong:GS2CGameStart(oPlayer)
    oPlayer:Send("GS2CGoldCoinPartyStart",{})
end

function CHuodong:GS2CGameEnd(oPlayer)
    oPlayer:Send("GS2CGoldCoinPartyEnd",{})
end

function CHuodong:GS2CGameReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mNet = {}
    local mReward = self.m_mRewardInfo[pid] or {}
    mNet.point = mReward.point
    mNet.allgoldcoin = self.m_iAllGoldCoin
    mNet.rewardlist = mReward.rewardlist
    mNet.recordlist = self.m_mRecordInfo
    mNet.endtime = self:GetEndTime()
    oPlayer:Send("GS2CGoldCoinPartyReward",mNet)
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
        "101 活动开始\nhuodongop goldcoinparty 101 {day=天数}",
        "102 活动结束\nhuodongop goldcoinparty 102",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        if not mArgs.day then
            oPlayer:NotifyMessage("day 参数未配置")
            return
        end
        self:TryGameStart(oPlayer,mArgs.day)
        if self:GetGameState() == GAME_START then
            oNotifyMgr:Notify(pid,"开启成功")
        else
            oNotifyMgr:Notify(pid,"开启失败")
        end
    elseif iFlag == 102 then
        self:GameEnd()
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 201 then -- huodongop goldcoinparty 201 {lottery=10,flag=1}
        self:GetLotteryReward(oPlayer,mArgs.lottery,mArgs.flag)
    elseif iFlag == 202 then -- huodongop goldcoinparty 202 {degree=1}
        self:GetDegreeReward(oPlayer,mArgs.degree)
    elseif iFlag == 203 then
        self:CheckGiveReward()
    elseif iFlag == 204 then
        self:GetEndTime()
    end
end
