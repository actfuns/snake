local global = require "global"
local skynet = require "skynet"

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

function CPerform:TargetList(oAttack)
    local lTarget = super(CPerform).TargetList(self, oAttack)
    local lResult = {}
    for _, oTarget in pairs(lTarget) do
        if not oTarget:HasKey("disable_cure") then
            table.insert(lResult, oTarget)
        end
    end
    return lResult
end

function CPerform:TruePerform(oAttack,oVictim,iDamageRatio)
    if not oVictim or oVictim:IsDead() then
        return
    end
    super(CPerform).TruePerform(self,oAttack,oVictim,iDamageRatio)
end

function CPerform:Effect_Condition_For_Victim(oVictim,oAttack, mArgs)
    local iHp = self:CalculateHp(oAttack, oVictim, 100)
    mArgs = mArgs or {}
    mArgs.hp_add = iHp
    
    local mFunc = oAttack:GetFunction("AddExtCurePower")
    if mFunc[7704] then
        mArgs.hp_add = mArgs.hp_add + mFunc[7704](7704, oAttack, oVictim, self, mArgs.hp_add)
    end
    super(CPerform).Effect_Condition_For_Victim(self, oVictim, oAttack, mArgs)
end

function CPerform:SortVictim(lTarget)
    table.sort(lTarget, function(x, y)
        local bSubX = x:GetHp() < x:GetMaxHp()
        local bSubY = y:GetHp() < y:GetMaxHp()
        if bSubX ~= bSubY then
            return bSubX
        end
        if x:GetHp() == y:GetHp() or (bSubX == false and bSubY == false) then
            if x.m_oBuffMgr:HasBuff(114) and not y.m_oBuffMgr:HasBuff(114) then
                return false
            end
            if not x.m_oBuffMgr:HasBuff(114) and y.m_oBuffMgr:HasBuff(114) then
                return true
            end
            return x:GetWid() < y:GetWid()
        else
            return x:GetHp() < y:GetHp()
        end
    end)
    return lTarget
end

function CPerform:NeedVictimTime()
    return false
end
