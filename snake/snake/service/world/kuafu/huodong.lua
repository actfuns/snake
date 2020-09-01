--import module
local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodong = import(service_path("huodong"))


HUODONGLIST = {
    -- ["fengyao"] = "fe  ngyao",
    ["singlewar"] = "kuafu_ks.singlewar",
    ["treasure"] = "treasure",
    ["jyfuben"] = "jyfuben",
    ["signin"] = "kuafu_ks.signin",
    ["activepoint"] = "kuafu_ks.activepoint",
}

function NewHuodongMgr(...)
    return CHuodongMgr:New(...)
end

CHuodongMgr = {}
CHuodongMgr.__index = CHuodongMgr
inherit(CHuodongMgr, huodong.CHuodongMgr)

function CHuodongMgr:New()
    local o = super(CHuodongMgr).New(self)
    return o
end

function CHuodongMgr:GetHuoDongListConfig()
    return HUODONGLIST
end

function CHuodongMgr:Init()
    for sName,oHuodong in pairs(self.m_mHuodongList) do
        oHuodong:Init()
    end
    self:Schedule()
end


