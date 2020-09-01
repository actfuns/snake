--import module

local global = require "global"
local skynet = require "skynet"

local attrmgr = import(service_path("attrmgr"))


function NewSummonAttrMgr(pid)
    local o = CSummonAttrMgr:New(pid)
    return o
end


CSummonAttrMgr = {}
CSummonAttrMgr.__index =CSummonAttrMgr
inherit(CSummonAttrMgr, attrmgr.CAttrMgr)

function CSummonAttrMgr:New(sid)
    local o = super(CSummonAttrMgr).New(self, sid)
    return o
end