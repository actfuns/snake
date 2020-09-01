--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--再生

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnNewBout(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(iPerform,oAttack)
    if not oAttack or oAttack:IsDead() then 
        return 
    end
    local oWar  = oAttack:GetWar()
    if not oWar then 
        return 
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then 
        return 
    end
    local iHP = math.floor(oAttack:GetGrade()*5)
    if iHP>0 then
        global.oActionMgr:DoAddHp(oAttack,iHP)
    end
end