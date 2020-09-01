local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.friendctrl"))

CFriendCtrl = {}
CFriendCtrl.__index = CFriendCtrl
inherit(CFriendCtrl, basectrl.CFriendCtrl)

function CFriendCtrl:New(pid)
    local o = super(CFriendCtrl).New(self, pid)
    return o
end

function CFriendCtrl:SaveDb()
end

function CFriendCtrl:ConfigSaveFunc()
end

function CFriendCtrl:OnLogout(oPlayer)
end

function CFriendCtrl:SetRelation(iPid, iRelation)
end

function CFriendCtrl:ResetRelation(iPid, iRelation)
end

function CFriendCtrl:ExtendFriendCnt(iCnt)
end

function CFriendCtrl:DelFriend(iPid)
end

function CFriendCtrl:AddFriend(iPid, mExtra)
end

function CFriendCtrl:SetBothFriend(iPid)
end

function CFriendCtrl:ClearBothFriend(iPid)
end

function CFriendCtrl:ClearFriendDegree(iPid)
end

function CFriendCtrl:AddFriendDegree(iPid, iDegree)
end

function CFriendCtrl:Shield(iPid)
end

function CFriendCtrl:Unshield(iPid)
end

function CFriendCtrl:AddChat(iPid, sMessageId, sMsg)
end

function CFriendCtrl:DelChat(iPid, sMessageId)
end

function CFriendCtrl:EraseChat(iPid, sMessageId)
end

function CFriendCtrl:ChangePushConfig(iChatPush)
end

function CFriendCtrl:ChangeFriendSysConfig(iRefuseToggle, iVerifyToggle, iStrangerMsgToggle)
end

function CFriendCtrl:AddVerifyApply(iPid, sName, sMsg)
end

function CFriendCtrl:DelVerifyApply(iPid)
end

function CFriendCtrl:SetVerifyRefused(iFlag)
end

function CFriendCtrl:SetMentoringCD(iTime)
end

