--import module
local global = require "global"
local skynet = require "skynet"
local record = require "public.record"
local bson = require "bson"
local res = require "base.res"
local bkdefines = import(service_path("bkdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local behaviordefines = import(service_path("behaviordefines"))


function NewBehaviorObj(...)
    local o = CBehaviorObj:New(...)
    return o
end

--玩家行为
CBehaviorObj = {}
CBehaviorObj.__index = CBehaviorObj

function CBehaviorObj:New()
    local o = setmetatable({}, self)
    return o
end

function CBehaviorObj:Init()
end

function CBehaviorObj:GetServers(bAllServer, lServerId)
    local oBackendObj = global.oBackendObj
    if bAllServer then
        return oBackendObj:GetServerList()
    end

    local lServer = {}
    for _, id in pairs(lServerId or {}) do
        local oServer = oBackendObj:GetServer(id)
        if oServer then
            table.insert(lServer, oServer)
        end
    end
    return lServer
end

function CBehaviorObj:GetBehaviorInfo(iType)
    local lRet = {}
    local mBehavior = res["daobiao"]["log"]["behaviorinfo"]
    for iId, mInfo in pairs(mBehavior) do
        if (iType == 0 and iId < 100) or (iType == 1 and iId > 100) then
            table.insert(lRet, mInfo)
        end
    end
    return lRet
end

function CBehaviorObj:SystemBehaviorType(mArgs)
    local lRet = {}
    for iType, mData in pairs(behaviordefines.BEHAVIOR_MAP) do
        table.insert(lRet, {value=iType, text=mData["title"], selected=(iType==1)})
    end
    return lRet
end

function CBehaviorObj:SystemBehavior(mArgs)
    local bAllServer = mArgs["allServer"]
    local lServerId = mArgs["serverIds"]
    local iStartTime = mArgs["startTime"]
    local iEndTime = mArgs["endTime"]
    local lTypeId = mArgs["type"] or {}

    local lServer = self:GetServers(bAllServer, lServerId)
    local lRet = {}
    for _, i in pairs(lTypeId) do
        local mTable
        if i == 15 then
            mTable = self:EquipMakeStatistics(lServer, iStartTime, iEndTime)
        else
            mTable = self:SystemStatistics(i, lServer, iStartTime, iEndTime)
        end
        if mTable then
            table.insert(lRet, mTable)
        end
    end
    return lRet
end

-- 普通系统行为分析
function CBehaviorObj:SystemStatistics(iType, lServer, iStartTime, iEndTime)
    local mBehaviorMap = behaviordefines.BEHAVIOR_MAP[iType]
    if not mBehaviorMap then return end
    local lSubType = mBehaviorMap["subtype"]
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)

    local mSearch = {subtype={["$in"]=lSubType}}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)} 

    local mResult = self:SearchStatistics(lServer, lDateList, mSearch)
    local mTable = {title=mBehaviorMap["title"], columns={}, data={}}
    for _, cName in pairs(mBehaviorMap["columns"]) do
        local sColName = behaviordefines.COLUMNS_TYPE[cName]
        assert(sColName, string.format("behavior statistics not column name:%s", cName))
        table.insert(mTable.columns, {field=cName, align="center", title=sColName})
    end

    for _, sSubType in pairs(lSubType) do
        local mData = mResult[sSubType] or {}
        local mDto = {name=behaviordefines.BEHAVIOR_NAME[sSubType]}
        mDto["totalCnt"] = mData["total"] or 0
        mDto["playerCnt"] = table_count(mData["pids"] or {})
        if mDto["playerCnt"] > 0 then
            mDto["avgCnt"] = mDto["totalCnt"] / mDto["playerCnt"]
        else
            mDto["avgCnt"] = 0
        end

        local mCost = mData["cost"] or {}
        mDto["amtCnt"] = mCost[gamedefines.MONEY_TYPE.GOLDCOIN] or 0
        mDto["goldCnt"] = mCost[gamedefines.MONEY_TYPE.GOLD] or 0
        mDto["silverCnt"] = mCost[gamedefines.MONEY_TYPE.SILVER] or 0
        for iKey, iValue in pairs(mCost) do
            mDto["c"..iKey] = iValue
        end
        for iKey, iValue in pairs(mData["reward"] or {}) do
            mDto["r"..iKey] = iValue
        end

        local mRow = {}
        for _, cName in pairs(mBehaviorMap["columns"]) do
            mRow[cName] = mDto[cName] or 0
        end
        table.insert(mTable.data, mRow)
    end
    return mTable
