--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local cjson = require "cjson"
local mongoop = require "base.mongoop"
local record = require "public.record"
local extend = require "base.extend"
local router = require "base.router"
local serverdefines = require "public.serverdefines"

local datactrl = import(lualib_path("public.datactrl"))

function NewDataCenter(...)
    local o = CDataCenter:New(...)
    return o
end

CDataCenter = {}
CDataCenter.__index = CDataCenter
inherit(CDataCenter, datactrl.CDataCtrl)

function CDataCenter:New()
    local o = super(CDataCenter).New(self)
    o.m_oGameDb = nil
    return o
end

function CDataCenter:Init()
end

function CDataCenter:InitDataCenterDb(mInit)
    local oClient = mongoop.NewMongoClient({
        host = mInit.host,
        port = mInit.port,
        username = mInit.username,
        password = mInit.password,
    })
    self.m_oGameDb = mongoop.NewMongoObj()
    self.m_oGameDb:Init(oClient, mInit.name)

    skynet.fork(function ()
        local o = self.m_oGameDb

        local sTestTableName = "roleinfo"
        o:CreateIndex(sTestTableName, {pid = 1}, {name = "role_pid_index"})
        o:CreateIndex(sTestTableName, {"account", "channel", name = "role_account_index"})

        local sTestTableName = "register"
        o:CreateIndex(sTestTableName, {"account", "channel", "platform", name = "register_account_index"})

        local sTestTableName = "device_register"
        o:CreateIndex(sTestTableName, {device_id = 1}, {unique = true, name = "device_id_index"})
    end)
end

function CDataCenter:TryCreateRole(sServerTag, sBornServer, sAccount, iChannel, mInfo, endfunc)
    interactive.Request(".idsupply", "common", "GenPlayerId", {},
        function(mRecord, mData)
            endfunc(self:_TryCreateRole2(mRecord, mData, sServerTag, sBornServer, sAccount, iChannel, mInfo))
        end
    )
end

function CDataCenter:_TryCreateRole2(mRecord, mData, sServerTag, sBornServer, sAccount, iChannel, mInfo)
    if is_release(self) then
        return
    end
    local iPid = mData.id
    local mInsert = {
        server = sBornServer,
        now_server = sServerTag,
        account = sAccount,
        platform = mInfo.platform,
        pid = iPid,
        icon = mInfo.icon,
        grade = 0,
        school = mInfo.school,
        name = mInfo.name,
        channel = iChannel,
        login_time = get_time(),
    }
    mongoop.ChangeBeforeSave(mInsert)
    if not self.m_oGameDb:Insert("roleinfo", mInsert) then
        record.error(string.format("try create role insert db error: info %s", extend.Table.serialize(mInsert)))
        return 
    end
    return iPid
end

function CDataCenter:UpdateRoleInfo(iPid, mInfo)
    if not mInfo.no_login then
        mInfo.login_time = mInfo.login_time or get_time()
    end
    mongoop.ChangeBeforeSave(mInfo)
    self.m_oGameDb:Update("roleinfo", {pid = iPid}, {["$set"]=mInfo}, true)
end

function CDataCenter:CheckFirstRegister(sAccount, lChannel, iPlatform, sDeviceId)
    local bFirstRegister, bDeviceFirstRegister
    local m = self.m_oGameDb:Find("register", {
            account = sAccount,
            channel = {["$in"] = lChannel},
            platform = iPlatform,
        }, {
            account = true,
            channel = true,
            platform = true,
    })
    if m:hasNext() then
        bFirstRegister = false
    else
        for _, iChannel in ipairs(lChannel) do
            local mInfo = {
                account = sAccount,
                channel = iChannel,
                platform = iPlatform,
            }
            mongoop.ChangeBeforeSave(mInfo)
            self.m_oGameDb:Insert("register", mInfo)
        end
        bFirstRegister = true
    end

    local m = self.m_oGameDb:Find("device_register", {
            device_id = sDeviceId,
        }, {
            device_id = true,
    })
    if m:hasNext() then
        bDeviceFirstRegister = false
    else
        local mInfo = {
            device_id = sDeviceId,
        }
        mongoop.ChangeBeforeSave(mInfo)
        self.m_oGameDb:Insert("device_register", mInfo)
        bDeviceFirstRegister = true
    end

    return bFirstRegister, bDeviceFirstRegister
end

