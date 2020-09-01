--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewMoveAI(...)
    local o = CMoveAI:New(...)
    return o
end

CMoveAI = {}
CMoveAI.__index = CMoveAI
inherit(CMoveAI, logic_base_cls())

function CMoveAI:New()
    local o = super(CMoveAI).New(self)
    return o
end

function CMoveAI:Init(entityobj, mArgs)
    -- body
end