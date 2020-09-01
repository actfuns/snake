--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))

local CHANNEL_TYPE = gamedefines.CHANNEL_TYPE

function NewNotifyMgr(...)
    return CNotifyMgr:New(...)
end


CNotifyMgr = {}
CNotifyMgr.__index = CNotifyMgr
inherit(CNotifyMgr,logic_base_cls())

function CNotifyMgr:New()
    local o = super(CNotifyMgr).New(self)
    return o
end

function CNotifyMgr:OnLogin(oPlayer, bReEnter)
    local mRole = {
        pid = oPlayer:GetPid(), 
    }

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.WORLD_TYPE, 1, true},
        },
        info = mRole,
    })

    local iTeamID = oPlayer:TeamID()
    if iTeamID then
        interactive.Send(".broadcast", "channel", "SetupChannel", {
            pid = oPlayer:GetPid(),
            channel_list = {
                {gamedefines.BROADCAST_TYPE.TEAM_TYPE, iTeamID, true},
            },
            info = mRole,
        })
    end
    self:SetupPubTeamChannel(oPlayer, true)
end

function CNotifyMgr:SetupPubTeamChannel(oPlayer, bSetup)
    if not oPlayer then return end

    local mRole = {
        pid = oPlayer:GetPid(), 
        teamid = oPlayer:TeamID(),
        grade = oPlayer:GetGrade(),
    }

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.PUB_TEAM_TYPE, 1, bSetup},
        },
        info = mRole,
    })
end

function CNotifyMgr:OnLogout(oPlayer)
    local mRole = {
        pid = oPlayer:GetPid(), 
    }

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.WORLD_TYPE, 1, false},
        },
        info = mRole,
    })

    local iTeamID = oPlayer:TeamID()
    if iTeamID then
        interactive.Send(".broadcast", "channel", "SetupChannel", {
            pid = oPlayer:GetPid(),
            channel_list = {
                {gamedefines.BROADCAST_TYPE.TEAM_TYPE, iTeamID, false},
            },
            info = mRole,
        })
    end
    self:SetupPubTeamChannel(oPlayer, false)
end

function CNotifyMgr:OnDisconnected(oPlayer)
    local mRole = {
        pid = oPlayer:GetPid(), 
    }

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.WORLD_TYPE, 1, false},
        },
        info = mRole,
    })

    local iTeamID = oPlayer:TeamID()
    if iTeamID then
        interactive.Send(".broadcast", "channel", "SetupChannel", {
            pid = oPlayer:GetPid(),
            channel_list = {
                {gamedefines.BROADCAST_TYPE.TEAM_TYPE, iTeamID, false},
            },
            info = mRole,
        })
    end
    self:SetupPubTeamChannel(oPlayer, false)
end

function CNotifyMgr:Notify(iPid, sMsg)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CNotify", {
            cmd = sMsg,
        })
    end
end

function CNotifyMgr:ItemNotify(iPid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CItemNotify", mNet)
    end
end

function CNotifyMgr:SummonNotify(iPid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CSummonNotify", mNet)
    end
end

function CNotifyMgr:UIEffectNotify(iPid, sEffect, lMsg)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CUIEffectNotify", {
            effect = sEffect,
            cmds = lMsg,
        })
    end
end

function CNotifyMgr:SendWorldChat(sMsg, mRoleInfo, mExclude)
    local mNet = {
        type = gamedefines.CHANNEL_TYPE.WORLD_TYPE,
        cmd = sMsg,
        role_info = mRoleInfo,
    }
    local mData = {
        message = "GS2CChat",
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = mNet,
        exclude = mExclude,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CNotifyMgr:SendSysChat(sMsg, iTag, iHorse, mExclude)
    local mNet = {
        content = sMsg,
        tag_type = iTag, 
        horse_race = iHorse,
    }
    local mData = {
        message = "GS2CSysChat",
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = mNet,
        exclude = mExclude,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CNotifyMgr:SendTeamChat(sMsg, iID, mRole, mExclude)
    local mNet = {
        cmd = sMsg,
        type = gamedefines.CHANNEL_TYPE.TEAM_TYPE,
        role_info = mRole,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CChat",
        id = iID,
        type = gamedefines.BROADCAST_TYPE.TEAM_TYPE,
        data = mNet,
        exclude = mExclude,
    })
end

function CNotifyMgr:SendOrgChat(sMsg, iOrgID, mRole, mExclude)
    local mNet = {
        cmd = sMsg,
        type = gamedefines.CHANNEL_TYPE.ORG_TYPE,
        role_info = mRole,
    }

    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CChat",
        id = iOrgID,
        type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
        data = mNet,
        exclude = mExclude,
    })
