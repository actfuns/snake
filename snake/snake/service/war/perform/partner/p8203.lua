--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--妖皇降临

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

