--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local mongoop = require "base.mongoop"
local bson = require "bson"
local res = require "base.res"

local bkdefines = import(service_path("bkdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function PostQueryData(mArgs)
    local oQueryObj = global.oQueryObj
    local sType = mArgs.sType
    local mData = {}
    if sType == "querylogtype" then
        mData = oQueryObj:QueryLogType(mArgs)
    elseif sType == "querysubtype" then
        mData = oQueryObj:QuerySubLogType(mArgs)
    elseif sType == "querylog" then
        local bQuery, ret = oQueryObj:QueryLog(mArgs)
        if not bQuery then 
            return {errcode=1,errmsg=ret} 
        else
            mData = ret
        end
    elseif sType == "querylogbytype" then
        mData = oQueryObj:QeuryLogByType(mArgs)
    end
    return {errcode=0,data=mData}
end

function PullData(mArgs)
    local sServerKey = mArgs.serverkey
    local sDbname = mArgs.dbname
    local sTablename = mArgs.tablename
    local oQueryObj = global.oQueryObj
    return oQueryObj:PullData(sServerKey,sDbname,sTablename)
end

function NewQueryObj(...)
    local o = QueryObj:New(...)
    return o
end

QueryObj = {}
QueryObj.__index = QueryObj

function QueryObj:New()
    local o = setmetatable({}, self)
    return o
end

function QueryObj:Init()
end

function QueryObj:GetServerGameDB(sServer)
    local oBackendObj = global.oBackendObj
    local oServer = oBackendObj.m_mServers[sServer]
    if not oServer then
        return
    end
    return oServer.m_oGameDb:GetDb()
end

function QueryObj:GetServerGameLogDB(sServer, iYear, iMonth)
    local oBackendObj = global.oBackendObj
    local oServer = oBackendObj.m_mServers[sServer]
    if not oServer then
        return
    end
    return oServer.m_oGameLogDb:GetDb(iYear, iMonth)
end

function QueryObj:GetLogParams(log,subtype)
    local mInfo = res["daobiao"]["log"][log][subtype]["log_format"]
    local idlist = {}
    local mBackInfo = {_time=true}
    local mNickName = {}
    for _,mUnit in pairs(mInfo) do
        local id = mUnit.id
        local desc = mUnit.desc
        table.insert(idlist,id)
        mBackInfo[id] = true
        mNickName[id] = desc
    end
    return idlist,mBackInfo,mNickName
end

function QueryObj:FormatQueryCmd(sCmd)
    if not sCmd or #sCmd <= 0 then return {} end

    local function Trace(sMsg)
    end
    local bSucc, mCmd = xpcall(formula_string, Trace, sCmd, {})
    if not bSucc or type(mCmd) ~= "table" then
        return
    end
    return mCmd
end

function QueryObj:FormatServer(lServerIds)
    if lServerIds and type(lServerIds) == "table" and #lServerIds > 0 then
        return lServerIds
    end
    local mServer = global.oBackendObj:GetServerList()
    return table_key_list(mServer)
end

function QueryObj:QueryLog(mArgs)
    local pid = (mArgs.pid == "" and nil) or mArgs.pid
    local log = mArgs.logType
    local subtype = mArgs.subType
    local mCmd = self:FormatQueryCmd(mArgs.cmd)
    if not mCmd then return false, "cmd error" end

    if not log or not subtype then
        return false, "no log type"
    end

    local oBackendObj = global.oBackendObj
    local serverIds = self:FormatServer(mArgs.serverIds)
    local iStartTime = bkdefines.AnalyTimeStamp2(mArgs.startTime)
    local iEndTime = bkdefines.AnalyTimeStamp2(mArgs.endTime)
    local ilimit = 1000 --bkdefines.limit
    local idlist,mBackInfo,mNickName = self:GetLogParams(log,subtype)
    table.sort(idlist)
    local iBSStartTime = bson.date(iStartTime)
    local iBSEndTime = bson.date(iEndTime)
    local mSearch = {subtype=subtype,_time = {["$gte"]=iBSStartTime,["$lt"]=iBSEndTime}}
    if pid then
        mSearch["pid"] = tonumber(pid)
    end
    for k,v in pairs(mCmd) do
        mSearch[k] = v
    end

    local tRet = {}
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)
    for _,lDate in pairs(lDateList) do
        local year, month = lDate[1], lDate[2]
        for _, sServer in pairs(serverIds) do
            local oGameLogDb = self:GetServerGameLogDB(sServer,year,month)
            if oGameLogDb then
                -- mSearch["_time"] = {["$gte"]=bson.date(iTime),["$lt"]=bson.date(iTime+24*3600)}
                local m = oGameLogDb:Find(log,mSearch,mBackInfo)
                m = m:sort({_time = 1}):limit(ilimit)
                while m:hasNext() do
                    local mData = m:next()
                    local _,time = bson.type(mData._time)
                    local sTmp = ""
                    for _,id in pairs(idlist) do
                        local name = mNickName[id]
                        local value = mData[id]
                        if type(value) == "table" then
                            value = ConvertTblToStr(value)
                        end
                        if sTmp == "" then
                            sTmp = string.format("%s: %s" ,name,tostring(value))
                        else
                            sTmp = string.format("%s  ,  %s: %s" ,sTmp,name,tostring(value))
                        end
                    end
                    table.insert(tRet,{date=bkdefines.FormatTimeToSec(time),slog=sTmp,time=time})
                    if #tRet >= ilimit then
                        break
                    end
                end
            end
            if #tRet >= ilimit then
                break
            end
        end
        if #tRet >= ilimit then
            break
        end
    end

    table.sort( tRet, function ( a , b )
        return a.time < b.time
    end)
    return true, tRet
end

function QueryObj:QeuryLogByType(mArgs)
    local sType = mArgs.logType
    local sSubType = mArgs.subType
    local lServerIds = self:FormatServer(mArgs.serverIds)
    local iStartTime = bkdefines.AnalyTimeStamp2(mArgs.startTime)
    local iEndTime = bkdefines.AnalyTimeStamp2(mArgs.endTime)
    local iBSStartTime = bson.date(iStartTime)
    local iBSEndTime = bson.date(iEndTime)
    local mSearch = {subtype=sSubType,_time = {["$gte"]=iBSStartTime,["$lt"]=iBSEndTime}}
    local iPid = mArgs.pid
    if iPid then
        mSearch["pid"] = iPid    
    end

    local tRet = {}
    local ilimit = 1000
    local _,mBackInfo,_ = self:GetLogParams(sType, sSubType)
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)
    for _,lDate in pairs(lDateList) do
        local iYear, iMonth = lDate[1], lDate[2]
        for _, sServer in pairs(lServerIds) do
            local oGameLogDb = self:GetServerGameLogDB(sServer, iYear, iMonth)
            if oGameLogDb then
                local m = oGameLogDb:Find(sType, mSearch, mBackInfo)
                m = m:sort({_time = 1}):limit(ilimit)
                while m:hasNext() do
                    local mData = m:next()
                    mData["_id"] = nil
                    local _,sTime = bson.type(mData._time)
                    mData["_time"] = nil
                    mData["time"] = sTime
                    mData["server"] = sServer
                    table.insert(tRet, mData)
                end
            end
            if #tRet >= ilimit then
                break
            end
        end
        if #tRet >= ilimit then
            break
        end
    end
    return tRet
