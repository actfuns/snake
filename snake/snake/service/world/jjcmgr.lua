local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"
local statistics = require "public.statistics"


local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local robot = import(service_path("jjc.robot"))
local rewardmonitor = import(service_path("rewardmonitor"))
local analy = import(lualib_path("public.dataanaly"))
local gamedb = import(lualib_path("public.gamedb"))


function NewJJCMgr(...)
    return CJJCMgr:New(...)
end

local ASSIST_SCHOOL_CNT = 3

CJJCMgr = {}
CJJCMgr.__index = CJJCMgr
CJJCMgr.DB_KEY = "jjc"
inherit(CJJCMgr, datactrl.CDataCtrl)

function CJJCMgr:New()
    local o = super(CJJCMgr).New(self)
    o.m_mRobots = {}
    o.m_iMonth = 0
    o.m_iVersion = 0

    o.m_mRobotList = {}
    o.m_mFightingRobot = {}
    o.m_mFightingPlayer = {}
    o.m_mTop3Detail = {}
    o.m_oRewardMonitor = nil
    o.m_mPlayerActiveTime = {}               -- 只需记录在榜内的
    return o
end

function CJJCMgr:Release()
    if self.m_oRewardMonitor then
        baseobj_safe_release(self.m_oRewardMonitor)
    end
    self:ClearJJCRobot()
    super(CJJCMgr).Release(self)
end

function CJJCMgr:ClearJJCRobot()
    for _, oRobot in pairs(self.m_mRobotList) do
        baseobj_safe_release(oRobot)
    end
    self.m_mRobotList = {}
end

