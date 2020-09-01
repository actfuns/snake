-----------------
--新伙伴装备
-----------------

local global = require "global"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))


function NewEquipCtrl(...)
    return CEquipCtrl:New(...)
end

function NewEquipObj(...)
    return CEquip:New(...)
end


CEquipCtrl = {}
CEquipCtrl.__index = CEquipCtrl
inherit(CEquipCtrl, datactrl.CDataCtrl)

function CEquipCtrl:New(iPartner, iPid, iSid)
    local o = super(CEquipCtrl).New(self, {partner = iPartner, pid=iPid})
    o.m_iPartner = iPartner
    o.m_iOwner = iPid
    o.m_iSid = iSid
    o.m_mPos2Equip = {}
    o.m_mApply = {}
    return o
end

function CEquipCtrl:Release()
    for iPos, oEquip in pairs(self.m_mPos2Equip) do
        oEquip:Release()
    end
    self.m_mPos2Equip = {}
    super(CEquipCtrl).Release(self)
end

function CEquipCtrl:Load(mData)
    if not mData then return end
    
    for iPos, mEquip in pairs(mData.pos2equip or {}) do
        local oEquip = NewEquipObj(iPos)
        oEquip:Load(mEquip)
        self.m_mPos2Equip[iPos] = oEquip
    end
end

function CEquipCtrl:Save()
    local mPos2Equip = {}
    for iPos, oEquip in pairs(self.m_mPos2Equip) do
        mPos2Equip[iPos] = oEquip:Save()
    end
    local mData = {}
    mData.pos2equip = mPos2Equip
    return mData
end

function CEquipCtrl:Setup()
    for iPos, oEquip in pairs(self.m_mPos2Equip) do
        local mApply = oEquip:GetAllApplyInfo()
        self:ClearApplyByPos(iPos, true)
        self:DispatchApply(iPos, mApply, true)
    end
end

function CEquipCtrl:AddEquipByPos(oPartner, iPos)
    local oEquip = NewEquipObj(iPos)
    self.m_mPos2Equip[iPos] = oEquip

    local mApply = oEquip:GetAllApplyInfo()
    self:ClearApplyByPos(iPos, true)
    self:DispatchApply(iPos, mApply, true)

    global.oScoreCache:Dirty(self.m_iOwner, "partnerctrl")
    global.oScoreCache:PartnerDirty(self.m_iPartner)
    oPartner:PropChange("equipsid", "score")
end

function CEquipCtrl:GetEquipByPos(iPos)
    return self.m_mPos2Equip[iPos]
end

function CEquipCtrl:ValidUpgrade(oPlayer, iPos, bGoldCoin)
    local oEquip = self.m_mPos2Equip[iPos]
    local oPartner = self:GetPartner()
    local mConfig = GetPartnerEquipInfo(iPos)

    if not oEquip then
        local sMsg = global.oToolMgr:GetTextData(2007, {"partner"})
        return false, sMsg
    end

    local iLevel = oEquip:GetLevel() + mConfig.upgrade
    if iLevel > oPartner:GetGrade() then
        local sMsg = global.oToolMgr:GetTextData(2008, {"partner"})
        return false, sMsg
    end

    local mUpgradeCost = GetPartnerEquipUpgradeCost()
    local mCostItem = mUpgradeCost[iLevel]
    if not mCostItem then
        local sMsg = global.oToolMgr:GetTextData(2012, {"partner"})
        return false, sMsg
    end

    local iSid = mConfig.upgrade_cost_sid
    local iAmount = mCostItem.upgrade_cost_amount
    local sName = global.oItemLoader:GetItem(iSid):TipsName()
    local sMsg = global.oToolMgr:GetTextData(2009, {"partner"})
    sMsg = global.oToolMgr:FormatColorString(sMsg, {material=sName})
    local mAnaly = {}

    if bGoldCoin then
        local mCost = {item={[iSid] = iAmount}}
        local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, mCost, "伙伴装备升级")
        if not bSucc then
            return false, sMsg
        end
        for iCostSid, iCostAmount in pairs(mLogCost.item or {}) do
            mAnaly[iCostSid] = iCostAmount
        end
        mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mLogCost.goldcoin
    else
        if oPlayer:GetItemAmount(iSid) < iAmount then
            return false, sMsg
        end
        oPlayer:RemoveItemAmount(iSid, iAmount, "伙伴装备升级")
        mAnaly[iSid] = iAmount
    end

    return true, mAnaly
end

