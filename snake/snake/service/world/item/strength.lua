local global = require "global"
local extend = require "base/extend"
local record = require "public.record"

local gamedefines = import(lualib_path("public/gamedefines"))
local analylog = import(lualib_path("public.analylog"))

function GetStrengthData()
    local res = require "base.res"
    return res["daobiao"]["strength"]
end

-- 强化材料lv+1应该存在在"strength"表中存在
-- TODO 此处以后加上preCheck
function GetStrengthMaterial()
    local res = require "base.res"
    return res["daobiao"]["strengthmaterial"]
end

function GetStrengthRatio()
    local res = require "base.res"
    return res["daobiao"]["strengthratio"]
end

function GetEquipBreakInfo()
    local res = require "base.res"
    return res["daobiao"]["equipbreak"]
end

CEquipStrengthenMgr = {}
CEquipStrengthenMgr.__index = CEquipStrengthenMgr
inherit(CEquipStrengthenMgr, logic_base_cls())

function CEquipStrengthenMgr:StrengthSilver(oPlayer, iPos)
    -- local iStrengthenLevel = oEquip:GetData("strength_level",0)
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos)
    local iSilver = iStrengthenLevel * 500 + 100
    return iSilver
end

-- 是否足够, 消耗道具, 缺失的白水晶数目
function CEquipStrengthenMgr:StrengthMaterial(oPlayer, oEquip)
    local iPos = oEquip:EquipPos()
    local mData = GetStrengthMaterial()
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos)
    local iNextLevel = iStrengthenLevel + 1
    mData = mData[iNextLevel]
    assert(mData,string.format("strengthen err level %d",iNextLevel))
    mData = mData[iPos]
    assert(mData,string.format("strengthen err pos %d %d",iNextLevel,iPos))
    local iShape = mData["sid"]
    local iAmount = mData["amount"]
    local mAmount = {}
    for iUseShape = iShape,11092,-1 do
        local iHasAmount = oPlayer:GetItemAmount(iUseShape)
        assert(iHasAmount >= 0, "strengthen err find" .. iUseShape .. "amount" .. iHasAmount)
        if iHasAmount >= iAmount then
            mAmount[iUseShape] = iAmount
            return true, mAmount, 0
        else
            if iHasAmount > 0 then
                mAmount[iUseShape] = iHasAmount
            end
            if iUseShape == 11092 then
                iAmount = iAmount - iHasAmount
                return false, mAmount, iAmount
            else
                iAmount = (iAmount - iHasAmount) * 4
            end
        end
    end
end

-- 最大的强化到等级
function CEquipStrengthenMgr:GetMaxStrengthLv()
    return #GetStrengthMaterial()
end

function CEquipStrengthenMgr:ValidStrength(oPlayer, oEquip)
    local iPid = oPlayer:GetPid()
    local iPos = oEquip:EquipPos()
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos) or 0
    local iMaxStrengthLv = self:GetMaxStrengthLv()
    local iGrade = oPlayer:GetGrade()
    if iStrengthenLevel >= iGrade or iStrengthenLevel >= iMaxStrengthLv then
        return false, global.oItemHandler:GetTextData(1080)
    end

    -- 判断突破等级
    local iBreakLv = oPlayer.m_oEquipCtrl:GetBreakLevel(iPos)
    local mBreakInfo = self:GetEquipBreakInfo(iBreakLv, iPos)
    if mBreakInfo.max_lv <= iStrengthenLevel then
        return false, global.oItemHandler:GetTextData(1081)
    end

    local iNextLevel = iStrengthenLevel + 1
    local mStrengthInfo = GetStrengthData()[iNextLevel]
    -- if not mStrengthInfo then
    --     oNotifyMgr:Notify(iPid, "ERROR: 配表错误，此等级没有强化数据")
    --     return false
    -- end
    assert(mStrengthInfo, string.format("StrengthenLevelOverFlow err:Player=%d nextLv=%d", iPid, iNextLevel))

    mStrengthInfo = mStrengthInfo[iPos]
    -- if not mStrengthInfo then
    --     oNotifyMgr:Notify(iPid, "ERROR: 配表错误，此等级此部位没有强化数据")
    --     return false
    -- end
    assert(mStrengthInfo, string.format("StrengthenLevelOverFlow err:Player=%d nextLv=%d equipPos=%d", iPid, iNextLevel, iPos))

    local mStrengthMaterialInfo = GetStrengthMaterial()[iNextLevel]
    -- if not mStrengthMaterialInfo then
    --     oNotifyMgr:Notify(iPid, "ERROR: 配表错误，此等级没有强化材料数据")
    --     return false
    -- end
    assert(mStrengthMaterialInfo, string.format("StrengthMaterialOverFlow err:Player=%d nextLv=%d", iPid, iNextLevel))

    mStrengthMaterialInfo = mStrengthMaterialInfo[iPos]
    -- if not mStrengthMaterialInfo then
    --     oNotifyMgr:Notify(iPid, "ERROR: 配表错误，此等级此部位没有强化材料数据")
    --     return false
    -- end
    assert(mStrengthMaterialInfo, string.format("StrengthMaterialOverFlow err:Player=%d nextLv=%d equipPos=%d", iPid, iNextLevel, iPos))
    return true
