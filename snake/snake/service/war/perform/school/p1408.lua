local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

--仙气萦绕

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


function CPerform:Effect_Condition_For_Victim(oVictim, oAttack, mArgs)
    mArgs = mArgs or {}
    if oAttack then
        mArgs.grade = oAttack:GetGrade()
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
            if x.m_oBuffMgr:HasBuff(129) and not y.m_oBuffMgr:HasBuff(129) then
                return false
            end
            if not x.m_oBuffMgr:HasBuff(129) and y.m_oBuffMgr:HasBuff(129) then
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
