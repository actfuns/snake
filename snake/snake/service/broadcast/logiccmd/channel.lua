--import module
local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local teamchannel = import(service_path("teamchannel"))
local worldchannel = import(service_path("worldchannel"))
local friendfocuschannel = import(service_path("friendfocuschannel"))
local orgchannel = import(service_path("orgchannel"))
local interfacechannel = import(service_path("interfacechannel"))
local pubteamchannel = import(service_path("pubteamchannel"))

function SetupChannel(mRecord, mData)
    local iPid = mData.pid
    local mInfo = mData.info
    local lChannelList = mData.channel_list or {}

    local mChannelInfo = {}
    for _, v in ipairs(lChannelList) do
        local iType, iId, bFlag = table.unpack(v)
        if not mChannelInfo[iType] then
            mChannelInfo[iType] = {}
        end
        mChannelInfo[iType][iId] = bFlag
    end

    for k, v in pairs(mChannelInfo) do
        local o1 = global.mChannels[k]
        local lDel = {}
        if o1 then
            for k2, v2 in pairs(v) do
                local o2 = o1[k2]
                if not o2 then
                    if k == gamedefines.BROADCAST_TYPE.WORLD_TYPE then
                        o2 =  worldchannel.NewWorldChannel()
                    elseif k == gamedefines.BROADCAST_TYPE.TEAM_TYPE then
                        o2 = teamchannel.NewTeamChannel()
                    elseif k == gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE then
                        o2 = friendfocuschannel.NewFriendFocusChannel()
                    elseif k == gamedefines.BROADCAST_TYPE.ORG_TYPE then
                        o2 = orgchannel.NewOrgChannel()
                    elseif k == gamedefines.BROADCAST_TYPE.INTERFACE_TYPE then
                        o2 = interfacechannel.NewInterfaceChannel()
                    elseif k == gamedefines.BROADCAST_TYPE.PUB_TEAM_TYPE then
                        o2 = pubteamchannel.NewPubTeamChannel()
                    end
                    o1[k2] = o2
                end
                if o2 then
                    if v2 then
                        o2:Add(iPid, mInfo)
                    else
                        o2:Del(iPid)
                    end
                    if o2:GetAmount() <= 0 then
                        table.insert(lDel, k2)
                    end
                end
            end
            for _, id in ipairs(lDel) do
                if o1[id] then
                    baseobj_delay_release(o1[id])
                end
                o1[id] = nil
            end
        end
    end
end

function SendChannel(mRecord, mData)
    local iType = mData.type
    local iId = mData.id
    local o = global.mChannels[iType][iId]
    if o then
        o:Send(mData.message, mData.data, mData.exclude)
    end
end

function SendChannel2Targets(mRecord, mData)
    local iType = mData.type
    local iId = mData.id
    local o = global.mChannels[iType][iId]
    if o then
        o:Send2Targets(mData.message, mData.data, mData.targets)
    end
end

function SendPubTeamChannel(mRecord, mData)
    local o = global.mChannels[gamedefines.BROADCAST_TYPE.PUB_TEAM_TYPE][1]
    if o then
        o:Send(mData.message, mData.data, mData.args)
    end        
end
