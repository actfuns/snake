--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local CBaseChannel = import(service_path("basechannel")).CBaseChannel

function NewSysChannel(...)
    local o = CSysChannel:New(...)
    return o
end

CSysChannel = {}
CSysChannel.__index = CSysChannel
inherit(CSysChannel, CBaseChannel)

function CSysChannel:New()
    local o = super(CSysChannel).New(self)
    o.m_iType = gamedefines.CHANNEL_TYPE.SYS_TYPE
    return o
end