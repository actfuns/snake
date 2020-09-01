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

-- 逃逸
function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func1 = function (oAtt, oVic, oPerform)
        OnSealed(iPerform, oAtt, oVic, oUsePerform)        
    end
    oPerformMgr:AddFunction("OnSealed",self.m_ID, func1)

    local func2 = function (oAc)
        OnNewBout(iPerform, oAc)
    end
    oPerformMgr:AddFunction("OnNewBout",self.m_ID, func2)

    oAction:Set("escape_bout", 4)
end

function OnSealed(iPerform, oAttack, oVictim, oUsePerform)
    if not oVictim then return end

    local oWar = oVictim:GetWar()
    local iCurBout = oWar:CurBout()
    oVictim:Set("escape_bout", iCurBout + 1) 
end

function OnNewBout(iPerform, oAction)
    local oWar = oAction:GetWar()
    local iCurBout = oWar:CurBout()
    if iCurBout >= oAction:Query("escape_bout", 0) then
        oAction:SetExtData("escape_ratio", 1000)
        global.oActionMgr:WarEscape(oAction)
    end
end