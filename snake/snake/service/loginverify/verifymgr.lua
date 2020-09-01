--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"
local httpuse = require "public.httpuse"
local router = require "base.router"
local serverdefines = require "public.serverdefines"

local channelinfo = import(lualib_path("public.channelinfo"))
local urldefines = import(lualib_path("public.urldefines"))
local datactrl = import(lualib_path("public.datactrl"))
local serverinfo = import(lualib_path("public.serverinfo"))
local ipoperate = import(lualib_path("public.ipoperate"))
local analy = import(lualib_path("public.dataanaly"))


MAX_TOKEN_ID = 1000000
VALID_SECOND = 30 * 60

function NewVerifyMgr(...)
    local o = CVerifyMgr:New(...)
    return o
end

CVerifyMgr = {}
CVerifyMgr.__index = CVerifyMgr
inherit(CVerifyMgr, datactrl.CDataCtrl)

function CVerifyMgr:New(iServiceKey)
    local o = super(CVerifyMgr).New(self)
    o.m_ServiceKey = iServiceKey
    o.m_iDispatchMyTokenID = 0
    o.m_mValidLoginToken = {}
    return o
end

function CVerifyMgr:Init()
    self:Schedule()
end

function CVerifyMgr:DispatchMyToken()
    self.m_iDispatchMyTokenID = self.m_iDispatchMyTokenID + 1
    if self.m_iDispatchMyTokenID >= MAX_TOKEN_ID then
        self.m_iDispatchMyTokenID = 1
    end
    local iToken = get_time() * MAX_TOKEN_ID + self.m_iDispatchMyTokenID
    return string.format("%d_%d",iToken,self.m_ServiceKey)
end

function CVerifyMgr:Schedule()
    local f
    f = function()
        self:DelTimeCb("_CheckValidToken")
        self:AddTimeCb("_CheckValidToken", 10*60*1000, f)
        self:_CheckValidToken()
    end
    f()
end

function CVerifyMgr:_CheckValidToken()
    local lKey = {}
    for sToken, mData in pairs(self.m_mValidLoginToken) do
        if mData.time + VALID_SECOND < get_time() then
            table.insert(lKey, sToken)
        end
    end
    for _, sToken in ipairs(lKey) do
        self.m_mValidLoginToken[sToken] = nil
    end
end

function CVerifyMgr:KeepTokenAlive(sToken)
    local mData = self.m_mValidLoginToken[sToken]
    if not mData then
        return
    end
    mData.time = get_time()
end

function CVerifyMgr:VerifyMyToken(sToken)
    local mData = self.m_mValidLoginToken[sToken]
    if not mData then
        return nil
    end
    if mData.time + VALID_SECOND < get_time() then
        return nil
    else
        return mData
    end
end

function CVerifyMgr:GenerateMyToken(sAccount, iChannel, sCpsChannel, iPlatform, mOther)
    local sToken = self:DispatchMyToken()
    local mOtherCopy = table_copy(mOther)
    mOtherCopy.notice_ver = nil
    self.m_mValidLoginToken[sToken] = {
        account = sAccount,
        channel = iChannel,
        cps = sCpsChannel,
        platform = iPlatform,
        other = mOtherCopy,
        time = get_time()
    }
    return sToken
end

function CVerifyMgr:ClientVerifyAccount(sToken, iChannel, sDeviceId, sCpsChannel, sChannelUuid, iPlatform, mOther, endfunc)
    local mResult = {}
    if iChannel and iChannel ~= 0 then
        if not sToken or sToken == "" then
            endfunc({errcode = 1})
            return
        end
        self:SdkVerify(sToken, iChannel, sDeviceId, function (errcode, mAccount)
            self:SdkVerifyEnd(errcode, mAccount, iChannel, sChannelUuid, sCpsChannel, mResult, iPlatform, mOther, endfunc)
        end)
    else
        local iChannel = 0
        self:SdkVerifyEnd(0, {p=iChannel, uid=sChannelUuid}, iChannel, sChannelUuid, sCpsChannel, mResult, iPlatform, mOther, endfunc)
    end
end

