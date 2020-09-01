local global = require "global"

local datactrl = import(lualib_path("public.datactrl"))

CServState = {}
CServState.__index = CServState
inherit(CServState, datactrl.CDataCtrl)

function NewServState(sId, pid)
    local o = CServState:New(sId, pid)
    return o
end

function CServState:New(sId, pid)
    local o = super(CServState).New(self)
    o.m_sID = sId
    o.m_iPid = pid
    return o
end

function CServState:Init(mArgs)
end

function CServState:Save()
    local mData = {}
    return mData
end

function CServState:Load(mData)
end

function CServState:ValidSave()
    return false
end

function CServState:ID()
    return self.m_sID
end

function CServState:SetPid(pid)
    self.m_iPid = pid
end

function CServState:GetPid()
    return self.m_iPid
end

function CServState:GetName()
    return "base"
end

function CServState:OnLogin(oPlayer, bReEnter)
end

function CServState:OnLogout(oPlayer)
end

function CServState:FobidTeamAction(pid, sAction, mArgs)
end

------------------------------
CTeamServState = {}
CTeamServState.__index = CTeamServState
inherit(CTeamServState, CServState)

function NewTeamServState(sId, teamid)
    local o = CTeamServState:New(sId, teamid)
    return o
end

function CTeamServState:New(sId, iTeamid)
    local o = super(CServState).New(self)
    o.m_sID = sId
    o.m_iTeamId = iTeamid
    return o
end

function CTeamServState:Init(mArgs)
end

function CTeamServState:GetTeamId()
    return self.m_iTeamId
end
