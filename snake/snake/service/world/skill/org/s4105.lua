--import module

local global = require "global"
local skillobj = import(service_path("skill/org/orgbase"))

function NewSkill(iSk)
    local o = COrgSkill:New(iSk)
    return o
end


COrgSkill = {}
COrgSkill.__index = COrgSkill
inherit(COrgSkill, skillobj.COrgSkill)

function COrgSkill:New(iSk)
    local o = super(COrgSkill).New(self, iSk)
    return o
end

function COrgSkill:LimitLevel(oPlayer)
    return math.min(oPlayer:GetGrade() + 10, self:MaxLevel())
end

function COrgSkill:LearnNeedCost(iLv)
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["upgrade"][iLv]
    return mData["pass_silver"], mData["pass_offer"] 
end