function CJJCMgr:LoadDb()
    if self:IsLoaded() then return end
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.DB_KEY},
    }
    gamedb.LoadDb("jjc", "common", "DbOperate", mInfo, function (mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CJJCMgr:SaveDb()
    if self:IsDirty() then
        local mInfo = {
            module = "globaldb",
            cmd = "SaveGlobal",
            cond = {name = self.DB_KEY},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("jjc", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CJJCMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        local obj = global.oJJCMgr
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("jjcmgr save err: no obj")
        end
    end)
end

function CJJCMgr:_CheckSaveDb()
    assert(not is_release(self), "jjcmgr save fail: has release")
    assert(self:IsLoaded(), "jjcmgr save fail: is loading")
    self:SaveDb()
end

function CJJCMgr:Load(mData)
    mData = mData or {}
    if mData.robot then
        for sIdx, data in pairs(mData.robot) do
            self.m_mRobots[tonumber(sIdx)] = data
        end
    end
    self.m_iMonth = mData.month or 0
    self.m_iVersion = mData.version or 0
    self.m_mPlayerActiveTime = mData.playeractivetime or {}
end

function CJJCMgr:Save()
    local mData = {}
    local mSaveRobot = {}
    for idx, data in pairs(self.m_mRobots) do
        mSaveRobot[db_key(idx)] = data
    end
    mData.robot = mSaveRobot
    mData.month = self.m_iMonth
    mData.version = self.m_iVersion
    mData.playeractivetime = self.m_mPlayerActiveTime
    return mData
end

function CJJCMgr:MergeFrom(mFromData)
    self:Dirty()
    local iVersion = mFromData.version or 0
    self.m_iVersion = math.max(iVersion, self.m_iVersion) + 1
    self:InitRobot()
    interactive.Send(".rank", "rank", "PushJJCInitData", {data = self:PackRobotRankData()})
    return true
end

function CJJCMgr:AfterLoad()
    local oWorldMgr = global.oWorldMgr
    local mTimeData = os.date("*t", get_time())
    if mTimeData.month ~= self.m_iMonth then
        if self.m_iMonth == 0 or oWorldMgr:GetOpenDays() > 7 then
            self:NewGameSeason(mTimeData.month)
        end
    end
    if not self.m_oRewardMonitor then
        local o = rewardmonitor.NewMonitor("jjcmgr", {"jjc"})
        self.m_oRewardMonitor = o
    end

    oWorldMgr:AddEvent(self, gamedefines.EVENT.WORLD_SERVER_START_END, function (iEvent, mArgs)
        global.oJJCMgr:OnServerStartEnd()
    end)
end

function CJJCMgr:OnServerStartEnd()
    self:InitJJCTop3()
end

function CJJCMgr:InitJJCTop3()
    local f
    f = function (mRecord, mData)
        self:_InitJJCTop3(mData.data)
    end
    interactive.Request(".rank", "rank", "GetJJCTop3", {}, f)
end

function CJJCMgr:_InitJJCTop3(lRankData)
    if not lRankData or #lRankData <= 0 then
        self:AddTimeCb("InitJJCTop3", 10 * 1000, function ()
            self:InitJJCTop3()
        end)
        record.error("JJC _InitJJCTop3 not find data")
    else
        self:UpdateJJCTop3(lRankData)
    end
end

function CJJCMgr:OnLogout(oPlayer)
    self:SetPlayerActiveTime(oPlayer:GetPid())    
end

function CJJCMgr:SetPlayerActiveTime(iPid)
    if self.m_mPlayerActiveTime[iPid] then
        self.m_mPlayerActiveTime[iPid] = get_time()
        self:Dirty()
    end
end

function CJJCMgr:InitPlayerActiveTime(iPid)
    if not self.m_mPlayerActiveTime[iPid] then
        self.m_mPlayerActiveTime[iPid] = get_time()
        self:Dirty()
    end
end

function CJJCMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 0 then
        self:NewDay(mNow)
    elseif iHour == 22 then
        self:NewHour22(mNow)
    end
end

function CJJCMgr:NewDay(mNow)
    if self.m_oRewardMonitor then
        self.m_oRewardMonitor:ClearRecordInfo()
    end
    local oWorldMgr = global.oWorldMgr
    local mTimeData = mNow.date
    if mTimeData.month ~= self.m_iMonth then
        if oWorldMgr:GetOpenDays() <= 7 then
            self:Dirty()
            self.m_iMonth=mTimeData.month
            return
        end
        self:NewGameSeason(mTimeData.month)
    end
end

function CJJCMgr:NewHour22(mNow)
    interactive.Request(".rank", "rank", "GetJJCRankList", {}, function (mRecord, mData)
        self:BeginSendDayReward(mData)
    end)
end

function CJJCMgr:BeginSendDayReward(mData)
    if self:GetTimeCb("day_end") then
        record.warning("jjcmgr SendDayReward repeat")
        return
    end
    local mPids = mData.data
    self:_SendDayReward(mPids)
end

function CJJCMgr:NeedSendReward(iPid)
    local iActiveTime = self.m_mPlayerActiveTime[iPid]
    local iNowTime = get_time()
    if not iActiveTime then
        iActiveTime = iNowTime
        self:InitPlayerActiveTime(iPid)
    end
    if global.oWorldMgr:IsOnline(iPid) then return true end

    if iNowTime - iActiveTime < 3*24*3600 then
        return true
    end
    return false
end

function CJJCMgr:_SendDayReward(mPids)
    self:DelTimeCb("day_end")
    if not next(mPids) then
        return
    end
    local oMailMgr = global.oMailMgr
    local mRecReward = {}
    local lRewardInfo = res["daobiao"]["jjc"]["day_reward"]
    local lRewardRatio = res["daobiao"]["jjc"]["day_reward_ratio"]
    local iCnt = 1
    local lHasSend = {}
    for pid, info in pairs(mPids) do
        local mReward = self:LocateData(lRewardInfo, "rank", info.rank) or {}
        local mItem = mReward["item"]
        if mItem and #mItem > 0 and self:NeedSendReward(pid) then
            local iGrade = info.grade
            if not iGrade or iGrade == 0 then
                iGrade = 1
            end

            local lItems = {}
            local mRatio = self:LocateData(lRewardRatio, "grade", iGrade)
            for _, mInfo in ipairs(mItem) do
                local iSID = mInfo["sid"]
                local sAmount = mInfo["amont"]
                local iAmount = math.floor(formula_string(sAmount, {level=info.grade,k=mRatio["ratio"]}))
                local oItem = global.oItemLoader:Create(iSID)
                oItem:SetAmount(iAmount)
                table.insert(lItems, oItem)
                mRecReward[iSID] = (mRecReward[iSID] or 0) + iAmount
            end
            local mData, name = oMailMgr:GetMailInfo(2006)
            mData.context = global.oToolMgr:FormatColorString(mData.context, {rank = info.rank})
            oMailMgr:SendMail(0, name, pid, mData, 0, lItems)
        end
        iCnt = iCnt + 1
        table.insert(lHasSend, pid)
        if iCnt > 100 then
            break
        end
    end
    for _, pid in pairs(lHasSend) do
        mPids[pid] = nil
    end
    self:AddTimeCb("day_end", 1 * 500, function ()
        self:_SendDayReward(mPids)
    end)

    statistics.system_collect_reward("sys_jjc", mRecReward)
end

function CJJCMgr:NewGameSeason(iMonth)
    if self.m_iMonth and self.m_iMonth ~= 0 then
        self:GameSeasonEnd()
    end
    local mLogData = {}
    mLogData.month = iMonth
    record.user("jjc", "new_season", mLogData)
    self:Dirty()
    self.m_iMonth = iMonth
    self.m_NextSeasonTime = nil
    self:InitRobot()
    interactive.Send(".rank", "rank", "PushJJCInitData", {data = self:PackRobotRankData()})
end

function CJJCMgr:GameSeasonEnd()
    local mLogData = {}
    mLogData.month = self.m_iMonth
    record.user("jjc", "season_end", mLogData)
    interactive.Request(".rank", "rank", "GetJJCRankList", {}, function (mRecord, mData)
        self:BeginSendSeasonReward(mData)
    end)
end

function CJJCMgr:BeginSendSeasonReward(mData)
    if self:GetTimeCb("season_end") then
        record.warning("jjcmgr SendSeasonReward repeat")
        return
    end
    local mPids = mData.data
    self:_SendSeasonReward(mPids)
end

function CJJCMgr:_SendSeasonReward(mPids)
    self:DelTimeCb("season_end")
    if not next(mPids) then
        return
    end
    local oMailMgr = global.oMailMgr
    local lRewardInfo = res["daobiao"]["jjc"]["month_reward"]
    local lRewardRatio = res["daobiao"]["jjc"]["month_reward_ratio"]
    local iCnt = 1
    local lHasSend = {}
    local mRecReward = {}
    for pid, info in pairs(mPids) do
        local mReward = self:LocateData(lRewardInfo, "rank", info.rank) or {}
        local mItem = mReward["item"]
        if mItem and #mItem > 0 then
            local mRatio = self:LocateData(lRewardRatio, "grade", math.max(info.grade, 1))
            local lItems = {}
            for _, mInfo in ipairs(mItem) do
                local iSID = mInfo["sid"]
                local sAmount = mInfo["amont"]
                local iAmount = math.floor(formula_string(sAmount, {level=info.grade,k=mRatio["ratio"]}))
                local oItem = global.oItemLoader:Create(iSID)
                oItem:SetAmount(iAmount)
                table.insert(lItems, oItem)
                mRecReward[iSID] = (mRecReward[iSID] or 0) + iAmount
            end
            local mData, name = oMailMgr:GetMailInfo(2005)
            mData.context = global.oToolMgr:FormatColorString(mData.context, {rank = info.rank})
            oMailMgr:SendMail(0, name, pid, mData, 0, lItems)
        end
        iCnt = iCnt + 1
        table.insert(lHasSend, pid)
        if iCnt > 100 then
            break
        end
    end
    for _, pid in pairs(lHasSend) do
        mPids[pid] = nil
    end
    self:AddTimeCb("season_end", 1 * 1000, function ()
        self:_SendSeasonReward(mPids)
    end)
end

function CJJCMgr:GetJJCGlobalData()
    return res["daobiao"]["jjc"]["jjc_global"][1]
end

function CJJCMgr:GetJJCFightCDConfig()
    local iRet = self:GetJJCGlobalData()["fight_cd"]
    assert(iRet, string.format("jj GetJJCFightCDConfig err: %d", iRet))
    return iRet
end

function CJJCMgr:GetJJCFightMaxConfig()
    local iRet = self:GetJJCGlobalData()["fight_max"]
    assert(iRet, string.format("jj GetJJCFightMaxConfig err: %d", iRet))
    return iRet
end

function CJJCMgr:GetJJCFightLimitConfig()
    local iRet = self:GetJJCGlobalData()["fight_limit"]
    assert(iRet, string.format("jj GetJJCFightLimitConfig err: %d", iRet))
    return iRet
end

function CJJCMgr:GetJJCRecoverTimesConfig()
    local iRet = self:GetJJCGlobalData()["recover_times"]
    assert(iRet, string.format("jj GetJJCRecoverTimesConfig err: %d", iRet))
    return iRet
end

function CJJCMgr:GetJJCTimeCDHourConfig()
    local iRet = self:GetJJCGlobalData()["time_cd"]
    assert(iRet, string.format("jj GetJJCTimeCDHourConfig err: %d", iRet))
    return iRet
end

function CJJCMgr:GetJJCClearCDCostConfig(iMin)
    local sRet = self:GetJJCGlobalData()["cd_cost"]
    assert(sRet, string.format("jj GetJJCClearCDCostConfig err: %s", sRet))
    return math.floor(formula_string(sRet,{minute=iMin}))
end

function CJJCMgr:GetJJCRewardTimesConfig()
    local iRet = self:GetJJCGlobalData()["reward_times"]
    assert(iRet >= 0, string.format("jjc GetJJCRewardTimesConfig err: %s", iRet))
    return iRet
end

function CJJCMgr:GetJJCRefreshTimesConfig()
    local iRet = self:GetJJCGlobalData()["refresh_times"]
    assert(iRet >= 0, string.format("jjc GetJJCRefreshTimesConfig err: %s", iRet))
    return iRet
end

function CJJCMgr:GetJJCBoutOutConfig()
    local iRet = self:GetJJCGlobalData()["bout_out"]
    assert(iRet >= 0, string.format("jjc GetJJCBoutOutConfig err: %s", iRet))
    return iRet
end

function CJJCMgr:GetJJCBarrageShowConfig()
    local iRet = self:GetJJCGlobalData()["jjc_barrage_show"]
    assert(iRet >= 0, string.format("jjc GetJJCBarrageShowConfig err: %s", iRet))
    return iRet
end

function CJJCMgr:GetJJCBarrageSendConfig()
    local iRet = self:GetJJCGlobalData()["jjc_barrage_send"]
    assert(iRet >= 0, string.format("jjc GetJJCBarrageSendConfig err: %s", iRet))
    return iRet
end

function CJJCMgr:UpdateJJCTop3(lRankData)
    self:WaitLoaded(function (oJJCMgr)
        oJJCMgr:_UpdateJJCTop32(lRankData)
    end)
end

function CJJCMgr:_UpdateJJCTop32(lRankData)
    self:Dirty()
    for iRank, mData in ipairs(lRankData) do
        local iType = mData.type
        local id = mData.id

        if iType == gamedefines.JJC_TARGET_TYPE.ROBOT then
            local oRobot = self:GetRobot(id)
            self.m_mTop3Detail[iRank] = oRobot:PackTargetInfo(iType, iRank)
        else
            global.oWorldMgr:LoadJJC(id, function (oJJCCtrl)
                self:Dirty()
                self.m_mTop3Detail[iRank] = oJJCCtrl:PackTargetInfo(iType, iRank)
            end)
        end
    end
end

function CJJCMgr:GetTop3Info()
    local mNet = {}
    for iRank, info in pairs(self.m_mTop3Detail) do
        table.insert(mNet, info)
    end
    return mNet
end

function CJJCMgr:LocateData(mData, sKey, ikey)
    local tmpdata = {}
    for _, data in ipairs(mData) do
        local iMin, iMax = table.unpack(data[sKey])
        if not iMax then
            iMax = iMin
        end
        if ikey >= iMin and ikey <= iMax then
            return data
        end
    end
    return tmpdata
end

function CJJCMgr:InitPartnerInfo(iRobotGrade, idx, iSchool)
    local mSchoolInfo = res["daobiao"]["jjc"]["school_partner"][iSchool]
    assert(mSchoolInfo, "jjc init find partner info err")

    local sRange, sMaxGrade = table.unpack(mSchoolInfo["grade"])
    local iRange = formula_string(sRange, {rlv=iRobotGrade})
    local iMinGrade = math.max(iRobotGrade - iRange,1)
    local iMaxGrade
    if sMaxGrade then
        iMaxGrade = formula_string(sMaxGrade, {rlv=iRobotGrade})
    else
        iMaxGrade = iMinGrade
    end
    if iMinGrade > iMaxGrade then
        iMinGrade = iMaxGrade
    end
    local iGrade = math.random(iMinGrade, iMaxGrade)
    
    local mSchoolRatio = {}
    local lSchoolGroup = {}    
    for _,v in pairs(mSchoolInfo["school_ratio"]) do
        mSchoolRatio[v.school] = v.weight
    end
    for i=1,4 do
        local iKey = table_choose_key(mSchoolRatio)
        if not iKey then break end

        mSchoolRatio[iKey] = nil
        table.insert(lSchoolGroup, iKey)
    end 

    local lPartnerSid = {}
    for _,iGroup in pairs(lSchoolGroup) do
        local mSchoolPartner = res["daobiao"]["jjc"]["robot_partner"][iGroup]
        assert(mSchoolPartner, string.format("jjc init partner info err iGroup:%s", iGroup))
        local mRatio = {}
        for _,v in pairs(mSchoolPartner["partner"]) do
            mRatio[v.partner] = v.weight
        end
        local iPratner = table_choose_key(mRatio)
        table.insert(lPartnerSid, iPratner)
    end
    return iGrade, lPartnerSid
end

function CJJCMgr:InitSummonInfo(iGrade, idx, iSchool)
    local lSIDs = table_key_list(res["daobiao"]["jjc"]["summon_attr"])
    return iGrade + 5, extend.Random.random_choice(lSIDs)
end

function CJJCMgr:TransRobotDaobiao()
    local oWorldMgr = global.oWorldMgr
    local iServerGrade = oWorldMgr:GetServerGrade()

    local mRoleInfo = res["daobiao"]["roletype"]
    local lRoleType = {}
    for roletype, mInfo in pairs(mRoleInfo) do
        if mInfo["roletype"] ~= 4 then
            table.insert(lRoleType, mInfo["roletype"])
        end
    end

    local lGradeAndName = {}
    local lRobotBase = res["daobiao"]["jjc"]["robot_base"]
    for _, data in ipairs(lRobotBase) do
        local iMinRank, iMaxRank = table.unpack(data["rank"])
        if not iMaxRank then
            iMaxRank = iMinRank
        end
        local sMinGrade, sMaxGrade = table.unpack(data["grade"])
        local iMinGrade = formula_string(sMinGrade, {slv=iServerGrade})
        local iMaxGrade
        if sMaxGrade then
            iMaxGrade = formula_string(sMaxGrade, {slv=iServerGrade})
        else
            iMaxGrade = iMinGrade
        end
        table.insert(lGradeAndName, {iMinRank, iMaxRank, iMinGrade, iMaxGrade, data["school_name"]})
    end
    return lRoleType, lGradeAndName
end

function CJJCMgr:GetWeaponSid(iRoleType, iGrade)
    local mWeaponInfo = res["daobiao"]["equipweapon"]
    local mSid = mWeaponInfo[iRoleType]
    if not mSid then return end

    return mSid[iGrade//10*10]
end

function CJJCMgr:GetFunHun(iRank, iGrade)
    if iRank > self:GetJJCGlobalData()["fuhun_rank"] then return end
    if iGrade < self:GetJJCGlobalData()["fuhun_grade"] then return end

    return 1
end

function CJJCMgr:InitRobot()
    local mRobots = {}
    local mRoleInfo = res["daobiao"]["roletype"]
    local lRoleType, lGradeAndName = self:TransRobotDaobiao()
    local iRobotNum = self:GetJJCGlobalData()["robot_num"]
    for idx = 1, iRobotNum do
        local iGrade, sName
        local iRoleType = extend.Random.random_choice(lRoleType)
        local iShape = mRoleInfo[iRoleType]["shape"]
        local iSchool = extend.Random.random_choice(mRoleInfo[iRoleType]["school"])

        for _,info in ipairs(lGradeAndName) do
            if idx >= info[1] and idx <= info[2] then
                iGrade = math.random(info[3], info[4])
                local mName = info[5][iSchool]
                sName = mName["name"] or "神秘人"
            end
        end
        assert(iGrade, "jjc init robot err")
        mRobots[idx] = {
            school = iSchool,
            grade = iGrade,
            name = sName,
            shape = iShape,
            icon = iShape,
            weapon = self:GetWeaponSid(iRoleType, iGrade),
            fuhun = self:GetFunHun(idx, iGrade)
        }
    end
    self:Dirty()
    self.m_mRobots = mRobots
    self:ClearJJCRobot()
end

function CJJCMgr:PackRobotRankData()
    local lData = {}
    for idx, v in ipairs(self.m_mRobots) do
        local data = {
            id = idx,
            type = gamedefines.JJC_TARGET_TYPE.ROBOT,
            school = v.school,
            grade = v.grade,
            name = v.name,
        }
        table.insert(lData, data)
    end
    return lData
end

function CJJCMgr:GetRobot(idx)
    if self.m_mRobotList[idx] then
        return self.m_mRobotList[idx]
    end
    local mRobot = self.m_mRobots[idx]
    assert(mRobot, string.format("jjc getrobot err %d", idx))
    if not mRobot.isinit then
        local iGrade, iSchool = mRobot.grade, mRobot.school
        local iPartnerGrade, lPartnerSid = self:InitPartnerInfo(iGrade, idx, iSchool)
        local iSummonGrade, iSummonSid = self:InitSummonInfo(iGrade, idx, iSchool)
        mRobot.partnergrade = iPartnerGrade
        mRobot.partners = lPartnerSid
        mRobot.summonsid = iSummonSid
        mRobot.summongrade = iSummonGrade
        mRobot.isinit = true
        self:Dirty()
    end
    local oRobot = robot.NewRobot(idx, self.m_mRobots[idx])
    self.m_mRobotList[idx] = oRobot
    return oRobot
end

function CJJCMgr:FightTargetByRank(pid, iRank)
    local f
    f = function (mRecord, mData)
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        local iType = mData.type
        local id = mData.id
        self:StartFight(oPlayer, iType, id)
    end
    interactive.Request(".rank", "rank", "GetTargetByRank", {rank = iRank}, f)
end

function CJJCMgr:GetJJCRank(pid, endfunc)
    local f
    f = function (mRecord, mData)
        local iRank = mData.rank -- iRank可能为nil
        endfunc(pid, iRank)
    end
    interactive.Request(".rank", "rank", "RequestJJCRank", {pid = pid}, f)
end

function CJJCMgr:InitJJCTarget(oPlayer, endfunc)
    local iPid = oPlayer:GetPid()
    local iMonth = self.m_iMonth
    local f
    f = function (mRecord, mData)
        local lTargets = mData.targets
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:GetJJC():SetTargets(lTargets)
            oPlayer:GetJJC():SetRankChange(false)
            oPlayer:GetJJC():SetMonth(iMonth)
            oPlayer:GetJJC():SetVersion(self.m_iVersion)
            if endfunc then
                endfunc(oPlayer)
            end
        end
    end
    interactive.Request(".rank", "rank", "RequestJJCTarget", {pid = oPlayer:GetPid()}, f)
end

function CJJCMgr:GetJJCTarget(oPlayer, endfunc)
    local iPid = oPlayer:GetPid()
    local iMonth = self.m_iMonth
    local f
    f = function (mRecord, mData)
        local lTargets = mData.targets
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:GetJJC():SetTargets(lTargets)
            oPlayer:GetJJC():SetRankChange(false)
            oPlayer:GetJJC():SetMonth(iMonth)
            if endfunc then
                endfunc(oPlayer)
            end
        end
    end
    local oJJCCtrl = oPlayer:GetJJC()
    local targets = oJJCCtrl:GetTargets()
    interactive.Request(".rank", "rank", "RequestJJCTarget", {pid = oPlayer:GetPid(), targets=targets}, f)
end

function CJJCMgr:PackTargetInfo(iType, iRank, oTarget)
    if iType == gamedefines.JJC_TARGET_TYPE.ROBOT then
        return {
            type = iType,
            id = oTarget:GetPid(),
            rank = iRank,
            name = oTarget:GetName(),
            score = oTarget:GetScore(),
            model = oTarget:GetModelInfo(),
            grade = oTarget:GetGrade(),
            fighters = oTarget:PackPartnerLineup(),
        }
    else
        return {
            type = iType,
            id = oTarget:GetPid(),
            rank = iRank,
            name = oTarget:GetName(),
            score = oTarget:GetScore(),
            model = oTarget:GetModelInfo(),
            grade = oTarget:GetGrade(),
            fighters = oTarget:PackPartnerLineup(),
        }
    end
end

function CJJCMgr:PackJJCTargetInfos(lTargets, endfunc)
    local mHandle = {
        count = #lTargets,
        datalist = {},
        loaded = false,
    }
    local oWorldMgr = global.oWorldMgr
    for _, targetinfo in ipairs(lTargets) do
        local iType = targetinfo.type
        local id = targetinfo.id
        local iRank = targetinfo.rank

        if iType == gamedefines.JJC_TARGET_TYPE.ROBOT then
            local oRobot = self:GetRobot(id)
            table.insert(mHandle.datalist, oRobot:PackTargetInfo(iType, iRank))
            self:_PackJJCTargetInfos3(mHandle, endfunc)
        else
            oWorldMgr:LoadJJC(id, function (oJJCCtrl)
                self:_PackJJCTargetInfos2(iType, iRank, oJJCCtrl, mHandle, endfunc)
            end)
        end
    end
end

function CJJCMgr:_PackJJCTargetInfos2(iType, iRank, oJJCCtrl, mHandle, endfunc)
    if not oJJCCtrl then
        mHandle.count = mHandle.count - 1
        self:_PackJJCTargetInfos3(mHandle, endfunc)
    else
        table.insert(mHandle.datalist, oJJCCtrl:PackTargetInfo(iType, iRank))
        self:_PackJJCTargetInfos3(mHandle, endfunc)
    end
end

function CJJCMgr:_PackJJCTargetInfos3(mHandle, endfunc)
    if mHandle.count <= #mHandle.datalist and not mHandle.loaded then
        mHandle.loaded = true
        endfunc(mHandle.datalist)
    end
end

function CJJCMgr:RefreshJJCTarget(oPlayer, iRank)
    self:InitJJCTarget(oPlayer, function (oPlayer)
        self:_RefreshJJCTarget2(oPlayer, iRank)
    end)
end

function CJJCMgr:_RefreshJJCTarget2(oPlayer, iRank)
    local oJJCCtrl = oPlayer:GetJJC()
    local lTargets = oJJCCtrl:GetTargets()
    local iPid = oPlayer:GetPid()
    self:PackJJCTargetInfos(lTargets, function (targetdata)
        self:_RefreshJJCTarget3(iPid, targetdata, iRank)
    end)
end

function CJJCMgr:_RefreshJJCTarget3(iPid, targetdata, iRank)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet.infos = targetdata
    mNet.refresh_time = self:GetLeftRefreshTime(oPlayer)
    if iRank then
        mNet.rank = iRank
        mNet.top3 = self:GetTop3Info()
    end
    mNet = net.Mask("GS2CJJCMainInfo", mNet)
    oPlayer:Send("GS2CJJCMainInfo",mNet)
end

function CJJCMgr:GetJJCMainInfo(oPlayer)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end
    local oJJCCtrl = oPlayer:GetJJC()
    -- oJJCCtrl:CheckInitLineup(oPlayer)
    oJJCCtrl:CheckRoFight(oPlayer)
    if not oJJCCtrl:IsInitRank(self.m_iMonth, self.m_iVersion) then
        self:GetJJCTarget(oPlayer, function (oPlayer)
            self:_GetJJCMainInfo2(oPlayer)
        end)
    else
        self:InitJJCTarget(oPlayer, function (oPlayer)
            self:_GetJJCMainInfo2(oPlayer)
        end)
    end
end

function CJJCMgr:_GetJJCMainInfo2(oPlayer)
    local oJJCCtrl = oPlayer:GetJJC()
    local lTargets = oJJCCtrl:GetTargets()
    local iPid = oPlayer:GetPid()
    self:PackJJCTargetInfos(lTargets, function (targetdata)
        self:_GetJJCMainInfo3(iPid, targetdata)
    end)
end

function CJJCMgr:_GetJJCMainInfo3(iPid, targetdata)
    self:GetJJCRank(iPid, function (iPid, iRank)
        self:_GetJJCMainInfo4(iPid, iRank, targetdata)
    end)
end

function CJJCMgr:_GetJJCMainInfo4(iPid, iRank, targetdata)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    table.sort(targetdata, function (o1, o2)
        return o1.rank < o2.rank
    end)
    local oJJCCtrl = oPlayer:GetJJC()
    local mNet = {}
    mNet.rank = iRank or 0
    mNet.infos = targetdata
    mNet.top3 = self:GetTop3Info()
    mNet.lineup = oJJCCtrl:PacketLineupInfo()
    mNet.fighttimes = oJJCCtrl:GetFightTimes()
    mNet.fightcd = self:GetJJCFightCD(oPlayer)
    mNet.hasbuy = self:GetJJCBuyTimes(oPlayer)
    mNet.nextseason = self:GetNextSeasonTime(oPlayer)
    mNet.refresh_time = self:GetLeftRefreshTime(oPlayer)
    mNet.first_gift_status = self:GetFirstGiftStatus(oPlayer)
    mNet = net.Mask("GS2CJJCMainInfo", mNet)
    oPlayer:Send("GS2CJJCMainInfo",mNet)
end

function CJJCMgr:GetNextSeasonTime(oPlayer)
    if not self.m_NextSeasonTime then
        local date = os.date("*t",get_time())
        local iMonth = date.month
        local iYear = date.year
        local iDay = 1
        if iMonth>=12 then
            iMonth = 1
            iYear = iYear + 1
        else
            iMonth = iMonth +1
        end
        local oWorldMgr = global.oWorldMgr
        local iOpenDays = oWorldMgr:GetOpenDays()
        if iOpenDays<7 then
            local iTime = os.time({year=iYear,month=iMonth,day=iDay,hour=0,min=0,sec=0})
            local iDayNo = get_dayno(iTime) - get_dayno(iNowTime)
            if iDayNo + iOpenDays < 7 then
                iMonth = iMonth + 1
            end
        end
        self.m_NextSeasonTime = os.time({year=iYear,month=iMonth,day=iDay,hour=0,min=0,sec=0})
    end
    local mData = {}
    mData.nextseason = self.m_NextSeasonTime
    mData = net.Mask("GS2CJJCMainInfo", mData)
    oPlayer:Send("GS2CJJCMainInfo", mData)
end

function CJJCMgr:SetJJCFormation(oPlayer, iFormation)
    local oJJCCtrl = oPlayer:GetJJC()
    local oFmtMgr = oPlayer:GetFormationMgr()
    if oFmtMgr:GetFmtObj(iFormation) then
        local mLogData = oPlayer:LogData()
        mLogData.formation = iFormation
        record.user("jjc", "formation", mLogData)
        oJJCCtrl:SetFormation(oPlayer, iFormation)
    end
    local mData = {}
    mData.lineup = oJJCCtrl:PacketLineupInfo()
    mData = net.Mask("GS2CJJCMainInfo", mData)
    oPlayer:Send("GS2CJJCMainInfo", mData)
end

function CJJCMgr:SetJJCSummon(oPlayer, iSummonId)
    local mLogData = oPlayer:LogData()
    mLogData.summonid = iSummonId
    record.user("jjc", "summon", mLogData)
    local oJJCCtrl = oPlayer:GetJJC()
    oJJCCtrl:SetSummon(oPlayer, iSummonId)
    local mData = {}
    mData.lineup = oJJCCtrl:PacketLineupInfo()
    mData = net.Mask("GS2CJJCMainInfo", mData)
    oPlayer:Send("GS2CJJCMainInfo", mData)
    if iSummonId > 0 then
        oPlayer:NotifyMessage(self:GetTextData(1032))
    else
        oPlayer:NotifyMessage(self:GetTextData(1017))
    end
end

function CJJCMgr:CheckFightSchool(oPlayer, lPartners)
    local mSchool = gamedefines.ASSISTANT_SCHOOL
    local iCount = 0
    if mSchool[oPlayer:GetSchool()] then
        iCount = 1
    end
    for _, iPartner in ipairs(lPartners or {}) do
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartner)
        if oPartner and mSchool[oPartner:GetSchool()] then
            iCount = iCount + 1
        end  
    end
    if iCount > self:GetAssistSchoolCnt() then
        return false, self:GetTextData(1034, {amount=self:GetAssistSchoolCnt()})
    end
    return true
end

function CJJCMgr:GetAssistSchoolCnt()
    return ASSIST_SCHOOL_CNT
end

function CJJCMgr:SetJJCPartner(oPlayer, lPartners)
    local oJJCCtrl = oPlayer:GetJJC()
    local lLineup = oJJCCtrl:GetLineup()

    local bCheck, sMsg = self:CheckFightSchool(oPlayer, lPartners)
    if #lLineup <= #lPartners and not bCheck then
        oPlayer:NotifyMessage(sMsg)
        return
    end

    oJJCCtrl:SetLineup(oPlayer, lPartners)
    local mLogData = oPlayer:LogData()
    mLogData.partner = lPartners
    record.user("jjc", "partner", mLogData)
    local mData = {}
    mData.lineup = oJJCCtrl:PacketLineupInfo()
    mData = net.Mask("GS2CJJCMainInfo", mData)
    oPlayer:Send("GS2CJJCMainInfo", mData)

    if #lPartners > #lLineup then
        oPlayer:NotifyMessage(self:GetTextData(1015)) 
    elseif #lPartners == #lLineup then
        oPlayer:NotifyMessage(self:GetTextData(1033)) 
    else
        oPlayer:NotifyMessage(self:GetTextData(1016))     
    end
end

function CJJCMgr:QueryJJCTargetLineup(oPlayer, iType, id)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    if id == 0 then
        oNotifyMgr:Notify(iPid, "错误的id")
        return
    end
    if iType == gamedefines.JJC_TARGET_TYPE.PLAYER then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:LoadJJC(id, function (oTargetJJC)
            if not oTargetJJC then
                return
            end
            self:_QueryJJCTargetLineup2(iPid, iType, id, oTargetJJC)
        end)
    else
        local oRobot = self:GetRobot(id)
        self:_QueryJJCTargetLineup2(iPid, iType, id, oRobot)
    end
end

function CJJCMgr:_QueryJJCTargetLineup2(iPid, iType, id, oTarget)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mLineup = oTarget:PacketLineupInfo()
    oPlayer:Send("GS2CJJCTargetLineupInfo", {
        target = {
            type = iType,
            id = id,
        },
        lineup = mLineup,
    })
end

function CJJCMgr:StartFight(oPlayer, iType, id)
    local iPid = oPlayer:GetPid()
    local f = function (mRecord, mData)
        local iRank = mData.rank
        self:_StartFight2(iPid, iType, id, iRank)
    end
    interactive.Request(".rank", "rank", "RequestJJCRank", {pid=id, type=iType}, f)
end

function CJJCMgr:_StartFight2(iPid, iType, id, iRank)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oNotifyMgr = global.oNotifyMgr
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer, true) then
        return
    end
    if self:GetJJCFightCD(oPlayer) > 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "挑战cd中")
        return
    end
    local oJJCCtrl = oPlayer:GetJJC()
    if oJJCCtrl:GetFightTimes() <= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "挑战剩余次数不足")
        return
    end
    if oJJCCtrl:IsRankChange() then
        oNotifyMgr:Notify(oPlayer:GetPid(), "排名已改变")
        self:RefreshJJCTarget(oPlayer)
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene:ValidJJC() then
        oNotifyMgr:Notify(oPlayer:GetPid(), "此场景不能参加竞技场")
        return
    end
    local lPartners = oPlayer.m_oPartnerCtrl:GetCurrLineupPos()
    local bCheck, sMsg = self:CheckFightSchool(oPlayer, lPartners)
    if not bCheck then
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local mTargetInfo = oJJCCtrl:GetTargetInfo(iType, id)
    if not oPlayer.m_bGMFight and not mTargetInfo then
        -- record.warning(string.format("jjc fight err: not target %d %d %d", oPlayer:GetPid(), iType, id))
        return
    end
    -- assert(mTargetInfo or oPlayer.m_bGMFight, string.format("jjc fight err: not target %d %d %d", oPlayer:GetPid(), iType, id))
    if not oPlayer.m_bGMFight and mTargetInfo.rank ~= iRank then
        oPlayer:NotifyMessage("对手排名已发生变化,请重新挑选对手")
        self:RefreshJJCTarget(oPlayer)
        return
    end 

    local mLogData = oPlayer:LogData()
    mLogData.target_type = iType
    mLogData.target_id = id
    record.user("jjc", "fight", mLogData)
    if iType == gamedefines.JJC_TARGET_TYPE.ROBOT then
        self:FightWithRobot(oPlayer, id)
    else
        self:FightWithPlayer(oPlayer, id)
    end
