--import module

local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior, oBuffMgr)
    local func = function(oAttack, oPerform, lVictim)
        OnEndPerform(oAttack, oPerform, lVictim)
    end
    oBuffMgr:AddFunction("OnEndPerform", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)

    oBuffMgr:RemoveFunction("OnEndPerform", self.m_ID)
end

function OnEndPerform(oAttack, oPerform, lVictim)
    if oAttack:IsDead() then return end

    local oWar = oAttack:GetWar()
    if not oWar then return end

    local sKey = string.format("ignore_perform_again_%s", oPerform:Type())
    if oAttack:QueryBoutArgs(sKey) then
        return
    end

    if oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return
    end
    
    if not lVictim or not next(lVictim) then return end

    oAttack:SetBoutArgs(sKey, oPerform:Type())
    
    local lVictim1 = {}
    if not lVictim[1] or lVictim[1]:IsDead() then
        local mTarget = oPerform:PerformTarget(oAttack, lVictim[1])
        for _, iWid in ipairs(mTarget) do
            table.insert(lVictim1, oWar:GetWarrior(iWid))
        end
    else
        lVictim1 = lVictim
    end
    if #lVictim1 then
        for _, oVictim in pairs(lVictim1) do
            if oVictim:IsAlive() then
                oPerform:Perform(oAttack, lVictim1)
                break
            end
        end
    end
end