end

function QueryObj:QuerySubLogType(mArgs)
    local logtype = mArgs["logtype"]
    local mInfo = res["daobiao"]["log"][logtype]
    local lRet, iCnt = {}, 0
    if mInfo then
        for sSubType, mData in pairs(mInfo) do
            table.insert(lRet, {value=sSubType, text=mData["explain"]})
            iCnt = iCnt + 1
        end
    end
    if #lRet <= 0 then return lRet end

    table.sort(lRet, function (v1, v2)
        if v1.text >= v2.text then
            return false
        end
        return true
    end)
    local m = lRet[1]
    m.selected = true
    return lRet
end

function QueryObj:QueryLogType(mArgs)
    local lRet = {}
    for _, lLog in pairs(bkdefines.GAME_LOG_MAP) do
        table.insert(lRet, {value=lLog[1], text=lLog[2], selected=(lLog[1]=="player")})
    end
    return lRet
end

function QueryObj:PullData(sServerKey,sDbname,sTablename)
    local oDbObj
    local iNowTime = get_time()
    local sLogDbName = os.date("%Y%m", iNowTime)
    sLogDbName = "gamelog"..sLogDbName

    if sDbname == "game" then
        oDbObj = self:GetServerGameDB(sServerKey)
    elseif sDbname == sLogDbName then
        local iYear,iMonth = bkdefines.GetDateInfo(iNowTime)
        oDbObj = self:GetServerGameLogDB(sServerKey,iYear,iMonth)
    end
    if not oDbObj then
        return {errcode=1,errmsg="no such dbname"}
    end

    local mData = {}
    local m = oDbObj:Find(sTablename,{})
    while m:hasNext() do
        local mUnit = m:next()
        mUnit._id = nil
        if mUnit._time then
            local _,time = bson.type(mUnit._time)
            mUnit._time = bkdefines.FormatTimeToSec(time)
        end
        table.insert(mData,mUnit)
    end
    return {errcode=0,data=mData}
end
