local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--中毒

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    if not oAction or oAction:IsDead() then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local iDamage = self.m_mArgs.damage_buff or 0
    iDamage = iDamage - (iDamage * oAction:Query("res_poison_ratio", 0) / 100)
    if iDamage >= 0 then
        if iDamage >= oAction:GetHp() then
            oAction:SetBoutArgs("poison_die", 1)
        end
        local oAttack = oWar:GetWarrior(self:ActionWid())
        global.oActionMgr:DoSubHp(oAction, iDamage, oAttack)
    end
end

