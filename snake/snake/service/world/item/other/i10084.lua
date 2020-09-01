local global = require "global"
local skynet = require "skynet"
local itembase = import(service_path("item/other/i10080"))

function NewItem(iSid)
    local o = CItem:New(iSid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

