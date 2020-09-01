local global = require "global"
local extend = require "base/extend"

local gamedefines = import(lualib_path("public/gamedefines"))
local analylog = import(lualib_path("public.analylog"))

function GetEquipLevelData()
    local res = require "base.res"
    return res["daobiao"]["equiplevel"]
end

function GetWashEquipData()
    local res = require "base.res"
    return res["daobiao"]["washequip"]
end

function GetAttachAttrData()
    local res = require "base.res"
    return res["daobiao"]["equipattach"]
end

function GetSeData()
    local res = require "base.res"
    return res["daobiao"]["equipse"]
end

CEquipWashMgr = {}
CEquipWashMgr.__index = CEquipWashMgr
inherit(CEquipWashMgr, logic_base_cls())

function CEquipWashMgr:ValidWashEquip(oPlayer,oEquip)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer.m_iPid
    local iLevel = oEquip:EquipLevel()
    local iPos = oEquip:EquipPos()
    local mData = GetWashEquipData()
    mData = mData[iLevel]
    if not mData then
        oNotifyMgr:Notify(iPid,"暂未开发，敬请期待")
        return false
    end
    mData = mData[iPos]
    if not mData then
        oNotifyMgr:Notify(iPid,"暂未开发，敬请期待")
        return false
    end
    -- if not oEquip:IsMake() then
    --     oNotifyMgr:Notify(iPid, "无法洗练")
    --     return false 
    -- end
    -- 银币 和 数量的判断 被放回在washEquip
    -- local iSilver = mData["silver"]
    -- if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then
    --     return false
    -- end
    -- local iAmount = mData["amount"]
    -- -- 洗练石
    -- local iShape =  11097
    -- if oPlayer:GetItemAmount(iShape) < iAmount then
    --     local sTipsName = global.oItemLoader:GetItemTipsNameBySid(iShape)
    --     oNotifyMgr:Notify(iPid,string.format("[%s]不足", sTipsName))
    --     return false
    -- end
    return true
end

function CEquipWashMgr:WashEquip(oPlayer,oEquip, iFlag)
    if not global.oToolMgr:IsSysOpen("EQUIP_XL", oPlayer) then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if not self:ValidWashEquip(oPlayer,oEquip) then
        return
    end
    local mData = GetWashEquipData()
    local iPid = oPlayer.m_iPid
    local iLevel = oEquip:EquipLevel()
    local iPos = oEquip:EquipPos()
    mData = mData[iLevel][iPos]
    local iSilver = mData["silver"]
    local iAmount = mData["amount"]
    -- 洗练石的 sid
    local iShape = 11097
    local mCost = {}
    local sReason
    if iFlag and iFlag > 0 then
        sReason = "快捷洗练装备"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        mNeedCost["item"][iShape] = iAmount
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["silver"] then
            mCost[gamedefines.MONEY_TYPE.SILVER] = mTrueCost["silver"]
        end
        if mTrueCost["goldcoin"] then
            mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mCost[iSid] = iUseAmount
        end
    else
        sReason = "洗练装备"
        if oPlayer:GetItemAmount(iShape) < iAmount then
            oPlayer:NotifyMessage("洗练装备材料不足")
            return
        end
        if not oPlayer:ValidSilver(iSilver, {tip = "洗练装备银币不足"}) then
            return
        end
        mCost = {[iShape]=iAmount}
        oPlayer:ResumeSilver(iSilver, sReason)
        oPlayer:RemoveItemAmount(iShape,iAmount, sReason, {cancel_tip = true})
    end
    self:WashEquipAttachAttr(oPlayer, oEquip, mData["attr_cnt"])
    -- self:WashEquipSE(oEquip)
    oEquip:SendNetWash(oPlayer)

    mCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
    oPlayer.m_oItemCtrl:FireEquipWash(oEquip)
    oPlayer:MarkGrow(32)
    global.oNotifyMgr:UIEffectNotify(oPlayer:GetPid(), gamedefines.UI_EFFECT_MAP.XI_LIAN, {})
    analylog.LogSystemInfo(oPlayer, "equip_wash", oEquip:Shape(), mCost)
end

