-- import file

local lpsum = require "lpsum"


local PlayerAttr2C = {
    physique = 0,
    strength = 1,
    magic = 2,
    endurance = 3,
    agility = 4,
    max_hp = 5,
    max_mp = 6,
    phy_attack = 7,
    phy_defense = 8,
    mag_attack = 9,
    mag_defense = 10,
    speed = 11,
    cure_power = 12,
    seal_ratio = 13,
    res_seal_ratio = 14,
    phy_critical_ratio = 15,
    res_phy_critical_ratio = 16,
    mag_critical_ratio = 17,
    res_mag_critical_ratio = 18,
    critical_multiple = 19,
    res_phy_defense_ratio = 20,
    res_mag_defense_ratio = 21,
    mag_damage_add = 22,
    phy_damage_add = 23,
    hit_ratio = 24,
    hit_res_ratio = 25, 
    phy_hit_ratio = 26,
    phy_hit_res_ratio = 27, 
    mag_hit_ratio = 28,
    mag_hit_res_ratio = 29,
}

function IsAttr2C(sAttr)
    if PlayerAttr2C[sAttr] then
        return true
    end
    return false
end


function NewCSumAttr(...)
    return CCSummAttr:New(...)
end

CCSummAttr = {}
CCSummAttr.__index = CCSummAttr
inherit(CCSummAttr, logic_base_cls())

function CCSummAttr:New()
    local o = super(CCSummAttr).New(self)
    o.m_cSum = lpsum.lpsum_create()
    return o
end

function CCSummAttr:Release()
    self.m_cSum = nil
    super(CCSummAttr).Release(self)
end

function CCSummAttr:IsAttr2C(sAttr)
    return IsAttr2C(sAttr)
end


function CCSummAttr:SetGrade(iGrade)
    local oSum = self.m_cSum
    oSum:setgrade(iGrade)
end

function CCSummAttr:Set(iMo,sAttr,Val)
    if not self:IsAttr2C(sAttr) then return end

    local oSum = self.m_cSum
    oSum:set(sAttr,iMo,Val)
end

function CCSummAttr:Add(iMo,sAttr,Val)
    if not self:IsAttr2C(sAttr) then return end

    local oSum = self.m_cSum
    oSum:add(sAttr,iMo,Val)
end

function CCSummAttr:Clear(iMo)
    local oSum = self.m_cSum
    oSum:clear(iMo)
end

function CCSummAttr:GetAttr(sAttr)
    local oSum = self.m_cSum
    return oSum:getattr(sAttr)
end

function CCSummAttr:GetBaseAttr(sAttr)
    local oSum = self.m_cSum
    return oSum:getbaseattr(sAttr)
end

function CCSummAttr:GetBaseRatio(sAttr)
    local oSum = self.m_cSum
    return oSum:getbaseratio(sAttr)
end

function CCSummAttr:GetAttrAdd(sAttr)
    local oSum = self.m_cSum
    return oSum:getattradd(sAttr)
end

function CCSummAttr:Print(iMo)
    local oSum = self.m_cSum
    oSum:print(iMo)
end
