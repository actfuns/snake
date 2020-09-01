--import module

local global = require "global"
local skynet = require "skynet"

function C2GSApplyAddFriend(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:AddFriend(oPlayer, mData.pid)
end

function C2GSApplyDelFriend(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:DelFriend(oPlayer, mData.pid)
end

function C2GSChatTo(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:ChatToFriend(oPlayer, mData.pid, mData.message_id, mData.msg, mData.forbid)    
end

function C2GSAckChatFrom(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:AckChatFrom(oPlayer, mData.pid, mData.message_id)   
end

function C2GSFindFriend(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    local iPid = mData.pid
    local sName = mData.name
    if iPid and iPid ~= 0 then
        oFriendMgr:FindFriendByPid(oPlayer, iPid)
    else
        oFriendMgr:FindFriendByName(oPlayer, sName)
    end
end

function C2GSQueryFriendProfile(oPlayer, mData)
    if is_ks_server() then return end

    local oFriendMgr = global.oFriendMgr
    local lPidList = mData.pid_list or {}
    if #lPidList > 0 then
        oFriendMgr:QueryFriendProfile(oPlayer, lPidList)
    end
end

function C2GSFriendShield(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    local iPid = mData.pid
    if iPid and iPid ~= 0 then
        oFriendMgr:Shield(oPlayer, iPid)
    end
end

function C2GSFriendUnshield(oPlayer, mData)
    local oFriendMgr = global.oFriendMgr
    local iPid = mData.pid
    if iPid and iPid ~= 0 then
        oFriendMgr:Unshield(oPlayer, iPid)
    end
end

function C2GSSendFlower(oPlayer, mData)
    local iPid = mData.pid
    local iFlower = mData.type
    local iAmount = mData.amount
    local sBless = mData.bless
    local iSysBless = mData.sys_bless
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:SendFlower(oPlayer:GetPid(), iPid, iFlower, iAmount, sBless, iSysBless)
end

function C2GSOpenSendFlowerUI(oPlayer, mData)
    local iPid = mData.pid
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:OpenSendFlowerUI(oPlayer, iPid)
end

function C2GSVerifyFriend(oPlayer, mData)
    local iPid = mData.pid
    local sVerifyMsg = mData.msg
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:VerifyFriend(oPlayer, iPid, sVerifyMsg)
end

function C2GSVerifyFriendComfirm(oPlayer, mData)
    local iResult = mData.result
    local iPid = mData.pid
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:VerifyFriendConfirm(oPlayer, iResult, iPid)
end

function C2GSQueryPlayerProfile(oPlayer, mData)
    if is_ks_server() then return end

    local oFriendMgr = global.oFriendMgr
    local lPidList = mData.pid_list or {}
    if #lPidList > 0 then
        oFriendMgr:QueryPlayerProfile(oPlayer, lPidList,mData.flag)
    end
end
