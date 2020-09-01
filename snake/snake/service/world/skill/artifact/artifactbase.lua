local global = require "global"
local skillobj = import(service_path("skill/skillobj"))

function NewSkill(...)
    local o = CArtifactSkill:New(...)
    return o
end


ARTIFACT_POS = 8

CArtifactSkill = {}
CArtifactSkill.__index = CArtifactSkill
CArtifactSkill.m_sType = "artifact"
inherit(CArtifactSkill, skillobj.CSkill)

function CArtifactSkill:New(iSk)
    local o = super(CArtifactSkill).New(self, iSk)
    return o
end

function CArtifactSkill:Init()
    super(CArtifactSkill).Init(self)
    self.m_mRatioApply = {}
end

function CArtifactSkill:AddRatioApply(sAttr, iVal)
    local iApply = self.m_mRatioApply[sAttr] or 0
    self.m_mRatioApply[sAttr] = iApply + iVal
end

function CArtifactSkill:SkillEffect(oPlayer)
    self:SkillUnEffect(oPlayer)

    local mSkill = self:GetSkillData()
    local mEnv = {level = self:Level()}

    if mSkill.skill_effect and #mSkill.skill_effect > 0 then
        local mApply = formula_string(mSkill.skill_effect, {})
        for sAttr, iValue in pairs(mApply) do
            oPlayer.m_oSkillMgr:AddApply(sAttr, self.m_ID, iValue)
            --oPlayer.m_oEquipMgr:AddApply(sApply, ARTIFACT_POS, -iValue)
            self:AddApply(sAttr, iValue)
            oPlayer:AttrPropChange(sAttr)
        end
    end

    if mSkill.skill_effect_ratio and #mSkill.skill_effect_ratio > 0 then
        local mApply = formula_string(mSkill.skill_effect_ratio, {})
        for sAttr, iValue in pairs(mApply) do
            oPlayer.m_oSkillMgr:AddRatioApply(sAttr, self.m_ID, iValue)
            --oPlayer.m_oEquipMgr:AddRatioApply(sApply, ARTIFACT_POS, -iValue)
            self:AddRatioApply(sAttr, iValue)
            oPlayer:AttrPropChange(sAttr)
        end
    end
end

function CArtifactSkill:SkillUnEffect(oPlayer)
    for sApply, iValue in pairs(self.m_mApply) do
        oPlayer.m_oSkillMgr:AddApply(sApply, self.m_ID, -iValue)
        --oPlayer.m_oEquipMgr:AddApply(sApply, ARTIFACT_POS, -iValue)
        oPlayer:AttrPropChange(sApply)
    end
    self.m_mApply = {}

    for sApply, iValue in pairs(self.m_mRatioApply) do
        oPlayer.m_oSkillMgr:AddRatioApply(sApply, self.m_ID, -iValue)
        --oPlayer.m_oEquipMgr:AddRatioApply(sApply, ARTIFACT_POS, -iValue)
        oPlayer:AttrPropChange(sApply)
    end
    self.m_mRatioApply = {}
end

function CArtifactSkill:GetPerformList()
    local mData = self:GetSkillData()
    local mResult = {}
    for _, iPerform in ipairs(mData["pflist"] or {}) do
        mResult[iPerform] = 1
    end
    return mResult
end

