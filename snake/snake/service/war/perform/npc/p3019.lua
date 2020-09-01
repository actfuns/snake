local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

-- 混沌初开

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)
