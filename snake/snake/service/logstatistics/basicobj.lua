local global = require "global"
local skynet = require "skynet"
local bson = require "bson"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))
local pt = extend.Table.print

function NewBasicObj(...)
    local o = CBasicObj:New(...)
    return o
end

CBasicObj = {}
CBasicObj.__index = CBasicObj
inherit(CBasicObj, logic_base_cls())

function CBasicObj:New()
    local o = super(CBasicObj).New(self)
    o.m_mCostInfos = {}
    return o
end

function CBasicObj:Init()
    self:Schedule()
end

function CBasicObj:Release()
    release(self)
end

function CBasicObj:Schedule()
end

function CBasicObj:DoAllArrage()
    self:ArrageCreateAccount()
    self:ArrageNewRole()
    self:ArrageModel()
    self:ArrageOnline()
    self:ArrageGrade()
    self:ArrageDuration()
    self:ArrageCreateDevice()
    self:ArrageLoginAct()
    self:ArrageLoginRole()
    self:ArrageLoginDev()
    self:ArrageStoryTask()
    self:ArrageRestMoney()
end

function CBasicObj:DoStatistics(iTime)
    record.info("log statistics.....")

    self.m_iTime = iTime or get_time()
end

function CBasicObj:GetStatisticsTime()
    local iStaTime = self.m_iTime or get_time()

    local date = os.date("*t", iStaTime)
    local iYear, iMonth, iDay = date.year, date.month, date.day - 1
    local iStartTime = os.time({year=iYear,month=iMonth,day=iDay,hour=0,min=0,sec=0})
    local iEndTime = iStartTime + 24 * 60 * 60 
    return iStartTime, iEndTime
end

