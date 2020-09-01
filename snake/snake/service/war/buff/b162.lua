local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--我佛慈悲

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnNewBout(oAction, oBuffMgr)
    if not oAction or oAction:IsDead() then
        return
    end
    if not self.m_mArgs.hp_add then return end

    --oAction:AddHp(self.m_mArgs.hp_add)
    global.oActionMgr:DoAddHp(oAction, self.m_mArgs.hp_add)
end

