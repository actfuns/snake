--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end


--订婚技能
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SelfValidCast(oAttack, oVictim)
    local oWar = oAttack:GetWar()
    local iCouplePid = oAttack:GetCouplePid()
    local oCouple = oWar:GetPlayerWarrior(iCouplePid)
    if not oCouple or oVictim ~= oCouple then 
        oAttack:Notify("只能对和你有婚约关系另一半使用")
        return false
    end
    local iDegree = self:GetLimitDegree()
    if oAttack:GetCoupleDegree() < iDegree then
        oAttack:Notify(string.format("你和伴侣的好友度<%s", iDegree))
        return false
    end
    return true
end

function CPerform:BoutEnv(oAttack, oVictim)
    local mEnv = super(CPerform).New(self, oAttack, oVictim)
    mEnv.degree = oAttack:GetCoupleDegree()
    return mEnv
end

function CPerform:GetLimitDegree()
    return 2000
end

function CPerform:TargetList(oAttack)
    local oWar = oAttack:GetWar()
    if not oAttack:IsPlayer() then
        return {}
    end

    local iCouplePid = oAttack:GetCouplePid()
    local oCouple = oWar:GetPlayerWarrior(iCouplePid)
    local iDegree = self:GetLimitDegree()
    
    local lTarget = {}
    if oCouple and oAttack:GetCoupleDegree() >= iDegree then
        table.insert(lTarget, oCouple)
    end

    local mRet = {}
    local iStatus = self:TargetStatus()
    for _,oTarget in pairs(lTarget) do
        if iStatus == gamedefines.WAR_WARRIOR_STATUS.ALIVE then
            if oTarget:IsAlive() and oTarget:IsVisible(oAttack) then
                table.insert(mRet,oTarget)
            end
        elseif iStatus == gamedefines.WAR_WARRIOR_STATUS.DEAD then
            if oTarget:IsDead() then
                table.insert(mRet,oTarget)
            end
        else
            table.insert(mRet,oTarget)
        end
    end
    return mRet
end
