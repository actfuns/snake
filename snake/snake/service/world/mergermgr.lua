local global = require "global"
local extend = require "base.extend"
local interactive = require "base.interactive"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

local min = math.min
local max = math.max
local floor = math.floor

function NewMergerMgr(...)
    local o = CMergerMgr:New(...)
    return o
end

CMergerMgr = {}
CMergerMgr.__index = CMergerMgr
inherit(CMergerMgr, datactrl.CDataCtrl)

function CMergerMgr:New()
    local o = super(CMergerMgr).New(self)
    o.m_mMergedServers = {}
    return o
end

function CMergerMgr:Load(m)
    m = m or {}
    self.m_mMergerInfo = m.merger_info or {}
    self.m_iLastMerger = m.last_merger or 0
    self.m_iHasMerger = m.has_merger or 0
end

function CMergerMgr:Save()
    local m = {}
    m.merger_info = self.m_mMergerInfo
    m.last_merger = self.m_iLastMerger
    m.has_merger = self.m_iHasMerger
    return m
end

function CMergerMgr:GenMergedServers()
    self.m_mMergedServers = {}
    local mServers = self.m_mMergedServers
    for k, v in pairs(self.m_mMergerInfo) do
        mServers[v.from_server] = true
    end
end

function CMergerMgr:CheckMergedServer(sServerKey)
    local sServerTag = get_server_tag(sServerKey)
    return self.m_mMergedServers[sServerTag] and 0 or 1
end

function CMergerMgr:MergeFrom(mData)
    local mFromData = mData.from_data

    local iMergerTimes = mData.merger_times
    local sFromServer = mData.from_server
    local mMergerData = mData.merger

    if mMergerData and mMergerData.merger_info then
        for k, v in pairs(mMergerData.merger_info) do
            self.m_mMergerInfo[k] = v
        end
    end
    local iFromServerGrade = mFromData.server_grade
    local iFromServerOpenDays = mFromData.open_days
    self.m_mMergerInfo[iMergerTimes] = {
        from_server = sFromServer,
        from_grade = iFromServerGrade,
        from_open_day = iFromServerOpenDays,
        to_server = get_server_tag(),
        to_grade = global.oWorldMgr:GetServerGrade(),
        to_open_day = global.oWorldMgr:GetOpenDays(),
        time = get_time()
    }
    self.m_iLastMerger = iMergerTimes
    self.m_iHasMerger = 1
    return true
end

function CMergerMgr:OnServerStartEnd()
    if self.m_iHasMerger == 1 then
        print("merger HandleConfictNameOrg start----")
        self:HandleConfictNameOrg(function ()
            print("merger HandleConfictNamePlayer start----")
            self:HandleConfictNamePlayer(function ()
                save_all()
                global.oRankMgr:MergeFinish()
            end)
        end)
        self.m_iHasMerger = 0
        self:Dirty()
    end
    self:GenMergedServers()
end

function CMergerMgr:HandleConfictNameOrg(endfunc)
    local mInfo = {
        module = "orgdb",
        cmd = "GetConflictNameOrg",
    }
    gamedb.LoadDb("merge", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        self:_HandleConfictNameOrg1(endfunc, mRecord, mData)
    end)
end

function CMergerMgr:_HandleConfictNameOrg1(endfunc, mRecord, mData)
    local oMailMgr = global.oMailMgr
    local oOrgMgr = global.oOrgMgr
    local oItemLoader = global.oItemLoader
    for iOrgId, sOrgName in pairs(mData) do
        local oOrg = oOrgMgr:GetNormalOrg(iOrgId)
        if oOrg then
            oOrgMgr:ForceRenameOrg(iOrgId, sOrgName.."*"..oOrg:ShowID())
            -- xiong : 给帮主发改名卡
            local iLeader = oOrg:GetLeaderID()
            if iLeader then
                local oItem = oItemLoader:ExtCreate(10179)
                local mData, name = oMailMgr:GetMailInfo(9002)
                oMailMgr:SendMail(0, name, iLeader, mData, 0, {oItem})
            end
        else
            local oOrg = oOrgMgr:GetReadyOrg(iOrgId)
            if oOrg then
                oOrgMgr:ForceRenameReadyOrg(iOrgId, sOrgName.."*"..oOrg:ShowID())
                -- 先不给改名卡,创建成功给
                oOrg:SetData("renamecard", 1)
            end
        end
    end
    print("----merger HandleConfictNameOrg end: ", table_count(mData), mData)
    endfunc()
end

function CMergerMgr:HandleConfictNamePlayer(endfunc)
    local mInfo = {
        module = "playerdb",
        cmd = "GetConflictNamePlayer",
    }
    gamedb.LoadDb("merge", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        self:_HandleConfictNamePlayer1(endfunc, mRecord, mData)
    end)
end

function CMergerMgr:_HandleConfictNamePlayer1(endfunc, mRecord, mData)
    local oRenameMgr = global.oRenameMgr
    local oMailMgr = global.oMailMgr
    local oOrgMgr = global.oOrgMgr
    local oItemLoader = global.oItemLoader
    for iPid, sName in pairs(mData) do
        local sNewName = sName.."*"..iPid
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerMain",
            cond = {pid = iPid},
            data = {data = {name = sNewName}},
        }
        gamedb.SaveDb("merge", "common", "DbOperate", mInfo)
        local mInfo = {
            module = "namecounter",
            cmd = "InsertNewNameCounter",
            data = {name = sNewName},
        }
        gamedb.SaveDb("merge", "common", "DbOperate", mInfo)
        oRenameMgr:RefreshDbName(iPid, sName, sNewName)
        -- xiong : 给玩家发改名卡
        local oItem = oItemLoader:ExtCreate(10178)
        local mData, name = oMailMgr:GetMailInfo(9003)
        oMailMgr:SendMail(0, name, iPid, mData, 0, {oItem})
    end
    print("----merger HandleConfictNamePlayer end: ", table_count(mData), mData)
    endfunc()
