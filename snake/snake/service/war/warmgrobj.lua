--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local warobj = import(service_path("warobj"))
local orgwar = import(service_path("playwar.orgwar"))
local warvideo = import(service_path("warvideo"))
local gamedefines = import(lualib_path("public.gamedefines"))
local singlewar = import(service_path("playwar.singlewar"))

function NewWarMgr(...)
    local o = CWarMgr:New(...)
    return o
end

CWarMgr = {}
CWarMgr.__index = CWarMgr
inherit(CWarMgr, logic_base_cls())

function CWarMgr:New()
    local o = super(CWarMgr).New(self)
    o.m_mWars = {}
    return o
end

function CWarMgr:Release()
    for _, v in pairs(self.m_mWars) do
        baseobj_safe_release(v)
    end
    self.m_mWars = {}
    super(CWarMgr).Release(self)
end

function CWarMgr:ConfirmRemote(iWarId, iWarType, iSysType, mInfo)
    assert(not self.m_mWars[iWarId], string.format("ConfirmRemote error %d", iWarId))

    local oWar = nil
    if iWarType == gamedefines.WAR_TYPE.WAR_VIDEO_TYPE then
        oWar = warvideo.NewWar(iWarId)
    else
        if iSysType == gamedefines.GAME_SYS_TYPE.SYS_TYPE_ORGWAR then
            oWar = orgwar.NewWar(iWarId)
        elseif iSysType == gamedefines.GAME_SYS_TYPE.SYS_TYPE_SINGLEWAR then
            oWar = singlewar.NewWar(iWarId)
        else
            oWar = warobj.NewWar(iWarId)
        end
    end

    oWar:Init(iWarType, mInfo)
    self.m_mWars[iWarId] = oWar
end

function CWarMgr:GetWar(iWarId)
    return self.m_mWars[iWarId]
end

function CWarMgr:GetWars()
    return self.m_mWars
end

function CWarMgr:RemoveWar(iWarId)
    local oWar = self.m_mWars[iWarId]
    if oWar then
        self.m_mWars[iWarId] = nil
        baseobj_delay_release(oWar)
    end
end

function CWarMgr:DealExceptionWar(iWarId)
    local oWar = self:GetWar(iWarId)
    if not oWar then
        return
    end
    self.m_mWars[iWarId] = nil
    oWar:WarEndException()
    baseobj_delay_release(oWar)
end

function CWarMgr:ForceWarEnd(iWarId)
    local oWar = self:GetWar(iWarId)
    if not oWar then return end

    oWar:ForceWarEnd()
end
