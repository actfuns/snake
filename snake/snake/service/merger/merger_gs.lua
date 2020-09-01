--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local mongoop = require "base.mongoop"
local record = require "public.record"

local serverinfo = import(lualib_path("public.serverinfo"))
local defines = import(service_path("defines"))


function NewMerger(...)
    local o = CMerger:New(...)
    return o
end


CMerger = {}
CMerger.__index = CMerger
inherit(CMerger, logic_base_cls())

function CMerger:New()
    local o = super(CMerger).New(self)
    o.m_iMergerTimes = 0
    o.m_sFromServer = nil
    o.m_oFromDb = nil
    o.m_oLocalDb = nil
    o.m_iLocalMaxOrgShowId = 0
    o.m_mPending = {}
    o.m_lWaitFunc = {}
    return o
end

function CMerger:GetFromDb()
    local sFromServer = self.m_sFromServer
    local sFromServerKey = make_server_key(sFromServer)
    local mFromSlave = serverinfo.get_slave_dbs({sFromServerKey})[sFromServerKey]
    if not mFromSlave then
        record.error("merger error from server tag: %s", sFromServer)
        return
    end
    local oFromClient = mongoop.NewMongoClient({
        host = mFromSlave.game.host,
        port = mFromSlave.game.port,
        username = mFromSlave.game.username,
        password = mFromSlave.game.password
    })
    local oFromGameDb = mongoop.NewMongoObj()
    oFromGameDb:Init(oFromClient, "game")
    self.m_oFromDb = oFromGameDb
    return oFromGameDb
end

function CMerger:GetLocalDb()
    local mLocal = serverinfo.get_local_dbs()

    local oLocalClient = mongoop.NewMongoClient({
        host = mLocal.game.host,
        port = mLocal.game.port,
        username = mLocal.game.username,
        password = mLocal.game.password
    })
    local oLocalGameDb = mongoop.NewMongoObj()
    oLocalGameDb:Init(oLocalClient, "game")
    self.m_oLocalDb = oLocalGameDb
    return oLocalGameDb
end

function CMerger:GetLocalOrgShowId()
    local mData = self.m_oLocalDb:FindOne("world")
    if mData and mData.data and mData.data.orgid then
        self.m_iLocalMaxOrgShowId = mData.data.orgid
    end
    print(string.format("----merger get local org showid : %s ----", self.m_iLocalMaxOrgShowId))
end

function CMerger:StartMerger(iMergerTimes)
    local lInfo = defines.MERGER_INFO[iMergerTimes]
    if not lInfo then
        record.error("error merger times %s", iMergerTimes)
        return
    end
    if lInfo[2] ~= get_server_tag() then
        record.error("error host server %s", lInfo[2])
        return
    end
    self.m_iMergerTimes = iMergerTimes
    self.m_sFromServer = lInfo[1]
    local oFromGameDb = self:GetFromDb()
    local oLocalGameDb = self:GetLocalDb()
    if not oFromGameDb or not oLocalGameDb then
        return
    end
    print(string.format("----merger start: %s times----", iMergerTimes))

    self:GetLocalOrgShowId()

    print("start merge player----")
    self:MergePlayer(oFromGameDb, oLocalGameDb)
    print("----merge player finish")

    print("start merge offline----")
    self:MergeOffline(oFromGameDb, oLocalGameDb)
    print("----merge offline finish")

    print("start merge org----")
    self:MergeOrg(oFromGameDb, oLocalGameDb)
    print("----merge org finish")

    print("start merge orgready----")
    self:MergeOrgReady(oFromGameDb, oLocalGameDb)
    print("----merge orgready finish")

    print("start merge invitecode----")
    self:MergeInviteCode(oFromGameDb, oLocalGameDb)
    print("----merge invitecode finish")

    print("start merge warvideo----")
    self:MergeWarVideo(oFromGameDb, oLocalGameDb)
    print("----merge warvideo finish")

    -- 弹幕处理成不合并
    print("start merge bulletbarrage----")
    self:MergeBulletBarrage(oFromGameDb, oLocalGameDb)
    print("----merge bulletbarrage finish")

    print("start merge stall----")
    self:MergeStall(oFromGameDb, oLocalGameDb)
    print("----merge stall finish")
    
    print("start merge global----")
    self:MergeGlobal(oFromGameDb, oLocalGameDb)
    
    print("start merge huodong----")
    self:MergeHuodong(oFromGameDb, oLocalGameDb)
    
    print("start merge rank----")
    self:MergeRank(oFromGameDb, oLocalGameDb)
    
    print("start merge guild----")
    self:MergeGuild(oFromGameDb, oLocalGameDb)
    
    print("start merge price----")
    self:MergePrice(oFromGameDb, oLocalGameDb)
    
    print("start merge auction----")
    self:MergeAuction(oFromGameDb, oLocalGameDb)
    print("----merge player auction finish")
    
    print("start merge world----")
    self:MergeWorld(oFromGameDb, oLocalGameDb)
    
    print("start merge feedback ----")
    self:MergeFeedBack(oFromGameDb, oLocalGameDb)
    print("----merge feedback finish")

    self:Wait2Exec(function ()
        save_all()
        print("----data is merged! reboot now----")
    end)
