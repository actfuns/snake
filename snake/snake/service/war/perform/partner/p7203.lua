--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--连环炎爆

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

