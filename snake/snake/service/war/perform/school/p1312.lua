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

function CPerform:HitRatio(oAttack,oVictim)
    local iRatio = (self:Level() - oVictim:GetData("grade")) * 2 + 55
    return iRatio
end

function CPerform:TruePerform(oAttack,oVictim,iDamageRatio)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoSealAction(oAttack,oVictim,self,20,70)
end

function CPerform:Effect_Condition_For_Victim(oVcitim,oAttack)
    if not oVcitim or oVcitim:IsDead() then
        return
    end
    local mInfo = self:GetPerformData()
    local mBuff = mInfo["victimBuff"] or {}
    local mArgs = {
        level = self:Level()
    }
    local iBout = 3 + (self:Level() - oVcitim:GetData("grade")) / 10 + self:Level() / 80
    iBout = math.floor(iBout)
    if oVcitim and oVcitim.m_bAction then
        iBout = iBout + 1
    end
    local iBuffID = 107
    local oBuffMgr = oVcitim.m_oBuffMgr
    oBuffMgr:AddBuff(iBuffID,iBout,mArgs)
end
