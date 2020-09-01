local global = require "global"
local extend = require "base.extend"
local interactive = require "base.interactive"
local record = require "public.record"
local playersend = require "base.playersend"

function NewMailAddrMgr()
    return CMailAddrMgr:New()
end

CMailAddrMgr = {}
CMailAddrMgr.__index = CMailAddrMgr
inherit(CMailAddrMgr, logic_base_cls())

function CMailAddrMgr:New()
    local o = super(CMailAddrMgr).New(self)
    return o
end

function CMailAddrMgr:GetUpdateService()
    local lService = {".autoteam", ".broadcast", ".clientupdate", ".rank", ".version", ".chat"}
    for _, v in pairs(global.oWarMgr.m_lWarRemote) do
        table.insert(lService, v)
    end
    for _, v in pairs(global.oSceneMgr.m_lSceneRemote) do
        table.insert(lService, v)
    end
    return lService
end

function CMailAddrMgr:OnConnectionChange(oPlayer)
    local mService = self:GetUpdateService()
    local sCmd = [[
        local playersend = require "base.playersend"
    ]]
    local iPid = oPlayer:GetPid()
    local mMailAddr = oPlayer:MailAddr()
    playersend.UpdatePlayerMail(iPid,mMailAddr)
    if not mMailAddr then
        mMailAddr = "nil"
    else
        mMailAddr = ConvertTblToStr(mMailAddr)
    end
    sCmd =sCmd.."playersend.UpdatePlayerMail("..iPid..",".. mMailAddr .. ")"
    for _,iRemoteAdd in pairs(mService) do
        interactive.Send(iRemoteAdd, "default", "ExecuteString", {cmd = sCmd})
    end
end