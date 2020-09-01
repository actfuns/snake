local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/giftpack/i12929"))

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
