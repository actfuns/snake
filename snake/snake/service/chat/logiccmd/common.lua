--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local extend = require "base.extend"

function Test(mRecord, mData)
    interactive.Response(mRecord.source, mRecord.session, {
        errcode = 0,
        data = {},
    })
end

function HandleChatMsg(mRecord, mData)
    local iChannel = mData["channel"]
    local iPid = mData["pid"]
    local sMsg = mData["msg"]
    global.oChatMgr:HandleChatMsg(iPid, iChannel, sMsg)
end

function CheckChatMsg(mRecord, mData)
    local iChannel = mData["channel"]
    local iPid = mData["pid"]
    local sMsg = mData["msg"]
    local iForbid = mData["forbid"]
    local bRet = global.oChatMgr:CheckChatMsg(iPid, iChannel, sMsg, iForbid)
    interactive.Response(mRecord.source, mRecord.session, {
        code = bRet and 1 or 0,
    })
end

function OnLogin(mRecord, mData)
    local iPid = mData["pid"]
    local bReEnter = mData["re_enter"]
    global.oChatMgr:OnLogin(iPid, bReEnter)
end
