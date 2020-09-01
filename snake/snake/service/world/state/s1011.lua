local global = require "global"
local res = require "base.res"

local statebase = import(service_path("state/statebase"))
local itemdefines = import(service_path("item/itemdefines"))

CState = {}
CState.__index = CState
inherit(CState,statebase.CState)

function NewState(iState)
    local o = CState:New(iState)
    return o 
end

function CState:New(iState)
    local o = super(CState).New(self,iState)
    return o
end

function CState:OnAddState(oPlayer)
    local iAddPhyAttack = math.floor(oPlayer:GetPhyAttack() * 0.1)
    local iAddMagAttack = math.floor(oPlayer:GetMagAttack() * 0.1)
    local iAddPhyDefense = math.floor(oPlayer:GetPhyDefense() * 0.1)
    local iAddMagDefense = math.floor(oPlayer:GetMagDefense() * 0.1)
    local mAttrs = {
        phy_attack = iAddPhyAttack,
        mag_attack = iAddMagAttack,
        phy_defense = iAddPhyDefense,
        mag_defense = iAddMagDefense,
    }
    local iSourceId = self:GetApplySource()
    oPlayer.m_oEquipMgr:RemoveSource(iSourceId)
    for sAttr, iValue in pairs(mAttrs) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, iSourceId, iValue)
    end
    oPlayer:RefreshPropAll()
end

function CState:OnRemoveState(oPlayer)
    local iSourceId = self:GetApplySource()
    oPlayer.m_oEquipMgr:RemoveSource(iSourceId)
    oPlayer:RefreshPropAll()
end


function CState:GetApplySource()
    --pos 默认给个0
    local sApply = "treasureconvoy"
    return itemdefines.GetApplySource(0, sApply)
end