end



function CMerger:MergePlayer(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "player", 500) do
        for idx, mInfo in ipairs(lInfos) do
            oLocalGameDb:Update("namecounter", {name = mInfo.name}, {["$set"] = {name = mInfo.name}}, true)
        end
        oLocalGameDb:BatchInsert("player", lInfos)
    end
end

function CMerger:MergeOffline(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "offline", 500) do
        oLocalGameDb:BatchInsert("offline", lInfos)
    end
end

function CMerger:MergeOrg(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "org", 100, "HandleOrgData") do
        oLocalGameDb:BatchInsert("org", lInfos)
    end
end

function CMerger:HandleOrgData(mData)
    self.m_iLocalMaxOrgShowId = self.m_iLocalMaxOrgShowId + 1
    mData.showid = self.m_iLocalMaxOrgShowId
    mData.from_server = self.m_sFromServer
    return mData
end

function CMerger:MergeOrgReady(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "orgready", 100, "HandleOrgReadyData") do
        oLocalGameDb:BatchInsert("orgready", lInfos)
    end
end

function CMerger:HandleOrgReadyData(mData)
    self.m_iLocalMaxOrgShowId = self.m_iLocalMaxOrgShowId + 1
    mData.showid = self.m_iLocalMaxOrgShowId
    mData.from_server = self.m_sFromServer
    return mData
end

function CMerger:MergeInviteCode(oFromGameDb, oLocalGameDb)
    -- xiongyi:丢弃被合服数据
end

function CMerger:MergeWarVideo(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "warvideo", 100) do
        oLocalGameDb:BatchInsert("warvideo", lInfos)
    end
end

function CMerger:MergeBulletBarrage(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "bulletbarrage", 1) do
        local mData = lInfos[1]
        oLocalGameDb:Update("bulletbarrage", {id = mData.id, type = mData.type}, {["$set"] = mData}, true)
    end
end

function CMerger:MergeStall(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "stall", 500, "HandleStallData") do
        --oLocalGameDb:BatchInsert("stall", lInfos)
    end
end

function CMerger:HandleStallData(mInfo)
    if not mInfo then return end

    mongoop.ChangeAfterLoad(mInfo)
    self:AddPending("stall"..mInfo.pid)
    interactive.Request(".world", "merger", "MergeStallObj", {data = mInfo},
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        end
        self:OnModuleFinish("stall"..mInfo.pid)
    end)
    return mInfo
end


function CMerger:MergeGuild(oFromGameDb, oLocalGameDb)
    local mData = oFromGameDb:FindOne("guild", {name = "guild"})
    if not mData then
        return
    end
    local mFromData = mData.data
    mongoop.ChangeAfterLoad(mFromData)
    self:AddPending("guild")
    interactive.Request(".world", "merger", "MergeGuild", mFromData,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print("----merge guild finish")
        end
        self:OnModuleFinish("guild")
    end)
end

function CMerger:MergePrice(oFromGameDb, oLocalGameDb)
    local mData = oFromGameDb:FindOne("price", {name = "stall_price"})
    if not mData then
        return
    end
    local mFromData = mData.data
    mongoop.ChangeAfterLoad(mFromData)
    self:AddPending("price")
    interactive.Request(".world", "merger", "MergePrice", mFromData,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print("----merge price finish")
        end
        self:OnModuleFinish("price")
    end)
end

function CMerger:MergeAuction(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "auction", 1000, "HandleAuctionData") do
        if next(lInfos) then
            oLocalGameDb:BatchInsert("auction", lInfos)
        end
    end
end

function CMerger:HandleAuctionData(mInfo)
    local iSystemPid = 0
    if mInfo.pid == iSystemPid then
        print(string.format("merge sysauction %s start----", iSystemPid))
        local mFromData = mInfo.data
        mongoop.ChangeAfterLoad(mFromData)
        self:AddPending("sysauction")
        interactive.Request(".world", "merger", "MergeAuctionSys", {pid = iSystemPid ,data = mFromData},
        function (mRecord, mData)
            if mData.err then
                record.error(mData.err)
            else
                print(string.format("----merge sysauction %s finish", iSystemPid))
            end
            self:OnModuleFinish("sysauction")
        end)
        return
    else
        return mInfo
    end
end

GLOBAL_HANDLE = {
    ["chlgmatch"] = "HandleGlobalChlMatch",
    ["trialmatch"] = "HandleGlobalTrialMatch",
    ["jjc"] = "HandleGlobalJJC",
    ["redpacket"] = "HandleGlobalRedPacket",
    ["chatinfo"] = "HandleChatInfo",
    ["engageinfo"] = "HandleEngageInfo",
    ["yunyinginfo"] = "HandleYunYingInfo",
    ["mentoring"] = "HandleMentoring",
    ["marryinfo"] = "HandleMarryInfo",
}

