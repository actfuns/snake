-- 开箱玩法

local global = require "global"
local record = require "public.record"
local templ = import(service_path("templ"))

function NewBoxMgr()
    return CBoxMgr:New()
end

CBoxMgr = {}
CBoxMgr.__index = CBoxMgr
CBoxMgr.m_sName = "openbox"
CBoxMgr.m_sTempName = "开箱"
inherit(CBoxMgr, templ.CTempl) -- 类似于活动玩法

function CBoxMgr:New()
    local o = super(CBoxMgr).New(self)
    return o
end

function CBoxMgr:GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"openbox", "text"})
end

function CBoxMgr:GetFortune(iMoneyType, mArgs)
    return false
end

function CBoxMgr:TryOpenBox(oPlayer, iBoxSid)
    if oPlayer:GetItemAmount(iBoxSid) <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1004))
        return
    end
    local mItemInfo = global.oItemLoader:GetItemData(iBoxSid)
    if not mItemInfo then
        oPlayer:NotifyMessage(self:GetTextData(1001))
        return
    end
    local iRewardId = mItemInfo.open_reward_id
    if not iRewardId or iRewardId <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1002))
        return
    end
    local lOpenCosts = mItemInfo.open_cost
    for _, mNeed in ipairs(lOpenCosts) do
        local iNeedSid = mNeed.sid
        local iNeedAmount = mNeed.amount
        local iHasAmount = oPlayer:GetItemAmount(iNeedSid)
        if iHasAmount < iNeedAmount then
            local sMsg = global.oToolMgr:FormatString(self:GetTextData(1005), {item = global.oItemLoader:GetItemNameBySid(iNeedSid)})
            local mNet = {sid = iNeedSid, amount = iNeedAmount - iHasAmount, msg = sMsg}
            oPlayer:Send("GS2CQuickBuyItemUI", mNet)
            return
        end
    end
    local mRewardData = self:GetRewardData(iRewardId)
    local mRewardContent = self:GenRewardContent(oPlayer, mRewardData, mArgs)
    if not mRewardContent or not next(mRewardContent) then
        oPlayer:NotifyMessage(self:GetTextData(1003))
        return
    end
    local mCosts = {}
    for _, mNeed in ipairs(lOpenCosts) do
        local iNeedSid = mNeed.sid
        local iNeedAmount = mNeed.amount
        mCosts[iNeedSid] = (mCosts[iNeedSid] or 0) + iNeedAmount
        oPlayer:RemoveItemAmount(iNeedSid, iNeedAmount, "openbox_cost", {cancel_tip = true})
    end
    oPlayer:RemoveItemAmount(iBoxSid, 1, "openbox", {cancel_tip = true})

    local mLogData = oPlayer:LogData()
    local mContentCopy = self:SimplifyReward(oPlayer, mRewardContent or {}, mArgs)
    mLogData.reward = mContentCopy
    mLogData.rewardid = iRewardId
    mLogData.box = iBoxSid
    mLogData.costs = mCosts
    record.user("item", "openbox", mLogData)

    self:DoSendOpened(oPlayer, iBoxSid, mRewardContent)
    return self:RewardByContent(oPlayer, iRewardId, mRewardContent, {})
end

function CBoxMgr:DoSendOpened(oPlayer, iBoxSid, mRewardContent)
    local mSimpleItemsInfo = self:SimplifyRewardToItems(oPlayer, mRewardContent, {})
    local lItemInfos = {}
    for iSid, iAmount in pairs(mSimpleItemsInfo) do
        table.insert(lItemInfos, {sid = iSid, amount = iAmount})
    end
    oPlayer:Send("GS2COpenBoxUI", {box_sid = iBoxSid, reward_item = lItemInfos})
end

function CBoxMgr:GetRandomMax(itemidx, mArgs)
end

function CBoxMgr:ChooseRewardKey(oPlayer, mRewardInfo, itemidx, mArgs)
    local iSum = 0
    local mFiltered = {}
    local iPlayerGrade = oPlayer:GetGrade()
    for idx, mItemUnit in ipairs(mRewardInfo) do
        local lGradeInterval = mItemUnit.grade_interval
        if #lGradeInterval == 2 then
            if iPlayerGrade < lGradeInterval[1] or iPlayerGrade > lGradeInterval[2] then
                goto continue
            end
        end
        mFiltered[idx] = mItemUnit.ratio
        ::continue::
    end
    local iRandIdx = table_choose_key(mFiltered)
    if not iRandIdx then
        return
    end
    return mRewardInfo[iRandIdx]
end
