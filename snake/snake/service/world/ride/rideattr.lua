--import module

local global = require "global"
local skynet = require "skynet"

local attrmgr = import(service_path("attrmgr"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewAttrMgr(pid)
    local o = CAttrMgr:New(pid)
    o:SetSynclSum()
    return o
end

CAttrMgr = {}
CAttrMgr.__index =CAttrMgr
CAttrMgr.m_ApplySumDef = gamedefines.SUM_DEFINE.MO_RIDE_MGR
CAttrMgr.m_RatioSumDef = gamedefines.SUM_DEFINE.MO_RIDE_MGR_R
inherit(CAttrMgr, attrmgr.CAttrMgr)

function CAttrMgr:New(pid)
    local o = super(CAttrMgr).New(self,pid)
    return o
end