--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function CalPhyDefense(iPerform, oAttack, oVictim, oUsePerform)
    if not oVictim then return 0 end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return 0 end

    local oWar = oVictim:GetWar()
    if oWar:CurBout() > 3 then return 0 end

    local iRatio = oPerform:CalSkillFormula()
    local iDefense = oVictim:QueryAttr("phy_defense") * iRatio / 100
    return math.floor(iDefense)
end


-- 铁壁(天赋) 不需要做成buff
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oUsePerform)
        return CalPhyDefense(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oAction:AddFunction("CalPhyDefense", self.m_ID, func)
end

