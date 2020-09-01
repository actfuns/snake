--import module
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))


CSummonSkill = {}
CSummonSkill.__index =CSummonSkill
inherit(CSummonSkill, datactrl.CDataCtrl)

function NewSkill(iSk)
    local o = CSummonSkill:New(iSk)
    return o    
end

function CSummonSkill:New(iSk)
    local o = super(CSummonSkill).New(self)
    o.m_ID = iSk
    o:Init()
    return o
end

function CSummonSkill:Init()
    self:SetData("level", 0)
    self:SetData("innate", 0)
    self.m_mApply = {}

    local mSkillInfo = res["daobiao"]["summon"]["skill"][self.m_ID]
    assert(mSkillInfo, string.format("SummonSkill init err: bad id %d", self.m_ID))
end

function CSummonSkill:GetSkillInfo()
    local mSkillInfo = res["daobiao"]["summon"]["skill"][self.m_ID]
    assert(mSkillInfo, string.format("SummonSkill init err: bad id %d", self.m_ID))
    return mSkillInfo
end

function CSummonSkill:GetSkillCostInfo()
    return res["daobiao"]["summon"]["skillcost"]
end

function CSummonSkill:Save()
    local mData = {}
    mData["level"] = self:GetData("level", 0)
    mData["skid"] = self.m_ID
    mData["bind"] = self:GetData("bind", 0)
    mData["innate"] = self:GetData("innate", 0)
    return mData
end

function CSummonSkill:Load(mData)
    mData = mData or {}
    self:SetData("level", mData["level"] or 0)
    self:SetData("bind", mData["bind"] or 0)
    self:SetData("innate", mData["innate"] or 0)
end

function CSummonSkill:SkID()
    return self.m_ID
end

function CSummonSkill:Score()
    return self:GetSkillInfo()["score"] or 0
end

function CSummonSkill:FightScore()
    return self:GetSkillInfo()["fight_score"]
end

function CSummonSkill:Name()
    return self:GetSkillInfo()["name"] or ""
end

function CSummonSkill:Level()
    return self:GetSkillInfo()["level"]
end

function CSummonSkill:SetLevel(iLevel)
    local iLevel = iLevel or 1
    self:SetData("level", iLevel)
end

function CSummonSkill:LevelUp()
    self:SetData("level", self:GetData("level", 0) + 1)
end

function CSummonSkill:AddApply(sApply,iValue)
    local iApply = self.m_mApply[sApply] or 0
    self.m_mApply[sApply] = iApply + iValue
end

function CSummonSkill:GetApply(sApply,rDefault)
    rDefault = rDefault or 0
    return self.m_mApply[sApply] or rDefault
end

function CSummonSkill:CheckSkillEffect(oSummon)
    local mSkillEffect = oSummon:GetSkillEffect()
    if mSkillEffect[self.m_ID] then return end

    local mEquipSkill = oSummon:GetEquipSkills()
    local mSkill = oSummon:GetSkillMap()
    local iTopSkill = self:GetSkillInfo()["top_skill"]
    if iTopSkill and iTopSkill > 0 then
        local oTopSkill = mEquipSkill[iTopSkill] or mSkill[iTopSkill]
        if oTopSkill then return end
    else
        local iLowSkill = self:GetSkillInfo()["low_skill"]
        local oLowSkill = mEquipSkill[iLowSkill] or mSkill[iLowSkill]
        if oLowSkill and mSkillEffect[oLowSkill:SkID()] then
            oLowSkill:TrueSkillUnEffect(oSummon)
        end
    end
    self:TrueSkillEffect(oSummon)
end

function CSummonSkill:CheckSKillUnEffect(oSummon)
    local mSkillEffect = oSummon:GetSkillEffect()
    if not mSkillEffect[self.m_ID] then return end

    local mEquipSkill = oSummon:GetEquipSkills()
    local mSkill = oSummon:GetSkillMap()
    if mEquipSkill[self.m_ID] and mEquipSkill[self.m_ID] ~= self then return end
    if mSkill[self.m_ID] and mSkill[self.m_ID] ~= self then return end

    local iLowSkill = self:GetSkillInfo()["low_skill"]
    local oSkill = mEquipSkill[iLowSkill] or mSkill[iLowSkill]
    if iLowSkill and oSkill then
        oSkill:SkillEffect(oSummon)
    end
    self:TrueSkillUnEffect(oSummon)
end

