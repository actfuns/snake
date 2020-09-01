--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

-- 怒雷破
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:ConstantDamage(oAttack, oVictim, iRatio, mEnv)
    local iSelfAttact = oAttack:QueryAttr("phy_attack")
    local iTarAttact = oVictim:QueryAttr("phy_attack")
    local iTarDefense = oVictim:QueryAttr("phy_defense")
    mEnv = mEnv or {}
    mEnv["self_attack"] = iSelfAttact
    mEnv["tar_attact"] = iTarAttact
    mEnv["tar_defense"] = iTarDefense
    local iDamage = super(CPerform).ConstantDamage(self, oAttack, oVictim, iRatio, mEnv)
    return math.max(iDamage, 1)
end
