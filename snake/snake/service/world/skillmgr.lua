--import module

local global = require "global"
local skynet = require "skynet"

local attrmgr = import(service_path("attrmgr"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewSkillMgr(pid)
    local o = CSkillMgr:New(pid)
    o:SetSynclSum()
    return o
end

CSkillMgr = {}
CSkillMgr.__index =CSkillMgr
CSkillMgr.m_ApplySumDef = gamedefines.SUM_DEFINE.MO_SKILL_MGR
CSkillMgr.m_RatioSumDef = gamedefines.SUM_DEFINE.MO_SKILL_MGR_R
inherit(CSkillMgr,attrmgr.CAttrMgr)

function CSkillMgr:New(pid)
    local o = super(CSkillMgr).New(self,pid)
    return o
end