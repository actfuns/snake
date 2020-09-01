local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--掉血

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    local iSubHp = oAction:GetMaxHp() // 4 + 1
    global.oActionMgr:DoSubHp(oAction, iSubHp, oAction)
end
