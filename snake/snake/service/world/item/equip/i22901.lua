local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local itembase = import(service_path("item/equip/equipbase"))
local itemdefines = import(service_path("item.itemdefines"))
local loadskill = import(service_path("skill/loadskill"))


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_EngageType = 1


function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:Create(mArgs)
    mArgs = mArgs or {}
    self:SetData("engage_text", mArgs.engage_text)
    self:SetData("engage_pid", mArgs.engage_pid)
    self:SetData("engage_time", get_time())
    self:SetData("engage_type", mArgs.engage_type)
end

function CItem:Release()
    super(CItem).Release(self)
end

function CItem:PackEquipInfo()
    local mNet = super(CItem).PackEquipInfo(self)
    -- mNet["grow_level"] = self:GrowLevel()
    mNet["engage_text"] = self:GetData("engage_text")
    mNet["engage_time"] = self:GetData("engage_time")
    return mNet
end

function CItem:CanWield(oPlayer)
    return false, "不能装备"
end
