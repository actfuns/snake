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

local LOTTERY_FLAG = {
    [1] = "cost1",
    [10] = "cost10",
}

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "河神祈福"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mRewardInfo = {}
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
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iOpenDay = mData.openday or 0
    self.m_mRewardInfo = mData.rewardinfo or {}
    self.m_iGameDay = mData.gameday or 0
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong qifu without data"
    end

    self:Dirty()
    if self.m_iOpenDay ~= mFromData.openday 
        or self.m_iGameDay ~= mFromData.gameday then
        return true
    end

    for iPid, mData in pairs(mFromData.rewardinfo or {}) do
        self.m_mRewardInfo[iPid] = mData
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:GetConfigData()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
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

--运营开启活动接口
function CHuodong:TryGameStart(oPlayer,iGameDay)
    if self:GetGameState() == GAME_START then
        record.warning(string.format("%s gamestart error1 %s", self.m_sName,iGameDay)) 
        return
    end
    self:GameStart(iGameDay)
end

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

function CHuodong:GameStart(iGameDay)
    self:Dirty()
    self.m_mRewardInfo = {}
    self.m_iOpenDay = get_morningdayno()
    self.m_iGameDay = iGameDay
    record.info(string.format("%s GameStart %s %s",self.m_sName,self.m_iOpenDay,iGameDay))
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
            self:GS2CGameStart(oPlayer)
            self:GS2CGameReward(oPlayer)
    end
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

function CHuodong:GetGameDay()
    if self.m_iGameDay>0 then
        return self.m_iGameDay
    end
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    return  iGameDay
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd %s",self.m_sName,self.m_iOpenDay))
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self:CheckGiveReward()
    self.m_mRewardInfo = {}
    self.m_iOpenDay = 0
    self.m_iGameDay = 0
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CQiFuEnd",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {},
        exclude = {},
    })
end

function CHuodong:GetDegreeReward(oPlayer,iDegree)
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        return false
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
    local mLogData = {}
    mLogData.pid = pid
    mLogData.degree = iDegree
    record.log_db("huodong", "qifu_degree",mLogData)
    self:Dirty()
    mReward.rewardlist[iDegree] = STATE_REWARDED
    self.m_mRewardInfo[pid] = mReward
    local iReward = mDegreeRes[iDegree]["reward"]
    self:Reward(pid,iReward)
    self:GS2CGameReward(oPlayer)
end

function CHuodong:ValidLottery(oPlayer,iFlag)
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        return false
    end
    local mCostFlag = LOTTERY_FLAG[iFlag]
    if not mCostFlag then
        return false
    end
    local mConfig = self:GetConfigData()
    local iNeedGoldCoin = mConfig[mCostFlag]
    if iNeedGoldCoin <=0 then
        return false
    end
    if not oPlayer:ValidTrueGoldCoin(iNeedGoldCoin) then
        return false
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<iFlag then
        global.oNotifyMgr:Notify(pid,self:GetTextData(1001))
        return false
    end
    return true
end

function CHuodong:LotteryReward(pid)
    local mLotteryRes = res["daobiao"]["huodong"][self.m_sName]["lottery_reward"]
    local mBaojiRes = res["daobiao"]["huodong"][self.m_sName]["baoji_ratio"]
    local mRatio = {}
    for iIndex,mInfo in pairs(mLotteryRes) do
        mRatio[iIndex] = mInfo.ratio
    end
    local mBJRatio = {}
    for value,mInfo in pairs(mBaojiRes) do
        mBJRatio[value] = mInfo.ratio
    end
    local iKey = extend.Random.choosekey(mRatio)
    local iBaoji = extend.Random.choosekey(mBJRatio)
    local mItemInfo = mLotteryRes[iKey]
    local itemobj = global.oItemLoader:ExtCreate(mItemInfo.itemsid)
    if itemobj:ItemType() == "virtual" then
        local iValue = itemobj:GetData("Value",0)
        itemobj:SetData("Value",iValue*iBaoji)
    else
        itemobj:SetAmount(mItemInfo.amount*iBaoji)
    end
    if mItemInfo.bind == 1 then
        itemobj:Bind(pid)
    end
    local mResult = {}
    mResult.itemobj = itemobj
    mResult.baoji = iBaoji
    mResult.rare = mItemInfo.rare
    return mResult
end

