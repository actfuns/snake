--import module

local global = require "global"
local skillobj = import(service_path("skill/se/sebase"))

CSESkill = {}
CSESkill.__index = CSESkill
CSESkill.m_sType = "se"
inherit(CSESkill, skillobj.CSESkill)

function CSESkill:SkillEffect(oPlayer, bWield)
    local iPos = self:GetPos()
    if not iPos then return end

    assert(iPos>0 and iPos<7, "illegal pos id:"..iPos)

    local mData = self:GetSkillData()
    local mEffect = mData["skill_effect"] or {}
    local mEnv = {
        level = self:Level()
    }
    for _,sEffect in ipairs(mEffect) do
        local mArgs = formula_string(sEffect,mEnv)
        for sApply,iValue in pairs(mArgs) do
            oPlayer.m_oSkillMgr:AddApply(sApply,iPos,iValue)
            self:AddApply(sApply,iValue)
        end
    end
  
    local iLevel = oPlayer.m_oEquipCtrl:GetStrengthenLevel(iPos)
    if iLevel > 0 and not bWield then
        oPlayer:EquipStrength(iPos, iLevel)
    end
end

function CSESkill:SkillUnEffect(oPlayer)
    local iPos = self:GetPos()
    if not iPos then return end

    assert(iPos>0 and iPos<7, "illegal pos id:"..iPos)

    for sApply,iValue in pairs(self.m_mApply) do
        oPlayer.m_oSkillMgr:AddApply(sApply,iPos,-iValue)
    end
    self.m_mApply = {}

    local iLevel = oPlayer.m_oEquipCtrl:GetStrengthenLevel(iPos)
    if iLevel > 0 then
        oPlayer:EquipStrength(iPos, iLevel)
    end
end

function NewSkill(iSk)
    local o = CSESkill:New(iSk)
    return o
end
