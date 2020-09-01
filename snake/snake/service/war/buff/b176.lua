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

function CBuff:GetGanHua()
    return self.m_mArgs["point"] or 0
end

function CBuff:AddGanHua(oWarrior,iAdd)
    local iPoint = self:GetGanHua()
    iPoint = iPoint +iAdd
    self.m_mArgs["point"] = iPoint
    self:Refresh(oWarrior)
    if iPoint<=0 then
        oWarrior.m_oBuffMgr:RemoveBuff(self)
    elseif iPoint>=9 then
        local oWar=oWarrior:GetWar()
        oWar.m_iWarResult = 1
        oWar:WarEnd()
    end
end

function CBuff:PackAttr(oAction)
    local lAttr = super(CBuff).PackAttr(self, oAction)
    table.insert(lAttr,{key = "point",value = self:GetGanHua()})
    return lAttr
end
