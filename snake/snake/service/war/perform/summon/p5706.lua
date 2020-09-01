--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

-- 石化
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func = function(oVictim, oAttack)
        OnDeadAfterSubHp(iType, oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnDeadAfterSubHp", self.m_ID, func)
end

function OnDeadAfterSubHp(iPerform, oVictim, oAttack)
    if not oVictim or not oVictim:IsDead() or oVictim:IsGhost() then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local oSummon, iPercent = nil, 1
    for _,oSumm in pairs(oVictim:GetFriendList()) do
        if oSumm:IsSummon() and oVictim ~= oSumm then
            local iHpPercent = oSumm:GetHp() / oSumm:GetMaxHp()
            if iHpPercent < iPercent then
                iPercent = iHpPercent
                oSummon = oSumm  
            end
        end    
    end
    if oSummon then
        local iHp = oSummon:GetMaxHp() - oSummon:GetHp()
        global.oActionMgr:DoAddHp(oSummon, iHp)
        oVictim:GS2CTriggerPassiveSkill(iPerform, {{key="magic_id", value=iPerform},{key="select_id", value=oSummon:GetWid()},})
    end
end