end

function CBehaviorObj:SearchStatistics(lServer, lDateList, mSearch)
    local mResult = {}
    for sServer, oServer in pairs(lServer) do
        for _,lDate in pairs(lDateList) do
            local iYear, iMonth = lDate[1], lDate[2]
            local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
            if oGameLogDb then
                local mRet = oGameLogDb:Find("statistics", mSearch, {total=true, pids=true, cost=true, subtype=true, reward=true})
                while mRet:hasNext() do
                    local m = mRet:next()
                    local mTemp = mResult[m.subtype]
                    if not mTemp then
                        mTemp = {total=0, pids={}, cost={}, reward={}}
                    end

                    mTemp["total"] = mTemp["total"] + m.total
                    for pid,_ in pairs(m.pids or {}) do
                        mTemp["pids"][pid] = true
                    end
                    for sKey, iVal in pairs(m.cost) do
                        mTemp["cost"][tonumber(sKey)] = (mTemp["cost"][tonumber(sKey)] or 0) + iVal
                    end
                    for sKey, iVal in pairs(m.reward) do
                        mTemp["reward"][tonumber(sKey)] = (mTemp["reward"][tonumber(sKey)] or 0) + iVal
                    end
                    mResult[m.subtype] = mTemp
                end
            end
        end
    end
    return mResult
end

function CBehaviorObj:EquipMakeStatistics(lServer, iStartTime, iEndTime)
    local mBehaviorMap = behaviordefines.BEHAVIOR_MAP[15]
    if not mBehaviorMap then return end
    local lSubType = mBehaviorMap["subtype"]
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)

    local mSearch = {subtype="equip_make"}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)} 

    local mResult = {}
    for sServer, oServer in pairs(lServer) do
        for _,lDate in pairs(lDateList) do
            local iYear, iMonth = lDate[1], lDate[2]
            local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
            if oGameLogDb then
                local mRet = oGameLogDb:Find("statistics", mSearch, {total=true, pids=true, cost=true, subtype=true, reward=true})
                while mRet:hasNext() do
                    local m = mRet:next()
                    local mTemp = mResult[m.subtype]
                    if not mTemp then
                        mTemp = {total=0, pids={}, cost={}, reward={}}
                    end

                    mTemp["total"] = mTemp["total"] + m.total
                    for pid,_ in pairs(m.pids or {}) do
                        mTemp["pids"][pid] = true
                    end
                    for sKey, iVal in pairs(m.cost) do
                        mTemp["cost"][tonumber(sKey)] = (mTemp["cost"][tonumber(sKey)] or 0) + iVal
                    end
                    for sKey, iVal in pairs(m.reward) do
                        mTemp["reward"][tonumber(sKey)] = (mTemp["reward"][tonumber(sKey)] or 0) + iVal
                    end
                    mResult[m.subtype] = mTemp
                end
            end
        end
    end

    local mTable = {title=mBehaviorMap["title"], columns={}, data={}}
    for _, cName in pairs(mBehaviorMap["columns"]) do
        local sColName = behaviordefines.COLUMNS_TYPE[cName]
        assert(sColName, string.format("behavior statistics not column name:%s", cName))
        table.insert(mTable.columns, {field=cName, align="center", title=sColName})
    end
    
    for _, lItem in pairs(behaviordefines.EQUIP_MAKE_ITEM) do
        local iMin,iMax = lItem[1], lItem[2]
        for i = iMin, iMax do
            local mItem = res["daobiao"]["item"][i]
            if mItem then
                table.insert(mTable.columns, {field="c"..i, align="center", title=mItem["name"]})    
            end
        end
    end

    for _, sSubType in pairs(lSubType) do
        local mData = mResult[sSubType] or {}
        local mDto = {name=behaviordefines.BEHAVIOR_NAME[sSubType]}
        mDto["totalCnt"] = mData["total"] or 0
        mDto["playerCnt"] = table_count(mData["pids"] or {})
        if mDto["playerCnt"] > 0 then
            mDto["avgCnt"] = mDto["totalCnt"] / mDto["playerCnt"]
        else
            mDto["avgCnt"] = 0
        end

        local mCost = mData["cost"] or {}
        mDto["amtCnt"] = mCost[gamedefines.MONEY_TYPE.GOLDCOIN] or 0
        mDto["goldCnt"] = mCost[gamedefines.MONEY_TYPE.GOLD] or 0
        mDto["silverCnt"] = mCost[gamedefines.MONEY_TYPE.SILVER] or 0
        for iKey, iValue in pairs(mCost) do
            mDto["c"..iKey] = iValue
        end
        for iKey, iValue in pairs(mData["reward"] or {}) do
            mDto["r"..iKey] = iValue
        end

        local mRow = {}
        for _, mCol in pairs(mTable.columns) do
            mRow[mCol["field"]] = mDto[mCol["field"]] or 0
        end
        table.insert(mTable.data, mRow)
    end
    return mTable
