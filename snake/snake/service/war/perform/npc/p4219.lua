local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--炸弹人

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack)
        OnDead(iPerform, oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(iPerform, oVictim, oAttack)
    if not oAttack or oAttack:IsDead() then return end
    if not oVictim then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    for _, oWarrior in pairs(oAttack:GetFriendList(true)) do
        if oWarrior and oWarrior:IsAlive() then
            local sExtArg = oPerform:ExtArg()
            local mEnv = {max_hp = oWarrior:GetMaxHp()}
            local mExtArg = formula_string(sExtArg, mEnv)
            if mExtArg.sub_hp and mExtArg.sub_hp > 0 then
                global.oActionMgr:DoSubHp(oWarrior, mExtArg.sub_hp, oVictim)
            end
        end
    end
end