function CSummonSkill:TrueSkillEffect(oSummon, bEquip)
    local mEffect = self:GetSkillInfo()["skill_effect"] or {}
    for _,sEffect in ipairs(mEffect) do
        local sApply,sFormula = string.match(sEffect,"(.+)=(.+)")
        if sApply and sFormula then
            local iValue = formula_string(sFormula,{level=self:Level(), grade=oSummon:Grade()})
            oSummon:AddApply(sApply, iValue, self.m_ID)
        end
    end

    local mEffectRatio = self:GetSkillInfo()["skill_effect_ratio"] or {}
    for _, sEffect in ipairs(mEffectRatio) do
        local sApply, sFormula = string.match(sEffect, "(.+)=(.+)")
        if sApply and sFormula then
            local iValue = formula_string(sFormula, {level=self:Level(), grade=oSummon:Grade()})
            oSummon:AddRatioApply(sApply, iValue, self.m_ID)
        end
    end
    oSummon:SetSkillEffect(self.m_ID, true)
end

function CSummonSkill:SkillEffect(oSummon, bEquip)
    local mEffect = self:GetSkillInfo()["skill_effect"] or {}
    local mEffectRatio = self:GetSkillInfo()["skill_effect_ratio"] or {}    
    if self:Level() <= 0 then return end
    if table_count(mEffect) <= 0 and table_count(mEffectRatio) <= 0 then return end

    self:CheckSkillEffect(oSummon, bEquip)
end

function CSummonSkill:TrueSkillUnEffect(oSummon, bEquip)
    oSummon:RemoveApply(self.m_ID)
    oSummon:SetSkillEffect(self.m_ID, nil)
end

function CSummonSkill:SkillUnEffect(oSummon, bEquip)
    local mEffect = self:GetSkillInfo()["skill_effect"] or {}
    local mEffectRatio = self:GetSkillInfo()["skill_effect_ratio"] or {}    
    if self:Level() <= 0 then return end
    if table_count(mEffect) <= 0 and table_count(mEffectRatio) <= 0 then return end

    self:CheckSKillUnEffect(oSummon, bEquip)
end

function CSummonSkill:GenEffectKey()
    return self.m_ID 
end

function CSummonSkill:GetPerformList()
    local mPfData = self:GetSkillInfo()["pflist"]
    local mPerform = {}
    local iLevel = self:Level()
    for _,pfid in pairs(mPfData) do
        mPerform[pfid] = iLevel
    end
    return mPerform
end

function CSummonSkill:CanUpLevel()
    local mskill = self:GetSkillCostInfo()
    local nextlv = self:Level() + 1
    return mskill[nextlv]
end

function CSummonSkill:LearnNeedCost()
    if not self:CanUpLevel() then
        return 0
    end
    local mskill = self:GetSkillCostInfo()
    local nextlv = self:Level() + 1
    return mskill[nextlv]["amount"]
end

function CSummonSkill:LearnNeedGrade()
    if not self:CanUpLevel() then
        return 0
    end
    local mskill = self:GetSkillCostInfo()
    local nextlv = self:Level() + 1
    return mskill[nextlv]["needgrade"]
end

function CSummonSkill:LearnRatio()
    if not self:CanUpLevel() then
        return 0
    end
    local mskill = self:GetSkillCostInfo()
    local nextlv = self:Level() + 1
    return mskill[nextlv]["ratio"]
end

function CSummonSkill:LearnCostTot()
    local mskill = self:GetSkillCostInfo()
    local iCost = 0
    for i=1, self:Level() do
        if mskill[i] then
            iCost = iCost + mskill[i]["amount"]
        end
    end
    return iCost
end

function CSummonSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    mNet["cost"] = self:LearnNeedCost()
    mNet["needgrade"] = self:LearnNeedGrade()
    mNet["bind"] = self:GetData("bind")
    mNet["innate"] = self:GetData("innate")
    return mNet
end

function CSummonSkill:GetScore()
    local iValue = formula_string(self:FightScore(), {lv = self:Level()})
    return iValue
end

function CSummonSkill:IsBind()
    return self:GetData("bind", 0) > 0  
end

function CSummonSkill:SetBind(iFlag)
    self:SetData("bind", iFlag)
end

function CSummonSkill:GetPoint()
    if self:IsInnate() then return 0 end
    
    return self:GetSkillInfo()["point"] or 0
end

function CSummonSkill:IsInnate()
    return self:GetData("innate", 0) > 0
end

function CSummonSkill:SetInnate()
    self:SetData("innate", 1)
end

function CSummonSkill:TopSkill()
    return self:GetSkillInfo()["top_skill"]
end
