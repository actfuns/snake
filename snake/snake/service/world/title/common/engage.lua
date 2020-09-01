--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local titleobj = import(service_path("title.titleobj"))


function NewTitle(iPid, iTid, create_time, name)
    local o = CTitle:New(iPid, iTid, create_time, name)
    o:Init()
    return o
end

CTitle = {}
CTitle.__index = CTitle
inherit(CTitle, titleobj.CTitle)

function CTitle:GetName()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    local sName = self:GetConfigData()["name"]
    if oPlayer then
        return string.format(sName, oPlayer:GetCoupleName())
    end
    return sName
end
