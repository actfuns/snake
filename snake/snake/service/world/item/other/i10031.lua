local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who,target)
    who:Send("GS2CWashSummonUI", {})
    return true
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
