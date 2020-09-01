--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--化缘

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function OnBoutEnd(iPerform, oAttack)
    if not oAttack or oAttack:IsDead() then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = {level = oPerform:Level()}
    local mExtArg = formula_string(sExtArg, mEnv)

    local iAddHp = oAttack:GetMaxHp() * mExtArg.ratio // 100
    if iAddHp > 0 then
        global.oActionMgr:DoAddHp(oAttack, iAddHp)
    end
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnBoutEnd(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end
