local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--指挥

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oWarrior)
        OnNewBout(oWarrior)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(oAttack)
    local lEnemy = oAttack:GetEnemyList()
    if #lEnemy <= 0 then return end

    local oTarget = lEnemy[math.random(1, #lEnemy)]
    local sMsg = string.format("集火%s",oTarget:GetName())
    DoSpeek(oAttack,sMsg)
end

function DoSpeek(oWarrior, sContent)
    if oWarrior:IsDead() then
        return
    end
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local mCmd = {
        war_id = oWarrior:GetWarId(),
        wid = oWarrior:GetWid(),
        content = sContent,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end