function CHuodong:GetLotteryReward(oPlayer,iFlag)
    if not self:ValidLottery(oPlayer,iFlag) then
        return 
    end
    local pid = oPlayer:GetPid()
    local mCostFlag = LOTTERY_FLAG[iFlag]
    local mConfig = self:GetConfigData()
    local iNeedGoldCoin = mConfig[mCostFlag]
    local iRewardPoint = mConfig["point"]
    oPlayer:ResumeTrueGoldCoin(iNeedGoldCoin,self.m_sName)
    local itemlist = {}
    local mNet = {}
    local iAmount = 0
    for i=1,iFlag do
        local mResult = self:LotteryReward(pid)
        local itemobj = mResult.itemobj
        table.insert(itemlist,mResult.itemobj)
        iAmount = iAmount + itemobj:GetAmount()
        local mSubNet = {itemsid = itemobj:SID(),baoji=mResult.baoji,amount = itemobj:GetAmount()}
        if itemobj:ItemType() == "virtual" then
            mSubNet.amount=itemobj:GetData("Value")
        end
        table.insert(mNet,mSubNet)
        self:ItemAnnounce(oPlayer,itemobj,mResult.baoji,mResult.rare)
    end
    local mLogData = {}
    mLogData.pid = pid
    mLogData.flag = iFlag
    record.log_db("huodong", "qifu_lottery",mLogData)
    if not oPlayer:ValidGiveitemlist(itemlist,{cancel_tip = true}) then
        local mMailReward = {}
        mMailReward["items"] = itemlist
        local iMailID = res["daobiao"]["huodong"][self.m_sName]["config"][1]["mail"]
        self:SendMail(pid,iMailID,mMailReward)
        global.oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return
    end
    local mArgs = {cancel_tip=true,cancel_chat=true,refresh=1}
    if iFlag == 1 then
        mArgs = {}
    end
    oPlayer:GiveItemobj(itemlist,self.m_sName,mArgs)
    if iFlag == 10 then
        oPlayer:Send("GS2CQiFuLottery",{rewardlist=mNet})
    end
    self:Dirty()
    local mReward = self.m_mRewardInfo[pid] or {}
    if not mReward.point then
        mReward.point = 0
    end
    mReward.point = mReward.point + iFlag*iRewardPoint
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
    global.oNotifyMgr:Notify(pid,self:GetTextData(1002))
    mReward.rewardlist = lDegreeReward
    self.m_mRewardInfo[pid] = mReward
    self:GS2CGameReward(oPlayer)
end

function CHuodong:ItemAnnounce(oPlayer,itemobj,iBaoji,iRare)
    local iChuanwen = 0
    if iBaoji>1 and iRare ==1 then
        iChuanwen = 1088
    elseif iRare==1 then
        iChuanwen = 1087
    end
    if iChuanwen == 0 then
        return
    end
    local mChuanwen = res["daobiao"]["chuanwen"][iChuanwen]
    local sContent = global.oToolMgr:FormatColorString(mChuanwen.content,{role=oPlayer:GetName(),beilv = iBaoji,amount = itemobj:GetAmount(),sid = itemobj:SID()})
    global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
end

function CHuodong:CheckGiveReward()
    self:Dirty()
    local iMailID = res["daobiao"]["huodong"][self.m_sName]["config"][1]["mail"]
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

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {}
    mNet.endtime = self:GetEndTime()
    oPlayer:Send("GS2CQiFuStart",mNet)
end

function CHuodong:GS2CGameEnd(oPlayer)
    oPlayer:Send("GS2CQiFuEnd",{})
end

function CHuodong:GS2CGameReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mNet = {}
    local mReward = self.m_mRewardInfo[pid] or {}
    mNet.point = mReward.point
    mNet.rewardlist = mReward.rewardlist
    oPlayer:Send("GS2CQiFuReward",mNet)
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
        "101 活动开始\nhuodongop qifu 101 {day=天数}",
        "102 活动结束\nhuodongop qifu 102",
    }
    --sethdcontrol qifu default 0 60
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
    elseif iFlag == 201 then
        self:GetLotteryReward(oPlayer,mArgs.flag)
    elseif iFlag == 202 then
        self:GetDegreeReward(oPlayer,mArgs.degree)
    elseif iFlag == 203 then
        self:CheckGiveReward()
    end
end
