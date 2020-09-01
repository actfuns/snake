local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--星宿特殊加血buff

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    if not oAction or oAction:IsDead() then
        return
    end

    local iMaxHp = oAction:GetMaxHp()
    global.oActionMgr:DoAddHp(oAction, math.floor(iMaxHp*16/100))
end

