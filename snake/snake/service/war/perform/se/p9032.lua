--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--弱点击破

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:DamageRatioEnv(oAttack,oVictim)
    local mEnv = super(CPerform).DamageRatioEnv(self, oAttack, oVictim)
    mEnv.grade = oAttack:GetGrade()
    return mEnv
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local sArgs = self:ExtArg()
    local mEnv = {level = self:Level()}
    local mArgs = formula_string(sArgs, mEnv)
    oAttack.m_oPerformMgr:SetAttrBaseRatio("phy_attack", self.m_ID, mArgs.phy_attack_ratio)
    super(CPerform).TruePerform(self, oAttack, oVictim, iRatio)
    oAttack.m_oPerformMgr:SetAttrBaseRatio("phy_attack", self.m_ID, 0)
end