function CEquipCtrl:UpgardeEquipByPos(iPos)
    local oEquip = self.m_mPos2Equip[iPos]
    local oPartner = self:GetPartner()
    local oPlayer = self:GetOwner()
    local mConfig = GetPartnerEquipInfo(iPos)

    if oEquip and oPartner then
        local iLevel = oEquip:GetLevel() + mConfig.upgrade
        self:Dirty()
        oEquip:SetLevel(iLevel)
        self:ClearApplyByPos(iPos, true)
        local mApply = oEquip:GetAllApplyInfo()
        self:DispatchApply(iPos, mApply, true)
        oPartner:PropChange("equipsid", "score")
        global.oScoreCache:Dirty(self.m_iOwner, "partnerctrl")
        global.oScoreCache:PartnerDirty(self.m_iPartner)
        oPlayer:PropChange("score")

        local mLogData = oPlayer:LogData()
        mLogData["partner_sid"] = oPartner:GetSID().."|"..oPartner:GetName()
        mLogData["pos"] = iPos.."|"..oEquip:Name()
        mLogData["apply"] = oEquip:LogData()
        record.log_db("partner", "equip_partner", mLogData)
    end
end

function CEquipCtrl:ValidStrengthEquip(oPlayer, iPos)
    local oEquip = self.m_mPos2Equip[iPos]
    local oPartner = self:GetPartner()
    local mConfig = GetPartnerEquipInfo(iPos)

    if not oEquip then
        local sMsg = global.oToolMgr:GetTextData(2007, {"partner"})
        return false, sMsg
    end

    local iLevel = oEquip:GetStrengthLevel() + 1
    if iLevel > oPartner:GetGrade() then
        local sMsg = global.oToolMgr:GetTextData(2010, {"partner"})
        return false, sMsg
    end

    local mStrengthCost = GetPartnerEquipStrengthCost()
    if not mStrengthCost[iLevel] then
        local sMsg = global.oToolMgr:GetTextData(2013, {"partner"})
        return false, sMsg
    end

    local iCostSilver = mStrengthCost[iLevel].strength_silver
    if not oPlayer.m_oActiveCtrl:ValidSilver(iCostSilver, {cancel_tip=1}) then
        local sMsg = global.oToolMgr:GetTextData(2011, {"partner"})
        return false, sMsg
    end
    return true, {[gamedefines.MONEY_TYPE.SILVER] = iCostSilver}
end

function CEquipCtrl:StrengthEquipByPos(iPos, bQuick)
    local oEquip = self.m_mPos2Equip[iPos]
    local oPartner = self:GetPartner()
    local oPlayer = self:GetOwner()
    local mConfig = GetPartnerEquipInfo(iPos)

    if oEquip and oPartner then
        local mStrengthCost = GetPartnerEquipStrengthCost()
        local iLevel, iCostSilver = 0, 0
        if not bQuick then
            iLevel = oEquip:GetStrengthLevel() + 1
            iCostSilver = mStrengthCost[iLevel].strength_silver
            oPlayer.m_oActiveCtrl:ResumeSilver(iCostSilver, "伙伴装备强化")
        else
            local iCnt = 0
            for i = oEquip:GetStrengthLevel() + 1, oPartner:GetGrade() do
                if not mStrengthCost[i] or iCnt >= 10 then
                    break
                end
                local iTotal = iCostSilver + mStrengthCost[i].strength_silver
                if oPlayer.m_oActiveCtrl:ValidSilver(iTotal, {cancel_tip = 1}) then
                    iLevel = i
                    iCostSilver = iTotal
                    iCnt = iCnt + 1
                else
                    break
                end
            end
            oPlayer.m_oActiveCtrl:ResumeSilver(iCostSilver, "伙伴装备强化")
        end

        self:Dirty()
        oEquip:SetStrengthLevel(iLevel)
        self:ClearApplyByPos(iPos, true)
        local mApply = oEquip:GetAllApplyInfo()
        self:DispatchApply(iPos, mApply, true)

        global.oScoreCache:Dirty(self.m_iOwner, "partnerctrl")
        global.oScoreCache:PartnerDirty(self.m_iPartner)
        oPartner:PropChange("equipsid", "score")
        oPlayer:PropChange("score")

        local mLogData = oPlayer:LogData()
        mLogData["partner_sid"] = oPartner:GetSID().."|"..oPartner:GetName()
        mLogData["pos"] = iPos.."|"..oEquip:Name()
        mLogData["apply"] = oEquip:LogData()
        record.log_db("partner", "equip_partner", mLogData)
    end
end

function CEquipCtrl:DispatchApply(iPos, mApply, bRefresh)
    for sAttr, iVal in pairs(mApply) do
        if not self.m_mApply[sAttr] then
            self.m_mApply[sAttr] = {}
        end
        self.m_mApply[sAttr][iPos] = iVal
    end

    local oPartner = self:GetPartner()
    if oPartner and bRefresh and next(mApply) then
        local oPartner = self:GetPartner()
        local lRefresh = table_key_list(mApply)
        oPartner:PropChange(table.unpack(lRefresh))
        if mApply["max_hp"] or mApply["max_mp"] then
            oPartner:FullStatus(true)
        end
    end
