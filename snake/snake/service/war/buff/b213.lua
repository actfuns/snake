local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))



function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior,oBuffMgr)
    oWarrior:AddFunction("ChangeCmd", self.m_ID, function (oWarrior,mCmd)
        local cmd = ChangeCmd(oWarrior,mCmd)
        return cmd
    end)
end

function CBuff:OnRemove(oAction,oBuffMgr)
    oAction:RemoveFunction("ChangeCmd", self.m_ID)
end

function ChangeCmd(oAction,mCmd)
    local iSelectWid = nil
    local mFriend = oAction:GetFriendList()
    
    for _,oWarrior in pairs(mFriend) do
        if oWarrior~=oAction and oWarrior:IsVisible(oAction, true) then
            iSelectWid = oWarrior:GetWid()
        end
    end

    local mNewCmd = {}
    mNewCmd.cmd = "normal_attack"
    mNewCmd.data = {}
    mNewCmd.data.action_wlist = oAction:GetWid()
    mNewCmd.data.select_wid = iSelectWid
    return mNewCmd
end