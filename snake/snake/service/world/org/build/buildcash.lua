--import module

local global = require "global"
local buildbase = import(service_path("org/build/buildbase"))

function NewBuild(...)
    return CBuildCash:New(...)
end

CBuildCash = {}
CBuildCash.__index = CBuildCash
inherit(CBuildCash, buildbase.CBuildBase)

function CBuildCash:New(iBid, iOrgId)
    local o = super(CBuildCash).New(self, iBid, iOrgId)
    return o
end

function CBuildCash:GetAddMaxCash()
    return self:GetBuildData()["effect1"]
end