function CMerger:MergeGlobal(oFromGameDb, oLocalGameDb)
    local m = oFromGameDb:Find("global")
    while m:hasNext() do
        local mInfo = m:next()
        mInfo._id = nil
        local sName = mInfo.name
        print(string.format("merge global %s start----", sName))
        local f = self[GLOBAL_HANDLE[sName]]
        if not f then
            record.error("global %s merge failed : no handle", sName)
            goto continue
        end
        local mData = mInfo.data
        mongoop.ChangeAfterLoad(mData)
        f(self, sName, mData)
        ::continue::
    end
end

function CMerger:HandleGlobalChlMatch(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".recommend", "merger", "MergeChlMatch", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleGlobalTrialMatch(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".recommend", "merger", "MergeTrialMatch", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleGlobalJJC(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".world", "merger", "MergeJJC", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleGlobalRedPacket(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".world", "merger", "MergeRedPacket", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleChatInfo(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".chat", "merger", "MergeChatInfo", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleEngageInfo(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".world", "merger", "MergeEngageInfo", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleYunYingInfo(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".world", "merger", "MergeYunYingInfo", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleMentoring(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".world", "merger", "MergeMentoring", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end

function CMerger:HandleMarryInfo(sName, mInfo)
    self:AddPending("global."..sName)
    interactive.Request(".world", "merger", "MergeMarryInfo", mInfo,
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print(string.format("----merge global %s finish", sName))
        end
        self:OnModuleFinish("global."..sName)
    end)
end


function CMerger:MergeHuodong(oFromGameDb, oLocalGameDb)
    local m = oFromGameDb:Find("huodong")
    while m:hasNext() do
        local mInfo = m:next()
        mInfo._id = nil
        mongoop.ChangeAfterLoad(mInfo)
        local sName = mInfo.name
        print(string.format("merge huodong %s start----", sName))
        self:AddPending("huodong."..sName)
        interactive.Request(".world", "merger", "MergeHuodong", mInfo, function (mRecord, mData)
            if mData.err then
                record.error(mData.err)
            else
                print(string.format("----merge huodong %s finish", sName))
            end
            self:OnModuleFinish("huodong."..sName)
        end)
    end
end

function CMerger:MergeRank(oFromGameDb, oLocalGameDb)
    local m = oFromGameDb:Find("rank")
    while m:hasNext() do
        local mInfo = m:next()
        mInfo._id = nil
        mongoop.ChangeAfterLoad(mInfo)
        local sName = mInfo.name
        print(string.format("merge rank %s start----", sName))
        self:AddPending("rank."..sName)
        interactive.Request(".rank", "merger", "MergeRank", mInfo, function (mRecord, mData)
            if mData.err then
                record.error(mData.err)
            else
                print(string.format("----merge rank %s finish", sName))
            end
            self:OnModuleFinish("rank."..sName)
        end)
    end
end

function CMerger:MergeFeedBack(oFromGameDb, oLocalGameDb)
    for lInfos in self:BatchDealTable(oFromGameDb, "feedback", 500) do
        if next(lInfos) then
            oLocalGameDb:BatchInsert("feedback", lInfos)
        end
    end
end

function CMerger:MergeWorld(oFromGameDb)
    local mInfo = oFromGameDb:FindOne("world")
    local mData = mInfo.data
    mongoop.ChangeAfterLoad(mData)
    self:AddPending("world")
    interactive.Request(".world", "merger", "MergeWorld", {
        from_data = mData,
        org_showid = self.m_iLocalMaxOrgShowId,
        merger_times = self.m_iMergerTimes,
        from_server = self.m_sFromServer,
    },
    function (mRecord, mData)
        if mData.err then
            record.error(mData.err)
        else
            print("----merge world finish")
        end
        self:OnModuleFinish("world")
    end)
end

function CMerger:AddPending(sKey)
    self.m_mPending[sKey] = true
end

function CMerger:OnModuleFinish(sKey)
    self.m_mPending[sKey] = nil
    if not next(self.m_mPending) then
        for idx, func in ipairs(self.m_lWaitFunc) do
            func()
        end
    end
end

function CMerger:Wait2Exec(func)
    if not next(self.m_mPending) then
        func()
    else
        table.insert(self.m_lWaitFunc, func)
    end
end

function CMerger:BatchDealTable(oGameDb, sTable, iLimit, sHook)
    local m = oGameDb:Find(sTable)
    return function ()
        if not m:hasNext() then
            return
        end
        local lInfos = {}
        for i = 1, iLimit do
            if not m:hasNext() then
                break
            end
            local mInfo = m:next()
            mInfo._id = nil
            if sHook then
                local mRet = self[sHook](self, mInfo)
                if mRet then
                    table.insert(lInfos, mRet)
                end
            else
                table.insert(lInfos, mInfo)
            end
        end
        return lInfos
    end
end
