--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewMoveAI(...)
    local o = CXunLuo:New(...)
    return o
end

CXunLuo = {}
CXunLuo.__index = CXunLuo
inherit(CXunLuo, logic_base_cls())

function CXunLuo:New()
    local o = super(CXunLuo).New(self)
    return o
end

function CXunLuo:Init(entityobj, mArgs)
    entityobj.m_iXunLuoID = mArgs.xunluoid
end