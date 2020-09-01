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

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oPerform)
        return CalPhyDefense(iPerform, oAttack, oVictim, oPerform)
    end
    oAction:AddFunction("CalPhyDefense", self.m_ID, func)
end

function CalPhyDefense(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return 0 end

    local iMaxHp = oVictim:GetMaxHp()
    local iHp = oVictim:GetHp()

    local mEnv = {hp=iHp, maxhp=iMaxHp}
    local iRatio = oPerform:CalSkillFormula(mEnv) / 100
    return math.max(0, math.floor(oVictim:QueryAttr("phy_defense") * iRatio))
end
