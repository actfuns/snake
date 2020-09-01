--import module
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local psum = import(lualib_path("public.psum"))


function NewSkill(iSk)
    local mData = global.oFaBaoMgr:GetSkillConfig(iSk)
    assert(mData, string.format("not find fabao skill %s", iSk))
    local o = CFaBaoSkill:New(iSk)
    return o 
end

local SKILL_OPEN = 1
local SKILL_CLOSE = 0

CFaBaoSkill = {}
CFaBaoSkill.__index =CFaBaoSkill
inherit(CFaBaoSkill, datactrl.CDataCtrl)

function CFaBaoSkill:New(iSk)
    local o = super(CFaBaoSkill).New(self)
    o.m_ID = iSk
    o:Init()
    return o
end

function CFaBaoSkill:Init()
    self.m_iLevel = 0
    self.m_iExp = 0
    self.m_iOpen = SKILL_CLOSE
end

function CFaBaoSkill:GetConfigData()
    return global.oFaBaoMgr:GetSkillConfig(self:SkID())
end

function CFaBaoSkill:Save()
    local mData = {}
    mData.level = self.m_iLevel
    mData.exp = self.m_iExp
    mData.open = self.m_iOpen
    return mData
end

function CFaBaoSkill:Load(mData)
    self.m_iLevel = mData.level or 0
    self.m_iExp = mData.exp or 0
    self.m_iOpen = mData.open or SKILL_CLOSE
end

function CFaBaoSkill:SkID()
    return self.m_ID
end

function CFaBaoSkill:IsMaxLevel()
    if self:MaxLevel() <= self:Level() then
        return true
    end
    return false
end

function CFaBaoSkill:MaxLevel()
    return self:GetConfigData()["max_level"]
end

function CFaBaoSkill:IsOpen()
    return self.m_iOpen == SKILL_OPEN
end

function CFaBaoSkill:Open()
    self:Dirty()
    self.m_iOpen = SKILL_OPEN
end

function CFaBaoSkill:SetLevel(iLevel)
    self:Dirty()
    self.m_iLevel = iLevel
end

function CFaBaoSkill:Level()
    local iHun = self:GetConfigData()["hun"]
    if iHun==0 then
        return self.m_iLevel 
    else
        return self:MaxLevel()
    end
end

function CFaBaoSkill:Exp()
    return self.m_iExp
end

function CFaBaoSkill:SetExp(iExp)
    self:Dirty()
    self.m_iExp = iExp
end

function CFaBaoSkill:Name()
    return self:GetConfigData()["name"]
end

function CFaBaoSkill:SkillEffect(oPlayer)
    if not self:IsOpen() then
        return 
    end
    local sEffect = self:GetConfigData()["skill_effect"]
    if #sEffect <= 0 then return end
    local mEffect = formula_string(sEffect, {grade=oPlayer:GetGrade(),level=self:Level()})
    for sApply, iValue in pairs(mEffect) do
        if psum.IsAttr2C(sApply) then
            oPlayer.m_oFaBaoCtrl.m_oAttrMgr:AddApply(sApply, self.m_ID, iValue)
            oPlayer:PropChange(sApply)
        end
    end
end

function CFaBaoSkill:SkillUnEffect(oPlayer)
    if not self:IsOpen() then
        return 
    end
    oPlayer.m_oFaBaoCtrl.m_oAttrMgr:RemoveSource(self.m_ID)
end

function CFaBaoSkill:GetPerformList()
    local mPfData = self:GetConfigData()["pflist"]
    local mPerform = {}
    local iLevel = self:Level(true)
    for _,pfid in pairs(mPfData) do
        mPerform[pfid] = iLevel
    end
    return mPerform
end

function CFaBaoSkill:PackInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    mNet["exp"] = self:Exp()
    return mNet
end

function CFaBaoSkill:GetScore()
    local sFormula = self:GetConfigData()["score"]
    local iScore = formula_string(sFormula, {lv = self:Level()})
    return iScore
end

function CFaBaoSkill:GetPerformList()
    local mPfData = self:GetConfigData()["pflist"] or {}
    local mPerform = {}
    local iLevel = self:Level()
    if #mPfData>0 and iLevel>0 then
        mPerform[mPfData[1]] = iLevel
    end
    return mPerform
end

function CFaBaoSkill:IsActive()
    return self:GetConfigData()["type"] == 1
end

function CFaBaoSkill:GetOtherJXLevel(oPlayer)
    local iLevel = 0
    if not self:IsOpen() then
        return iLevel
    end
    local mEffect = self:GetConfigData()["skill_effect"] or {}
    if #mEffect <= 0 then 
        return iLevel
    end
    local mEffect = formula_string(mEffect, {grade=oPlayer:GetGrade(),level=self:Level()})
    if mEffect.level  then
        iLevel = iLevel + mEffect.level
    end
    return iLevel
end