end

function CJJCMgr:FightWithRobot(oPlayer, id)
    local iPid = oPlayer:GetPid()
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        -- record.warning(string.format("jjcmgr.FightWithRobot haswar %d", iPid))
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if not oPlayer:IsSingle() then
        oNotifyMgr:Notify(iPid, "请一个人挑战")
        return
    end
    if self.m_mFightingRobot[id] then
        oNotifyMgr:Notify(iPid, "该玩家正在战斗中")
        return
    end
    local oJJCCtrl = oPlayer:GetJJC()
    oJJCCtrl:AddFightTimes(-1)

    local iBoutOut = self:GetJJCBoutOutConfig()
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_JJC, 
        {bout_out={bout=iBoutOut,result=2},GamePlay=self.DB_KEY,barrage_show=self:GetJJCBarrageShowConfig(),barrage_send=self:GetJJCBarrageSendConfig()})
    local iWarId = oWar:GetWarId()

    oWarMgr:EnterWar(oPlayer, iWarId, {camp_id = gamedefines.WAR_WARRIOR_SIDE.FRIEND}, true)

    local oRobot = self:GetRobot(id)
    local mCampInfo = {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY}
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, {fmtinfo=oRobot:GetFormation()})
    oWar:EnterRoPlayer(oRobot, mCampInfo)
    oWar:EnterRoPartnerList(oRobot, mCampInfo)
    self.m_mFightingRobot[id] = iWarId

    local fCallback
    fCallback = function (mArgs)
        self:OnFightEnd(iPid, gamedefines.JJC_TARGET_TYPE.ROBOT, id, mArgs)
    end
    oWarMgr:SetCallback(iWarId, fCallback)
    oWarMgr:StartWar(iWarId)
    return oWar
