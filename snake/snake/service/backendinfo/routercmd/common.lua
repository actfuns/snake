--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"
local extend = require "base.extend"


function GetHuoDongTagInfo(mRecord, mData)
    local oBackendMgr = global.oBackendMgr
    local mInfo = oBackendMgr:GetHuoDongTagInfo()
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        data = mInfo,
    })
end

function UpdateHuoDongTagInfo(mRecord, mData)
    local bSucc, sMsg = global.oBackendMgr:UpdateHuoDongTagInfo(mData)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = bSucc and 0 or 1,
        errmsg = sMsg,
        data = {},
    })
end

function GetForbinInfo(mRecord, mData)
    local oBackendMgr = global.oBackendMgr
    local mInfo = oBackendMgr:GetForbinInfo()
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        data = mInfo,
    })
end


function UpdateOrSaveForbinInfo(mRecord, mData)
    local oBackendMgr = global.oBackendMgr
    local bSucc, sMsg = oBackendMgr:UpdateOrSaveForbinInfo(mData)
    local iErrCode = bSucc and 0 or 1
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = iErrCode,
        errmsg = sMsg,
    })
end

function DeleteForbinInfo(mRecord, mData)
    local oBackendMgr = global.oBackendMgr
    oBackendMgr:DeleteForbinInfo(mData.ids)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
    })
end

function SetCustServInfo(mRecord, mData)
    global.oYunYingInfoMgr:SetCustServInfo(mData)
end

function GetYunYingChannelAllInfo(mRecord, mData)
    local mInfo = global.oYunYingInfoMgr:GetAllInfo()
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        data = mInfo,
        })
end

function GetSysSwitchInfoToBS(mRecord, mData)
    local mInfo = global.oYunYingInfoMgr:PackSysSwitchInfoToBS()
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        data = mInfo,
        })
end

function SetSysSwitchInfo(mRecord, mData)
    global.oYunYingInfoMgr:SetSysSwitchInfo(mData)
end
