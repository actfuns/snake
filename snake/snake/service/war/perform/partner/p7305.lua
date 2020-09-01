--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--灵剑引心

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(iPerform, oAttack, oVictim, oPerform)
        return OnCalDamageRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnCalDamageRatio", self.m_ID, func)
end

function OnCalDamageRatio(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or oAttack:IsDead() then return 0 end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oUsePerform or oUsePerform:Type() ~= 7301 then
        return 0
    end

    local mEnv = {
        level = oPerform:Level(),
        mp = oAttack:GetMp(),
    }
    local sExtArgs = self:ExtArg()
    local mArgs = formula_string(sExtArgs, mEnv)
    oAttack:AddBoutArgs("phy_damage_add", mArgs.phy_damageadd)
    return 0
end