end

function CBehaviorObj:StallBehavior(mArgs)
    local mResult = {}
    local iType = mArgs["type"]
    if iType == 1 then
        mResult = self:StallBuyStatistics(mArgs)
    elseif iType == 2 then
        mResult = self:StallSellStatistics(mArgs)
    elseif iType == 3 then
        mResult = self:GuildBuyStatistics(mArgs)
    end
    return mResult
end

-- 交易系统(摆摊购买)
function CBehaviorObj:StallBuyStatistics(mArgs)
    local bAllServer = mArgs["allServer"]
    local lServerId = mArgs["serverIds"]
    local iStartTime = mArgs["startTime"]
    local iEndTime = mArgs["endTime"] + 24*3600
     
    local lServer = self:GetServers(bAllServer, lServerId)

    local mSearch = {subtype={["$in"]={"stall_buy"}}}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)} 

    local tResult = {}
    local iTotSliver = 0
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)
    for _, lDate in pairs(lDateList) do
        local iYear, iMonth = lDate[1], lDate[2]
        for _, oServer in pairs(lServer) do
            local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
            if oGameLogDb then
                local m = oGameLogDb:Find("economic", mSearch, 
                    {pid=true, query_id=true, buy_amount=true, buy_cost=true})
                while m:hasNext() do
                    local mLog = m:next()
                    local iSid = mLog.query_id
                    if iSid > 1000000 then
                        iSid = math.floor(iSid/1000) 
                    end

                    local mTemp = tResult[iSid]
                    if not mTemp then
                        mTemp = {pidlist={}, cnt=0, sliver=0}
                        tResult[iSid] = mTemp
                    end

                    if not table_in_list(mTemp["pidlist"], mLog.pid) then
                            table.insert(mTemp["pidlist"], mLog.pid)
                    end
                    mTemp["cnt"] = mTemp["cnt"] + mLog.buy_amount
                    mTemp["sliver"] = mTemp["sliver"] + mLog.buy_cost
                    iTotSliver = iTotSliver + mLog.buy_cost
                end
            end
        end
    end

    local lData = {}
    local res = require "base.res"    
    for iItem, mRet in pairs(tResult) do
        local mData = {}
        -- local iSid = math.floor(iItem/1000)
        mData["consumeCode"] = iItem
        local mItem = res["daobiao"]["item"][iItem]
        if mItem then
            mData["name"] = mItem["name"]
        end
        mData["playerAmt"] = #mRet["pidlist"]
        mData["num"] = mRet["cnt"]

        local mCost = mRet["costlist"]
        mData["amt"] = 0
        mData["gold"] = 0
        mData["sliver"] = mRet["sliver"] or 0
        mData["proportion"] = 0
        mData["goldProportion"] = 0
        mData["sliverProportion"] = 0

        if iTotSliver > 0 then
            mData["sliverProportion"] = mData["sliver"] / iTotSliver * 100
        end
        table.insert(lData, mData)
    end
    return lData
