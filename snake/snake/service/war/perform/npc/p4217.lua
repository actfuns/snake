
--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--反噬

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oVictim, oAttack)
        OnDead(oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(oVictim, oAttack)
    if not oVictim:IsDead() then 
        return
    end
    local lFriend = oVictim:GetFriendList()
    if not next(lFriend) then return end

    local oBoss = nil
    for _, oWarrior in pairs(lFriend) do
        if oWarrior:GetData("is_boss") == 1 then
            oBoss = oWarrior
            break
        end
    end
    if oBoss then
        local oBuff = oBoss.m_oBuffMgr:HasBuff(171)
        if oBuff then
            oBuff:AddFloor(oBoss,-1)
        end
        
        local iHp = oVictim:GetMaxHp()
        global.oActionMgr:DoAddHp(oVictim, iHp)
    end
end



