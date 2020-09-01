local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    if not oAction or oAction:IsDead() then
        return
    end
    local iHP = math.floor(oAction:GetMaxHp() *5 /100)
    if iHP>0 then
        global.oActionMgr:DoSubHp(oAction, iHP)
        oAction:SubHp(iHP, nil)
        --print("DoSubHp",208,iHP)
    end
end