local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/i11082"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