function CVerifyMgr:SdkVerify(sToken, iChannel, sDeviceId, func)
    local iRequestId = get_time()
    local mParam = {
        sid = sToken,
        appId = global.oDemiSdk:GetAppId(),
        id = iRequestId,
        p = iChannel,
        deviceId = sDeviceId
    }
    mParam["sign"] = global.oDemiSdk:Sign(mParam)

    local sHost = urldefines.get_out_host()
    local sUrl = urldefines.get_demi_url("login_verify")
    local sParam = httpuse.mkcontent_kv(mParam)
    local mHeader = {}
    mHeader["Content-type"] = "application/x-www-form-urlencoded"
    httpuse.post(sHost, sUrl, sParam, function(body, header)
        self:_SdkVerify1(body, iChannel, sToken, func)
    end, mHeader)
end

function CVerifyMgr:_SdkVerify1(sBody, iChannel, sToken, func)
    local mRet = httpuse.content_json(sBody)
    if not next(mRet) then
        record.error("SdkVerify %s %s no response", iChannel, sToken)
        func(101)
        return
    end
    if mRet.code ~= 0 then
        record.info("SdkVerify %s %s retcode:%s, msg:%s", iChannel, sToken, mRet.code, mRet.msg)
        func(102)
        return
    end
    if not mRet.item or not next(mRet.item) then
        record.error("SdkVerify %s %s item nil", iChannel, sToken)
        func(103)
        return
    end
    func(0, mRet.item)
end

function CVerifyMgr:SdkVerifyEnd(errcode, mAccount, iChannel, sChannelUuid, sCpsChannel, mResult, iPlatform, mOther, endfunc)
    if errcode ~= 0 then
        endfunc({errcode = errcode})
        return
    else
        local sAccount = mAccount.uid
        mOther.account = sAccount
        mResult.token = self:GenerateMyToken(sAccount, iChannel, sCpsChannel, iPlatform, mOther)
        mResult.uid = sAccount
        self:RequestServerInfo(iChannel, iPlatform, sCpsChannel, mOther, function (errcode, mInfo)
            self:OnGetServerList(errcode, mInfo, sAccount, iChannel, iPlatform, mResult, mOther, endfunc)
        end)
    end
end

function CVerifyMgr:RequestServerInfo(iChannel, iPlatform, sCpsChannel, mOther, func)
    local mArgs = {
        channel = iChannel,
        platform = iPlatform,
        cps = sCpsChannel,
        version = mOther.notice_ver,
        area = mOther.area,
        ckey = mOther.ckey,
        cname = mOther.cname,
        startver = mOther.startver,
        ip = mOther.ip,
        account = mOther.account,
    }
    interactive.Request(".serversetter", "common", "GetClientServerList", mArgs, function (mRecord, mData)
        self:_RequestServerInfo1(mData, mArgs, func)
    end)
end

function CVerifyMgr:_RequestServerInfo1(mData, mArgs, func)
    if mData.errcode ~= 0 then
        record.error("RequestServerInfo err retcode:%s", mData.errcode)
        func(301)
        return
    end
    if not next(mData.data.serverInfoList) then
        record.info("RequestServerInfo err: no server %s", serialize_table(mArgs))
        func(302)
        return
    end
    func(0, mData.data)
end

function CVerifyMgr:OnGetServerList(errcode, mInfo, sAccount, iChannel, iPlatform, mResult, mOther, endfunc)
    if errcode ~= 0 then
        endfunc({errcode = errcode})
        return
    else
        mResult.server_info = mInfo
        local lServerList = {}
        for _, info in ipairs(mInfo.serverInfoList) do
            table.insert(lServerList, get_server_tag(info.linkserver))
        end
        local sDeviceId = mOther.device_id
        self:RequestRoleInfos(sAccount, iChannel, iPlatform, lServerList, sDeviceId, function (errcode, mRoles, iFirstRegister, iFirstRegisterDevice)
            self:OnGetRoleInfos(errcode, mRoles, iFirstRegister, iFirstRegisterDevice, mResult, endfunc)
        end)
    end
end

function CVerifyMgr:RequestRoleInfos(sAccount, iChannel, iPlatform, lServerList, sDeviceId, func)
    local lChannel = channelinfo.get_same_channels(iChannel)
    if not lChannel or not next(lChannel) or not lServerList or not next(lServerList) then
        func(0, {})
        return
    end
    interactive.Request(".datacenter", "common", "GetRoleList", {account=sAccount, channel=lChannel, platform=iPlatform, server=lServerList, device_id=sDeviceId},
        function (mRecord, mData)
            self:_RequestRoleInfos1(mRecord, mData, sAccount, lChannel, iPlatform, lServerList, func)
        end
    )