end

-- 交易系统(摆摊上架)
function CBehaviorObj:StallSellStatistics(mArgs)
    local bAllServer = mArgs["allServer"]
    local lServerId = mArgs["serverIds"]
    local iStartTime = mArgs["startTime"]
    local iEndTime = mArgs["endTime"]
     
    local lServer = self:GetServers(bAllServer, lServerId)
    local mSearch = {subtype={["$in"]={"stall_upitem"}}}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)} 

    local tResult = {}
    local iTotSliver = 0
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)
    for _, lDate in pairs(lDateList) do
        local iYear, iMonth = lDate[1], lDate[2]
        for _, oServer in pairs(lServer) do
            local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
            if oGameLogDb then
                local m = oGameLogDb:Find("economic", mSearch, 
                    {pid=true, amount=true, sid=true, taxfee=true})
                while m:hasNext() do
                    local mLog = m:next()
                    local mTemp = tResult[mLog.sid]
                    if not mTemp then
                        mTemp = {pidlist={}, cnt=0, sliver=0}
                    end

                    if not table_in_list(mTemp["pidlist"], mLog.pid) then
                            table.insert(mTemp["pidlist"], mLog.pid)
                    end
                    mTemp["cnt"] = mTemp["cnt"] + mLog.amount
                    mTemp["sliver"] = mTemp["sliver"] + (mLog.taxfee or 0)
                    iTotSliver = iTotSliver + (mLog.taxfee or 0)
                    tResult[mLog.sid] = mTemp
                end
            end
        end
    end

    local lData = {}
    local res = require "base.res"    
    for iItem, mRet in pairs(tResult) do
        local mData = {}
        mData["consumeCode"] = iItem
        local mItem = res["daobiao"]["item"][iItem]
        if mItem then
            mData["name"] = mItem["name"]
        end
        mData["playerAmt"] = #mRet["pidlist"]
        mData["num"] = mRet["cnt"]

        local mCost = mRet["costlist"]
        mData["amt"] = 0
        mData["gold"] = 0
        mData["sliver"] = mRet["sliver"] or 0
        mData["proportion"] = 0
        mData["goldProportion"] = 0
        mData["sliverProportion"] = 0

        if iTotSliver > 0 then
            mData["sliverProportion"] = mData["sliver"] / iTotSliver * 100
        end
        table.insert(lData, mData)
    end
    return lData
end

