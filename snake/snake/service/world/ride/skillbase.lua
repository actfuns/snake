--import module
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local ridedefines = import(service_path("ride.ridedefines"))


function NewSkill(iSk)
    local mData = global.oRideMgr:GetSkillConfig(iSk)
    assert(mData, string.format("not find ride skill %s", iSk))
    local o = CRideSkill:New(iSk)
    return o 
end


CRideSkill = {}
CRideSkill.__index =CRideSkill
inherit(CRideSkill, datactrl.CDataCtrl)

function CRideSkill:New(iSk)
    local o = super(CRideSkill).New(self)
    o.m_ID = iSk
    o:Init()
    return o
end

function CRideSkill:Init()
    self.m_iLevel = 1
end

function CRideSkill:GetConfigData()
    return global.oRideMgr:GetSkillConfig(self:SkID())
end

function CRideSkill:Save()
    local mData = {}
    mData["level"] = self.m_iLevel
    return mData
end

function CRideSkill:Load(mData)
    self.m_iLevel = mData["level"]
end

function CRideSkill:SkID()
    return self.m_ID
end

function CRideSkill:Level()
    return self.m_iLevel
end

function CRideSkill:SkillType()
    return self:GetConfigData()["ride_type"]
end

function CRideSkill:IsBaseSkill()
    return self:SkillType() == ridedefines.SKILL_TYPE.BASE_SKILL
end

function CRideSkill:IsAdvanceSkill()
    return self:SkillType() == ridedefines.SKILL_TYPE.ADVANCE_SKILL
end

function CRideSkill:IsFinalSkill()
    return self:SkillType() == ridedefines.SKILL_TYPE.FINAL_SKILL
end

function CRideSkill:IsConSkill(iSkill)
    if table_in_list(self:GetConfigData()["con_skill"], iSkill) then
        return true
    end
    return true
end

function CRideSkill:GetBaseSkillId()
    return self:GetConfigData()["con_skill"][1]
end

function CRideSkill:GetAdvanceNum()
    return 2
end

function CRideSkill:AddLevel(iVal)
    self.m_iLevel = self.m_iLevel + iVal
    self:Dirty()
end

function CRideSkill:IsMaxLevel()
    if self:GetConfigData()["max_level"] <= self:Level() then
        return true
    end
    return false
end

function CRideSkill:AddApply(sApply, iValue)
    local iApply = self.m_mApply[sApply] or 0
    self.m_mApply[sApply] = iApply + iValue
end

function CRideSkill:GetApply(sApply, rDefault)
    rDefault = rDefault or 0
    return self.m_mApply[sApply] or rDefault
end

function CRideSkill:SkillEffect(oRideCtrl)
    if self:Level() <= 0 then return end

    local sEffect = self:GetConfigData()["skill_effect"]
    if #sEffect <= 0 then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(oRideCtrl:GetPid())
    if not oPlayer then return end

    local mEffect = formula_string(sEffect, {grade=oPlayer:GetGrade(),level=self:Level()})
    for sApply, iValue in pairs(mEffect) do
        oRideCtrl.m_oAttrMgr:AddApply(sApply, self.m_ID, iValue)
        oRideCtrl:PlayerProChange(sApply)
    end
end

function CRideSkill:SkillUnEffect(oRideCtrl)
    oRideCtrl.m_oAttrMgr:RemoveSource(self.m_ID)
end

function CRideSkill:GetPerformList()
    local mPfData = self:GetConfigData()["pflist"]
    local mPerform = {}
    local iLevel = self:Level()
    for _,pfid in pairs(mPfData) do
        mPerform[pfid] = iLevel
    end
    return mPerform
end

function CRideSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    mNet["type"] = self:SkillType()
    return mNet
end

function CRideSkill:GetScore()
    local sFormula = self:GetConfigData()["score"]
    local iScore = formula_string(sFormula, {lv = self:Level()})
    return iScore
end

