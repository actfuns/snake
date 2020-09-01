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

function CPerform:CalWarrior(oAction, oPerformMgr)
    oAction:AddFunction("OnBeforeAct", self.m_ID, function (oWarrior)
        AddDamageRadio(oWarrior)
    end)
end

function AddDamageRadio(oWarrior)
    local bFlag = true
    local mEnemy = oWarrior:GetFriendList(true)
    for _,oEnemy in pairs(mEnemy) do
        if oEnemy:IsBoss() and oEnemy:IsAlive() then
           bFlag = false
           break
        end
    end
    if bFlag then
        oWarrior:AddBoutArgs("damage_addratio",-30)
    end
end