end

function CVerifyMgr:_RequestRoleInfos1(mRecord, mData, sAccount, lChannel, iPlatform, lServerList, func)
    if mData.errcode ~= 0 then
        record.error("RequestRoleInfos err account:%s, channel:%s, platform:%s, retcode:%s", sAccount, serialize_table(lChannel), iPlatform, serialize_table(lServerList), mData.errcode)
        func(201)
    else
        func(0, mData.roles, mData.first_register, mData.first_register_device)
    end
end

function CVerifyMgr:OnGetRoleInfos(errcode, mRoles, iFirstRegister, iFirstRegisterDevice, mResult, endfunc)
    if errcode ~= 0 then
        endfunc({errcode = errcode})
        return
    else
        safe_call(self.LogAccountInfo, self, mResult.token, iFirstRegister)
        mResult.role_list = mRoles
        mResult.first_register = iFirstRegister
        mResult.first_register_for_phone = iFirstRegisterDevice
        endfunc({errcode = 0, info = mResult})
    end
end

function CVerifyMgr:LogAccountInfo(sToken, iFirstRegister)
    local mAccount = self.m_mValidLoginToken[sToken]
    if not mAccount then return end

    local mOther = mAccount.other
    if not mOther then return end
    local mLog = {
        account_id = mAccount.account or "",
        ip = mOther.ip or "127.0.0.1",
        device_model = "",
        udid = mOther.device_id or "",
        os = "",
        version = mOther.startver or "",
        app_channel = mAccount.channel,
        sub_channel = mAccount.cps,
        server = "",
        plat = mAccount.platform,

    }
    if iFirstRegister and iFirstRegister > 0 then
        analy.log_data("RegisterAccount_1", mLog)    
    end
    analy.log_data("LoginAccount_1", mLog)    
end

function CVerifyMgr:ClientQueryRoleList(sToken, endfunc)
    local mAccountInfo = self:VerifyMyToken(sToken)
    if not mAccountInfo then
        endfunc({errcode = 202})
        return
    end
    local sAccount = mAccountInfo.account
    local iChannel = mAccountInfo.channel
    local iPlatform = mAccountInfo.platform
    local sCpsChannel = mAccountInfo.cps
    local mOther = mAccountInfo.other

    self:RequestServerInfo(iChannel, iPlatform, sCpsChannel, mOther, function (errcode, mInfo)
        self:_ClientQueryRoleList1(errcode, mInfo, sAccount, iChannel, iPlatform, mOther, endfunc)
    end)
end

function CVerifyMgr:_ClientQueryRoleList1(errcode, mInfo, sAccount, iChannel, iPlatform, mOther, endfunc)
    if errcode ~= 0 then
        endfunc({errcode = errcode})
        return
    else
        local lServerList = {}
        for _, info in ipairs(mInfo.serverInfoList) do
            table.insert(lServerList, get_server_tag(info.linkserver))
        end
        local sDeviceId = mOther.device_id
        self:RequestRoleInfos(sAccount, iChannel, iPlatform, lServerList, sDeviceId, function (errcode, mRoles)
            self:_ClientQueryRoleList2(errcode, mRoles, endfunc)
        end)
    end
end

function CVerifyMgr:_ClientQueryRoleList2(errcode, mRoles, endfunc)
    if errcode ~= 0 then
        endfunc({errcode = errcode})
        return
    else
        endfunc({errcode = 0, role_list = mRoles})
    end
end

function CVerifyMgr:ClientQRCodeScan(sAccountToken, sCodeToken, endfunc)
    if not self:VerifyMyToken(sAccountToken) then
        record.info("ClientQRCodeScan err: no such sAccountToken:%s", sAccountToken)
        endfunc(501)
        return
    end
    if not sCodeToken then
        record.info("ClientQRCodeScan err: no sCodeToken")
        endfunc(502)
        return
    end

    local qrc_key = string.match(sCodeToken, "^(%w+)%-%d+")
    local iPort = tonumber(string.match(qrc_key, "%a+(%d+)"))
    local sQrcPorts = serverdefines.get_qrcode_ports()
    local lQrcPorts = split_string(sQrcPorts, ",", tonumber)
    if not table_in_list(lQrcPorts,iPort)  then
        record.error("ClientQRCodeScan err: no such qrc_key:%s %s", sCodeToken, qrc_key)
        endfunc(503)
        return
    end
    self:KeepTokenAlive(sAccountToken)
    router.Request("cs", string.format(".%s",qrc_key) , "common", "ScanQRCode", {
        code_token = sCodeToken,
    }, function (mRecord, mData)
        self:_ClientQRCodeScan1(mData, endfunc)
    end)
