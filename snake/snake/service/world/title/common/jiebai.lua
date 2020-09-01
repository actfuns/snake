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
    local iPid = self:GetPid()
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    local sName = self:GetConfigData()["name"]
    if not oHuodong then return sName end

    local oJieBai = oHuodong:GetJieBaiByPid(iPid)
    if oJieBai and oJieBai:State() == 3 then
        sName = string.format("%s.%s", oJieBai:GetTitle(), oJieBai:GetMingHao(iPid))
    end
    if sName ~= self:GetData("name") then
        self:SetName(sName)
    end
    return sName
end

function CTitle:GetShowName()
    if is_ks_server() then
        return self:GetData("name", self:GetConfigData()["name"])
    end
    return self:GetName()
end