end

function CEquipStrengthenMgr:StrengthRatio(oPlayer,iPos)
    local mRatio = GetStrengthRatio()
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos)
    local iNextLevel = iStrengthenLevel + 1
    local iBaseRatio = mRatio[iNextLevel]["ratio"]
    assert(iBaseRatio,string.format("strengthratio err:%d",iStrengthenLevel))
    local iFailCnt = oPlayer:StrengthFailCnt(iPos)
    local iAddRatio = iFailCnt * 10
    local iRatio = iBaseRatio + iAddRatio
    return iRatio, iBaseRatio, iAddRatio
end

function CEquipStrengthenMgr:QueryStrengthenRatio(oPlayer, iPos)
    local iMaxStrengthLv = self:GetMaxStrengthLv()
    local iRatio, iBaseRatio, iAddRatio = 0, 0, 0
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos)
    if iStrengthenLevel < iMaxStrengthLv then
        iRatio, iBaseRatio, iAddRatio = self:StrengthRatio(oPlayer,iPos)
    end
    return iBaseRatio, iAddRatio
end

function CEquipStrengthenMgr:EquipStrengthen(oPlayer, oEquip, iFlag)
    local bRet, sMsg = self:ValidStrength(oPlayer, oEquip)
    if not bRet then return false, {msg=sMsg} end

    -- 计算材料不足则用白水晶进行补充 11092
    local iPos = oEquip:EquipPos()
    local bEnough, mAmount, iNeedAmount = self:StrengthMaterial(oPlayer, oEquip)
    local iSilver = self:StrengthSilver(oPlayer, iPos)
    local mCost, sReason, bFast = {}, nil, false
    if iFlag and iFlag > 0 then
        bFast, sReason = true, "快捷装备强化"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        for iShape, iAmount in pairs(mAmount) do
            mNeedCost["item"][iShape] = iAmount
        end
        if not bEnough then
            if not mNeedCost["item"][11092] then
                mNeedCost["item"][11092] = iNeedAmount
            else
                mNeedCost["item"][11092] = mNeedCost["item"][11092] + iNeedAmount
            end
        end

        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return false, {fast=bFast, msg=global.oItemHandler:GetTextData(1082)} end

        if mTrueCost["silver"] then
            mCost[gamedefines.MONEY_TYPE.SILVER] = mTrueCost["silver"]
        end
        if mTrueCost["goldcoin"] then
            mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iShape, iUseAmount in pairs(mTrueCost["item"]) do
            mCost[iShape] = iUseAmount
        end
    else
        sReason = "装备强化"
        local sMsg = global.oItemHandler:GetTextData(1083)
        if not bEnough then return false, {msg=sMsg} end

        local sMsg = global.oItemHandler:GetTextData(1084)
        if not oPlayer:ValidSilver(iSilver, {cancel_tip=true}) then return false, {msg=sMsg} end

        oPlayer:ResumeSilver(iSilver,"装备强化")
        for iShape,iAmount in pairs(mAmount) do
            mCost[iShape] = iAmount
            oPlayer:RemoveItemAmount(iShape,iAmount, sReason, {cancel_tip=true})
        end
    end

    local iRatio = self:StrengthRatio(oPlayer, iPos)
    local bSucc = false
    if math.random(100) <= iRatio then
        bSucc = true
        self:StrengthSuccess(oPlayer, oEquip)
    else
        self:StrengthFail(oPlayer, oEquip, iRatio)
    end

    mCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
    local iTotal = 0
    for iShape, iAmount in pairs(mAmount) do
        if iShape == 11092 then
            iTotal = iAmount + iNeedAmount
        elseif iShape > 11092 then
            iTotal = math.floor(4^(iShape - 11092) * iAmount)
        end
    end
    global.oRankMgr:PushDataToEveryDayRank(oPlayer, "strength_equip", {cnt=iTotal})
    oPlayer.m_oItemCtrl:FireEquipStrengthen(oEquip, bSucc)
    analylog.LogSystemInfo(oPlayer, "equip_strength", iPos, mCost)
    return true, {fast=bFast, success=bSucc}