end

function CJJCMgr:FightWithPlayer(oPlayer, id)
    local pid = oPlayer:GetPid()
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadJJC(id, function (oJJCCtrl)
        self:_FightWithPlayer2(pid, oJJCCtrl)
    end)
end

function CJJCMgr:_FightWithPlayer2(pid, oJJCCtrl)
    assert(oJJCCtrl, string.format("jjc fight err: not jjcctrl %d", pid))
    local iTarget = oJJCCtrl:GetPid()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        -- record.warning(string.format("jjcmgr._FightWithPlayer2 haswar %d", pid))
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if not oPlayer:IsSingle() then
        oNotifyMgr:Notify(pid, "请一个人挑战")
        return
    end
    if self.m_mFightingPlayer[iTarget] then
        oNotifyMgr:Notify(pid, "该玩家正在战斗中")
        return
    end
    local oPlayerJJCCtrl = oPlayer:GetJJC()
    oPlayerJJCCtrl:AddFightTimes(-1)

    local iBoutOut = self:GetJJCBoutOutConfig()
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_JJC,  
        {bout_out={bout=iBoutOut,result=2},GamePlay=self.DB_KEY})
    local iWarId = oWar:GetWarId()

    oWarMgr:EnterWar(oPlayer, iWarId, {camp_id = gamedefines.WAR_WARRIOR_SIDE.FRIEND}, true)

    local mCampInfo = {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY}
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, {fmtinfo=oJJCCtrl:GetFormation()})
    oWar:EnterRoPlayer(oJJCCtrl, mCampInfo)
    oWar:EnterRoPartnerList(oJJCCtrl, mCampInfo)
    self.m_mFightingPlayer[iTarget] = iWarId
    oJJCCtrl:SetAlwaysActive(true)

    local fCallback
    fCallback = function (mArgs)
        self:OnFightEnd(pid, gamedefines.JJC_TARGET_TYPE.PLAYER, iTarget, mArgs)
    end
    oWarMgr:SetCallback(iWarId, fCallback)
    oWarMgr:StartWar(iWarId)
    return oWar
