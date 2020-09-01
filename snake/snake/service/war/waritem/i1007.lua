local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local waritem = import(service_path("waritem/waritembase"))


function NewWarItem(...)
    local o = CWarItem:New(...)
    return o
end

CWarItem = {}
CWarItem.__index = CWarItem
inherit(CWarItem, waritem.CWarItem)

function CWarItem:New(id)
    local o = super(CWarItem).New(self, id)
    return o
end

function CWarItem:CanUseItem(oAction, mArgs, iPid, iItemId)
    return true
end

function CWarItem:CheckAction(oAction, oVictim, mArgs, iPid)
    local lEnemy = oAction:GetEnemyList()
    for _,oWarrior in ipairs(lEnemy) do
        if oWarrior:IsNpc() and oWarrior:IsBoss() and not oWarrior:IsDead() and oWarrior:GetPerform(4286) then
            return true
        end
    end
    return false
end

function CWarItem:Action(oAction, oVictim, mArgs, iPid)
    local res = require "base.res"
    local lEnemy = oAction:GetEnemyList()
    for _,oWarrior in ipairs(lEnemy) do
        if oWarrior:IsNpc() and oWarrior:IsBoss() and not oWarrior:IsDead() and oWarrior:GetPerform(4286) then
            local iDamage = res["daobiao"]["huodong"]["nianshou"]["config"][1]["war_damage"]
            global.oActionMgr:DoSubHp(oWarrior,iDamage,oAction)
            break
        end
    end
end

function CWarItem:DoActionEnd(oAction, oVictim, mArgs, iPid, iItemId, sTips)
    return true
end