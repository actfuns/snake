local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--超级神佑
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oAttack)
        OnDead(oAction, oAttack, iPerform)
    end
    oPerformMgr:AddFunction("OnDead", iPerform, func)
end

function OnDead(oAction, oAttack, iPerform)
    if not oAction or oAction:IsAlive() then
        return
    end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArgs = oPerform:ExtArg()
    local mExtArgs = formula_string(sExtArgs, {})
    if math.random(100) <= mExtArgs.ratio then
        local iMaxHp = oAction:GetMaxHp()
        global.oActionMgr:DoAddHp(oAction, iMaxHp)
    end
end