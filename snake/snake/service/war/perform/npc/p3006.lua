--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--真·金刚伏魔 

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


