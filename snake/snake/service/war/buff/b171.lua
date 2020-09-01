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

function CBuff:AddFloor(oWarrior,iAdd)
    local iFloor = self:GetFloor()
    iFloor = iFloor +iAdd
    self.m_mArgs["floor"] = iFloor
    if iFloor<=0 then
        oWarrior.m_oBuffMgr:RemoveBuff(self)
    else
        local oBuffMgr = oWarrior.m_oBuffMgr
        oBuffMgr:SetAttrAddValue("damaged_ratio",self.m_ID,-10*iFloor)
        self:Refresh(oWarrior)
    end
end

function CBuff:GetFloor(oWarrior)
    return self.m_mArgs["floor"] or 0
end


function CBuff:CalAttrValue(sFormula)
    local iValue = math.floor(formula_string(sFormula,{level=self:PerformLevel(),floor = self:GetFloor()}))
    return iValue
end

function CBuff:PackAttr(oAction)
    local lAttr = super(CBuff).PackAttr(self, oAction)
    table.insert(lAttr,{key = "level",value = self:GetFloor()})
    return lAttr
end
