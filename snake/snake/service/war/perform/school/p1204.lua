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

function CPerform:ValidCast(oAttack,oVictim)
    if oAttack:GetCampId() ~= oVictim:GetCampId() then
        return false
    end
    return super(CPerform).ValidCast(self,oAttack, oVictim)
end

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    if not oVictim or oVictim:IsDead() then
        return
    end
    oVictim.m_oBuffMgr:RemoveClassBuff(gamedefines.BUFF_TYPE.CLASS_BENEFIT, nil, 1)
    oVictim.m_oBuffMgr:RemoveClassBuffInclude(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, {["封印"]=1})
end

function CPerform:NeedVictimTime()
    return false
end
