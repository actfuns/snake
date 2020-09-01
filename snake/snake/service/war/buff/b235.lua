--import module

local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction,oBuffMgr)
    local iSP = self:GetAttr("sp") or 0
    oAction:AddSP(iSP)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)

    oBuffMgr:RemoveFunction("CheckResumeSP", self.m_ID)
end
