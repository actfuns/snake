--import module

local global = require "global"
local buildbase = import(service_path("org/build/buildbase"))

function NewBuild(...)
    return CBuildHome:New(...)
end

CBuildHome = {}
CBuildHome.__index = CBuildHome
inherit(CBuildHome, buildbase.CBuildBase)

function CBuildHome:New(iBid, iOrgId)
    local o = super(CBuildHome).New(self, iBid, iOrgId)
    return o
end
