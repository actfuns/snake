--import module

local global = require "global"
local skillobj = import(service_path("skill/skillobj"))

CMarrySkill = {}
CMarrySkill.__index = CMarrySkill
CMarrySkill.m_sType = "other"
inherit(CMarrySkill, skillobj.CSkill)

function CMarrySkill:New(iSk)
    local o = super(CMarrySkill).New(self,iSk)
    return o
end

function CMarrySkill:SkillEffect(oPlayer, iSource)
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

function CMarrySkill:SkillUnEffect(oPlayer, iSource)
    for sApply,iValue in pairs(self.m_mApply) do
        oPlayer.m_oSkillMgr:AddApply(sApply,self.m_ID,-iValue)
    end
    self.m_mApply = {}

    oPlayer.m_oSkillCtrl:DelItemSkill(self.m_ID, iSource)
end

function CMarrySkill:GetPerformList()
    local mData = self:GetSkillData() or {}
    local mResult = {}
    for _, iPerform in ipairs(mData["pflist"] or {}) do
        mResult[iPerform] = self:Level()
    end
    return mResult
end

function CMarrySkill:Level()
    return 1
end

function CMarrySkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    return mNet
end

function NewSkill(iSk)
    local o = CMarrySkill:New(iSk)
    return o
end