-- 交易系统(商会购买)
function CBehaviorObj:GuildBuyStatistics(mArgs)
    local bAllServer = mArgs["allServer"]
    local lServerId = mArgs["serverIds"]
    local iStartTime = mArgs["startTime"]
    local iEndTime = mArgs["endTime"]
     
    local lServer = self:GetServers(bAllServer, lServerId)
    local mSearch = {subtype={["$in"]={"guild_buy"}}}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)} 

    local tResult = {}
    local iTotGold = 0
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)
    for _, lDate in pairs(lDateList) do
        local iYear, iMonth = lDate[1], lDate[2]
        for _, oServer in pairs(lServer) do
            local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
            if oGameLogDb then
                local m = oGameLogDb:Find("economic", mSearch, 
                    {pid=true, amount=true, sid=true, price_old=true})
                while m:hasNext() do
                    local mLog = m:next()
                    local mTemp = tResult[mLog.sid]
                    if not mTemp then
                        mTemp = {pidlist={}, cnt=0, gold=0}
                    end

                    if not table_in_list(mTemp["pidlist"], mLog.pid) then
                            table.insert(mTemp["pidlist"], mLog.pid)
                    end
                    mTemp["cnt"] = mTemp["cnt"] + mLog.amount
                    mTemp["gold"] = mTemp["gold"] + (mLog.price_old or 0) * mLog.amount
                    iTotGold = iTotGold + (mLog.price_old or 0) * mLog.amount
                    tResult[mLog.sid] = mTemp
                end
            end
        end
    end

    local lData = {}
    local res = require "base.res" 
    for iItem, mRet in pairs(tResult) do
        local mData = {}
        mData["consumeCode"] = iItem
        local mItem = res["daobiao"]["item"][iItem]
        if mItem then
            mData["name"] = mItem["name"]
        end
        mData["playerAmt"] = #mRet["pidlist"]
        mData["num"] = mRet["cnt"]

        local mCost = mRet["costlist"]
        mData["amt"] = 0
        mData["gold"] = mRet["gold"] or 0
        mData["sliver"] = 0
        mData["proportion"] = 0
        mData["goldProportion"] = 0
        mData["sliverProportion"] = 0

        if iTotGold > 0 then
            mData["goldProportion"] = mData["gold"] / iTotGold * 100
        end
        table.insert(lData, mData)
    end
    return lData
end

function CBehaviorObj:GameSysStatistics(mArgs)
    local bAllServer = mArgs["allServer"]
    local lServerId = mArgs["serverIds"]
    local iStartTime = mArgs["startTime"]
    local iEndTime = mArgs["endTime"]
    
    local lSubType = behaviordefines.GAME_SYS_MAP["subtype"] 
    local lServer = self:GetServers(bAllServer, lServerId)
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)

    local mSearch = {subtype={["$in"]=lSubType}}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)}

    local mResult = {}
    for sServer, oServer in pairs(lServer) do
        for _,lDate in pairs(lDateList) do
            local iYear, iMonth = lDate[1], lDate[2]
            local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
            if oGameLogDb then
                local mRet = oGameLogDb:Find("gamesys", mSearch, {total=true, pids=true, subtype=true, reward=true})
                while mRet:hasNext() do
                    local m = mRet:next()
                    local mTemp = mResult[m.subtype]
                    if not mTemp then
                        mTemp = {total=0, pids={}, reward={}}
                    end

                    mTemp["total"] = mTemp["total"] + (m["total"] or 0)
                    for pid,_ in pairs(m.pids or {}) do
                        mTemp["pids"][pid] = true
                    end
                    for sKey, iVal in pairs(m.reward or {}) do
                        mTemp["reward"][tonumber(sKey)] = (mTemp["reward"][tonumber(sKey)] or 0) + iVal
                    end
                    mResult[m.subtype] = mTemp
                end
            end
        end
    end
    
    local mTable = {title=behaviordefines.GAME_SYS_MAP["title"], columns={}, data={}}
    for _, cName in pairs(behaviordefines.GAME_SYS_MAP["columns"]) do
        local sColName = behaviordefines.COLUMNS_TYPE[cName]
        assert(sColName, string.format("behavior statistics not column name:%s", cName))
        table.insert(mTable.columns, {field=cName, align="center", title=sColName})
    end

    for _, sSubType in pairs(lSubType) do
        local mData = mResult[sSubType] or {}
        local mDto = {name=behaviordefines.BEHAVIOR_NAME[sSubType]}
        mDto["totalCnt"] = mData["total"] or 0
        mDto["playerCnt"] = table_count(mData["pids"] or {})
        if mDto["playerCnt"] > 0 then
            mDto["avgCnt"] = mDto["totalCnt"] / mDto["playerCnt"]
        else
            mDto["avgCnt"] = 0
        end

        local mReward = mData["reward"] or {}
        for iKey, iValue in pairs(mReward) do
            mDto["r"..iKey] = iValue
        end

        local mRow = {}
        for _, cName in pairs(behaviordefines.GAME_SYS_MAP["columns"]) do
            mRow[cName] = mDto[cName] or 0
        end
        table.insert(mTable.data, mRow)
    end

    return mTable
