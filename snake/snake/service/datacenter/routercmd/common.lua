--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"

function TestRouterSend(mRecord, mData)
    print("lxldebug datacenter TestRouterSend")
    print("show record")
    print(mRecord)
    print("show data")
    print(#mData.b)
end

function TestRouterRequest(mRecord, mData)
    print("lxldebug datacenter TestRouterRequest")
    print("show record")
    print(mRecord)
    print("show data")
    print(#mData.b)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 1,
    })
end

function TryCreateRole(mRecord, mData)
    local sServerTag = mData.server
    local sBornServer = mData.born_server
    local sAccount = mData.account
    local iChannel = mData.channel
    local mInfo = {
        name = mData.name,
        school = mData.school,
        icon = mData.icon,
        platform = mData.platform,
    }

    local oDataCenter = global.oDataCenter
    oDataCenter:TryCreateRole(sServerTag, sBornServer, sAccount, iChannel, mInfo, function(iNewId)
        if iNewId then
            router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
                errcode = 0,
                id = iNewId,
            })
        else
            router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
                errcode = 1,
            })
        end
    end)
end

function UpdateRoleInfo(mRecord, mData)
    local iPid = mData.pid
    local mInfo = {
        icon = mData.icon,
        grade = mData.grade,
        school = mData.school,
        name = mData.name,
        login_time = mData.login_time,
        no_login = mData.no_login
    }

    local oDataCenter = global.oDataCenter
    oDataCenter:UpdateRoleInfo(iPid, mInfo)
end

function GetCbtPayInfo(mRecord, mData)
    local sAccount = mData.account
    local iChannel = mData.channel
    local mCbtPay = global.oCbtPayMgr:GetCbtPayInfo(sAccount, iChannel)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        cbtpay = mCbtPay,
    })
end

function TryGetReturnReward(mRecord, mData)
    local sAccount = mData.account
    local iChannel = mData.channel
    local iPid = mData.pid
    local sName = mData.name
    local iKey = mData.key
    local iRet, mCbtPay = global.oCbtPayMgr:TryGetReturnReward(sAccount, iChannel, iPid, sName, iKey)

    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = iRet,
        cbtpay = mCbtPay,
    })
end

function TryGetFreeGift(mRecord, mData)
    local sAccount = mData.account
    local iChannel = mData.channel
    local iPid = mData.pid
    local sName = mData.name
    local iRet, mCbtPay = global.oCbtPayMgr:TryGetFreeGift(sAccount, iChannel, iPid, sName)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = iRet,
        cbtpay = mCbtPay,
    })
end

function GmSetCbtData(mRecord, mData)
    local sAccount = mData.account
    local iChannel = mData.channel
    local iPayCount = mData.paycount
    local mCbtPay = global.oCbtPayMgr:GmSetCbtData(sAccount, iChannel, iPayCount)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        cbtpay = mCbtPay,
    })
end

function OnGSDeleteRole(mRecord, mData)
    local iPid = mData.pid
    local oDataCenter = global.oDataCenter
    oDataCenter:OnGSDeleteRole(iPid)
end

function RevertRole(mRecord, mData)
    local oDataCenter = global.oDataCenter
    oDataCenter:RevertRole(mData.pid)
end

function GetRoleListByAccount(mRecord, mData)
    local sAccount = mData.account
    local iChannel = mData.channel
    local iPlatform = mData.platform

    local oDataCenter = global.oDataCenter
    local lRoleList = oDataCenter:GetRoleListByAccount(sAccount, iChannel, iPlatform)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        roles = lRoleList,
    })
end