end

function CJJCMgr:InitMultiItem(iPid, iSid, iAmount)
    local lItems = {}
    local oItem = global.oItemLoader:GetItem(iSid)
    local iMax = math.max(1, oItem:GetMaxAmount())
    local iNum = math.floor(iAmount / math.max(1, oItem:GetMaxAmount()))
    local iLeft = iAmount % iMax
    for i=1,iNum do
        local oNewItem = global.oItemLoader:Create(iSid)
        oNewItem:SetAmount(iMax)
        table.insert(lItems, oNewItem)
    end
    if iLeft > 0 then
        local oNewItem = global.oItemLoader:Create(iSid)
        oNewItem:SetAmount(iLeft)
        table.insert(lItems, oNewItem)
    end
    return lItems
end

function CJJCMgr:OnFightEnd(pid, iTargetType, iTarget, mArgs)
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    self.m_mFightingRobot[iTarget] = nil
    self.m_mFightingPlayer[iTarget] = nil
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    -- 添加活跃
    oPlayer:MarkGrow(20)
    oPlayer.m_oScheduleCtrl:Add(1007)
    oPlayer.m_oScheduleCtrl:HandleRetrieve(1007, 1)
    oPlayer.m_oScheduleCtrl:FireJJCFightEnd()
    local oJJCCtrl = oPlayer:GetJJC()
    oJJCCtrl:CheckInitLineup(oPlayer)
    self:InitPlayerActiveTime(pid)
    local mData = res["daobiao"]["jjc"]["fight_reward"]
    local iIdx
    local bEnemyWin = false
    if mArgs.win_side == gamedefines.WAR_WARRIOR_SIDE.FRIEND then
        iIdx = 1001
    else
        iIdx = 1002
        bEnemyWin = true
        self:SetJJCFightCD(oPlayer, self:GetJJCFightCDConfig()*60)
    end
    
    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(pid, iIdx, 1) then
            return
        end
    end

    local lRewardInfos = {}
    local mRecReward = {}
    local mItem = mData[iIdx]["item"]
    for _, mInfo in ipairs(mItem) do
        local iSID = mInfo["sid"]
        local sAmount = mInfo["amont"]
        local iAmount = formula_string(sAmount, {level=oPlayer:GetGrade()})
        oPlayer:RewardItems(iSID, iAmount, "竞技场战斗")
        -- local lItems = self:InitMultiItem(pid, iSID, iAmount)
        -- for _, oItem in ipairs(lItems) do
        --     oPlayer:RewardItem(oItem, "jjcfight")
        -- end
        table.insert(lRewardInfos, {iSID, iAmount})
        mRecReward[iSID] = (mRecReward[iSID] or 0) + iAmount
    end
    
    local sExp = mData[iIdx]["exp"]
    local iExp = formula_string(sExp, {lv=oPlayer:GetGrade()})
    if iExp > 0 then
        oPlayer:RewardExp(iExp, "jjc", {bEffect = true})
    end

    local sSilver = mData[iIdx]["silver"]
    local iSilver = formula_string(sSilver,{lv=oPlayer:GetGrade()})
    if iSilver > 0 then
        oPlayer:RewardSilver(iSilver,"竞技场战斗")
    end

    local mLogData = oPlayer:LogData()
    mLogData.items = lRewardInfos
    mLogData.point = 0
    record.user("jjc", "reward", mLogData)
    if not bEnemyWin then
        local mRankData = {
            defeat_data={type=iTargetType, id=iTarget},
            type =  gamedefines.JJC_TARGET_TYPE.PLAYER,
            id = pid,
            school = oPlayer:GetSchool(),
            grade = oPlayer:GetGrade(),
            name = oPlayer:GetName(),
        }
        interactive.Request(".rank", "rank", "PushJJCDataToRank", {data=mRankData}, function (mRecord, mData)
            local iDefeatRank = mData.defeaterank
            local iRank = mData.rank
            local bChange = mData.change
            self:OnChangeRank(pid, iTarget, iTargetType, lRewardInfos, bEnemyWin, iDefeatRank, iRank, bChange)
        end)

        if oPlayer.m_oTodayMorning:Query("jjc_first_gift", 0) == 0 then
            oPlayer.m_oTodayMorning:Set("jjc_first_gift", 1)
            self:RefreshJJCFirstGiftStatus(oPlayer)
        end
    else
        self:OnChangeRank(pid, iTarget, iTargetType, lRewardInfos, bEnemyWin)
    end

    safe_call(self.TriggerSendReward, self, oPlayer, iIdx)
    statistics.system_collect_reward("sys_jjc", mRecReward, oPlayer:GetPid())
    self:LogJJCAnalyInfo(oPlayer, iTargetType, iTarget, mRecReward, not bEnemyWin)
