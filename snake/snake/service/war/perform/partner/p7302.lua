--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--狂剑诀

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:SelfValidCast(oAttack,oVictim)
    if oAttack:GetHp() > oAttack:GetMaxHp() * 5 /10 then
        return true
    end
    if oAttack:IsPlayer() then
        oAttack:Notify("当前气血大于气血50%方能使用")
    end
    return false
end

function CPerform:Perform(oAttack,lVictim)
    local oActionMgr = global.oActionMgr
    if #lVictim <= 0 then
        return
    end
    local oVictim = lVictim[1]
    oActionMgr:PerformPhyAttack(oAttack,oVictim,self,100,3)
    self:EndPerform(oAttack, lVictim)
end

