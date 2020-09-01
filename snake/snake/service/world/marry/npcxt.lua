--import module
local global  = require "global"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"

local npcobj = import(service_path("npc.npcobj"))


function NewNpcXT(...)
    return CXTNpc:New(...)
end


CXTNpc = {}
CXTNpc.__index = CXTNpc
inherit(CXTNpc, npcobj.CNpc)

function CXTNpc:New(mArgs)
    local o = super(CXTNpc).New(self)
    o:Init(mArgs)
    return o
end

function CXTNpc:Init(mArgs)
    local mArgs = mArgs or {}

    self.m_iType = mArgs["type"] or 0
    self.m_sName = mArgs["name"] or ""
    self.m_iMapid = mArgs["map_id"] or 0
    self.m_mModel = mArgs["model_info"] or {}
    self.m_mPosInfo = mArgs["pos_info"] or {}
    self.m_iEvent = mArgs["event"] or 0
    self.m_iNpcId = mArgs["npc_id"] or 0
end

function CXTNpc:NpcID()
    return self.m_iNpcId
end

function CXTNpc:do_look(oPlayer)
    global.oMarryMgr:PickMarryXT(oPlayer, self)
end

