--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local loadpartner = import(service_path("partner/loadpartner"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

-- tips
local mTips = {"partner"}

function GetReplaceItem(iSid, iAmount)
    local lReplace = {}
    local mUseTbl = res["daobiao"]["itemcompound"]
    if not mUseTbl[iSid] then
        local mUnit = {}
        mUnit.sid = iSid
        mUnit.amount = iAmount
        table.insert(lReplace, mUnit)
    else
        local lCostItem = mUseTbl[iSid]["sid_item_list"]
        for _, mItem in ipairs(lCostItem) do
            local mUnit = {}
            mUnit.sid = mItem.sid
            mUnit.amount = mItem.amount*iAmount
            table.insert(lReplace, mUnit)
        end
    end
    return lReplace
end

function C2GSRecruit(oPlayer, mData)
    if not oPlayer then
        return
    end

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_SYS", oPlayer) then
        return
    end

    if not oToolMgr:IsSysOpen("PARTNER_ZM", oPlayer) then
        return
    end

    local sid = mData["sid"]
    local iFlag = mData["flag"]
    if oPlayer.m_oPartnerCtrl:QueryPartner(sid) then
        return
    end

    local oPartner = loadpartner.GetPartner(sid)
    if not oPartner then
        return
    end
    if not oPartner:PreCheckRecruit(oPlayer) then
        return
    end

    local mCost, iSilver = oPartner:GetRecruitCost()
    if not iFlag or iFlag <= 0 then
        if 0 < iSilver then
            if not oPlayer:ValidSilver(iSilver) then
                return
            end
        end
    end

    local iSid, iCostAmount = mCost.id, mCost.amount
    local lCostItem = {{sid=mCost.id, amount=mCost.amount}}
    local lTrueCostItem = {}
    local lReplaceItem = {}
    for _, mItem in ipairs(lCostItem) do
        local iHave = oPlayer.m_oItemCtrl:GetItemAmount(mItem.sid)
        if iHave < mItem.amount then
            if iHave > 0 then
                local mUnit = {sid = mItem.sid, amount = iHave}
                table.insert(lTrueCostItem, mUnit)
            end
            for _, mReplace in pairs(GetReplaceItem(mItem.sid, mItem.amount-iHave)) do
                table.insert(lReplaceItem, mReplace)
            end
        else
            table.insert(lTrueCostItem, mItem)
        end
    end

    local sReason
    local mStat = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷伙伴招募"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        -- 伙伴招募不会出现同一sid 同时出现在 lTrueCostItem 与 lReplaceItem 的情况
        for _, mItem in ipairs(lTrueCostItem) do
            mNeedCost["item"][mItem.sid] = mItem.amount
        end
        for _,mItem in ipairs(lReplaceItem) do
            mNeedCost["item"][mItem.sid] = mItem.amount
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["silver"] then
            mStat[gamedefines.MONEY_TYPE.SILVER] = mTrueCost["silver"]
        end
        if mTrueCost["goldcoin"] then
            mStat[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mStat[iSid] = iUseAmount
        end
    else
        sReason = "伙伴招募"
        for _, mItem in ipairs(lReplaceItem) do
            if oPlayer.m_oItemCtrl:GetItemAmount(mItem.sid) < mItem.amount then
                return
            end
        end

--        local iHaveAmount = oPlayer.m_oItemCtrl:GetItemAmount(iSid)
--        if iHaveAmount < iCostAmount then
--            return
--        end

        if iSilver > 0 then
            oPlayer.ResumeSilver(iSilver, sReason)
            mStat[gamedefines.MONEY_TYPE.SILVER] = iSilver
        end

        for _, mItem in ipairs(lTrueCostItem) do
            mStat[mItem.sid] = mItem.amount
            oPlayer:RemoveItemAmount(mItem.sid, mItem.amount, sReason)
        end
        for _, mItem in ipairs(lReplaceItem) do
            mStat[mItem.sid] = mItem.amount
            oPlayer:RemoveItemAmount(mItem.sid, mItem.amount, sReason)
        end
    end
       local oNewPartner = loadpartner.CreatePartner(sid, oPlayer:GetPid())
       oNewPartner:Setup()
       local bSucc = oPlayer.m_oPartnerCtrl:AddPartner(oNewPartner)

       local mLogData = oPlayer:LogData()
       mLogData["partner_sid"] = sid
       mLogData["sid"] = iSid
       mLogData["amount"] = mStat
       mLogData["silver"] = iSilver
       record.log_db("partner", "add_partner", mLogData)

       if not bSucc then
           baseobj_delay_release(oNewPartner)
       end
end

function C2GSUpgradeQuality(oPlayer, mData)
    if not oPlayer then
        return
    end

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_SYS", oPlayer) then
        return
    end
    if not oToolMgr:IsSysOpen("PARTNER_JJ", oPlayer) then
        return
    end

    local ipn = mData["partnerid"]
    local iFlag = mData["flag"]
    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(ipn)
    if not oPartner then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    if oPartner:PreCheckQuality() then
        local sReason
        local mCost, iSilver = oPartner:GetUpgradeQualityCost()

        -- if iSilver > 0 and not oPlayer:ValidSilver(iSilver, sReason) then
        --     return
        -- end
        -- 计算花费,有来源于其他物品合成的二级物品
        local lTrueCostItem = {}
        local lReplaceItem = {}

        for _, mData in pairs(mCost) do
            local iHaveAmount = oPlayer.m_oItemCtrl:GetItemAmount(mData.itemid)
            if iHaveAmount < mData.amount then
                if iHaveAmount > 0 then
                    local mUnit = {sid = mData.itemid, amount = iHaveAmount}
                    table.insert(lTrueCostItem, mUnit)
                end
                local iRet = mData.amount - iHaveAmount
                for _, mReplace in pairs(GetReplaceItem(mData.itemid, iRet)) do
                    table.insert(lReplaceItem, mReplace)
                end
            else
                local mUnit = {sid=mData.itemid, amount=mData.amount}
                table.insert(lTrueCostItem, mUnit)
            end
        end

        -- 从lTrueCostItem 获得 mTrueCostItem 用于对物品数目的计算
        local mTrueCostItem = {}
        for _, mData in ipairs(lTrueCostItem) do
            mTrueCostItem[mData.sid] = (mTrueCostItem[mData.sid] or 0) + mData.amount
        end
        -- 当伙伴进阶时记录消耗
        local mStaCost = {}
        if iFlag and iFlag > 0 then
            sReason = "快捷伙伴进阶"
            local mNeedCost = {}
            mNeedCost["silver"] = iSilver
            mNeedCost["item"] = {}
            for iSid, iAmount in pairs(mTrueCostItem) do
                mNeedCost["item"][iSid] = iAmount
            end
            for _, mItem in ipairs(lReplaceItem) do
                mNeedCost["item"][mItem.sid] = (mNeedCost["item"][mItem.sid] or 0) + mItem.amount
            end
            local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
            if not bSucc then return end
            if mTrueCost["silver"] then
                mStaCost[gamedefines.MONEY_TYPE.SILVER] = mTrueCost["silver"]
            end
            if mTrueCost["goldcoin"] then
                mStaCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
            end
            for iSid, iUseAmount in pairs(mTrueCost["item"]) do
                mStaCost[iSid] = iUseAmount
            end
        else
            sReason = "伙伴进阶"
            if iSilver > 0 and not oPlayer:ValidSilver(iSilver, sReason) then
                return
            end
            for _, mItem in ipairs(lReplaceItem) do
                local iHas = oPlayer.m_oItemCtrl:GetItemAmount(mItem.sid)
                local iTrueCostNeed = mTrueCostItem[mItem.sid] or 0 
                if oPlayer.m_oItemCtrl:GetItemAmount(mItem.sid)  - iTrueCostNeed < mItem.amount then
                    return
                end
            end

            if iSilver > 0 then
                oPlayer:ResumeSilver(iSilver, sReason)
            end
            for _, mItem in ipairs(lTrueCostItem) do
                mStaCost[mItem.sid] = mItem.amount
                oPlayer:RemoveItemAmount(mItem.sid, mItem.amount, sReason)
            end
            for _, mItem in ipairs(lReplaceItem) do
                mStaCost[mItem.sid] = mItem.amount
                oPlayer:RemoveItemAmount(mItem.sid, mItem.amount, sReason)
            end
        end

        local mLogData = oPlayer:LogData()
        mLogData["quality_old"] = oPartner:GetQuality()

        oPartner:IncreaseQuality(1)

        mLogData["partner_sid"] = oPartner:GetSID()
        mLogData["cost"] = mStaCost
        mLogData["silver"] = iSilver
        mLogData["quality_add"] = 1
        mLogData["quality_now"] = oPartner:GetQuality()
        record.log_db("partner", "quality_partner", mLogData)

        mStaCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
        analylog.LogSystemInfo(oPlayer, "partner_quality", oPartner:GetSID(), mStaCost)
    end
end

function C2GSUpperGradeLimit(oPlayer, mData)
    if not oPlayer then
        return
    end

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_SYS", oPlayer) then
        return
    end
    if not oToolMgr:IsSysOpen("PARTNER_TP", oPlayer) then
        return
    end

    local ipn = mData["partnerid"]
    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(ipn)
    if not oPartner then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    if oPartner:PreCheckUpper() then
        local mCost = oPartner:GetUpperLimitCost()
        for _, mData in pairs(mCost) do
            local iHaveAmount = oPlayer.m_oItemCtrl:GetItemAmount(mData.itemid)
            if iHaveAmount < mData.amount then
                return
            end
        end

        local mStaCost = {}
        local sReason = "伙伴突破"
        for _, mData in pairs(mCost) do
            mStaCost[mData.itemid] = mData.amount
            oPlayer:RemoveItemAmount(mData.itemid, mData.amount, sReason)
        end

        local mLogData = oPlayer:LogData()
        mLogData["upper_old"] = oPartner:GetUpper()

        oPartner:IncreaseUpper(1)

        mLogData["partner_sid"] = oPartner:GetSID()
        mLogData["cost"] = mCost
        mLogData["upper_add"] = 1
        mLogData["upper_now"] = oPartner:GetUpper()
        record.log_db("partner", "upper_partner", mLogData)

        analylog.LogSystemInfo(oPlayer, "partner_upper", oPartner:GetSID(), mStaCost)
    end
end

function C2GSUseUpgradeProp(oPlayer, mData)
    -- 伙伴升级道具
    local update ={30661, 30662, 30663}

    -- 检查玩家是否拥有指定伙伴
    local ipn = mData["partnerid"]
    local itemid = mData["itemid"]

    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(ipn)
    if not oPartner then
        return
    end

    --  是否拥有该道具
    local oItem= oPlayer.m_oItemCtrl:HasItem(itemid)
    if not oItem then
        return
    end

    -- 判断伙伴道具合法
    local iSid = oItem:SID()
    local tableop = import(lualib_path("base.tableop"))
    local err= tableop.table_in_list(update, iSid)

    -- 使用伙伴升级道具
    if err then
        if oItem:Use(oPlayer, ipn) then
            oPlayer.m_oPartnerCtrl:FireUseUpgradeProp(oPartner, iSid)
        end
    end
end

-- 伙伴技能升级
function C2GSUpgradeSkill(oPlayer, mData)
    local iPartnerid = mData["partnerid"]
    local iSk = mData["skid"]
    local iFlag = mData["flag"]

    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr

    -- 检查伙伴
    local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(iPartnerid)
    if not  oPartner then
        return
    end

    -- 检查技能
    local oSk = oPartner.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return
    end

    local bRet = oSk:PreCheckUpgrade()
    if not bRet  then
        return
    end

    local mSkillUpgrade = oSk:GetSkillUpgradeInfo()
    if oPartner:GetGrade() < mSkillUpgrade["partner_level"] then
        oPartner:SendNotification(1015, {partner=oPartner:GetName(), level=mSkillUpgrade["partner_level"]})
        return
    end

    local iItemSid, iAmount = mSkillUpgrade.cost.itemid, mSkillUpgrade.cost.amount
    local iHaveAmount = oPlayer:GetItemAmount(iItemSid)
    local sReason
    local mCost = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷伙伴技能升级"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        mNeedCost["item"][iItemSid] = iAmount
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["goldcoin"] then
            mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iItemSid, iUseAmount in pairs(mTrueCost["item"]) do
            mCost[iItemSid] = iUseAmount
        end
    else
        sReason = "伙伴技能升级"
        if iHaveAmount < iAmount then
            return
        end
        oPlayer:RemoveItemAmount(iItemSid, iAmount, sReason)
        mCost[iItemSid] = iAmount
    end

    local mLogData = oPlayer:LogData()
    mLogData["lv_old"] = oSk:Level()
    -- 回复升级
    oSk:Upgrade(oPartner)
    oPartner:SendNotification(1017, {skname = oSk:Name()})

    mLogData["partner_sid"] = oPartner:GetSID()
    mLogData["skill"] = iSk
    mLogData["lv_now"] = oSk:Level()
    mLogData["cost"] = mCost
    record.log_db("partner", "skill_upgrade", mLogData)
    return
end

function C2GSWieldEquip(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_SYS", oPlayer) then
        return
    end

    if not oToolMgr:IsSysOpen("PARTNER_ZB", oPlayer) then
        return
    end

    local iPartnerid = mData["partnerid"]
    local iEquipId = mData["itemid"]

    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartnerid)
    if not oPartner then
        return
    end

    --  是否拥有该道具
    local oItem= oPlayer.m_oItemCtrl:HasItem(iEquipId)
    if not oItem then
        return
    end

    oItem:Use(oPlayer, iPartnerid)
    oPartner:SendNotification(1009, {item = oItem:Name()})
end

function C2GSSetPartnerPosInfo(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_BZ", oPlayer) then
        return
    end
    local oPartnerCtrl = oPlayer.m_oPartnerCtrl
    local iLineup = mData.lineup
    local lPosList = mData.pos_list
    local iFmtId = mData.fmt_id

    local oPartnerCtrl = oPlayer.m_oPartnerCtrl
    if oPartnerCtrl.ValidAdjustPartner then
        if not oPartnerCtrl:ValidAdjustPartner(oPlayer, lPosList) then
            local iIdx = oPartnerCtrl:GetCurrLineup()
            oPartnerCtrl:RefreshSingleLineupInfo(iIdx)
            return
        end
    end

    oPartnerCtrl:SetLineup(iLineup, lPosList, iFmtId)
end

function C2GSGetAllLineupInfo(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_BZ", oPlayer) then
        return
    end
    local oPartnerCtrl = oPlayer.m_oPartnerCtrl
    oPartnerCtrl:RefreshAllLineupInfo()
end

function C2GSSetCurrLineup(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_BZ", oPlayer) then
        return
    end
    local oPartnerCtrl = oPlayer.m_oPartnerCtrl
    local iLineup = mData.lineup
    if oPartnerCtrl.ValidAdjustPartner then
        local lPartner = table_get_depth(oPartnerCtrl.m_mLineup, {iLineup, "pos_list"}) or {}
        if not oPartnerCtrl:ValidAdjustPartner(oPlayer, lPartner) then
            local iIdx = oPartnerCtrl:GetCurrLineup()
            oPlayer:Send("GS2CSetCurrLineup", {lineup=iIdx})
            return
        end
    end
    oPartnerCtrl:SetCurrLineup(iLineup)
end

function C2GSSwapProtectSkill(oPlayer, mData)
    local iOldSkill = mData.skill_old
    local iNewSkill = mData.skill_new
    local iPartner = mData.partner_id

    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartner)
    if oPartner then
        oPartner:SwapProtectSkill(oPlayer, iOldSkill, iNewSkill)
    end
end

function C2GSUpgradePartnerEquip(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_SYS", oPlayer) then
        return
    end

    if not oToolMgr:IsSysOpen("PARTNER_ZB", oPlayer) then
        return
    end

    local iPartner = mData.partner_id
    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartner)
    if not oPartner then return end

    local iPos = mData.equip_sid
    local bGoldCoin = mData.goldcoin == 1
    local bRet, rMsg = oPartner.m_oEquipCtrl:ValidUpgrade(oPlayer, iPos, bGoldCoin)
    if not bRet then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), rMsg)
        return
    end
    oPartner.m_oEquipCtrl:UpgardeEquipByPos(iPos)
    analylog.LogSystemInfo(oPlayer, "partnerequip_upgrade", iPos, rMsg)
end

function C2GSStrengthPartnerEquip(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("PARTNER_SYS", oPlayer) then
        return
    end

    if not oToolMgr:IsSysOpen("PARTNER_ZB", oPlayer) then
        return
    end

    local iPartner = mData.partner_id
    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartner)
    if not oPartner then return end

    local iPos = mData.equip_sid
    local bRet, rMsg = oPartner.m_oEquipCtrl:ValidStrengthEquip(oPlayer, iPos)
    if not bRet then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), rMsg)
        return
    end
    oPartner.m_oEquipCtrl:StrengthEquipByPos(iPos, mData.quick==1)
    analylog.LogSystemInfo(oPlayer, "partnerequip_strength", iPos, rMsg)
end

