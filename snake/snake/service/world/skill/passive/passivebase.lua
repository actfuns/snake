--import module

local global = require "global"
local skillobj = import(service_path("skill/skillobj"))

CSchoolPassiveSkill = {}
CSchoolPassiveSkill.__index = CSchoolPassiveSkill
CSchoolPassiveSkill.m_sType = "passive"
inherit(CSchoolPassiveSkill,skillobj.CSkill)

function CSchoolPassiveSkill:New(iSk)
    local o = super(CSchoolPassiveSkill).New(self,iSk)
    return o
end

function CSchoolPassiveSkill:OpenLevel()
    return self:GetSkillData()["open_level"] or 5
end

function CSchoolPassiveSkill:SkillEffect(oPlayer)
    if self:Level() <= 0 then
        return
    end
    self:SkillUnEffect(oPlayer)
    local mEffect = self:GetSkillData()["skill_effect"] or {}
    for _,sEffect in ipairs(mEffect) do
        local sApply,sFormula = string.match(sEffect,"(.+)=(.+)")
        if sApply and sFormula then
            local iValue = formula_string(sFormula,{level=self:Level()})
            iValue = math.floor(iValue)
            oPlayer.m_oSkillMgr:AddApply(sApply,self.m_ID,iValue)
            self:AddApply(sApply,iValue)
            oPlayer:AttrPropChange(sApply)
        end
    end
end

function CSchoolPassiveSkill:SkillUnEffect(oPlayer)
    for sApply,iValue in pairs(self.m_mApply) do
        oPlayer.m_oSkillMgr:AddApply(sApply,self.m_ID,-iValue)
        oPlayer:AttrPropChange(sApply)
    end
    self.m_mApply = {}
end

-- function CSchoolPassiveSkill:LearnNeedCost(iLevel)
--     iLevel = iLevel or self.m_iLevel + 1
--     local iNowLevel = iLevel - 1
--     local iSilver = 0
--     if iLevel < 40 then
--         iSilver = (iLevel ^ 3 * 1.3 - iLevel ^ 2 * 20 + (iLevel-1) * 150 + 60) / (iLevel*iLevel/250+5)
--     elseif iLevel >= 40 and iLevel < 80 then
--         iSilver = (iLevel ^ 3 * 1.3 - iLevel ^2 * 20 + (iLevel-1) * 150 + 60) * ((iLevel - 39) * 0.1 + 1) * 2 / (iLevel * iLevel/250 + 5)
--     elseif iLevel >= 80 and iLevel <100 then
--         iSilver = (iLevel ^ 3 * 1.3 - iLevel ^2 * 20 + (iLevel-1) * 150 + 60) * ((iLevel - 39) * 0.1 + 1) * ((iLevel - 79) * 0.1 + 1 ) * 2 / (iLevel * iLevel/250 + 5)
--     elseif iLevel >= 100 and iLevel < 120 then
--         iSilver = (iLevel ^ 3 * 1.3 - iLevel ^2 * 20 + (iLevel-1) * 150 + 60) * ((iLevel - 39) * 0.1 + 1) * ((iLevel - 79) * 0.1 + 1 ) * 2.5 / (iLevel * iLevel/250 + 5)
--     else
--         iSilver = (iLevel ^ 3 * 1.3 - iLevel ^2 * 20 + (iLevel-1) * 150 + 60) * ((iLevel - 39) * 0.1 + 1) * ((iLevel - 79) * 0.1 + 1 ) * 3 / (iLevel * iLevel/250 + 5)
--     end
--     local oWorldMgr = global.oWorldMgr
--     local iServerGrade = oWorldMgr:GetServerGrade()
--     if iNowLevel < iServerGrade - 5 then
--         iSilver = iSilver / 2
--     end
--     if iNowLevel >= iServerGrade + 5 then
--         iSilver = iSilver * 3 / 2
--     end
--     iSilver = math.floor(iSilver)
--     return iSilver
-- end

function CSchoolPassiveSkill:LearnNeedCost(iLevel)
    iLevel = iLevel or self.m_iLevel + 1
    local iCost = self:LearnCostSilver(iLevel)
    assert(iCost > 0, string.format("passive LearnNeedCost err level: %d", iLevel))
    return iCost
end

function CSchoolPassiveSkill:LearnCostSilver(iLevel)
    iLevel = iLevel or self.m_iLevel + 1
    local res = require "base.res"
    local mCost = res["daobiao"]["passive_cost"][iLevel]
    if not mCost then return 0 end
        
    return mCost["silver_cost"] 
end

function CSchoolPassiveSkill:LimitLevel(oPlayer)
    local sTopLimit = self:GetSkillData()["limit_level"]
    local iLevel = tonumber(sTopLimit)
    if iLevel then
        return iLevel
    end
    local mEnv = {
        grade = oPlayer:GetGrade(),
    }
    local iLevel = formula_string(sTopLimit,mEnv)
    return math.floor(iLevel)
end

function CSchoolPassiveSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    mNet["type"] = 2
    mNet["needmoney"] = self:LearnCostSilver()
    return mNet
end

function CSchoolPassiveSkill:GetInitLevel()
    local mData = self:GetSkillData()
    return mData["init_level"]
end

function NewSkill(iSk)
    local o = CSchoolPassiveSkill:New(iSk)
    return o
end
