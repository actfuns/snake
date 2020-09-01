local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

local lResDrug = {{5, 100}, {10, 80}, {15, 65}, {31, 50}}

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oAction, oBuffMgr)
end

function CBuff:OnBoutEnd(oAction, oBuffMgr)
    local iSub = 2 + math.floor(self:GetStack() / 7)
    self:AddDrugPoint(-iSub, oAction)
end

function CBuff:AddDrugPoint(iPoint, oAction)
    if iPoint > 0 then
        self:AddStack(iPoint)
    else
        self:SubStack(-iPoint)
    end

    local oBuffMgr = oAction.m_oBuffMgr
    oBuffMgr:SetAttrAddValue("res_drug", self.m_ID, self:CalResDrug())

    local oWar = oAction:GetWar()
    oAction:SendAll("GS2CWarBuffBout", {
        war_id = oWar:GetWarId(),
        wid = oAction:GetWid(),
        buff_id = self.m_ID,
        bout  = self:Bout(),
        stack = self:GetStack()
    })
    oWar:AddDebugMsg(string.format("#B%s#nbuff#R%s#n药品抗性%d", 
        oAction:GetName(), self:Name(), self:GetStack()))
end

function CBuff:CalResDrug()
    local iDrugPoint = self:GetStack()
    for _, l in pairs(lResDrug) do
        if iDrugPoint < l[1] then
            return l[2] - 100
        end
    end
    return 0
end

function CBuff:MaxStack()
    return 30
end