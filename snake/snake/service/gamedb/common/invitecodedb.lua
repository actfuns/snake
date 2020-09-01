--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sInviteCodeTableName = "invitecode"

function InsertAccountInviteCode(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Insert(sInviteCodeTableName, mData)
end

function GetAcountInviteCode(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sInviteCodeTableName, {channel = mCond.channel, account = mCond.account}, {invitecode = true})
    local ret
    if m then
        ret = {invitecode = m.invitecode}
    else
        ret = {}
    end
    return ret
end
