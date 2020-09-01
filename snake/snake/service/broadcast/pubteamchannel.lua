--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local CBaseChannel = import(service_path("basechannel")).CBaseChannel
local playersend = require "base.playersend"


function NewPubTeamChannel(...)
    local o = CPubTeamChannel:New(...)
    return o
end


CPubTeamChannel = {}
CPubTeamChannel.__index = CPubTeamChannel
inherit(CPubTeamChannel, CBaseChannel)

function CPubTeamChannel:New()
    local o = super(CPubTeamChannel).New(self)
    o.m_iType = gamedefines.BROADCAST_TYPE.TEAM_TYPE
    return o
end

function CPubTeamChannel:Send(sMessage, mData, mArgs)
    local sData = playersend.PackData(sMessage, mData)

    mArgs = mArgs or {}
    local iMinGrade = mArgs.mingrade or 0
    local iMaxGrade = mArgs.maxgrade or 999
    local lInclude = mArgs.include or {}
    for k, o in pairs(self.m_mMembers) do
        local iGrade = o.m_mInfo["grade"] or 0
        local iTeamId = o.m_mInfo["teamid"]
        if table_in_list(lInclude, k) then
            o:SendRaw(sData)
        else
            if not iTeamId and iMinGrade <= iGrade and iGrade <= iMaxGrade then
                o:SendRaw(sData)
            end
        end
    end
end

