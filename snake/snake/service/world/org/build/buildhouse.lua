--import module

local global = require "global"
local buildbase = import(service_path("org/build/buildbase"))

function NewBuild(...)
    return CBuildHouse:New(...)
end

CBuildHouse = {}
CBuildHouse.__index = CBuildHouse
inherit(CBuildHouse, buildbase.CBuildBase)

function CBuildHouse:New(iBid, iOrgId)
    local o = super(CBuildHouse).New(self, iBid, iOrgId)
    return o
end

function CBuildHouse:GetAddMaxMem()
    return self:GetBuildData()["effect2"][1]["val"] or 0
end

function CBuildHouse:GetAddMaxXueTu()
    return self:GetBuildData()["effect2"][2]["val"] or 0
end