end

function CMergerMgr:OnLogin(oPlayer)
    local sNowServer = oPlayer:GetNowServer()
    local iPMergerCnt = oPlayer:Query("merger_cnt", 0)
    local iGrade = oPlayer:GetGrade()
    if iPMergerCnt < self.m_iLastMerger then
        oPlayer:Set("merger_cnt", self.m_iLastMerger)
        oPlayer:SetNowServer()
        if iGrade < 30 then
            return
        end
        print("----merger buchange start: ", oPlayer:GetPid(), iGrade, sNowServer, iPMergerCnt)
        local iNow = get_time()
        local lDayNo = {}
        for i = iPMergerCnt + 1, self.m_iLastMerger do
            local mInfo = self.m_mMergerInfo[i]
            if mInfo and mInfo.time + 2592000 > iNow then
                local iDayNo = get_dayno(mInfo.time)
                if table_in_list(lDayNo, iDayNo) then
                    goto continue 
                end
                if mInfo.from_server == sNowServer then
                    sNowServer = mInfo.to_server
                    self:FromBuchang(i, oPlayer, mInfo)
                    table.insert(lDayNo, iDayNo)
                elseif mInfo.to_server == sNowServer then
                    self:LocalBuchang(i, oPlayer, mInfo)
                    table.insert(lDayNo, iDayNo)
                end
                ::continue::
            end
        end
        print("----merger buchange end")
    end
end

function CMergerMgr:FromBuchang(iTimes, oPlayer, mInfo)
    local oItemLoader = global.oItemLoader
    local lItems = {}
    local mLogItems = {}

    local iPid = oPlayer:GetPid()
    local iGrade = oPlayer:GetGrade()
    local iDiffDay = max(0, mInfo.to_open_day - mInfo.from_open_day)
    local iDiffGrade = max(0, mInfo.to_grade - mInfo.from_grade)

    oPlayer.m_oBaseCtrl:AddDoublePoint(240)
    oPlayer.m_oBaseCtrl:RefreshDoublePoint()

    --人物经验
    local iExp = floor(((iGrade + iDiffGrade / 2) * 4800 + 25000 ) * 9 * min(60, iDiffDay))
    if iExp > 0 then
        local oItem = oItemLoader:ExtCreate(1005)
        oItem:SetData("Value", iExp)
        table.insert(lItems, oItem)
        mLogItems[oItem:Name()] = iExp
    end
    
    --银币
    local iSilver = floor(min(60, iDiffDay) * 200000 + max(0, iGrade - 40) * 100000 + 1000000)
    if iSilver > 0 then
        local oItem = oItemLoader:ExtCreate(1002)
        oItem:SetData("Value", iSilver)
        table.insert(lItems, oItem)
        mLogItems[oItem:Name()] = iSilver
    end

    --双倍丹
    local oItem = oItemLoader:ExtCreate(10013)
    oItem:SetAmount(2)
    oItem:Bind(iPid)
    table.insert(lItems, oItem)
    mLogItems[oItem:Name()] = 2

    --还童丹
    local oItem = oItemLoader:ExtCreate(10031)
    oItem:SetAmount(80)
    oItem:Bind(iPid)
    table.insert(lItems, oItem)
    mLogItems[oItem:Name()] = 80

    if iGrade >= 60 then
        --坐骑经验
        local iRideExp = floor(min(60, iDiffDay) * 2)
        if iRideExp > 0 then
            local oItem = oItemLoader:ExtCreate(11099)
            oItem:SetAmount(iRideExp)
            oItem:Bind(iPid)
            table.insert(lItems, oItem)
            mLogItems[oItem:Name()] = iRideExp
        end
    end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(9004)
    mData.createtime = mInfo.time
    oMailMgr:SendMail(0, name, oPlayer:GetPid(), mData, 0, lItems)
    record.user("player", "merger_reward", {pid=oPlayer:GetPid(), times=iTimes, items=mLogItems})
end

function CMergerMgr:LocalBuchang(iTimes, oPlayer, mInfo)
    local iGrade = oPlayer:GetGrade()
    local lItems = {}
    local mLogItems = {}

    local iPid = oPlayer:GetPid()
    local oItemLoader = global.oItemLoader
    --银币
    local iSilver = 1000000
    local oItem = oItemLoader:ExtCreate(1002)
    oItem:SetData("Value", iSilver)
    table.insert(lItems, oItem)
    mLogItems[oItem:Name()] = iSilver

    --双倍丹
    local oItem = oItemLoader:ExtCreate(10013)
    oItem:SetAmount(2)
    oItem:Bind(iPid)
    table.insert(lItems, oItem)
    mLogItems[oItem:Name()] = 2

    --还童丹
    local oItem = oItemLoader:ExtCreate(10031)
    oItem:SetAmount(80)
    oItem:Bind(iPid)
    table.insert(lItems, oItem)
    mLogItems[oItem:Name()] = 80

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(9004)
    mData.createtime = mInfo.time
    oMailMgr:SendMail(0, name, oPlayer:GetPid(), mData, 0, lItems)
    record.user("player", "merger_reward", {pid=oPlayer:GetPid(), times=iTimes, items=mLogItems})
end
