-- 画舫灯谜金钟罩，AOI在前端表现特效
local global = require "global"
local res = require "base.res"
local statebase = import(service_path("state/statebase"))

function NewState(iState)
    local o = CState:New(iState)
    return o
end

CState = {}
CState.__index = CState
inherit(CState, statebase.CState)

function CState:ValidSave()
    return false
end

function CState:OnAddState(oPlayer)
    super(CState).OnAddState(self, oPlayer)
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return end
    local iMapId = oScene:MapId()
    local sVirtual = table_get_depth(res, {"daobiao", "map", iMapId, "virtual_game"})
    if sVirtual == "hfdm" then
        oPlayer.m_oStateCtrl:RefreshMapFlag()
    end
end

function CState:OnRemoveState(oPlayer)
    super(CState).OnRemoveState(self, oPlayer)
    oPlayer.m_oStateCtrl:RefreshMapFlag()
end

function CState:SetHide(bValue)
    self.m_bHide = bValue
end

function CState:MapFlag()
    if self.m_bHide then
        return 0
    end
    return super(CState).MapFlag(self)
end
