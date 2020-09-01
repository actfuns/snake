--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"
local interactive = require "base.interactive"


function GSSetOpenState(mRecord, mData)
    local server_key = mData.server_key
    local status = mData.status

    local oStatusMgr = global.oStatusMgr
    oStatusMgr:SetGSStatus(server_key, status)
end

function GetServerList(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local br, m = safe_call(oSetterMgr.GetServerList, oSetterMgr)
    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function SaveOrUpdateServer(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local br, m = safe_call(oSetterMgr.SaveOrUpdateServer, oSetterMgr, mData)
    local mRet = {}
    if br then
        mRet = {errcode=0, data={}}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function DeleteServer(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local ids = mData["ids"]
    local br, m = safe_call(oSetterMgr.DeleteServer, oSetterMgr, ids)

    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function SaveOrUpdateShenhe(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local br, m = safe_call(oSetterMgr.SaveOrUpdateShenhe, oSetterMgr, mData)

    local mRet = {}
    if br then
        mRet = {errcode=0}
    else
        mRet = {errcode=1}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function GetWhiteAccountList(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local br, m = safe_call(oSetterMgr.GetWhiteAccountList, oSetterMgr)

    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function SaveWhiteAccount(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local mArgs = mData["data"]
    local br, m = safe_call(oSetterMgr.SaveWhiteAccount, oSetterMgr, mArgs)

    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function DeleteWhiteAccount(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local ids = mData["ids"]
    local br, m = safe_call(oSetterMgr.DeleteWhiteAccount, oSetterMgr, ids)

    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function SaveOrUpdateNotice(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    oSetterMgr:SaveOrUpdateNotice(mData)
end

function GetNoticeList(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local br, m = safe_call(oSetterMgr.GetNoticeList, oSetterMgr)
    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function DeleteNotice(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    oSetterMgr:DeleteNotice(mData["ids"])
end

function PublishNotice(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    oSetterMgr:PublishNotice(mData["ids"])
end

function GetChannelList(mRecord, mData)
    local oSetterMgr = global.oSetterMgr
    local br, m = safe_call(oSetterMgr.GetChannelList, oSetterMgr)
    local mRet = {}
    if br then
        mRet = {errcode=0, data=m}
    else
        mRet = {errcode=1, data={}}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet) 
end

function SyncServerStatus(mRecord, mData)
    global.oSetterMgr:SetServerStatus(mData)

    interactive.Request(".router_s2", "common", "GetServerStatus", nil,
    function(mRecord1, mData1)
        local mResult = {
            result = global.oSetterMgr:PackServerStatus(mData1.result)
        }
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mResult) 
    end)
end


ForwardCmd = {}
function ForwardCmd.GetSetterConfig(mData)
    return global.oSetterMgr:GetSetterConfig(mData.server_key, mData.ver)
end 

function ForwardCmd.SaveBlackIp(mData)
    global.oSetterMgr:SaveBlackIp(mData)
end

function ForwardCmd.GetBlackIpList(mData)
    return global.oSetterMgr:GetBlackIpList(mData)
end

function ForwardCmd.DeleteBlackIp(mData)
    global.oSetterMgr:DeleteBlackIp(mData.ids)
end

function ForwardCmd.GetBlackAccountList(mData)
    return global.oSetterMgr:GetBlackAccountList()
end

function ForwardCmd.SaveBlackAccount(mData)
    global.oSetterMgr:SaveBlackAccount(mData)
end

function ForwardCmd.DeleteBlackAccount(mData)
    global.oSetterMgr:DeleteBlackAccount(mData.ids)
end

function Forward(mRecord, mData)
    local sCmd = mData["cmd"]
    local mArgs = mData["data"]
    
    local sFunc = ForwardCmd[sCmd]
    local mRet = {}
    if sFunc then
        local br, mr = safe_call(sFunc, mArgs)
        if br then
            mRet = {errcode = 0, data = mr}
        else
            mRet = {errcode = 1, errmsg = "call error"}
        end
    else
        mRet = {errcode = 2, errmsg = "not find function"}
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end
