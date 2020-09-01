--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local titledefines = import(service_path("title.titledefines"))
local titleobj = import(service_path("title.titleobj"))


function NewTitle(iPid, iTid, create_time, name)
    local o = CTitle:New(iPid, iTid, create_time, name)
    o:Init()
    return o
end

function CheckTitleExpire(iPid, iTid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    
    local oTitle = oPlayer.m_oTitleCtrl:GetTitleByTid(iTid)
    if oTitle then
        oTitle:_DoExpire()
    end
end

CTitle = {}
CTitle.__index = CTitle
inherit(CTitle, titleobj.CTitle)

function CTitle:New(iPid, iTid, create_time, name)
    local o = super(CTitle).New(self, iPid, iTid, create_time, name)
    return o
end

function CTitle:GetName()
    local oOrgMgr = global.oOrgMgr
    if not oOrgMgr then
        return super(CTitle).GetName(self)
    end
    local iOrgID = oOrgMgr:GetPlayerOrgId(self:GetPid())
    local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
    if not oOrg then
        -- record.warning("title not find org %d %d", self:TitleID(), self:GetPid())
        return self:GetConfigData()["name"]
    end

    local sName = self:GetConfigData()["name"]
    local sName = string.format(sName, oOrg:GetName())
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
