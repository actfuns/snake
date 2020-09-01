--import module
local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))

HUODONGLIST = {
    ["fengyao"] = "fengyao",
    ["trapmine"] = "trapmine",
    ["normal"] = "test.normal",
    ["excellent"] = "test.excellent",
    ["treasure"] = "treasure",
    ["devil"] = "devil",
    ["arena"] = "arena",
    ["shootcraps"] = "shootcraps",
    ["dance"] = "dance",
    ["signin"] = "signin",
    ["orgcampfire"] = "orgcampfire",
    ["mengzhu"] = "mengzhu",
    ["biwu"] = "biwu",
    ["schoolpass"] = "schoolpass",
    ["moneytree"] = "moneytree",
    ["orgtask"] = "orgtask",
    ["charge"] = "charge",
    ["bottle"] = "bottle",
    ["baike"] = "baike",
    ["liumai"] = "liumai",
    ["lingxi"] = "lingxi",
    ["guessgame"] = "guessgame",
    ["jyfuben"] = "jyfuben",
    ["welfare"] = "yunying.welfare",
    ["collect"] = "yunying.collect",
    ["caishen"] = "caishen",
    ["orgwar"] = "orgwar.main",
    ["trial"] = "trial",
    ["grow"] = "grow",
    ["hfdm"] = "hfdm.main",
    ["returngoldcoin"] = "yunying.returngoldcoin",
    ["kaifudianli"] = "yunying.kaifudianli",
    ["sevenlogin"] = "yunying.sevenlogin",
    ["everydaycharge"] = "yunying.everydaycharge",
    ["xingxiu"] = "xingxiu",
    ["superrebate"] = "yunying.superrebate",
    ["onlinegift"] = "onlinegift",
    ["totalcharge"] = "yunying.totalcharge",
    ["fightgiftbag"] = "yunying.fightgiftbag",
    ["fuyuanbox"] = "fuyuanbox",
    ["dayexpense"] = "yunying.dayexpense",
    ["threebiwu"] = "threebiwu",
    ["jubaopen"] = "yunying.jubaopen",
    ["qifu"] = "yunying.qifu",
    ["everydayrank"] = "yunying.everydayrank",
    ["nianshou"] = "nianshou",
    ["drawcard"] = "yunying.drawcard",
    ["activepoint"] = "yunying.activepointgift",
    ["continuouscharge"] = "yunying.continuouscharge",
    ["continuousexpense"] = "yunying.continuousexpense",
    ["limittimediscount"] = "limittimediscount",
    ["festivalgift"] = "festivalgift",
    ["goldcoinparty"] = "yunying.goldcoinparty",
    ["mysticalbox"] = "yunying.mysticalbox",
    ["luanshimoying"] = "luanshimoying",
    ["joyexpense"] = "yunying.joyexpense",
    ["jiebai"] = "jiebai",
    ["iteminvest"] = "yunying.iteminvest",
    ["singlewar"] = "singlewar",
    ["imperialexam"] = "imperialexam",
    ["singlewar_ks"] = "kuafu_gs.singlewar",
    ["discountsale"] = "yunying.discountsale",
    ["zeroyuan"] = "zeroyuan",
    ["foreshow"] = "yunying.foreshow",
    ["retrieveexp"] = "retrieveexp",
    ["zongzigame"] = "yunying.zongzigame",
    ["duanwuqifu"] = "yunying.duanwuqifu",
    ["worldcup"] = "yunying.worldcup",
    ["treasureconvoy"] = "treasureconvoy",
}

function NewHuodongMgr(...)
    return CHuodongMgr:New(...)
end

CHuodongMgr = {}
CHuodongMgr.__index = CHuodongMgr
inherit(CHuodongMgr,logic_base_cls())

function CHuodongMgr:New()
    local o = super(CHuodongMgr).New(self)
    o.m_mHuodongList = {}
    o.m_mHuodongState = {}
    for sHuodongName, sDir in pairs(self:GetHuoDongListConfig()) do
        local sPath = string.format("huodong.%s",sDir)
        local oModule = import(service_path(sPath))
        assert(oModule,string.format("Create Huodong err:%s %s",sHuodongName,sPath))
        local oHuodong = oModule.NewHuodong(sHuodongName)
        o.m_mHuodongList[sHuodongName] = oHuodong
    end
    o.m_bAllHuodongLoaded = false
    o.m_lWaitLoadingFunc = {}
    return o
