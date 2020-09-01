local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"

local itembase = import(service_path("item.other.i11169"))
local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
--紫
CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)