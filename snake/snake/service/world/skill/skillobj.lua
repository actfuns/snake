--import module

local global = require "global"

local datactrl = import(lualib_path("public.datactrl"))

CSkill = {}
CSkill.__index =CSkill
CSkill.m_sType = "base"
inherit(CSkill,datactrl.CDataCtrl)

function CSkill:New(iSk)
    local o = super(CSkill).New(self)
    o.m_ID = iSk
    o:Init()
    return o
end

function CSkill:Init()
    self.m_iLevel = 0
    self.m_mApply = {}
    -- self.m_mSkillData = self:GetSkillData()
end

function CSkill:Save()
    local mData = {}
    mData["level"] = self.m_iLevel
    mData["pos"] = self.m_iPos
    return mData
end

function CSkill:Load(mData)
    mData = mData or {}
    self.m_iLevel = mData["level"] or self.m_iLevel
    self.m_iPos = mData["pos"]
end

function CSkill:GetSkillData()
    local res = require "base.res"
    local mData = res["daobiao"]["skill"]
    return mData[self.m_ID]
end

function CSkill:ID()
    return self.m_ID
end

function CSkill:Name()
    return self:GetSkillData()["name"]
end

function CSkill:Level()
    return self.m_iLevel
end

function CSkill:SetLevel(iLevel)
    self:Dirty()
    self.m_iLevel = iLevel
end

function CSkill:Type()
    return self.m_sType
end

function CSkill:LimitLevel(oPlayer)
    return 10
end

function CSkill:SkillEffect(oPlayer)
    --
end

function CSkill:SkillUnEffect(oPlayer)
    --
end

function CSkill:AddApply(sApply,iValue)
    local iApply = self.m_mApply[sApply] or 0
    self.m_mApply[sApply] = iApply + iValue
end

function CSkill:GetApply(sApply,rDefault)
    rDefault = rDefault or 0
    return self.m_mApply[sApply] or rDefault
end

function CSkill:PackNetInfo()
    return {}
end

function CSkill:GetScore()
    local mData = self:GetSkillData()
    local iValue = formula_string(mData["score"], {lv = self:Level()})
    return iValue
end

function CSkill:SetPos(iPos)
    self.m_iPos = iPos
end

function CSkill:GetPos()
    return self.m_iPos
end
