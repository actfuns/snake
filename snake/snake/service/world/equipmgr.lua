local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local attrmgr = import(service_path("attrmgr"))
local itemdefines = import(service_path("item.itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewEquipMgr(pid)
    local o = CEquipMgr:New(pid)
    o:SetSynclSum()
    return o
end

CEquipMgr = {}
CEquipMgr.__index = CEquipMgr
CEquipMgr.m_ApplySumDef = gamedefines.SUM_DEFINE.MO_EQUIP_MGR
CEquipMgr.m_RatioSumDef = gamedefines.SUM_DEFINE.MO_EQUIP_MGR_R
inherit(CEquipMgr, attrmgr.CAttrMgr)

function CEquipMgr:New(pid)
    local o = super(CEquipMgr).New(self,pid)
    o.m_iOwner = pid
    o.m_mStrengthenApply = {}
    o.m_mStrengthenRatioApply = {}
    return o
end

function CEquipMgr:Release()
    super(CEquipMgr).Release(self)
end

function CEquipMgr:GetOwner()
    return self.m_iOwner
end

function CEquipMgr:PreLogin(bReEnter)
    if bReEnter then return end

    self:ReCalculateStrengthEffect()
    self:CalMasterApply()
end

function CEquipMgr:ReCalculateStrengthEffect()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then return end

    for iPos = 1, 6 do
        local iLevel = oPlayer.m_oEquipCtrl:GetStrengthenLevel(iPos)
        if iLevel > 0 then
            self:UpdateStrengthenSource(iPos, iLevel)
        end
    end
    -- TODO 可以将强化大师的结果记录为全装备后生效的结果，然后通过判断是否生效来决定是否加
    local iMasterLevel = oPlayer:StrengthMasterLevel()
    if iMasterLevel > 0 then
        self:UpdateStrengthenSource(itemdefines.STRENGTH_MASTER, iMasterLevel)
    end
end

function CEquipMgr:CalMasterApply()
    local iMasterSourceId = itemdefines.STRENGTH_MASTER
    self:RemoveSource(iMasterSourceId)
    local mAttrs = self:GetStrengthenApplyBySource(iMasterSourceId)
    if mAttrs then
        for sAttr, iValue in pairs(mAttrs) do
            self:AddApply(sAttr, iMasterSourceId, iValue)
        end
    end
end

function CEquipMgr:SetStrengthenApplyBySource(iSource, sAttr, iValue)
    table_set_depth(self.m_mStrengthenApply, {iSource}, sAttr, iValue)
end

function CEquipMgr:SetStrengthenRatioApplyBySource(iSource, sAttr, iValue)
    table_set_depth(self.m_mStrengthenRatioApply, {iSource}, sAttr, iValue)
end

function CEquipMgr:SetStrengthenSource(iSource, mApply, mRatioApply)
    self.m_mStrengthenApply[iSource] = mApply
    self.m_mStrengthenRatioApply[iSource] = mRatioApply
end

function CEquipMgr:GetStrengthenApplyBySource(iSource)
    return self.m_mStrengthenApply[iSource]
end

function CEquipMgr:GetStrengthenRatioApplyBySource(iSource)
    return self.m_mStrengthenRatioApply[iSource]
end

function CEquipMgr:RemoveStrengthenSource(iSource)
    self.m_mStrengthenApply[iSource] = nil
    self.m_mStrengthenRatioApply[iSource] = nil
end

function CEquipMgr:UpdateStrengthenSource(iSource, iLevel)
    -- self:RemoveSource(iSource)
    self:RemoveStrengthenSource(iSource)
    -- 加新数据
    local mApply, mRatioApply
    if iSource == itemdefines.STRENGTH_MASTER then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
        if oPlayer then
            mApply = self:CalcStrengthenMasterAttrs(iLevel, oPlayer:GetSchool())
        end
    else
        mApply = self:CalcStrengthenAttrsByPos(iLevel, iSource)
    end
    self.m_mStrengthenApply[iSource] = mApply
end

function CEquipMgr:CalcStrengthenAttrsByPos(iDoLevel, iPos)
    if not (iDoLevel > 0) then
        return {}
    end
    local res = require "base.res"
    local mData = table_get_depth(res, {"daobiao", "strength", iDoLevel, iPos})
    assert(mData, string.format("CalcStrengthenAttrsByPos err:%d %d %d", self:GetOwner(), iDoLevel, iPos))
    if not mData then
        return {}
    end
    local sEffect = mData["strength_effect"]
    if not sEffect then
        return {}
    end
    local mEnv = {}
    local mAttrs = {}
    local mArgs = formula_string(sEffect, mEnv)
    for sAttr, iValue in pairs(mArgs) do
        mAttrs[sAttr] = (mAttrs[sAttr] or 0) + iValue
    end
    mAttrs = self:StrengthAddRatio(mAttrs, iPos)

    return mAttrs
end

--易成长加成
function CEquipMgr:StrengthAddRatio(mAttrs, iPos)
    local iOwner = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if not oPlayer then return mAttrs end

    local iRatio = oPlayer.m_oSkillMgr:GetApplyBySource("strength_add_ratio", iPos)
    if iRatio <= 0 then return mAttrs end

    local mResult = {}
    for sAttr, iVal in pairs(mAttrs) do
        mResult[sAttr] = math.floor(iVal * (100 + iRatio) / 100)
    end
    return mResult
end

function CEquipMgr:CalcStrengthenMasterAttrs(iDoLevel, iSchool)
    if not (iDoLevel > 0) then
        return {}
    end
    local res = require "base.res"
    local mData = table_get_depth(res, {"daobiao", "strengthmaster", iSchool, iDoLevel})
    assert(mData, string.format("CalcStrengthenMasterAttrs err:%d %d %d", self:GetOwner(), iDoLevel, iSchool))
    
    local sFormula = mData["strength_effect"]
    local mAttrs = formula_string(sFormula, {})
    return mAttrs
end

function CEquipMgr:GetScore(bForce)
    local rScore = 0
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return rScore 
    end
    for iPos=1,6 do
        local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
        if oItem then
            rScore = rScore + oItem:GetScore(bForce)
            rScore = rScore + self:GetStrengthenPosScore(oItem:EquipPos())
        end
    end
    rScore = math.floor(rScore)
    return rScore
end

function CEquipMgr:GetScoreBySH()
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    local rScore = 0
    for iPos=1,6 do
        local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
        if oItem then
            rScore = rScore + oItem:GetScoreBySH()
        end
    end
    return rScore
end

function CEquipMgr:GetScoreByStrength()
    local rScore = 0
    for i = 1 , 6 do 
        rScore = rScore + self:GetStrengthenPosScore(i)
    end
    return rScore
end

function CEquipMgr:GetScoreByHunShi()
    local rScore = 0
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return rScore
    end
    for iPos = 1 , 6 do 
        local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
        if oItem then
            rScore = rScore + oItem:GetScoreByHunShi()
        end
    end
    rScore = math.floor(rScore)
    return rScore
end

function CEquipMgr:GetStrengthenMasterScore()
    local rScore = 0 
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return rScore
    end
    local iMinStrengthLevel = 1000000
    for iPos=1,6 do
        local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
        if not oItem then
            rScore = 0
            return rScore
        end
        local iStrengthLevel = oPlayer.m_oEquipCtrl:GetStrengthenLevel(iPos)
        if iStrengthLevel<iMinStrengthLevel then
            iMinStrengthLevel = iStrengthLevel
        end
    end

    local sStrengthMasterScore = res["daobiao"]["strengthscore"]["masterscore"]["score"]
    local iStrengthLevel = math.floor(iMinStrengthLevel/5)
    rScore = formula_string(sStrengthMasterScore,{grade = iStrengthLevel})
    return rScore
end

function CEquipMgr:GetStrengthenPosScore(iPos)
    local rScore = 0 
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return rScore
    end
    local sStrengthEquipScore = res["daobiao"]["strengthscore"]["equipscore"]["score"]
    local iStrengthLevel = oPlayer.m_oEquipCtrl:GetStrengthenLevel(iPos)
    rScore = formula_string(sStrengthEquipScore,{grade = iStrengthLevel})
    return rScore
end

function CEquipMgr:CountScoreByAttrs(mFormulas, mAttrs)
    local rScore = 0
    for sAttr, mInfo in pairs(mFormulas) do
        local iValue = mAttrs[sAttr] or 0
        local sFormula = mInfo.command
        rScore = rScore + formula_string(sFormula, {attr = iValue})
    end
    return rScore
end

function CEquipMgr:CountAllScoreByAttrs(mAttrs)
    if not mAttrs or table_count(mAttrs) == 0 then
        return 0
    end
    local rScore = 0
    local mFormulas = res["daobiao"]["rolebasicscore"]
    rScore = rScore + self:CountScoreByAttrs(mFormulas, mAttrs)
    local mFormulas = res["daobiao"]["extrapoint"]
    rScore = rScore + self:CountScoreByAttrs(mFormulas, mAttrs)
    return rScore
end
