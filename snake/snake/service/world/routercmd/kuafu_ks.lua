--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"
local record = require "public.record" 


------------------gs 2 ks-----------------------------------
function GS2KSRemoteConfirm(mRecord, mData)
    local iPid = mData.pid 
    local mInfo = mData.info
    global.oWorldMgr:RemoteGSConfirm(iPid, mRecord.srcsk, mInfo,
    function(mArgs)
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mArgs)
    end)
end

function GS2KSPushMail(mRecord, mData)
    local iPid = mData.pid
    local mMail = mData.mail
    local iMail = mData.mailid
    global.oMailMgr:AddGSMail(iPid, iMail, mMail)
end

function GS2KSLogoutPlayer(mRecord, mData)
    local iPid = mData.pid
    local iCode = mData.code
    global.oWorldMgr:HandleLogoutPlayer(iPid, iCode)
end

function GS2KSHuodongCmd(mRecord, mData)
    local sHdName = mData.hdname
    local sOrder = mData.order
    local mArgs = mData.data
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong(sHdName)
    if not oHuodong then
        record.warning("ks GS2KSHuodongCmd not find huodong "..sHdName)        
        return
    end
    oHuodong:TestOp(sOrder, mArgs)
end

