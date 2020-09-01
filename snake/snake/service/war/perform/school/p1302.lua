--import module

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

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:TruePerform(oAttack,oVictim,iDamageRatio)
    super(CPerform).TruePerform(self,oAttack,oVictim,iDamageRatio)

    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    if mExtArg.sub_mp > 0 then
        global.oActionMgr:DoAddMp(oVictim, -mExtArg.sub_mp)
    end
end
