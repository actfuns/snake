local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local shopbase = import(service_path("shop.shopbase"))

function NewShop(...)
    return CShop:New(...)
end

CShop = {}
CShop.__index = CShop
inherit(CShop, shopbase.CShop)
