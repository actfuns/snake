--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--三连击

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack, lVictim)
    if #lVictim <= 0 then return end

    local oVictim = lVictim[1]
    global.oActionMgr:PerformPhyAttack(oAttack, oVictim, self, 100, 3)
    self:EndPerform(oAttack, lVictim)
end
