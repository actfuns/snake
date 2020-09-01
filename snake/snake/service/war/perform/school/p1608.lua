local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack, lVictim)
    local oActionMgr = global.oActionMgr
    if #lVictim <= 0 then
        return
    end
    local oVictim = lVictim[1]
    local iAttackCnt = self:Range()
    oActionMgr:PerformPhyAttack(oAttack,oVictim,self,100,iAttackCnt)
    self:EndPerform(oAttack, lVictim)
end

