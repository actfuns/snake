--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--长生

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    if not oAction:IsPartnerLike() then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local iOwner = oAction:GetOwner()
    if not iOwner then return end

    local oWarrior = oWar:GetPlayerWarrior(iOwner)
    if not oWarrior then return end

    local mEnv = {
        level = self:Level(),
    }
    local sExtArgs = self:ExtArg()
    local mArgs = formula_string(sExtArgs, mEnv)

    local iOldMax = oWarrior:GetMaxHp()
    oWarrior:SetData("max_hp", iOldMax+mArgs.max_hp)
    oWarrior:StatusChange("max_hp")
    oWarrior:AddHp(mArgs.hp)
end
