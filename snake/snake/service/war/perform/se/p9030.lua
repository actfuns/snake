--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--破血狂攻

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack, lVictim)
    if #lVictim <= 0 then return end

    local oVictim = lVictim[1]
    local oActionMgr = global.oActionMgr
    oActionMgr:PerformPhyAttack(oAttack, oVictim, self, 100, 2)
    self:EndPerform(oAttack, lVictim)
end
