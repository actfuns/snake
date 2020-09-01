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
    local iRatio = self:CalSkillFormula(oAction, nil, 100)
    local func = function (oAttack, oVictim, oPerform)
        return OnCalDamagedResultRatio(oAttack, oVictim, oPerform, iRatio)
    end
    oAction:AddFunction("OnCalDamagedResultRatio", self.m_ID, func)
end

function OnCalDamagedResultRatio(oAttack, oVictim, oPerform, iRatio)
    local iSchool = oAttack:IsPlayer() and oAttack:GetData("school")
    if iSchool == gamedefines.PLAYER_SCHOOL.JINSHAN 
        or iSchool == gamedefines.PLAYER_SCHOOL.YAOCHI 
        or iSchool == gamedefines.PLAYER_SCHOOL.QINGSHAN then
        
        -- oPerform == nil 为普攻
        local lPerform = {1403, 1506}    
        if oPerform == nil or (oPerform and table_in_list(lPerform, oPerform:Type())) then
            return iRatio or 100
        end
    end
    return 0
 end
