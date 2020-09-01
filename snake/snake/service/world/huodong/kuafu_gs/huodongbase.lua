local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:OnStartKSHuodong(sKuaFu, mInfo)
    
end

function CHuodong:OnEndKSHuodong(sKuaFu)
    
end