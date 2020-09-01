--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))


function NewInterfaceMgr(...)
    return CInterfaceMgr:New(...)
end

CInterfaceMgr = {}
CInterfaceMgr.__index = CInterfaceMgr
inherit(CInterfaceMgr,logic_base_cls())

function CInterfaceMgr:New()
    local o = super(CInterfaceMgr).New(self)
    o.m_mInterface = {}
    return o
end

function CInterfaceMgr:OnLogin(oPlayer, bReEnter)
    local iOldType = self:Get(oPlayer)
    if iOldType then
        self:Close(oPlayer, iOldType)
    end
end

function CInterfaceMgr:OnLogout(oPlayer)
    local iOldType = self:Get(oPlayer)
    if iOldType then
        self:Close(oPlayer, iOldType)
    end
end

function CInterfaceMgr:OnDisconnected(oPlayer)
    local iOldType = self:Get(oPlayer)
    if iOldType then
        self:Close(oPlayer, iOldType)
    end
end

function CInterfaceMgr:Get(oPlayer)
    return self.m_mInterface[oPlayer:GetPid()]
end

function CInterfaceMgr:Open(oPlayer, iType)
    local iPid = oPlayer:GetPid()
    self.m_mInterface[iPid] = iType

    local mRole = {
        pid = iPid, 
    }
    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = iPid,
        channel_list = {
            {gamedefines.BROADCAST_TYPE.INTERFACE_TYPE, iType, true},
        },
        info = mRole,
    })
end

function CInterfaceMgr:Close(oPlayer, iType)
    local iPid = oPlayer:GetPid()
    local iOldType = self:Get(oPlayer)

    if iOldType == iType then
        self.m_mInterface[iPid] = nil

        local mRole = {
            pid = iPid, 
        }
        interactive.Send(".broadcast", "channel", "SetupChannel", {
            pid = iPid,
            channel_list = {
                {gamedefines.BROADCAST_TYPE.INTERFACE_TYPE, iType, false},
            },
            info = mRole,
        })
    end
end

function CInterfaceMgr:ClientOpen(oPlayer, iType)
    local iOldType = self:Get(oPlayer)
    if iOldType then
        self:Close(oPlayer, iOldType)
    end
    self:Open(oPlayer, iType)
end

function CInterfaceMgr:ClientClose(oPlayer, iType)
    self:Close(oPlayer, iType)
end

-- 帮派响应列表界面的响应人数刷新
function CInterfaceMgr:RefreshOrgRespond(mNet)
    self:RefreshInterface(gamedefines.INTERFACE_TYPE.ORG_RESPOND_TYPE, "GS2CRefreshRespond", mNet)
end

function CInterfaceMgr:RefreshBaikeCurRank(mNet)
    self:RefreshInterface(gamedefines.INTERFACE_TYPE.BAIKE_MAINUI_TYPE, "GS2CBaikeCurRank", mNet)
end

function CInterfaceMgr:RefreshInterface(iType, sMsg, mNet)
    local mData = {
        message = sMsg,
        type = gamedefines.BROADCAST_TYPE.INTERFACE_TYPE,
        id = iType,
        data = mNet,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end
