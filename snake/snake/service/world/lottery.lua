local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewLottery(sid)
    local o = CLottery:New(sid)
    return o
end

function NewLotteryMgr()
    local o = CLotteryMgr:New()
    return o
end

CLotteryMgr = {}
CLotteryMgr.__index = CLotteryMgr
inherit(CLotteryMgr, logic_base_cls())

function CLotteryMgr:New()
    local o = super(CLotteryMgr).New(self)
    o.m_mList = {}
    return o
end

function CLotteryMgr:Lottery(oPlayer, sid, func, cbfunc)
    if not self.m_mList[sid] then
        local oLottery = NewLottery(sid)
        self.m_mList[sid] = oLottery
    end
    local oLottery = self.m_mList[sid]
    oLottery:Lottery(oPlayer, func, cbfunc)
end

CLottery = {}
CLottery.__index = CLottery
inherit(CLottery, logic_base_cls())

function CLottery:New(sid)
    local o = super(CLottery).New(self)
    o.m_iSid = sid
    return o
end

function CLottery:Lottery(oPlayer, func, cbfunc)
    -- 发放抽奖奖励
    local mItems = self:InitLotteryItem(oPlayer)
    if not mItems then return end

    local iSid = self.m_iSid 
    oPlayer:SetLogoutJudgeTime(-1)

    local func1 = function(oPlayer, mData)
        local sReason = "lottery" .. iSid
        if func then
            safe_call(func, oPlayer, mItems, sReason)
        else
            safe_call(PlayLotteryCB, oPlayer, mItems, sReason)
        end
        if cbfunc then
            safe_call(cbfunc, oPlayer, mItems)
        end
    end
    local mNet = {}
    mNet.type = self.m_iSid
    mNet.idx = mItems["info"]["pos"]
    local iPid = oPlayer:GetPid()
    local oCbMgr = global.oCbMgr
    local iSession = oCbMgr:SetCallBack(iPid, "GS2CPlayLottery", mNet, nil, func1)

    local func2 = function()
        TryStopLottery(iPid, iSid, mItems, iSession, func1)
    end
    oPlayer:DelTimeCb("TryStopLottery")
    oPlayer:AddTimeCb("TryStopLottery", 10*1000, func2)
end

function CLottery:InitLotteryItem(oPlayer)
    if not self.m_iSid then return end

    local mLotteryItem = self:GetItemLotteryData(self.m_iSid)
    if not mLotteryItem then return end

    local mItemInfo = self:ChooseLotteryKey(oPlayer, mLotteryItem)
    if not mItemInfo then return end

    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iAmount = mItemInfo["amount"]
    local iBind = mItemInfo["bind"]
    while (iAmount > 0) do
        local oItem = global.oItemLoader:ExtCreate(sShape)
        local iSid = oItem:SID()
        local iAddAmount = math.min(oItem:GetMaxAmount(), iAmount)
        iAmount = iAmount - iAddAmount
        oItem:SetAmount(iAddAmount)
        if iBind ~= 0 then
            oItem:Bind(oPlayer:GetPid())
        end
        local lItems = mItems["items"]
        if not lItems then
            lItems = {}
            mItems["items"] = lItems
        end
        table.insert(lItems, oItem)
    end
    mItems["info"] = mItemInfo
    return mItems
end

function CLottery:GetItemLotteryData(iItemLottery)
    local mData = res["daobiao"]["lottery"][iItemLottery]
    assert(mData, string.format("CLottery:GetItemLotteryData err %s", iItemLottery))
    return mData
end

function CLottery:ChooseLotteryKey(oPlayer, mLotteryInfo)
    local iLimit = 10000
    local iRandom = math.random(iLimit)
    local iTotal = 0
    for _, mItemUnit in ipairs(mLotteryInfo) do
        iTotal = iTotal + mItemUnit["ratio"]
        if iRandom <= iTotal then
            return table_deep_copy(mItemUnit)
        end
    end
end

function PlayLotteryCB(oPlayer, mItems, sReason)
    oPlayer:SetLogoutJudgeTime()
    oPlayer:DelTimeCb("TryStopLottery")
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local mItemAmounts = {}
    local mItemNames = {}
    local lItems = mItems["items"]
    for _, oItem in ipairs(lItems) do
        local sid = oItem:SID()
        local iAmount = oItem:GetAmount()
        oPlayer:RewardItem(oItem, sReason)

        mItemAmounts[sid] = (mItemAmounts[sid] or 0) + iAmount
        if not mItemNames[sid] then
           mItemNames[sid] = oItem:TipsName() 
        end
    end
    local lCw = {}
    local iSys = mItems["info"]["sys"]
    local mChuanwen = res["daobiao"]["chuanwen"][iSys]
    for sid, sName in pairs(mItemNames) do
        local iAmount = mItemAmounts[sid]
        if mChuanwen then
            local sRoleName = oPlayer:GetName()
            local sCw = oToolMgr:FormatColorString(mChuanwen.content, {role = sRoleName, amount = iAmount, item = sName, npc = ""})
            table.insert(lCw,sCw)
        end
    end
    local sMsg = table.concat(lCw, ",")
    if #sMsg > 0 then
        oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end
end

function TryStopLottery(iPid, iSid, mItems, iSession, func)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        record.warning("%s not online when stop lottery %s %s", iPid, iSid, mItems["info"]["pos"])
        return
    end

    global.oCbMgr:RemoveCallBack(iSession)
    if func then
        func(oPlayer)
    end
end