end

function CHuodongMgr:GetHuoDongListConfig()
    return HUODONGLIST
end

function CHuodongMgr:Init()
    local mAllHuodong = {}
    for sName,oHuodong in pairs(self.m_mHuodongList) do
        mAllHuodong[sName] = true
    end
    for sName,oHuodong in pairs(self.m_mHuodongList) do
        oHuodong:Init()
        oHuodong:LoadDb()
        oHuodong:WaitLoaded(function (o)
            mAllHuodong[sName] = nil
            if not next(mAllHuodong) then
                self.m_bAllHuodongLoaded = true
                self:WakeUpFunc()
            end
        end)
    end
    self:Schedule()
end

function CHuodongMgr:Execute(func)
    if self.m_bAllHuodongLoaded then
        func()
    else
        table.insert(self.m_lWaitLoadingFunc,func)
    end
end

function CHuodongMgr:WakeUpFunc()
    local lFuncs = self.m_lWaitLoadingFunc
    self.m_lWaitLoadingFunc = {}
    for _, func in ipairs(lFuncs) do
        safe_call(func)
    end
end

function CHuodongMgr:Schedule()
end

function CHuodongMgr:GetHuodong(sHuodongName)
    return self.m_mHuodongList[sHuodongName]
end

function CHuodongMgr:NewHour(mNow)
    for _, oHuodong in pairs(self.m_mHuodongList) do
        safe_call(oHuodong.NewHour, oHuodong, mNow)
    end
    if mNow.date.hour == 5 then
        self:NewDay(mNow)
    end
end

function CHuodongMgr:NewDay(mNow)
    for _, oHuodong in pairs(self.m_mHuodongList) do
        safe_call(oHuodong.NewDay, oHuodong, mNow)
        if oHuodong.m_oRewardMonitor then
            oHuodong.m_oRewardMonitor:NewHour5()
        end
    end
    self:RefreshHuodongState(mNow.time)
end

function CHuodongMgr:OnServerStartEnd()
    for _, oHuodong in pairs(self.m_mHuodongList) do
        safe_call(oHuodong.OnServerStartEnd, oHuodong)
    end
    self:RefreshHuodongState(get_time())
end

function CHuodongMgr:OnLogin(oPlayer,bReEnter)
    for _, oHuodong in pairs(self.m_mHuodongList) do
        safe_call(oHuodong.OnLogin, oHuodong, oPlayer, bReEnter)
    end
    oPlayer:Send("GS2CRefreshAllHuodongState",{hdlist = self:PackHDState()})
end

function CHuodongMgr:OnLogout(oPlayer)
    for _, oHuodong in pairs(self.m_mHuodongList) do
        safe_call(oHuodong.OnLogout, oHuodong, oPlayer)
    end
end

function CHuodongMgr:RefreshHuodongState(iTime)
    for sHuodongName, oHuodong in pairs(self.m_mHuodongList) do
        if self.m_mHuodongState[sHuodongName] and self.m_mHuodongState[sHuodongName]["state"] == gamedefines.ACTIVITY_STATE.STATE_END then
            self.m_mHuodongState[sHuodongName] = nil
        end
        if oHuodong:IsOpenDay(iTime) and not self.m_mHuodongState[sHuodongName] then
            local iScheduleID = oHuodong:ScheduleID()
            local iState = gamedefines.ACTIVITY_STATE.STATE_READY
            local sStartTime = oHuodong:GetStartTime()
            self.m_mHuodongState[sHuodongName] = {["scheduleid"]=iScheduleID, ["state"]=iState, ["time"]=sStartTime}
        end
    end
    self:RefreshAllHuoDongState()
end

function CHuodongMgr:SetHuodongState(sHuodongName, iScheduleID, iState, sTime, iOpenTimestamp)
    self.m_mHuodongState[sHuodongName] = {["scheduleid"]=iScheduleID, ["state"]=iState, ["time"]=sTime}
    local oWorldMgr = global.oWorldMgr
    self:RefreshHuoDongState( iScheduleID, iState, sTime, iOpenTimestamp)