end

function CJJCMgr:LogJJCAnalyInfo(oPlayer, iTargetType, iTarget, mRecReward, isWin)
    if not oPlayer then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["category"] = 1
    mAnalyLog["turn_times"] = oPlayer:GetJJC():GetFightTimes()
    mAnalyLog["win_mark"] = isWin
    mAnalyLog["match_player"] = ""
    mAnalyLog["reward_detail"] = analy.table_concat(mRecReward)
    if iTargetType == gamedefines.JJC_TARGET_TYPE.ROBOT then
        local mRobot = self.m_mRobots[iTarget]
        if not mRobot then return end
        mAnalyLog["match_player"] = "is_robot+"..mRobot.school.."+"..mRobot.grade
        analy.log_data("arena", mAnalyLog)
    else
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:LoadProfile(iTarget, function (o)
            if not o then return end

            mAnalyLog["match_player"] = ""..o:GetPid().."+"..o:GetSchool().."+"..o:GetGrade()
            analy.log_data("arena", mAnalyLog)    
        end)
    end
end

function CJJCMgr:OnChangeRank(pid, iTarget, iTargetType, lRewardInfos, bEnemyWin, iDefeatRank, iRank, bChange)
    iRank = iRank or 0
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mLogData = oPlayer:LogData()
    mLogData.rank = iRank
    mLogData.defeatrank = iDefeatRank or 0
    mLogData.target_id = iTarget
    mLogData.target_type  = iTargetType
    if bEnemyWin then
        mLogData.win = 1
    else
        mLogData.win = 0
    end
    record.user("jjc", "rank", mLogData)
    local sTargetName
    if iTargetType == gamedefines.JJC_TARGET_TYPE.PLAYER then
        local oJJCCtrl = oWorldMgr:GetJJC(iTarget)
        assert(oJJCCtrl, string.format("jjc fight err: OnFightEnd %d", iTarget))
        local iLogRank = iDefeatRank or 0
        if bChange then
            iLogRank = iRank
        end
        oJJCCtrl:AddJJCLog(true, oPlayer:GetName(), bEnemyWin, iLogRank)
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if oTarget then
            -- oTarget:Send("GS2CJJCNotifyLog", {})
            self:GetJJCFightLog(oTarget)
            if bChange and global.oInterfaceMgr:Get(oTarget) == gamedefines.INTERFACE_TYPE.JJC_MAINUI_TYPE then
                self:RefreshJJCTarget(oTarget, iRank)
            end
        end
        oJJCCtrl:SetAlwaysActive(false)
        if not bEnemyWin then
            oJJCCtrl:SetRankChange(true)
            oPlayer:GetJJC():SetRankChange(true)
        end
        sTargetName = oJJCCtrl:GetName()
    else
        local oRobot = self:GetRobot(iTarget)
        sTargetName = oRobot:GetName()
    end
    if bChange then
        self:SendJJCFightResult(oPlayer, bEnemyWin, iRank, iDefeatRank, lRewardInfos)
    else
        self:SendJJCFightResult(oPlayer, bEnemyWin, 0, 0, lRewardInfos)    
    end

    if iDefeatRank and bChange then
        self:InitJJCTarget(oPlayer)        
        if iDefeatRank <= 1 then
            local oToolMgr = global.oToolMgr
            local oChatMgr = global.oChatMgr
            local mChuanwen = res["daobiao"]["chuanwen"][1026]
            local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = {oPlayer:GetName(), sTargetName}})
            oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
        elseif iDefeatRank <= 10 then
            local oToolMgr = global.oToolMgr
            local oChatMgr = global.oChatMgr
            local mChuanwen = res["daobiao"]["chuanwen"][1027]
            local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = oPlayer:GetName(), rank = iDefeatRank})
            oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
        end
    end
