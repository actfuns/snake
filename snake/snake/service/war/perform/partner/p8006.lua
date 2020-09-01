--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--凤血之力

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnNewBout(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(iPerform, oAttack)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    local lFriend = oAttack:GetFriendList(true)
    for _, oWarrior in pairs(lFriend or {}) do
        oWarrior:AddBoutArgs("phy_defense", mExtArg.phy_defense)
        oWarrior:AddBoutArgs("mag_defense", mExtArg.mag_defense)
    end
end