function CBasicObj:ArrageCreateAccount()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime()

    local sTableName = "account"
    local mSearch = {subtype="create",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {account=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {table=sTableName,search=mSearch,back=mBackInfo,time=iStartTime},
        function (mRecord, mData)
            self:ArrageCreateAccount2(mData.data)
        end
    )
end

function CBasicObj:ArrageCreateAccount2(data)
    local iLimit = 1000
    local tRecord = {}
    local time = nil
    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local account = info.account
        time = info._time
        if platform and channel then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            table.insert(tRecord[platform][channel],account)
            if #tRecord[platform][channel] >= iLimit then
                record.log_unmovedb("analy","newaccount",{_time=time,platform=platform,channel=channel,alist=tRecord[platform][channel]})
                tRecord[platform][channel] = {}
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,alist in pairs(info) do
            if #alist > 0 then
                record.log_unmovedb("analy","newaccount",{_time=time,platform=platform,channel=channel,alist=alist})
            end
        end
    end
end

function CBasicObj:ArrageNewRole()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime() 

    local sTableName = "player"
    local mSearch = {subtype="newrole",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {account=true,pid=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageNewRole2(mData.data)
        end
    )
end

function CBasicObj:ArrageNewRole2(data)
    local iLimit = 1000
    local tRecord = {}
    local time = nil

    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local account = info.account
        local pid = info.pid
        time = info._time
        if platform and channel then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            table.insert(tRecord[platform][channel],pid)
            if #tRecord[platform][channel] >= iLimit then
                record.log_unmovedb("analy","newrole",{_time=time,platform=platform,channel=channel,plist=tRecord[platform][channel]})
                tRecord[platform][channel] = {}
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,plist in pairs(info) do
            if #plist > 0 then
                record.log_unmovedb("analy","newrole",{_time=time,platform=platform,channel=channel,plist=plist})
            end
        end
    end
end

function CBasicObj:ArrageCreateDevice()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime() 

    local sTableName = "player"
    local mSearch = {subtype="login",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {device=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageCreateDevice2(mData.data)
        end
    )
end

function CBasicObj:ArrageCreateDevice2(data)
    local tRecord = {}
    local time = nil
    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local device = info.mac or ""
        time = info._time
        if platform and channel then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {dlist={},newlist={}}
            table.insert(tRecord[platform][channel]["dlist"],device)
            tRecord[platform][channel]["newlist"][device] = true
        end
    end
    local sTableName = "analy"
    local mSearch = {subtype="newdevice"}
    local mBackInfo = {dlist=true,platform=true,channel=true}
    for platform,info in pairs(tRecord) do
        for channel,info2 in pairs(info) do
            mSearch["dlist"] = {["$in"]=info2["dlist"]}
            mSearch["platform"] = platform
            mSearch["channel"] = channel
            interactive.Request(".logdb", "common", "FindUnmoveLog", {table=sTableName,search=mSearch,back=mBackInfo},
                function (mRecord, mData)
                    self:ArrageCreateDevice3(platform,channel,time,info2["newlist"],mData.data)
                end
            )
        end
    end
end

function CBasicObj:ArrageCreateDevice3(platform,channel,time,newlist,data)
    local iLimit = 1000
    for _,info in pairs(data) do
        local dlist = info.dlist or {}
        for _,device in pairs(dlist) do
            newlist[device] = nil
        end
    end
    local dlist = {}
    for device,_ in pairs(newlist) do
        table.insert(dlist,device)
        if #dlist >= iLimit then
            record.log_unmovedb("analy","newdevice",{_time=time,platform=platform,channel=channel,dlist=dlist})
        end
    end
    if #dlist > 0 then
        record.log_unmovedb("analy","newdevice",{_time=time,platform=platform,channel=channel,dlist=dlist})
    end
end

function CBasicObj:ArrageLoginAct()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime() 

    local sTableName = "player"
    local mSearch = {subtype="login",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {account=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageLoginAct2(mData.data)
        end
    )
end

function CBasicObj:ArrageLoginAct2(data)
    local iLimit,tRecord,tHas,time = 1000,{},{},nil
    for _,info in pairs(data) do
        local platform = info.platform
        local channel = info.channel or ""
        local account = info.account or gamedefines.GAME_CHANNEL.develop
        time = info._time
        if platform and channel then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            tHas[platform] = tHas[platform] or {}
            tHas[platform][channel] = tHas[platform][channel] or {}
            if account and not tHas[platform][channel][account] then
                tHas[platform][channel][account] = true
                table.insert(tRecord[platform][channel],account)
                if #tRecord[platform][channel] > iLimit then
                    record.log_unmovedb("analy","loginact",{_time=time,platform=platform,channel=channel,alist=tRecord[platform][channel]})
                    tRecord[platform][channel] = {}
                end
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,alist in pairs(info) do
            if #alist > 0 then
                record.log_unmovedb("analy","loginact",{_time=time,platform=platform,channel=channel,alist=alist})
            end
        end
    end
end

function CBasicObj:ArrageLoginRole()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime() 

    local sTableName = "player"
    local mSearch = {subtype="login",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {pid=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageLoginRole2(mData.data)
        end
    )
end

function CBasicObj:ArrageLoginRole2(data)
    local iLimit,tRecord,tHas,time = 1000,{},{},nil
    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local pid = info.pid
        time = info._time
        if platform and channel then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            tHas[platform] = tHas[platform] or {}
            tHas[platform][channel] = tHas[platform][channel] or {}
            if pid and not tHas[platform][channel][pid] then
                tHas[platform][channel][pid] = true
                table.insert(tRecord[platform][channel],pid)
                if #tRecord[platform][channel] > iLimit then
                    record.log_unmovedb("analy","loginrole",{_time=time,platform=platform,channel=channel,plist=tRecord[platform][channel]})
                    tRecord[platform][channel] = {}
                end
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,plist in pairs(info) do
            if #plist > 0 then
                record.log_unmovedb("analy","loginrole",{_time=time,platform=platform,channel=channel,plist=plist})
            end
        end
    end
end

function CBasicObj:ArrageLoginDev()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime()

    local sTableName = "player"
    local mSearch = {subtype="login",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {mac=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageLoginDev2(mData.data)
        end
    )
end

function CBasicObj:ArrageLoginDev2(data)
    local iLimit,tRecord,tHas,time = 1000,{},{},nil
    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local device = info.mac
        time = info._time
        if platform and channel then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            tHas[platform] = tHas[platform] or {}
            tHas[platform][channel] = tHas[platform][channel] or {}
            if device and not tHas[platform][channel][device] then
                tHas[platform][channel][device] = true
                table.insert(tRecord[platform][channel],device)
                if #tRecord[platform][channel] > iLimit then
                    record.log_unmovedb("analy","logindev",{_time=time,platform=platform,channel=channel,dlist=tRecord[platform][channel]})
                    tRecord[platform][channel] = {}
                end
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,dlist in pairs(info) do
            if #dlist > 0 then
                record.log_unmovedb("analy","logindev",{_time=time,platform=platform,channel=channel,dlist=dlist})
            end
        end
    end
end

function CBasicObj:ArrageModel()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime() 

    local sTableName = "player"
    local mSearch = {subtype="login",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {device=true,pid=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageModel2(mData.data)
        end
    )
end

function CBasicObj:ArrageModel2(data)
    local iLimit,tRecord,tHas,time = 1000,{},{},nil
    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local model = info.device or ""
        local pid = info.pid
        time = info._time
        if platform and channel and pid then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            tRecord[platform][channel][model] = tRecord[platform][channel][model] or {}
            tRecord[platform][channel][model][pid] = true
        end
    end
    for platform,info in pairs(tRecord) do
        for channel,info2 in pairs(info) do
            local mlist = {}
            for model,plist in pairs(info2) do
                table.insert(mlist,{model=model,cnt=table_count(plist)})
                if #mlist >= iLimit then
                    record.log_unmovedb("analy","loginmodel",{_time=time,platform=platform,channel=channel,mlist=mlist})
                end
            end
            if #mlist > 0 then
                record.log_unmovedb("analy","loginmodel",{_time=time,platform=platform,channel=channel,mlist=mlist})
            end
        end
    end
end

function CBasicObj:ArrageOnline()
    local iStartTime = get_daytime({factor=-1,day=1}).time
    local iEndTime = get_daytime({day=0}).time
    iStartTime, iEndTime = self:GetStatisticsTime() 

    local sTableName = "online"
    local mSearch = {subtype="detail",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {online_cnt=true,platform=true,channel=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageOnline2(mData.data)
        end
    )
end

function CBasicObj:ArrageOnline2(data)
    local tRecord,logtime = {},nil
    for _,info in pairs(data) do
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        local online_cnt = info.online_cnt
        local _,time = bson.type(info._time)
        logtime = info._time
        if platform and channel and online_cnt then
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {maxcnt=0,avgcnt=0,interval={},num=0}
            tRecord[platform][channel]["maxcnt"] = math.max(tRecord[platform][channel]["maxcnt"],online_cnt)
            tRecord[platform][channel]["avgcnt"] = tRecord[platform][channel]["avgcnt"] + online_cnt
            tRecord[platform][channel]["num"] = tRecord[platform][channel]["num"] + 1
            table.insert(tRecord[platform][channel]["interval"],{cnt=online_cnt,ptime=info._time})
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,info2 in pairs(info) do
            table.sort(info2["interval"],function (a,b)
                local _,time1 = bson.type(a.ptime)
                local _,time2 = bson.type(b.ptime)
                return time1 < time2
            end)
            info2["avgcnt"] = info2["avgcnt"] // ( math.max(info2["num"],1) )
            record.log_unmovedb("analy","online",{
                platform=platform,channel=channel,maxcnt=info2["maxcnt"],
                avgcnt=info2["avgcnt"],interval=info2["interval"],_time=logtime
            })
        end
    end
end

function CBasicObj:ArrageGrade()
    local sTableName = "player"
    local mBackInfo = {pid=true,base_info=true,channel=true,platform=true}

    gamedb.LoadDb("logstatistics", "common", "FindDb", {table=sTableName,search={},back=mBackInfo},
        function (mRecord, mData)
            self:ArrageGrade2(mData.data)
        end
    )
end

function CBasicObj:ArrageGrade2(data)
    local iLimit = 1000
    local tRecord = {}
    local iStartTime, iEndTime = self:GetStatisticsTime()
    for _,info in pairs(data) do
        local pid = info.pid
        local baseinfo = info.base_info
        if pid and baseinfo then
            local platform = info.platform or ""
            local channel = info.channel or gamedefines.GAME_CHANNEL.develop
            local grade = baseinfo.grade or 0
            tRecord[platform] = tRecord[platform] or {}
            tRecord[platform][channel] = tRecord[platform][channel] or {}
            table.insert(tRecord[platform][channel],{pid=pid,grade=grade})
            if #tRecord[platform][channel] >= iLimit then
                record.log_unmovedb("analy","upgrade",{
                    _time=bson.date(iEndTime-1),
                    platform=platform,channel=channel,
                    plist=tRecord[platform][channel]
                    }
                )
                tRecord[platform][channel] = {}
            end
        end
    end
    
    for platform,info in pairs(tRecord) do
        for channel,plist in pairs(info) do
            if #plist > 0 then
                record.log_unmovedb("analy","upgrade",{_time=bson.date(iEndTime-1),platform=platform,channel=channel,plist=plist})
            end
        end
    end
end

function CBasicObj:ArrageDuration()
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime()

    local sTableName = "player"
    local mSearch = {subtype="logout",_time={["$gte"] = bson.date(iStartTime),["$lt"] = bson.date(iEndTime)} }
    local mBackInfo = {pid=true,platform=true,channel=true,duration=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageDuration2(mData.data)
        end
    )
end

function CBasicObj:ArrageDuration2(logout_data)
    -- local iStartTime = get_daytime({factor=-1,day=1}).time
    -- local iEndTime = get_daytime({day=0}).time
    local iStartTime, iEndTime = self:GetStatisticsTime()

    local sTableName = "player"
    local mSearch = {subtype="newday",_time={["$gt"] = bson.date(iStartTime),["$lte"] = bson.date(iEndTime)} }
    local mBackInfo = {pid=true,platform=true,channel=true,duration=true,_time=true}

    interactive.Request(".logdb", "common", "FindLog", {time=iStartTime,table=sTableName,search=mSearch,back=mBackInfo},
        function (mRecord, mData)
            self:ArrageDuration3({logout_data,mData.data})
        end
    )
end

function CBasicObj:ArrageDuration3(loglist)
    local tRecord,time = {}, nil

    for _,log in pairs(loglist) do
        for _,info in pairs(log) do
            local platform = info.platform or ""
            local channel = info.channel or gamedefines.GAME_CHANNEL.develop
            local pid = info.pid
            local duration = info.duration
            time = info._time
            if platform and channel then
                tRecord[platform] = tRecord[platform] or {}
                tRecord[platform][channel] = tRecord[platform][channel] or {}
                tRecord[platform][channel][pid] = tRecord[platform][channel][pid] or 0
                tRecord[platform][channel][pid] = tRecord[platform][channel][pid] +duration
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,info2 in pairs(info) do
            local plist ={}
            for pid,tlen in pairs(info2) do
                table.insert(plist,{pid=pid,tlen=tlen})
            end
            record.log_unmovedb("analy","duration",{
                platform = platform,channel=channel,
                plist = plist,_time=time,
            })
        end
    end

end

function CBasicObj:ArrageStoryTask()
    local sTableName = "player"
    local mBackInfo = {pid=true,task_info=true,base_info=true,channel=true,platform=true}

    gamedb.LoadDb("logstatistics", "common", "FindDb", {table=sTableName,search={},back=mBackInfo},
        function (mRecord, mData)
            self:ArrageStoryTask2(mData.data)
        end
    )
end

function CBasicObj:ArrageStoryTask2(data)
    local iLimit = 1000
    local tRecord = {}
    local iStartTime, iEndTime = self:GetStatisticsTime()
    for _,info in pairs(data) do
        local pid = info.pid
        local baseinfo = info.base_info or {}
        local task_info = info.task_info or {}
        local taskdata = task_info.TaskData or {}
        local platform = info.platform or ""
        local channel = info.channel or gamedefines.GAME_CHANNEL.develop
        if pid and taskdata then
            for tid,_ in pairs(taskdata) do
                local taskid = tonumber(tid)
                if res["daobiao"]["task"]["story"]["task"][tonumber(taskid)] then
                    tRecord[platform] = tRecord[platform] or {}
                    tRecord[platform][channel] = tRecord[platform][channel] or {}
                    table.insert(tRecord[platform][channel],{pid=pid,taskid=taskid})
                    if #tRecord[platform][channel]>= iLimit then
                        record.log_unmovedb("analy","storytask",{
                            platform=platform,channel=channel,
                            plist=tRecord[platform][channel],_time=bson.date(iEndTime-1),
                        })
                        tRecord[platform][channel] = {}
                    end
                    break
                end
            end
        end
    end

    for platform,info in pairs(tRecord) do
        for channel,plist in pairs(info) do
            if #plist > 0 then
                record.log_unmovedb("analy","storytask",{_time=bson.date(iEndTime-1),platform=platform,channel=channel,plist=plist})
            end
        end
    end
end

function CBasicObj:ArrageRestMoney()
    local sTableName = "player"
    local mBackInfo = {pid=true,["base_info.grade"]=true,channel=true,platform=true,
                       ["active_info.silver"]=true, ["active_info.gold"]=true}

    gamedb.LoadDb("logstatistics", "common", "FindDb", {table=sTableName,search={},back=mBackInfo},
        function (mRecord, mData)
            self:ArrageRestMoney2(mData.data)
        end
    )

end

function CBasicObj:ArrageRestMoney2(mData)
    local tRecord, tPlayer = {}, {}
    local iStartTime, iEndTime = self:GetStatisticsTime()
    for _, mInfo in pairs(mData) do
        local sChannel = mInfo.channel or gamedefines.GAME_CHANNEL.develop
        local iPlatform = mInfo.platform or 3
        local iGrade = mInfo.base_info.grade
        local iGold = mInfo.active_info.gold or 0
        local iSilver = mInfo.active_info.silver or 0

        local iKey = (iGrade // 10) * 10
        tRecord[iPlatform] = tRecord[iPlatform] or {}
        tRecord[iPlatform][sChannel] = tRecord[iPlatform][sChannel] or {}
        local mTmp = tRecord[iPlatform][sChannel][iKey]
        if not mTmp then
            mTmp = {silver=0, gold=0}
            tRecord[iPlatform][sChannel][iKey] = mTmp
        end
        mTmp.silver = mTmp.silver + iSilver
        mTmp.gold = mTmp.gold + iGold
        tPlayer[mInfo.pid] = {channel=sChannel, platform=iPlatform}
    end    

    for platform, mPlatform in pairs(tRecord) do
        for channel, mChannel in pairs(mPlatform) do
            for grade, mGrade in pairs(mChannel) do
                if mGrade.silver > 0 then
                    record.log_unmovedb("analy","totalsilver",{
                    _time=bson.date(iEndTime-1),
                    platform=platform,channel=channel,grade=grade,
                    value=mGrade.silver
                    })
                end

                if mGrade.gold > 0 then
                    record.log_unmovedb("analy","totalgold",{
                    _time=bson.date(iEndTime-1),
                    platform=platform,channel=channel,grade=grade,
                    value=mGrade.gold
                    })
                end
            end
        end
    end

    local sTableName = "offline"
    local mBackInfo = {pid=true,["profile_info.grade"]=true, ["profile_info.GoldCoin"]=true, ["profile_info.RplGoldCoin"]=true}  
    gamedb.LoadDb("logstatistics", "common", "FindDb", {table=sTableName,search={},back=mBackInfo},
        function (mRecord, mData)
            self:ArrageRestMoney3(mData.data, tPlayer)
        end
    )
end

function CBasicObj:ArrageRestMoney3(mData, mPlayer)
    local tRecord = {}
    local iStartTime, iEndTime = self:GetStatisticsTime()
    for _, mInfo in pairs(mData) do
        local m = mPlayer[mInfo.pid]
        if m then
            local mProfileInfo = mInfo.profile_info or {}
            local sChannel = m.channel or gamedefines.GAME_CHANNEL.develop
            local iPlatform = m.platform or 3
            local iGrade = mProfileInfo.grade or 0
            local iGoldCoin = mProfileInfo.GoldCoin or 0
            local iRpCoin = mProfileInfo.RplGoldCoin or 0

            local iKey = (iGrade // 10) * 10
            tRecord[iPlatform] = tRecord[iPlatform] or {}
            tRecord[iPlatform][sChannel] = tRecord[iPlatform][sChannel] or {}
            local mTmp = tRecord[iPlatform][sChannel][iKey]
            if not mTmp then
                mTmp = {coin=0, rpcoin=0}
                tRecord[iPlatform][sChannel][iKey] = mTmp
            end
            mTmp.coin = mTmp.coin + iGoldCoin
            mTmp.rpcoin = mTmp.rpcoin + iRpCoin
        end
    end

    for platform, mPlatform in pairs(tRecord) do
        for channel, mChannel in pairs(mPlatform) do
            for grade, mGrade in pairs(mChannel) do
                if mGrade.coin > 0 or mGrade.rpcoin then
                    record.log_unmovedb("analy","totalcoin",{
                    _time=bson.date(iEndTime-1),
                    platform=platform,channel=channel,grade=grade,
                    value=mGrade.coin, rpcoin=mGrade.rpcoin
                    })
                end
            end
        end
    end
end
