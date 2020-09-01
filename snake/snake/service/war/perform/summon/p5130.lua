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
    local iType = self:Type()
    local func = function(oAttack, oVictim, oPerform, iSealRatio)
        return OnSealedRatio(oAttack, oVictim, oPerform, iSealRatio, iType)
    end
    oPerformMgr:AddFunction("OnSealedRatio", self.m_ID, func)
    -- oPerformMgr:SetAttrAddValue("phy_damage_addratio", self.m_ID, -20)
end

function OnSealedRatio(oAttack, oVictim, oUsePerform, iSealRatio, iPerform)
    if not oVictim then return 0 end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return 0 end

    return - math.ceil(iSealRatio * oPerform:CalSkillFormula() / 100) 
end