function CEquipWashMgr:RandomRatio(lAttrRatio)
    local mRatio = {}
    for idx, m in pairs(lAttrRatio) do
        mRatio[idx] = m["weight"]
    end
    local iRan = table_choose_key(mRatio)
    local mData = lAttrRatio[iRan]
    return math.random(mData["min"], mData["max"])
end

--洗附加属性
function CEquipWashMgr:WashEquipAttachAttr(oPlayer, oEquip, iAttachCnt)
    local mData = GetAttachAttrData()[oPlayer:GetSchool()]
    if not mData then return end
    
    local mRatio = {}        
    local mAttr = mData["attr"] or {}
    for id, mData in pairs(mAttr) do
        mRatio[id] = mData["ratio"]
    end

    local lWashAttach, mRandomCnt = {}, {}
    for i=1, iAttachCnt do
        local idx = table_choose_key(mRatio)
        local mAttrData = mAttr[idx]
        mRandomCnt[idx] = (mRandomCnt[idx] or 0) + 1
        if mRandomCnt[idx] >= mAttrData["re_cnt"] then
            mRatio[idx] = nil
        end
        
        local iRatio = self:RandomRatio(mAttrData["attr_ratio"])        
        local mEnv = {
            lv = oEquip:EquipLevel(),
            k = iRatio/100,
        }
        for _,sArgs in pairs(mAttrData["attachAttr"] or {}) do
            local mAttr = formula_string(sArgs, mEnv)
            for sAttr,iValue in pairs(mAttr) do
                table.insert(lWashAttach, {[sAttr]=math.floor(iValue)})
            end
        end
    end
    oEquip:SetData("wash_back", lWashAttach)
end

--洗特效
function CEquipWashMgr:WashEquipSE(oEquip,mArgs)
    local oEquipMakeMgr = global.oItemHandler.m_oEquipMakeMgr
    local iEquipLevel = oEquip:EquipLevel()
    local iEquipPos = oEquip:EquipPos()
    local bSucc = false
    local mEquipSE = oEquip:GetSE()
    local iCount = table_count(mEquipSE)
    local lPosList = {iEquipPos, 99}

    if iCount >= 2 then
        oEquip:SetBackSe(nil)
        for _, iPos in ipairs(lPosList) do
            local bRet = self:ReplaceSE(oEquip, iEquipLevel, iPos, mEquipSE)
            bSucc = bSucc or bRet
        end
    elseif iCount == 1 then
        oEquip:SetBackSe(nil)
        local iOldSE = next(mEquipSE)
        for _, iPos in ipairs(lPosList) do
            local mSelect = oEquipMakeMgr:GetSelectSEMap(iEquipLevel, iPos)
            if mSelect[iOldSE] then
                local bRet = self:ReplaceSE(oEquip, iEquipLevel, iPos, mEquipSE)
                bSucc = bSucc or bRet
            else
                if math.random(100) <= 2 then
                    local bRet = self:ReplaceSE(oEquip, iEquipLevel, iPos)
                    bSucc = bSucc or bRet
                end
            end
        end
    else
        for _, iPos in ipairs(lPosList) do
            if math.random(100) <= 3 then
                if not bSucc then oEquip:SetBackSe(nil) end
                local bRet = self:ReplaceSE(oEquip, iEquipLevel, iPos)
                bSucc = bSucc or bRet
            end
        end
    end
    if not bSucc then
        -- 清除预洗结果（增量更新，减少存盘次数）
        local oldBackSe = oEquip:GetBackSe()
        if oldBackSe and next(oldBackSe) then
            oEquip:SetBackSe(nil)
        end
    end
end

function CEquipWashMgr:ReplaceSE(oEquip, iLevel, iPos, mEquipSE)
    local oEquipMakeMgr = global.oItemHandler.m_oEquipMakeMgr
    local mSelect = oEquipMakeMgr:GetSelectSEMap(iLevel, iPos, mEquipSE)
    if not next(mSelect) then
        mSelect = oEquipMakeMgr:GetSelectSEMap(iLevel, iPos)
    end
    local iSE = table_choose_key(mSelect)
    if iSE then
        oEquip:AddBackSe(iSE)
        return true
    end
end
