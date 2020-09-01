local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/itembase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who,target)
    who:Send("GS2CRPItem",self:PackRP())
    return true
end

function CItem:PackRP()
    return {id=self.m_ID,
    name=self:GetData("name",""),
    count=self:GetData("count",0),
    goldcoin=self:GetData("goldcoin",0)}
end