function CDataCenter:GetRoleList(sAccount, lChannel, iPlatform, lServer)
    local mRet = {}
    local m = self.m_oGameDb:Find("roleinfo", {
            account = sAccount,
            channel = {["$in"] = lChannel},
            platform = iPlatform,
            now_server = {["$in"] = lServer},
        }, {
            server = true,
            now_server = true,
            pid = true,
            icon = true,
            name = true,
            school = true,
            grade = true,
            login_time = true,
            deleted = true
    })
    while m:hasNext() do
        local mInfo = m:next()
        if not mInfo.deleted then
            table.insert(mRet, {
                server = make_server_key(mInfo.server),
                now_server = make_server_key(mInfo.now_server),
                pid = mInfo.pid,
                icon = mInfo.icon,
                name = mInfo.name,
                school = mInfo.school,
                grade = mInfo.grade,
                login_time = mInfo.login_time or 0,
            })
        end
    end
    mongoop.ChangeAfterLoad(mRet)
    self:CheckDeleteRole(sAccount, lChannel, iPlatform)
    return mRet
end

function CDataCenter:GetRoleNowServer(iPid)
    local m = self.m_oGameDb:FindOne("roleinfo", {pid = iPid}, {now_server = true, server = true})
    if m then
        return m.now_server or m.server
    end
    return nil
end

function CDataCenter:DeleteRole(sAccount, iChannel, iPid, func)
    local mRoleInfo = self.m_oGameDb:FindOne("roleinfo", {
            account = sAccount,
            channel = iChannel,
            pid = iPid,
        }, {
            now_server = true,
            server = true,
            grade = true,
            platform = true
        })
    if not mRoleInfo then
        record.error("DeleteRole error account has no pid %s %s %s", sAccount, iChannel, iPid)
        func(1)
        return
    end

    local sServerTag = mRoleInfo.now_server
    local iPlatform = mRoleInfo.platform
    local m = self.m_oGameDb:Find("roleinfo", {
            account = sAccount,
            channel = iChannel,
            now_server = sServerTag,
            platform = iPlatform,
        },{
            pid = true,
            grade = true,
            deleted = true,
        })
    local iCnt = 0
    local iMaxGrade = 0
    while m:hasNext() do
        local mInfo = m:next()
        if not mInfo.deleted then
            iCnt = iCnt + 1
            if mInfo.grade > iMaxGrade then
                iMaxGrade = mInfo.grade
            end
        end
    end
    if iCnt > 3 then
        if mRoleInfo.grade == iMaxGrade then
            func(2)
            return
        end
    else
        if mRoleInfo.grade > 10 then
            func(3)
            return
        end
    end

    local service = string.format(".pay%s", math.random(1, PAY_SERVICE_COUNT))
    interactive.Request(service, "common", "QueryRoleHasPay", {pid=iPid},
    function(mRecord, mData)
        self:_DeleteRole1(mData, iPid, sServerTag, func)
    end)
end

function CDataCenter:_DeleteRole1(mData, iPid, sServerTag, func)
    if not mData then
        record.error("DeleteRole QueryRoleHasPay no data return: pid %d", iPid)
        func(1)
        return
    end
    if mData.ret then
        func(4)
        return
    end
    self:MarkRoleAsDelete(iPid, sServerTag)
    func(0)
end

function CDataCenter:MarkRoleAsDelete(iPid, sServerTag)
    self.m_oGameDb:Update("roleinfo", {pid = iPid}, {["$set"] = {deleted = 1}})
    self:NotifyGS2DeleteRole(iPid, sServerTag)
end

function CDataCenter:NotifyGS2DeleteRole(iPid, sServerTag)
    router.Send(sServerTag, ".world", "datacenter", "DeleteRole", {
        pid=iPid,
    })
end

function CDataCenter:CheckDeleteRole(sAccount, lChannel, iPlatform)
    local mInfo = self.m_oGameDb:FindOne("roleinfo", {
        account = sAccount,
        channel = {["$in"] = lChannel},
        platform = iPlatform,
        deleted = 1,
    }, {
        pid = true,
        now_server = true,
    })
    if not mInfo then
        return
    end
    self:NotifyGS2DeleteRole(mInfo.pid, mInfo.now_server)
end

function CDataCenter:OnGSDeleteRole(iPid)
    self.m_oGameDb:Update("roleinfo", {pid = iPid}, {["$set"] = {deleted = 2}})
end

function CDataCenter:RevertRole(iPid)
    self.m_oGameDb:Delete("roleinfo", {pid = iPid})
end

function CDataCenter:GetRoleListByAccount(sAccount, iChannel, iPlatform)
    if not iChannel then return end
    
    local mRet = {}
    local m = self.m_oGameDb:Find("roleinfo", {
            account = sAccount,
            channel = {["$in"] = {iChannel}},
            platform = iPlatform,
        }, {
            server = true,
            now_server = true,
            pid = true,
    })
    while m:hasNext() do
        local mInfo = m:next()
        table.insert(mRet, {
            server = make_server_key(mInfo.server),
            now_server = make_server_key(mInfo.now_server),
            pid = mInfo.pid,
        })
    end
    mongoop.ChangeAfterLoad(mRet)
    return mRet
end