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
    local o = super(CPerform).New(self,pfid)
    return o
end

-- TODO 无用的
function CPerform:CalWarrior(oAttack,oPerformMgr)
    local iDefense = oAttack:GetData("grade") * 0.6 + self:Level() * 10
    oPerformMgr:SetAttrAddValue("mag_defense",self.m_ID,iDefense)
    oPerformMgr:SetAttrAddValue("phy_defense",self.m_ID,iDefense)
end