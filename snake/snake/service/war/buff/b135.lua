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

function CBuff:OnNewBout(oAction,oBuffMgr)
    local oWar = oAction:GetWar()
    local lWid = {}
    for iWid, iBout in pairs(self:GetSetAttr()) do
        if oWar.m_iBout >= iBout then
            table.insert(lWid, iWid)
        end
    end

    for _,iWid in ipairs(lWid) do
        self:SetAttr(iWid, nil)
    end
end