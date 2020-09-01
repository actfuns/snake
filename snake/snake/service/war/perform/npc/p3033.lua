local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--同归于尽
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iPerform)
    end
    oPerformMgr:AddFunction("OnAttacked",self.m_ID, func)

    local func2 = function(oAction)
        DoSpeek(oAction, "吓死本宝宝了，不跟你们玩了")
    end
    oPerformMgr:AddFunction("OnEscape", self.m_ID, func2)
end

function OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iPerform)
    if not oVictim or oVictim:IsDead() then return end

    local iSubHp = oVictim:GetHp()
    if iSubHp > 0 then
        DoSpeek(oVictim, "爆炸就是艺术")
        global.oActionMgr:DoSubHp(oVictim, iSubHp, oAttack, {hited_effect=1})
    end

    local iGrade = oVictim:GetGrade()
    local iDamage = iGrade * 20 + 100
    local mEnemy = oVictim:GetEnemyList()
    for _,oWarrior in pairs(mEnemy) do
        global.oActionMgr:DoReceiveDamage(oWarrior, iDamage, oVictim, oPerform, mArgs)
    end
end

function DoSpeek(oAction, sContent)
    local oWar = oAction:GetWar()
    if not oWar then return end
    local mNet = {
        war_id = oAction:GetWarId(),
        speeks = {
            {
                wid = oAction:GetWid(),
                content = sContent,
            },
        },
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end