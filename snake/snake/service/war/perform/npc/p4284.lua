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

function CPerform:Perform(oAttack,lVictim)
    local lTempVictim = {}
    local lEnemy = oAttack:GetEnemyList()
    for _,oWarrior in ipairs(lEnemy) do
        if oWarrior:IsBoss() then
            table.insert(lTempVictim,oWarrior)
        end
    end
    if #lTempVictim<=0 then
        return 
    end
     super(CPerform).Perform(self, oAttack,lVictim)
end