end

function CVerifyMgr:_ClientQRCodeScan1(mRet, func)
    if mRet.errcode ~= 0 then
        record.error("ClientQRCodeScan err retcode:%s", mRet.errcode)
        func(504)
        return
    end
    func(0)
end

function CVerifyMgr:ClientQRCodeLogin(sAccountToken, sCodeToken, mOther, mTransferInfo, endfunc)
    local mAccountInfo = self:VerifyMyToken(sAccountToken)
    if not mAccountInfo then
        record.info("ClientQRCodeLogin err: no such sAccountToken:%s", sAccountToken)
        endfunc(401)
        return
    end

    local sAccount = mAccountInfo.account
    local iChannel = mAccountInfo.channel
    local sCpsChannel = mAccountInfo.cps
    local iPlatform = mAccountInfo.platform
    local mOther = mAccountInfo.other
    
    local func
    func = function (mInfo)
        self:_ClientQRCodeLogin1(sCodeToken, mTransferInfo, mInfo, endfunc)
    end
    local mResult = {
        token = self:GenerateMyToken(sAccount, iChannel, mAccountInfo.cps, iPlatform, mOther)
    }
    self:RequestServerInfo(iChannel, iPlatform, sCpsChannel, mOther, function (errcode, mInfo)
        self:OnGetServerList(errcode, mInfo, sAccount, iChannel, iPlatform, mResult, mOther, func)
    end)
end

function CVerifyMgr:_ClientQRCodeLogin1(sCodeToken, mTransferInfo, mInfo, endfunc)
    if mInfo.errcode ~= 0 then
        endfunc(mInfo.errcode)
        return
    end

    local qrc_key = string.match(sCodeToken, "^(%w+)%-%d+")
    local iPort = tonumber(string.match(qrc_key, "%a+(%d+)"))
    local sQrcPorts = serverdefines.get_qrcode_ports()
    local lQrcPorts = split_string(sQrcPorts, ",", tonumber)
    if not table_in_list(lQrcPorts,iPort)  then
        record.error("_ClientQRCodeLogin1 err: no such qrc_key:%s %s", sCodeToken, qrc_key)
        endfunc(402)
        return
    end

    router.Request("cs", string.format(".%s",qrc_key) , "common", "CSSendAccountInfo", {
        code_token = sCodeToken,
        acount_info = httpuse.mkcontent_json(mInfo),
        transfer_info = httpuse.mkcontent_json(mTransferInfo),
    }, function (mRecord, mData)
        self:_ClientQRCodeLogin2(mData, endfunc)
    end)
end

function CVerifyMgr:_ClientQRCodeLogin2(mRet, func)
    if mRet.errcode ~= 0 then
        record.error("_ClientQRCodeLogin2 err retcode:%s", mRet.errcode)
        func(403)
        return
    end
    func(0)
end

function CVerifyMgr:ClientDeleteRole(sAccountToken, iPid, func)
    local mAccountInfo = self:VerifyMyToken(sAccountToken)
    if not mAccountInfo then
        record.info("ClientDeleteRole err: no such sAccountToken:%s", sAccountToken)
        func(501)
        return
    end
    local sAccount = mAccountInfo.account
    local iChannel = mAccountInfo.channel
    interactive.Request(".datacenter", "common", "DeleteRole", {account=sAccount, channel=iChannel, pid=iPid},
        function (mRecord, mData)
            self:_ClientDeleteRole1(mRecord, mData, iPid, func)
        end
    )
end

function CVerifyMgr:_ClientDeleteRole1(mRecord, mData, iPid, func)
    func(mData.errcode)
end

function CVerifyMgr:ClientCheckSdkOpen(sIp)
    -- if ipoperate.is_white_ip(sIp) then
    --     return 1
    -- end
    -- return 0
    do return 1 end
end
