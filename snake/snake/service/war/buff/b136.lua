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

function CBuff:CalInit(oAction, oBuffMgr)
    local iMp = self:GetSetAttr()["mp_add"] or 0
    global.oActionMgr:DoAddMp(oAction, iMp)
end

function CBuff:OnNewBout(oAction, oBuffMgr)
    local iMp = self:GetSetAttr()["mp_add"] or 0
    global.oActionMgr:DoAddMp(oAction, iMp)
end
