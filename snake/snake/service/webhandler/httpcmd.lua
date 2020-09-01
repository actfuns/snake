--import module
local global = require "global"
local skynet = require "skynet"
local cjson = require "cjson"
local interactive = require "base.interactive"
local record = require "public.record"
local httpuse = require "public.httpuse"

local serverdefines = require "public.serverdefines"

Method = {}

Method.backend = {
    POST = true
}
function backend(oHttp)
    local br, mData = pcall(cjson.decode, oHttp:GetBody())
    if not br then
        record.error("httpcmd backend error body null")
        oHttp:Finish()
        return
    end
    local sModule = mData.module
    local sCmd = mData.cmd
    local mArgs = mData.args
    if sModule and sCmd then
        interactive.Request(".backend", sModule, sCmd, mArgs, function (mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    else
        oHttp:Finish()
    end
end

local function get_loginverify_service(sToken)
    local iNo
    if sToken then
        iNo = string.match(sToken, "%w+_(%d+)")
    else
        iNo = math.random(1, VERIFY_SERVICE_COUNT)
    end
    return string.format(".loginverify%s",iNo)
end

Method.loginverify = {
    POST = true
}
function loginverify(oHttp)
    local sMethod = oHttp:GetAddress()[1]
    local br, mArgs = pcall(cjson.decode, oHttp:GetBody())
    if not br then
        record.error(string.format("httpcmd loginverify error body null Method:%s", sMethod))
        oHttp:Finish()
        return
    end
    if sMethod == "check_sdk_open" then
        local sServiceName = get_loginverify_service()
        mArgs.ip = oHttp.m_sRemoteIp
        interactive.Request(sServiceName, "common", "ClientCheckSdkOpen", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    elseif sMethod == "verify_account" then
        local sServiceName = get_loginverify_service()
        mArgs.ip = oHttp.m_sRemoteIp
        interactive.Request(sServiceName, "common", "ClientVerifyAccount", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    elseif sMethod == "query_role_list" then
        local sServiceName = get_loginverify_service(mArgs.token)
        interactive.Request(sServiceName, "common", "ClientQueryRoleList", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    elseif sMethod == "qrcode_scan" then
        local sServiceName = get_loginverify_service(mArgs.account_token)
        interactive.Request(sServiceName, "common", "ClientQRCodeScan", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    elseif sMethod == "qrcode_login" then
        local sServiceName = get_loginverify_service(mArgs.account_token)
        interactive.Request(sServiceName, "common", "ClientQRCodeLogin", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    elseif sMethod == "delete_role" then
        local sServiceName = get_loginverify_service(mArgs.account_token)
        interactive.Request(sServiceName, "common", "ClientDeleteRole", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    else
        oHttp:Finish()
    end
end

Method.qrpay = {
    POST = true
}
function qrpay(oHttp)
    local sMethod = oHttp:GetAddress()[1]
    local br, mArgs = pcall(cjson.decode, oHttp:GetBody())
    if not br then
        record.error(string.format("httpcmd qrpay error body null Method:%s", sMethod))
        oHttp:Finish()
        return
    end
    if sMethod == "scan" then
        local service = string.format(".pay%s", math.random(1, PAY_SERVICE_COUNT))
        interactive.Request(service, "common", "ClientQrpayScan", mArgs,
        function(mRecord, mData)
            local sRes = cjson.encode(mData)
            oHttp:Response(sRes)
            oHttp:Finish()
        end)
    else
        oHttp:Finish()
    end
end

Method.paycb = {
    POST = true
}
function paycb(oHttp)
    local mBody = httpuse.content_kv(oHttp:GetBody())
    if mBody and next(mBody) then
        local service = string.format(".pay%s", math.random(1, PAY_SERVICE_COUNT))
        interactive.Request(service, "common", "PayCallback", mBody,
        function(mRecord, mData)
            oHttp:Response(mData.ret)
            oHttp:Finish()
        end)
    else
        record.error("httpcmd paycb error body null")
        oHttp:Finish()
    end
end

Method.clientlog = {
    POST = true
}
function clientlog(oHttp)
    local br, mArgs = pcall(cjson.decode, oHttp:GetBody())
    if not br then
        record.error("httpcmd clientlog error body null")
        oHttp:Finish()
        return
    end
    local sType = mArgs["logtype"]
    if not sType then
        -- interactive.Request(".backend", "analysis", "RecordClientLog", mArgs, function (mRecord, mData)
        --     local sRes = cjson.encode(mData)
        --     oHttp:Response(sRes)
        --     oHttp:Finish()
        -- end)
        oHttp:Response(cjson.encode({}))
        oHttp:Finish()
    elseif sType == "analylog" then
        local mLog = mArgs["data"]
        local sFileType = mArgs["analytype"]
        if sFileType then
            interactive.Send(".logfile", "common", "WriteData",  {sName = sFileType, data = mLog})
        else
            record.warning("not find　clientlog analytype")
        end
        if sFileType == "behavior" then
            interactive.Send(".logfile", "common", "WriteMtbi",  {sName = sFileType, data = mLog})
        end
        oHttp:Response(cjson.encode({}))
        oHttp:Finish()
    else
        oHttp:Finish()
    end
end