end

function CBehaviorObj:OrgMemberStatistics(mArgs)
    local bAllServer = mArgs["allServer"]
    local lServerId = mArgs["serverIds"]
    local iSearchTime = mArgs["searchTime"]
    local iStartTime = iSearchTime
    local iEndTime = iSearchTime + 24 * 3600

    local lSubType = behaviordefines.GAME_SYS_MAP["subtype"] 
    local lServer = self:GetServers(bAllServer, lServerId)
    local lDateList = bkdefines.GetYearMonthList(iStartTime, iEndTime)
    local lDate = lDateList[1]

    local mSearch = {subtype={["$in"]={"org_member"}}}
    mSearch["_time"] = {["$gte"]=bson.date(iStartTime), ["$lt"]=bson.date(iEndTime)}

    local iOrgLevel, iPlayerGrade = 10, 60
    local mMember, mOrg, iTotalMem, iTotalOrg = {}, {}, 0, 0
    for sServer, oServer in pairs(lServer) do
        local iYear, iMonth = lDate[1], lDate[2]
        local oGameLogDb = oServer.m_oGameLogDb:GetDb(iYear, iMonth)
        if oGameLogDb then
            local m = oGameLogDb:FindOne("gamesys", mSearch, {member=true, org=true})
            if m then
                for sLv, mLevel in pairs(m.member or {}) do
                    iOrgLevel = math.max(tonumber(sLv), iOrgLevel)
                    local mLvData = mMember[sLv]
                    if not mLvData then
                        mLvData = {data={}, total=0}
                        mMember[sLv] = mLvData
                    end
                    for sGrade, iCnt in pairs(mLevel) do
                        iPlayerGrade = math.max(tonumber(sGrade), iPlayerGrade)
                        mLvData["data"][sGrade] = (mLvData["data"][sGrade] or 0) + iCnt
                        mLvData["total"] = (mLvData["total"] or 0) + iCnt
                        iTotalMem = iTotalMem + iCnt
                    end
                end
                for sLv, iCnt in pairs(m.org or {}) do
                    mOrg[sLv] = (mOrg[sLv] or 0) + iCnt
                    iTotalOrg = iTotalOrg + iCnt
                end
            end
        end
    end
    
    local mTable = {title="帮派成员统计", columns={}, data={}}
    table.insert(mTable.columns, {field="name", align="center", title="帮派等级"})
    table.insert(mTable.columns, {field="number", align="center", title="帮派数量"})
    table.insert(mTable.columns, {field="rate", align="center", title="比率"})
    table.insert(mTable.columns, {field="playerCnt", align="center", title="人数"})
    table.insert(mTable.columns, {field="playerRate", align="center", title="人数百分比"})
    for i = 10, iPlayerGrade, 10 do
        table.insert(mTable.columns, {field="grade"..i, align="center", title=i.."级玩家"})
    end

    for iOrg = 1, iOrgLevel do
        local mRow = {}
        local sOrgLv = db_key(iOrg)
        mRow["name"] = iOrg.."级帮派"
        mRow["number"] = mOrg[sOrgLv] or 0
        mRow["rate"] = (mRow["number"]) / math.max(1, iTotalOrg)
        
        local mLvMember = mMember[sOrgLv] or {}
        mRow["playerCnt"] = mLvMember["total"] or 0
        mRow["playerRate"] = (mRow["playerCnt"]) / math.max(1, iTotalMem) * 100
        for iGrade = 10, iPlayerGrade, 10 do
            local sGrade = db_key(iGrade)
            mRow["grade"..iGrade] = 0
            if mLvMember["data"] then
                mRow["grade"..iGrade] = mLvMember["data"][sGrade] or 0
            end
        end
        table.insert(mTable.data, mRow)
    end
    return mTable
end