end

function CJJCMgr:SendJJCFightResult(oPlayer, bEnemyWin, iRank, iDefeatRank, lRewardInfos)
    local mNet = {}
    mNet.result = not bEnemyWin and 1 or 0
    mNet.oldrank = iRank
    mNet.newrank = iDefeatRank
    local lInfo = {}
    for _,info in ipairs(lRewardInfos) do
        table.insert(lInfo, {sid=info[1], amount=info[2]})
    end
    mNet.items = lInfo
    oPlayer:Send("GS2CJJCFightEndInfo", mNet)
end

function CJJCMgr:GetJJCFightLog(oPlayer)
    local mNet = oPlayer:GetJJC():PacketJJCLog()
    oPlayer:Send("GS2CJJCFightLog",{logs=mNet})
end

function CJJCMgr:ValidAddFightTimes(oPlayer)
    if oPlayer:GetJJC():GetFightTimes() >= self:GetJJCFightLimitConfig() then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(1018))
        return false
    else
        return true
    end
end

function CJJCMgr:JJCBuyFightTimes(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    if not self:ValidAddFightTimes(oPlayer) then
        return
    end
    local iHasBuy = self:GetJJCBuyTimes(oPlayer)
    local mInfo = res["daobiao"]["jjc"]["buy_jjctimes"]
    local iGold = 0
    for _, info in ipairs(mInfo) do
        if iHasBuy + 1 >= info["hasbuy"][1] and iHasBuy + 1 <= info["hasbuy"][2] then
            iGold = info["gold"]
            break
        end
    end
    if iGold <= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "购买次数到达上限")
        return
    end
    if not oPlayer:ValidGoldCoin(iGold) then
        return
    end
    local mLogData = oPlayer:LogData()
    mLogData.hasbuy = iHasBuy
    mLogData.gold = iGold
    record.user("jjc", "fight_times", mLogData)
    oPlayer:ResumeGoldCoin(iGold,"购买竞技场战斗次数")
    self:AddJJCBuyTimes(oPlayer, 1)
    oPlayer:GetJJC():AddFightTimes(1)
    oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(1010))

    local mNet = {}
    mNet.fighttimes = oPlayer:GetJJC():GetFightTimes()
    mNet.hasbuy = self:GetJJCBuyTimes(oPlayer)
    mNet = net.Mask("GS2CJJCMainInfo", mNet)
    oPlayer:Send("GS2CJJCMainInfo",mNet)
