local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local geometry = require "base.geometry"

local gamedefines = import(lualib_path("public.gamedefines"))
local CEntity = import(service_path("entityobj")).CEntity

function NewTeamEntity(...)
    return CTeamEntity:New(...)
end


CTeamEntity = {}
CTeamEntity.__index = CTeamEntity
inherit(CTeamEntity, CEntity)

function CTeamEntity:New(iEid, iTeam, mMem, mShort)
    local o = super(CTeamEntity).New(self, iEid)
    o.m_iType = gamedefines.SCENE_ENTITY_TYPE.TEAM_TYPE
    o.m_iTeam = iTeam
    o.m_mTeamData = mMem
    o.m_mTeamShort = mShort
    return o
end

function CTeamEntity:GetTeamId()
    return self.m_iTeam
end

function CTeamEntity:GetTeamInfo()
    local oScene = self:GetScene()
    local iTeam = self:GetTeamId()
    local lTeam = self:GetTeamSortMember()
    return {data = lTeam, team_id = iTeam}
end

function CTeamEntity:GetTeamLeader()
    local oScene = self:GetScene()
    local iLeaderPid = self:GetLeaderPid()
    return oScene:GetPlayerEntity(iLeaderPid)
end

function CTeamEntity:GetLeaderPid()
    for k, v in pairs(self.m_mTeamData) do
        if v == 1 then
            return k
        end
    end
end

function CTeamEntity:IsLeader(iPid)
    return iPid == self:GetLeaderPid()
end

function CTeamEntity:GetTeamMember()
    return self.m_mTeamData
end

function CTeamEntity:SetTeamMember(m)
    self.m_mTeamData = m
end

function CTeamEntity:GetTeamShort()
    return self.m_mTeamShort
end

function CTeamEntity:SetTeamShort(m)
    self.m_mTeamShort = m
end

function CTeamEntity:GetTeamLength()
    local l = self:GetTeamSortMember()
    return #l
end

function CTeamEntity:GetTeamSortMember()
    local l = {}
    local i = 0
    for k, v in pairs(self.m_mTeamData) do
        i = i + 1
        l[v] = k
    end
    assert(#l == i, string.format("CTeamEntity GetTeamSortMember error %d %d", #l, i))
    return l
end