end

function CEquipCtrl:ClearApplyByPos(iPos, bRefresh)
    local mRefresh = {}
    for sAttr, mApply in pairs(self.m_mApply) do
        if mApply[iPos] then
            mApply[iPos] = nil
            mRefresh[sAttr] = 1
        end
    end
    local oPartner = self:GetPartner()
    if oPartner and bRefresh and next(mRefresh) then
        local lRefresh = table_key_list(mRefresh)
        oPartner:PropChange(table.unpack(lRefresh))
        if mRefresh["max_hp"] or mRefresh["max_mp"] then
            oPartner:FullStatus(true)
        end
    end
    return mRefresh
end

function CEquipCtrl:GetApply(sAttr)
    local mApply = self.m_mApply[sAttr] or {}
    local iApply = 0
    for iPos, iVal in pairs(mApply) do
        iApply = iApply + iVal
    end
    return iApply
end

function CEquipCtrl:GetRatioApply(sAttr)
    return 0
end

function CEquipCtrl:GetScore()
    local iScore = 0
    for iPos, oEquip in pairs(self.m_mPos2Equip) do
        iScore = iScore + oEquip:GetScore()
    end
    return iScore
end

function CEquipCtrl:PackNetInfo()
    local lEquip = {}
    for iPos, oEquip in pairs(self.m_mPos2Equip) do
        local mEquip = {
            level = oEquip:GetLevel(),
            equip_sid = iPos,
            strength = oEquip:GetStrengthLevel(),
        }
        table.insert(lEquip, mEquip)
    end
    return lEquip
end

function CEquipCtrl:GetPartner()
    local oPlayer = self:GetOwner()
    if oPlayer then
        return oPlayer.m_oPartnerCtrl:GetPartner(self.m_iPartner)
    end
end

function CEquipCtrl:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iOwner)
    return oPlayer
end


CEquip = {}
CEquip.__index = CEquip
inherit(CEquip, datactrl.CDataCtrl)

function CEquip:New(iPos)
    local mInfo = GetPartnerEquipInfo(iPos)
    local o = super(CEquip).New(self)
    o.m_iPos = iPos
    o.m_iLevel = mInfo.init_lv or 10    --等级
    o.m_iStrengthLevel = 0              --强化
    return o
end

function CEquip:Name()
    local mConfig = GetPartnerEquipInfo(self.m_iPos)
    return mConfig.equip_name
end

function CEquip:SetLevel(iLevel)
    self.m_iLevel = iLevel
end

function CEquip:GetLevel()
    return self.m_iLevel
end

function CEquip:SetStrengthLevel(iLevel)
    self.m_iStrengthLevel = iLevel
end

function CEquip:GetStrengthLevel()
    return self.m_iStrengthLevel
end

function CEquip:Save()
    local mData = {}
    mData.level = self.m_iLevel
    mData.strengthlevel = self.m_iStrengthLevel
    return mData
end

function CEquip:Load(m)
    if not m then return end

    self.m_iLevel = m.level
    self.m_iStrengthLevel = m.strengthlevel
end

function CEquip:GetApplyInfo()
    local mEnv = {lv = self.m_iLevel}
    local mInfo = GetPartnerEquipInfo(self.m_iPos)
    return formula_string(mInfo.attr_formula, mEnv)
end

function CEquip:GetStrengthInfo()
    local mEnv = {lv = self.m_iStrengthLevel}
    local mInfo = GetPartnerEquipInfo(self.m_iPos)
    return formula_string(mInfo.strength_formula, mEnv)
end

function CEquip:GetAllApplyInfo()
    local mApply = self:GetApplyInfo()
    local mStrength = self:GetStrengthInfo()
    for sKey, iVal in pairs(mStrength) do
        mApply[sKey] = (mApply[sKey] or 0) + iVal
    end
    return mApply
end

function CEquip:GetScore()
    local mEnv = {lv = self.m_iLevel, strength_lv = self.m_iStrengthLevel}
    local mInfo = GetPartnerEquipInfo(self.m_iPos)
    return formula_string(mInfo.score, mEnv)
end

function CEquip:LogData()
    return string.format("level:%d,strength:%d", self:GetLevel(), self:GetStrengthLevel())
end


function GetPartnerEquipInfo(iPos)
    return res["daobiao"]["partner"]["partner_equip"][iPos]
end

function GetPartner2EquipSid(iSid)
    return res["daobiao"]["partner"]["partner2equipsid"][iSid]
end

function GetPartnerEquipUpgradeCost()
    return res["daobiao"]["partner"]["partner_equip_upgrade_cost"]
end

function GetPartnerEquipStrengthCost()
    return res["daobiao"]["partner"]["partner_equip_strength_cost"]
end