end

function CEquipStrengthenMgr:StrengthSuccess(oPlayer,oEquip)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer.m_iPid
    local iPos = oEquip:EquipPos()
    oPlayer:SetStrengthFailCnt(iPos,0)
    local iLevel = oPlayer:StrengthenLevel(iPos)
    local iNewLevel = iLevel + 1

    local mLogData = oPlayer:LogData()
    mLogData.pos = iPos
    mLogData.level = iNewLevel
    mLogData.fail_cnt = 0
    mLogData.succ = 1
    record.user("equip", "strength", mLogData)
    oPlayer:EquipStrength(iPos,iNewLevel)
    oPlayer:MarkGrow(15)

    -- global.oNotifyMgr:UIEffectNotify(oPlayer:GetPid(), gamedefines.UI_EFFECT_MAP.QIANG_HUA, {})
    -- oPlayer:Send("GS2CGetScore",{op = 2,score = oPlayer:GetRoleScore()})
end

function CEquipStrengthenMgr:StrengthFail(oPlayer,oEquip,iRatio)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer.m_iPid
    local iPos = oEquip:EquipPos()
    local iFailCnt = oPlayer:StrengthFailCnt(iPos)
    iFailCnt = iFailCnt + 1
    oPlayer:SetStrengthFailCnt(iPos,iFailCnt)
    local mData = GetStrengthMaterial()
    local iLevel = oPlayer:StrengthenLevel(iPos)
    local mLogData = oPlayer:LogData()
    mLogData.pos = iPos
    mLogData.level = iLevel
    mLogData.succ = 0
    mLogData.fail_cnt = iFailCnt
    record.user("equip", "strength", mLogData)

    -- oPlayer:SyncStrengthenInfo(iPos, false)
    -- oNotifyMgr:Notify(iPid, "强化失败")
end

function CEquipStrengthenMgr:GetEquipBreakInfo(iBreakLv, iPos)
    local mData = GetEquipBreakInfo()
    mData = mData[iBreakLv]
    assert(mData, string.format("equipbreak not find level %d", iBreakLv))
    mData = mData[iPos]
    assert(mData,string.format("equipbreak level(%d) not find pos %d", iBreakLv, iPos))
    return mData
end

function CEquipStrengthenMgr:GetBreakMaxLevel()
    local mData = GetEquipBreakInfo()
    return table_count(mData) - 1
end

