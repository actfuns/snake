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

-- 患难
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local iWid = oAction:GetWid()
    if not oAction:IsSummon() then return end
    
    local iOwner = oAction:GetOwnerWid()
    local oPlayer = oAction:GetWarrior(iOwner)

    local func1 = function (oVictim, oAttack, iDamage)
        return OnShareDamage(iWid, iType, iOwner, oVictim, oAttack, iDamage) or 0
    end
    local func2 = function (oVictim, oAttack, iDamage)
        return OnShareDamage(iWid, iType, iWid, oVictim, oAttack, iDamage) or 0
    end

    local oWar = oAction:GetWar()
    local iCurBout = oWar:CurBout()
    oPerformMgr:AddFunction("OnShareDamage", self.m_ID, func1)
    oAction:Set("p5702_bout", math.max(iCurBout, 1))
    oPlayer.m_oPerformMgr:AddFunction("OnShareDamage", self.m_ID, func2)
    oPlayer:Set("p5702_bout", math.max(iCurBout, 1))
end

function OnShareDamage(iAcWid, iPerform, iShareWid, oVictim, oAttack, iDamage)
    if not oVictim or oVictim:IsDead() then return 0 end

    local oWar = oVictim:GetWar()
    local oShare = oVictim:GetWarrior(iShareWid)
    if not oShare or oShare:IsDead() then return 0 end

    local iBout = oShare:Query("p5702_bout", 0)
    if oWar:CurBout() >= iBout + 3 then return end

    local iShareDamage = math.floor(iDamage * 0.3)
    if iShareDamage <= 0 then return 0 end

    global.oActionMgr:DoSubHp(oShare, iShareDamage, oAttack, {hited_effect=1})
    return iShareDamage
end


