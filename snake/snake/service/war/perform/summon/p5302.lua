--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end


CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRatio)
    local iRatio = self:CalSkillFormula(oAttack, oVictim, 100)
    
    if math.random(100) <= iRatio then
        oAttack:Add("damage_addratio", self:CalDamageRatio())
        super(CPerform).TruePerform(self, oAttack, oVictim, iDamageRatio)
        oAttack:Add("damage_addratio", -self:CalDamageRatio())
    else
        local oActionMgr = global.oActionMgr
        local bHit = oActionMgr:CalActionHit(oAttack, oVictim, self)
        if bHit then
            local iHp = oActionMgr:CalPhyDamage(oAttack, oVictim, self, iDamageRatio) 
            oActionMgr:DoAddHp(oVictim, iHp)
        end
    end
end

function CPerform:CalDamageRatio()
    local sExtArgs = self:ExtArg()
    return formula_string(sExtArgs, self:SkillFormulaEnv())
end
