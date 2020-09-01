local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local loadpartner = import(service_path("partner/loadpartner"))
local itembase = import(service_path("item/itembase"))
local loadpartnerskill = import(service_path("partner.skill.loadskill"))


local max = math.max
local min = math.min

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "partnerequip"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:Name()
    local sName = self:GetItemData()["name"]
    return sName
end

function CItem:GetPartnerId()
    return self:GetItemData()["partnerid"]
end

function CItem:GetEquipPos()
    return self:GetItemData()["equippos"]
end

function CItem:GetEffect()
    return self:GetItemData()["equip_effect"]
end

function CItem:Use(oPlayer,target)
    local oPartner =  oPlayer.m_oPartnerCtrl:GetPartner(target)
    if not oPartner then 
        return
    end
    if oPartner:GetSID() ~= self:GetPartnerId() then
        return
    end
    local iPos = self:GetEquipPos()
    if oPartner.m_oEquipCtrl:GetEquip(iPos) then
        return
    end
    local iSid = self:SID()
    local mApply = self:GetApply()
    oPlayer:RemoveOneItemAmount(self,1,"itemuse")

    oPartner.m_oEquipCtrl:AddEquip(oPartner, iPos, iSid, mApply)
    oPartner:PropChange("equipsid")
    oPartner:SecondLevelPropChange()
    return true
end

function CItem:GetApply()
    local mEffectInfo = self:GetEffect()
    local mApply = {}
    for _, sEffect in ipairs(mEffectInfo) do
        local sAttr,sFormula = string.match(sEffect,"(.+)=(.+)")
        if sAttr and sFormula then
            local iValue = formula_string(sFormula, {})
            iValue = decimal(iValue)
            mApply[sAttr] = iValue
        end
    end
    return mApply
end

function CItem:GetScore()
    -- body
end
