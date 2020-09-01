--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--神雷审判

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


