local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--灼烧

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    if not oAction or oAction:IsDead() then
        return
    end
    local oWar = oAction:GetWar()
    if not oWar then return end

    if not self.m_mArgs.hp_sub then return end

    local iHp = self.m_mArgs.hp_sub
    iHp = iHp - (iHp * oAction:Query("res_poison_ratio", 0) / 100)
    if iHp > 0 then
        local oAttack = oWar:GetWarrior(self:ActionWid())
        global.oActionMgr:DoSubHp(oAction, iHp, oAttack)
    end
end