end

function CNotifyMgr:SendOrgBulletBarrage(sMsg, iOrgID, sName, mExclude)
    local mNet = {
        orgid = iOrgID,
        name = sName,
        msg = sMsg,
    }

    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2COrgBulletBarrage",
        id = iOrgID,
        type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
        data = mNet,
        exclude = mExclude,
    })
end

function CNotifyMgr:SendOrgFlag(iOrgID, mData, mExclude)
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2COrgFlag",
        id = iOrgID,
        type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
        data = mData,
        exclude = mExclude,
    })
end

function CNotifyMgr:SendOrgFlag2Targets(iOrgID, mData, mTarget)
    interactive.Send(".broadcast", "channel", "SendChannel2Targets", {
        message = "GS2COrgFlag",
        id = iOrgID,
        type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
        data = mData,
        targets = mTarget,
    })
end

function CNotifyMgr:SendGS2Org(iOrgID, sGsMsg, mData, mExclude)
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = sGsMsg,
        id = iOrgID,
        type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
        data = mData,
        exclude = mExclude,
    })
end

function CNotifyMgr:SendChuanYin(iType, sMsg, mRoleInfo)
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CChuanYin",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {cmd = sMsg, type = iType, role_info=mRoleInfo}
    })
end

function CNotifyMgr:BroadcastOrgsMembersInScene(sNetMessage, mNet, fCheckFunc)
    local mOrgs = global.oOrgMgr:GetNormalOrgs()
    for iOrgId, oOrg in pairs(mOrgs) do
        self:BroadcastOneOrgMembersInScene(oOrg, sNetMessage, mNet, fCheckFunc)
    end
end

function CNotifyMgr:BroadcastOneOrgMembersInScene(oOrg, sNetMessage, mNet, fCheckFunc)
    local iScene = oOrg:GetOrgSceneID()
    local oScene = global.oSceneMgr:GetScene(iScene)
    local iOrgId = oOrg:OrgID()
    -- oScene:QueryRemote("all_players", {}, function (mRecord, mData)
    --     local m = mData.data
    --     if not m then
    --         return
    --     end
    --     local lPids = m.pids
    --     if #lPids <= 0 then
    --         return
    --     end
    --     local mPids = list_key_table(lPids, true)
    --     if fCheckFunc then
    --         mPids = fCheckFunc(mPids)
    --     end
    --     self:OrgMembersInSceneBroadcast(mPids, iOrgId, sNetMessage, mNet)
    -- end)
    local lPids = oScene:GetAllPlayerIds()
    local mPids = list_key_table(lPids, true)
    if fCheckFunc then
        mPids = fCheckFunc(mPids)
    end
    if next(mPids) then
        self:OrgMembersInSceneBroadcast(mPids, iOrgId, sNetMessage, mNet)
    end
end

function CNotifyMgr:OrgMembersInSceneBroadcast(mPids, iOrgId, sNetMessage, mNet)
    -- 不用判断在帮派场景内，因为广播是对于帮派频道而发的
    local mNet = mNet
    local mData = {
        message = sNetMessage,
        id = iOrgId,
        type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
        data = mNet,
        targets = mPids,
    }
    interactive.Send(".broadcast", "channel", "SendChannel2Targets", mData)
end

function CNotifyMgr:WorldBroadcast(sNetMessage, mNet, mExclude)
    local mData = {
        message = sNetMessage,
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = mNet,
        exclude = mExclude or {},
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CNotifyMgr:SendPubTeamMsg(sMsg, mRole, mArgs)
    local mNet = {
        cmd = sMsg,
        type = gamedefines.CHANNEL_TYPE.TEAM_TYPE,
        role_info = mRole,
    }
    self:PubTeamBroadcast("GS2CChat", mNet, mArgs)
end

function CNotifyMgr:PubTeamBroadcast(sNetMessage, mNet, mArgs)
    local mData = {
        message = sNetMessage,
        data = mNet,
        args = mArgs,
    }
    interactive.Send(".broadcast", "channel", "SendPubTeamChannel", mData)
end
