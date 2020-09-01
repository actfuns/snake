local global = require "global"
local res = require "base.res"

local statebase = import(service_path("state/statebase"))

CState = {}
CState.__index = CState
inherit(CState,statebase.CState)

function NewState(iState)
    local o = CState:New(iState)
    return o 
end

function CState:OnAddState(oPlayer)
    super(CState).OnAddState(self, oPlayer)
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return end

    local iMapId = oScene:MapId()
    local sVirtual = table_get_depth(res, {"daobiao", "map", iMapId, "virtual_game"})
    if sVirtual == "orgwar" then
        oPlayer.m_oStateCtrl:RefreshMapFlag()
    end
end

function CState:OnRemoveState(oPlayer)
    super(CState).OnRemoveState(self, oPlayer)
    oPlayer.m_oStateCtrl:RefreshMapFlag()
end


