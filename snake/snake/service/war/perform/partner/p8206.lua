--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--鬼魂

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
    for _, oWarrior in ipairs(lFriend or {}) do
        local iSchool = oWarrior:GetData("school", 0)
        if iSchool == 1 or iSchool == 6 then
            oWarrior:AddBoutArgs("phy_damage_ratio", mExtArg.phy_damage_ratio)
        end
    end
end
