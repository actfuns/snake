--import module

local global = require "global"
local skilobj = import(service_path("skill/skillobj"))

CSchoolActiveSkill = {}
CSchoolActiveSkill.__index = CSchoolActiveSkill
CSchoolActiveSkill.m_sType = "active"
inherit(CSchoolActiveSkill,skilobj.CSkill)

function CSchoolActiveSkill:New(iSk)
    local o = super(CSchoolActiveSkill).New(self,iSk)
    return o
end

function CSchoolActiveSkill:OpenLevel()
    return self:GetSkillData()["open_level"] or 5
end

function CSchoolActiveSkill:GetPerformList()
    local mPfData = self:GetSkillData()["pflist"] or {}
    local mPerform = {}
    local iLevel = self:Level()
    for _,mData in pairs(mPfData) do
        local iNeedLevel = mData["level"]
        local iPerform = mData["pfid"]
        if iLevel >= iNeedLevel then
            mPerform[iPerform] = iLevel
        end
    end
    return mPerform
end

function CSchoolActiveSkill:LearnCostSilver(iLevel)
    iLevel = iLevel or self.m_iLevel + 1
    local sFormula
    local mSilver = self:GetSkillData()["silver_learn"] or {}
    for _,mData in pairs(mSilver) do
        if iLevel >= mData["lv"] then
            sFormula = mData["formula"]
        end
    end
    if not sFormula then
        return 0
    end
    local iSilver = tonumber(sFormula)
    if iSilver then
        return iSilver
    else
        local iSilver = math.floor(formula_string(sFormula, {level=iLevel}))
        return math.floor(iSilver)
    end
    return 0
end

function CSchoolActiveSkill:LearnCostSkillPoint(iLevel)
    iLevel = iLevel or self.m_iLevel + 1
    local sFormula
    local mPoint = self:GetSkillData()["skillpoint_learn"] or {}
    for _,mData in pairs(mPoint) do
        if iLevel >= mData["lv"] then
            sFormula = mData["formula"]
        end
    end
    if not sFormula then
        return 0
    end
    local iPoint = tonumber(sFormula)
    if iPoint then
        return iPoint
    else
        local iPoint = formula_string(sFormula, {level=iLevel})
        return math.floor(iPoint)
    end
    return 0
end

function CSchoolActiveSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    mNet["type"] = 2
    mNet["needmoney"] = self:LearnCostSilver()
    mNet["needpoint"] = self:LearnCostSkillPoint()
    return mNet
end

function CSchoolActiveSkill:LimitLevel(oPlayer)
    local sTopLimit = self:GetSkillData()["top_limit"]
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

function CSchoolActiveSkill:ResetResume()
    local mResume = self:GetSkillData()["reset_resume"]
    local mResetResume = {}
    for sid, mData in pairs(mResume) do
        local sFormula = mData["amount"]
        local iAmount = tonumber(sFormula)
        if not iAmount then
            iAmount = formula_string(sFormula, {level=self:Level()})
        end
        mResetResume[sid] = {amount = iAmount, gold = mData["gold"]}
    end
    return mResetResume
end

function CSchoolActiveSkill:GetGradeLimit()
    local mData = self:GetSkillData()
    local iLevel = self:Level() + 1
    return table_get_depth(mData, {"learn_limit", iLevel, "grade"})
end

function CSchoolActiveSkill:GetInitLevel()
    local mData = self:GetSkillData()
    return mData["init_level"]
end

function NewSkill(iSk)
    local o = CSchoolActiveSkill:New(iSk)
    return o
end
