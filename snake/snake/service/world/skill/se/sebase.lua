--import module

local global = require "global"
local skillobj = import(service_path("skill/skillobj"))

CSESkill = {}
CSESkill.__index = CSESkill
CSESkill.m_sType = "se"
inherit(CSESkill,skillobj.CSkill)

function CSESkill:New(iSk)
    local o = super(CSESkill).New(self,iSk)
    return o
end

function CSESkill:SkillEffect(oPlayer, bWield, iSource)
    local mData = self:GetSkillData()
    local mEffect = mData["skill_effect"] or {}
    local mEnv = {
        level = self:Level()
    }
    for _,sEffect in ipairs(mEffect) do
        local mArgs = formula_string(sEffect,mEnv)
        for sApply,iValue in pairs(mArgs) do
            oPlayer.m_oSkillMgr:AddApply(sApply,self.m_ID,iValue)
            self:AddApply(sApply,iValue)
        end
    end
    local lPerform = mData["pflist"] or {}
    if lPerform and next(lPerform) then
        oPlayer.m_oSkillCtrl:AddItemSkill(self.m_ID, self:Save(), iSource)
    end
end

function CSESkill:SkillUnEffect(oPlayer, iSource)
    for sApply,iValue in pairs(self.m_mApply) do
        oPlayer.m_oSkillMgr:AddApply(sApply,self.m_ID,-iValue)
    end
    self.m_mApply = {}

    oPlayer.m_oSkillCtrl:DelItemSkill(self.m_ID, iSource)
end

function CSESkill:ApplyName()
    local res = require "base.res"
    local mAttrName = res["daobiao"]["attrname"]
    local str = ""
    for sApply,iValue in pairs(self.m_mApply) do
        local sName = mAttrName[sApply]["name"]
        if iValue > 0 then
            str = str .. string.format("%s+%s",sName,iValue)
        else
            str = str .. string.format("%s-%s",sName,iValue)
        end
    end
    return str
end

function CSESkill:GetPerformList()
    local mData = self:GetSkillData()
    local mResult = {}
    for _, iPerform in ipairs(mData["pflist"] or {}) do
        mResult[iPerform] = self:Level()
    end
    return mResult
end

function CSESkill:GetScore(iEquipLevel)
    iEquipLevel  = iEquipLevel or 0
    local mData = self:GetSkillData()
    local iValue = formula_string(mData["score"], {lv = iEquipLevel})
    return iValue
end

function NewSkill(iSk)
    local o = CSESkill:New(iSk)
    return o
end
