
local skynet = require "skynet"
local servicetimer = require "base.servicetimer"

local floor = math.floor
local max = math.max
local min = math.min

function get_time(bFloat)
    local iTime = servicetimer.ServiceTime()
    if bFloat then
        return iTime/100
    else
        return floor(iTime/100)
    end
end

function get_current()
    return servicetimer.ServiceNow()
end

function get_second()
    return floor(get_current()/100)
end

function get_ssecond()
    return get_current()/100
end

function get_msecond()
    return get_current()*10
end

function get_starttime()
    return servicetimer.ServiceStartTime()
end

--2017/1/2
local iStandTime = 1483286400

function get_dayno(iSec)
    local iSec = iSec or get_time()
    local iTime = iSec - iStandTime
    local iDayNo = floor(iTime // (3600*24))
    return iDayNo
end

--5点算天
function get_morningdayno(iSec)
    local iSec = iSec or get_time()
    local iTime = iSec - iStandTime
    local iDayMorningNo = floor((iTime-5*3600) // (3600*24))
    return iDayMorningNo
end

function get_weekno(iSec)
    local iSec = iSec or get_time()
    local iTime = iSec - iStandTime
    local iWeekNo = floor(iTime//(7*3600*24))
    return iWeekNo
end

--5点算星期
function get_morningweekno(iSec)
    local iSec = iSec or get_time()
    local iTime = iSec - iStandTime
    local iWeekNo = floor((iTime-5*3600)//(7*3600*24))
    return iWeekNo
end

function get_hourno(iSec)
    local iSec = iSec or get_time()
    local iTime = iSec - iStandTime
    local iHourNo = floor(iTime//3600)
    return iHourNo
end

function get_weekno2time(ino)
    local iSec = ino*604800 + iStandTime
    return iSec
end

function get_morningweekno2time(ino)
    local iSec = ino*604800+18000 + iStandTime
    return iSec
end


function get_timetbl(iTime)
    iTime = iTime or get_time()
    local retbl = {}
    retbl.time = iTime
    retbl.date = os.date("*t",iTime)
    retbl.date.wday = get_weekday(iTime)
    return retbl
end

function get_daytime(tab)
    local iFactor = tab.factor  or 1                                        --正负因子
    local iDay = tab.day or 1                                                  --距离天数
    local iAnchor = tab.anchor or 0                                     --锚点
    local iCurTime = tab.time or get_time()
    iDay = iDay * iFactor                                                             
    local iTime = iCurTime + iDay * 3600 * 24
    local date = os.date("*t",iTime)
    iTime = os.time({year=date.year,month=date.month,day=date.day,hour=iAnchor,min=0,sec=0})
    return get_timetbl(iTime)
end

function get_hourtime(tab)
    local iFactor = tab.factor or 1                                                --正负因子
    local iHour = tab.hour or 1                                                     --距离小时
    local iCurTime = tab.time or get_time()
    iHour = iHour * iFactor
    local iTime = iCurTime + iHour * 3600
    local date = os.date("*t",iTime)
    iTime = os.time({year=date.year,month=date.month,day=date.day,hour=date.hour,min=0,sec=0})
    return get_timetbl(iTime)
end

function get_mintime(tab)
    local iFactor = tab.factor or 1                                                --正负因子
    local iMin = tab.min or 1                                                      --距离小时
    local iCurTime = tab.time or get_time()
    iMin = iMin * iFactor
    local iTime = iCurTime + iMin * 60
    local date = os.date("*t",iTime)
    iTime = os.time({year=date.year,month=date.month,day=date.day,hour=date.hour,min=date.min,sec=0})
    return get_timetbl(iTime)
end

function get_wdaytime(tab)
    local iFactor = tab.factor or 1
    local iDelta = tab.delta or 0
    iDelta = iFactor * iDelta
    local iWDay = tab.wday or 1
    local iHour = tab.hour or 0
    local iMin = tab.min or 0
    local iCurTime = tab.time or get_time()

    local iTime = iCurTime + iDelta * 3600 * 24 * 7
    local date = get_timetbl(iTime).date
    iTime = iTime + (iWDay - date.wday) * 3600 * 24 + (iHour - date.hour) * 3600 + (iMin - date.min) * 60 - date.sec
    return get_timetbl(iTime)
end

function get_weekday(iTime)
    local iTime = iTime or get_time()
    local wday = tonumber(os.date("%w",iTime))
    if wday == 0 then
        return 7
    else
        return wday
    end
end

function get_morningweekday(iTime)
    local iTime = iTime or get_time()
    return get_weekday(iTime - 5 * 3600)
end

function get_mondaytime(iTime)
    local iTime = iTime or get_time()
    local wday = get_weekday(iTime)
    return iTime - (wday - 1) * 24 * 3600
end

function get_format_time(iTime)
    iTime = iTime or get_time()
    return os.date("%c", iTime)
end

function get_time_format_str(iTime, sFormat)
    iTime = iTime or get_time()
    return os.date(sFormat, iTime)
end

function get_second2string(sec)
    local s = math.floor(sec % 60)
    local m = math.floor((sec / 60)  % 60)
    local h = math.floor(sec / 3600)
    local str = ""
    if h > 0 then
        str = string.format("%s%02d时",str,h)
    end
    str = string.format("%s%02d分",str,m)
    str = string.format("%s%02d秒",str,s)
    return str
end

--[[
    "2018-2-1"
    "2018-02-01 12"
    "2018-02-01 12:13"
    "2018-02-01 12:13:14"
]]
function get_str2timestamp(s)
    assert(s and type(s)=="string", "timeop get_str2timestamp s not a string")
    local dl = split_string(s, " ")
    local datel = split_string(dl[1], "-")
    local timel = dl[2] and split_string(dl[2], ":") or {}
    local year, month, day = table.unpack(datel)
    assert(year and month and day, string.format("timeop get_str2timestamp date error %s", s))
    local hour, minute, secend = table.unpack(timel)
    local t = {
        year = year,
        month = month,
        day = day,
        hour = hour or 0,
        min = minute or 0,
        sec = secend or 0,
    }
    return os.time(t)
end