end

function CHuodongMgr:QueryHuodongState(sHuodongName)
    return table_get_depth(self.m_mHuodongState, {sHuodongName, "state"})
end

function CHuodongMgr:HuodongState()
    return self.m_mHuodongState
end

function CHuodongMgr:TestWeekData(i)
    local mData = res["daobiao"]["schedule"]["week"]
    local lDaySchedules = {}
    for k,v in pairs(mData) do
        local scheduleid = v["ActiveID"][i]
        if scheduleid and scheduleid ~= 0 then
            table.insert(lDaySchedules, {scheduleid, v["time"]})
        end
    end
    return lDaySchedules
end

function CHuodongMgr:WeekScheduleList()
    local mWeekSchedule = {}
    for i = 1, 7 do
        local mTmpSchedule = {}
        local lDaySchedules = {}
        for _, oHuodong in pairs(self.m_mHuodongList) do
            local scheduleid = oHuodong:ScheduleID()
            local starttime = oHuodong:GetStartTime()
            if scheduleid and starttime ~= "" then
                table.insert(lDaySchedules, {scheduleid, starttime})
            end
        end
        extend.Array.append(lDaySchedules,self:TestWeekData(i))
        for _, v in ipairs(lDaySchedules) do
            local scheduleid, starttime = table.unpack(v)
            if type(starttime) == "string" then
                starttime = {starttime,}
            end
            for _, sTime in pairs(starttime) do
                if mTmpSchedule[sTime] then
                    table.insert(mTmpSchedule[sTime], scheduleid)
                else
                    mTmpSchedule[sTime] = {scheduleid,}
                end
            end
        end
        local mDaySchedules = {}
        for sTimes, lSchedule in pairs(mTmpSchedule) do
            table.insert(mDaySchedules, {["time"]=sTimes, ["scheduleid"]=lSchedule})
        end
        if mDaySchedules then
            table.insert(mWeekSchedule, {["weekday"]=i, ["daychedules"]=mDaySchedules})
        end
    end
    return mWeekSchedule
end

function CHuodongMgr:RefreshHuoDongState(iScheduleID, iState, sTime, iOpenTimestamp)
    local oHuodongMgr = global.oHuodongMgr
    local mState = {}
    mState["scheduleid"] = iScheduleID
    mState["state"] = iState
    mState["time"] = sTime
    mState["opentimestamp"] = iOpenTimestamp -- 用于前端产生预告倒计时，不填无倒计时

    local mData = {
        message = "GS2CRefreshHuodongState",
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = {
        hdlist = mState
        },
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CHuodongMgr:RefreshAllHuoDongState()
    local mNet = self:PackHDState()
    local oHuodongMgr = global.oHuodongMgr
    local mData = {
        message = "GS2CRefreshAllHuodongState",
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = {
        hdlist = mNet
        },
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CHuodongMgr:PackHDState()
    local mNet = {}
    for _ , mInfo in pairs(self.m_mHuodongState) do
        table.insert(mNet,mInfo)
    end
    return mNet
end

function CHuodongMgr:TestOP(oPlayer,iFlag,mArgs)
    local pid = oPlayer:GetPid()
    mArgs=mArgs or {}
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr=global.oChatMgr
    local mCommand={
        "100 指令集合",
        "101 所有活动刷时",
        "102 所有活动刷天",
    }

    if iFlag==100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
    elseif iFlag == 101 then
        local mNow = get_timetbl()
        self:NewHour(mNow)
        oNotifyMgr:Notify(pid, "刷时完毕")
    elseif iFlag == 102 then
        local mNow = get_timetbl()
        self:NewDay(mNow)
        oNotifyMgr:Notify(pid, "刷天完毕")
    end
end

function CHuodongMgr:CallHuodongFunc(sHuodongName, sFunc, ...)
    local oHuodong = self:GetHuodong(sHuodongName)
    if not oHuodong then
        return
    end
    local fFunc = oHuodong[sFunc]
    if not fFunc then
        return
    end
    return fFunc(oHuodong, ...)
end
