--import module

local global = require "global"
local skynet = require "skynet"

local attrmgr = import(service_path("attrmgr"))

function NewTouxianAttrMgr(pid)
    local o = CTouxianAttrMgr:New(pid)
    return o
end

CTouxianAttrMgr = {}
CTouxianAttrMgr.__index =CTouxianAttrMgr
inherit(CTouxianAttrMgr,attrmgr.CAttrMgr)

function CTouxianAttrMgr:New(pid)
    local o = super(CTouxianAttrMgr).New(self,pid)
    return o
end