-- 返回 道具是否足够, 消耗道具, 缺失的白灵晶数目
function CEquipStrengthenMgr:EquipBreakMaterial(oPlayer, oEquip)
    local iPos = oEquip:EquipPos()
    local iBreakLv = oPlayer.m_oEquipCtrl:GetBreakLevel(iPos)
    local mData = self:GetEquipBreakInfo(iBreakLv, iPos)
    local iSid, iAmount = mData["sid"], mData["amount"]
    if iSid <= 0 or iAmount <=0 then
        return false, nil ,nil
    end

    local iShape = iSid
    local mAmount = {}
    for iUseShape = iShape, 11160 , -1 do
        local iHasAmount = oPlayer:GetItemAmount(iUseShape)
        assert(iHasAmount >= 0 ,string.format("equipbreak err find %d amount %d", iUseShape, iHasAmount))
        if iHasAmount >= iAmount then
            mAmount[iUseShape] = iAmount
            return true, mAmount, 0
        else
            if iHasAmount > 0 then
                mAmount[iUseShape] = iHasAmount
            end
            if iUseShape == 11160 then
                iAmount = iAmount -iHasAmount
                return false, mAmount, iAmount
            else
                iAmount = (iAmount - iHasAmount) * 4
            end
        end
    end
end

function CEquipStrengthenMgr:EquipBreak(oPlayer, oEquip, iFlag)
    local iPos = oEquip:EquipPos()
    local iBreakLv = oPlayer.m_oEquipCtrl:GetBreakLevel(iPos)

    -- 判断当前最大等级才能突破
    local iMaxBreak = self:GetBreakMaxLevel()
    if iBreakLv >= iMaxBreak then
        oPlayer:NotifyMessage(global.oItemHandler:GetTextData(1086))
        return
    end 

    local bEnough, mAmount, iNeedAmount = self:EquipBreakMaterial(oPlayer, oEquip)
    if not iNeedAmount then return end
    local sReason
    local mCost = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷装备突破"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        for iShape, iAmount in pairs(mAmount) do
           mNeedCost["item"][iShape] = iAmount
       end
       if not bEnough then
            if not mNeedCost["item"][11160] then
                mNeedCost["item"][11160] = iNeedAmount
            else
                mNeedCost["item"][11160] = mNeedCost["item"][11160] + iNeedAmount
            end
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["goldcoin"] then
            mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iShape, iUseAmount in pairs(mTrueCost["item"]) do
            mCost[iShape] =iUseAmount
        end
    else
        sReason = "装备突破消耗"
        if not bEnough then
            oPlayer:NotifyMessage(global.oItemHandler:GetTextData(1087))
            return
        end
        
        for iShape ,iAmount in pairs(mAmount) do
            mCost[iShape] = iAmount
            oPlayer:RemoveItemAmount(iShape, iAmount, sReason, {cancel_tip = true})
        end
    end

    oPlayer.m_oEquipCtrl:SetBreakLevel(iPos, iBreakLv + 1)
    oPlayer:SyncStrengthenInfo(iPos)

    local mLogData = oPlayer:LogData()
    mLogData.pos = iPos
    mLogData.level = iBreakLv + 1
    mLogData.cost = mCost
    record.user("equip", "break", mLogData)
end

function CEquipStrengthenMgr:FastEquipStrengh(oPlayer, oEquip, iFlag, iFast)
    local iPos = oEquip:EquipPos()
    local iOldLevel = oPlayer:StrengthenLevel(iPos)
    local bStrengh, mArgs = self:EquipStrengthen(oPlayer, oEquip, iFlag)
    mArgs = mArgs or {}
    if not bStrengh then
        oPlayer:NotifyMessage(mArgs.msg)
        return
    end   

    local iNewLevel = iOldLevel
    if iFast and iFast > 0 then
        for i = 1, 50 do
            local bStrengh, mArgs = self:EquipStrengthen(oPlayer, oEquip, 0)
            if not bStrengh then break end

            iNewLevel = oPlayer:StrengthenLevel(iPos)
            if iNewLevel - iOldLevel >= 5 then break end
        end
    end

    iNewLevel = oPlayer:StrengthenLevel(iPos)
    if iNewLevel <= iOldLevel then
        oPlayer:SyncStrengthenInfo(iPos, false)
        oPlayer:NotifyMessage(global.oItemHandler:GetTextData(1085))
    else
        global.oNotifyMgr:UIEffectNotify(oPlayer:GetPid(), gamedefines.UI_EFFECT_MAP.QIANG_HUA, {})
        oPlayer:Send("GS2CGetScore",{op = 2,score = oPlayer:GetRoleScore()})
        oPlayer:SyncStrengthenInfo(iPos, true)
    end
end
