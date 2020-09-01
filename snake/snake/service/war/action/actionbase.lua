--import module

local global = require "global"

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, logic_base_cls())

function CWarAction:New(iWarid)
    local o = super(CWarAction).New(self)
    self.m_iWarId = iWarid
    return o
end

function CWarAction:GetWarId()
    return self.m_iWarId
end

function CWarAction:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self:GetWarId())
end

function CWarAction:DoAction(mInfo)
end
