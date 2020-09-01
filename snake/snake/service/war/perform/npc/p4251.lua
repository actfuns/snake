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

-- 超级反击
function CPerform:CalWarrior(oAction, oPerformMgr)
    local iRatio = self:CalSkillFormula(oAction, nil, 100)
    local iPerform = self:Type()
    local func = function (oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iRatio, iPerform)
    end
    oPerformMgr:AddFunction("OnAttacked",self.m_ID, func)
end

function OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iRatio, iPerform)
    if not oVictim or oVictim:IsDead() then return end
    local iCnt = oVictim:QueryBoutArgs("p4251", 0)
    if iCnt > 10 then return end

    oVictim:SetBoutArgs("p4251", iCnt + 1)
    local oWar = oVictim:GetWar()
    local lEnemy = oVictim:GetEnemyList()
    if #lEnemy <= 0 then return end

    local lSelect = {}
    for _, oEnemy in pairs(lEnemy) do
        if oVictim:IsVisible(oEnemy) then
            table.insert(lSelect, oEnemy:GetWid())
        end
    end

    oVictim:SendAll("GS2CWarSkill", {
        war_id = oVictim:GetWarId(),
        action_wlist = {oVictim:GetWid(),},
        select_wlist = lSelect,
        skill_id = iPerform,
        magic_id = 1,
    })
    
    for _, oEnemy in pairs(lEnemy) do
        if table_in_list(lSelect, oEnemy:GetWid()) then
            local iSubHp = math.floor(iRatio * oEnemy:GetMaxHp() / 100)
            global.oActionMgr:DoSubHp(oEnemy, iSubHp, oVictim)
        end
    end
end
