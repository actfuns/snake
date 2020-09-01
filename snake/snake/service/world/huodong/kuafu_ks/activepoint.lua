local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "活跃礼包"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:CheckReward(oPlayer, iPoint, bModule)
    if not bModule or iPoint <= 0 then return end

    local iTotal = oPlayer:Query("ks_activepoint_add", 0) + iPoint
    oPlayer:Set("ks_activepoint_add", iTotal)
end


