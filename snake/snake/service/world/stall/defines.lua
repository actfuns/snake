function EncodeKey(iPid, iPos)
    return iPid*100 + iPos
end

function DecodeKey(iKey)
    return iKey//100, iKey%100
end

function GetItemSid(iSid)
    return iSid // 1000
end

function DecodeSid(iSid)
    local iTrueSid = math.floor(iSid/1000)
    local iQuality = math.floor(iSid%1000)
    return iTrueSid, iQuality*10+1 , (iQuality+1)*10
end

function EncodeSid(iTrueSid, iQuality)
    if not iQuality or iQuality < 1 then
        iQuality = 1
    end
    assert(iQuality>=1, "quality need greater than 1 " .. iQuality)
    return iTrueSid * 1000 + math.floor(math.max(0, (iQuality-1))/10)
end

function GetRefreshCost()
    local res = require "base.res"
    local mData = res["daobiao"]["global"]
    return tonumber(mData[107].value)
end

function GetUnlockCost()
    local res = require "base.res"
    local mData = res["daobiao"]["global"]
    return tonumber(mData[109].value)
end

function GetKeepTime()
    local res = require "base.res"
    local mData = res["daobiao"]["global"]
    return tonumber(mData[108].value) * 60
end

function InitTimeByGrade(iGrade)
    local res = require "base.res"
    local mData = res["daobiao"]["stall"]["stall_config"][1]
    local mEnv = {grade = iGrade}
    return formula_string(mData.time_delay, mEnv)
end

FUZHUAN = {
    [10190] = 1,
    [10191] = 1,
    [10192] = 1,
    [10193] = 1,
    [10194] = 1,
    [10195] = 1,
    [10196] = 1,
}

ITEM_TYPE_SYS           =1
ITEM_TYPE_STALL         =2

ITEM_SIZE_LIMIT         = 10
--ITEM_KEEP_TIME        = 18*3600
ITEM_KEEP_TIME          = 5*60
SYS_AMOUNT              = 1

ITEM_STATUS_NORMAL      = 1
ITEM_STATUS_OVERTIME    = 2
ITEM_STATUS_EMPTY       = 3

UNLOCK_GRID_GOLD        = 50
REFRESH_GOLD            = 100
REFRESH_TIME            = 300

PAGE_AMOUNT             = 8

