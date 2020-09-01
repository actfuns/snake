--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--法泉

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

    local sArgs = self:ExtArg()
    local mEnv = {level = self:Level()}
    local mArgs = formula_string(sArgs, mEnv)

    local iOldMax = oWarrior:GetMaxMp()
    oWarrior:SetData("max_mp", iOldMax+mArgs.max_mp)
    oWarrior:StatusChange("max_mp")
    global.oActionMgr:DoAddMp(oWarrior, mArgs.mp)
end