end

function CJJCMgr:JJCClearCD(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local iTime = self:GetJJCFightCD(oPlayer)
    if iTime <= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "无CD无需清除")
        return
    end
    local iMin = iTime // 60
    if iTime % 60 > 0 then
        iMin = iMin + 1
    end
    local iGold = self:GetJJCClearCDCostConfig(iMin)
    if not oPlayer:ValidGoldCoin(iGold) then
        return
    end
    local mLogData = oPlayer:LogData()
    mLogData.time = iTime
    mLogData.gold = iGold
    record.user("jjc", "cd", mLogData)
    oPlayer:ResumeGoldCoin(iGold,"清除竞技场CD")
    self:ClearJJCFightCD(oPlayer)
    oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(1014))

    local mNet = {}
    mNet.fightcd = self:GetJJCFightCD(oPlayer)
    mNet = net.Mask("GS2CJJCMainInfo", mNet)
    oPlayer:Send("GS2CJJCMainInfo",mNet)
end

function CJJCMgr:TriggerSendReward(oPlayer, iReward)
    local oHuodong = global.oHuodongMgr:GetHuodong("collect")
    if not oHuodong then return end

    oHuodong:TriggerCollectReward(oPlayer:GetPid(), "jjc", iReward)    
end

function CJJCMgr:ValidReceiveFirstGift(oPlayer)
    if self:GetFirstGiftStatus(oPlayer) == 0 then
        oPlayer:NotifyMessage(self:GetTextData(1029))
        return false
    end
    if self:GetFirstGiftStatus(oPlayer) == 2 then
        oPlayer:NotifyMessage(self:GetTextData(1030))
        return false
    end
    return true
end

function CJJCMgr:TryReceiveFirstGift(oPlayer)
    if not self:ValidReceiveFirstGift(oPlayer) then return end

    local lRewardItem = self:GetJJCGlobalData()["first_win_gift"]
    local mGiveItem = {}
    for _,mItem in pairs(lRewardItem) do
        mGiveItem[mItem["sid"]] = mItem["cnt"]
    end
    if not oPlayer:ValidGive(mGiveItem) then 
        oPlayer:NotifyMessage(self:GetTextData(1031))
        return 
    end

    oPlayer.m_oTodayMorning:Set("jjc_first_gift", 2)
    for _,mItem in pairs(lRewardItem) do
        oPlayer:RewardItems(mItem["sid"], mItem["cnt"], "竞技场首胜奖励")
    end
    self:RefreshJJCFirstGiftStatus(oPlayer)
end

function CJJCMgr:C2GSRefreshJJCTarget(oPlayer)
    if oPlayer.m_oThisTemp:Query("jjc_refresh_time", 0) > 0 then
        oPlayer:NotifyMessage(self:GetTextData(1035))
        return
    end
    oPlayer.m_oThisTemp:Set("jjc_refresh_time", get_time(), 60)
    self:RefreshJJCTarget(oPlayer)
end

function CJJCMgr:GetLeftRefreshTime(oPlayer)
    local iRefreshTime = oPlayer.m_oThisTemp:Query("jjc_refresh_time", 0)
    local iLeftTime = iRefreshTime + 60 - get_time()
    if iLeftTime < 0 then return 0 end

    return iLeftTime
end

function CJJCMgr:GetTextData(idx, mReplace)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetSystemText({"jjc"}, idx, mReplace)
end

function CJJCMgr:GetJJCFightCD(oPlayer)
    return oPlayer.m_oThisTemp:Validate("jjcfightfail") or 0
end

function CJJCMgr:SetJJCFightCD(oPlayer, iSec)
    oPlayer.m_oThisTemp:Set("jjcfightfail", 1, iSec)
end

function CJJCMgr:ClearJJCFightCD(oPlayer)
    oPlayer.m_oThisTemp:Delete("jjcfightfail")
end

function CJJCMgr:GetJJCBuyTimes(oPlayer)
    return oPlayer.m_oTodayMorning:Query("jjc_buytimes", 0)
end

function CJJCMgr:AddJJCBuyTimes(oPlayer, iAdd)
    oPlayer.m_oTodayMorning:Add("jjc_buytimes", iAdd)
end

function CJJCMgr:GetFirstGiftStatus(oPlayer)
    return oPlayer.m_oTodayMorning:Query("jjc_first_gift", 0)
end

function CJJCMgr:RefreshJJCFirstGiftStatus(oPlayer)
    local mNet = {}
    mNet.first_gift_status = self:GetFirstGiftStatus(oPlayer)
    mNet = net.Mask("GS2CJJCMainInfo", mNet)
    oPlayer:Send("GS2CJJCMainInfo",mNet)
end


