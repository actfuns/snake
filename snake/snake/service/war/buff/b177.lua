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

function CBuff:GetDianHua()
    return self.m_mArgs["point"] or 0
end

function CBuff:AddDianHua(oWarrior,iAdd)
    local iPoint = self:GetDianHua()
    iPoint = iPoint +iAdd
    iPoint = math.max(iPoint,0)
    self.m_mArgs["point"] = iPoint
    self:Refresh(oWarrior)
    if iPoint<=0 then
        oWarrior.m_oBuffMgr:RemoveBuff(self)
    end
end

function CBuff:PackAttr(oAction)
    local lAttr = super(CBuff).PackAttr(self, oAction)
    table.insert(lAttr,{key = "point",value = self:GetDianHua()})
    return lAttr
end
