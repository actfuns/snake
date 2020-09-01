--import module
local global = require "global"
local skynet = require "skynet"
local cjson = require "cjson"
local interactive = require "base.interactive"
local record = require "public.record"
local router = require "base.router"

function HttpGameServer(mRecord, mData)
    local oBackendObj = global.oBackendObj
    local sServer = mData["servers"]

    local lServer = {}
    if mData["allserver"] then
        lServer = oBackendObj:GetServerListForGM()
    else
        local lServerId = split_string(sServer, ",")
        lServer = oBackendObj:GetServerListForGM(lServerId)
    end

    if #lServer <= 0 then
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = 1,
            errmsg = "not find server",
        })
        record.warning(string.format("HttpGameServer not find server %s", sServer))
        return
    end

    local iCnt = #lServer
    for _, oServer in pairs(lServer) do
        local sServerKey = oServer:ServerID()
        router.Request(get_server_tag(sServerKey), ".world", "gmtools", "Forward", mData, function(m1, mRes)
            iCnt = iCnt - 1
            if mRes.errcode and mRes.errcode > 0 then
                record.error(string.format("server:%s, errCode:%s, errMsg:%s", sServerKey, mRes.errcode, mRes.errmsg))
            end
            if iCnt <= 0 then
                interactive.Response(mRecord.source, mRecord.session, mRes)
            end
        end)
    end
end

function RedeemCode(mRecord, mData)
    router.Request("cs", ".redeemcode", "common", "Forward", mData, function (m1, m2)
        interactive.Response(mRecord.source, mRecord.session, m2)
    end)
end

function SearchPlayer(mRecord, mData)
    local oBackendObj = global.oBackendObj
    local iType = mData["type"]
    local lCondition = mData["data"]
    -- local mData["servers"]

    local mSearch = {}
    if iType == 1 then
        mSearch = {name = {['$in'] = lCondition}}
    else
        mSearch = {pid = {['$in'] = lCondition}}
    end

    local oGmToolsObj = global.oGmToolsObj
    local br, mRet = safe_call(oGmToolsObj.SearchPlayer, oGmToolsObj, mSearch)
    if br then
        interactive.Response(mRecord.source, mRecord.session, {errcode=0, data=mRet})
    else
        interactive.Response(mRecord.source, mRecord.session, {errcode=1, data={}})
    end
end

function SearchPlayerSummon(mRecord, mData)
    local oBackendObj = global.oBackendObj

    local iPid = mData["pid"]
    local sName = mData["pname"]
    -- local mData["servers"]
    local lServers = oBackendObj:GetServersByIds()

    local mSearch = {}
    if iType == 1 then
        mSearch = {name = sName}
    else
        mSearch = {pid = iPid}
    end

    local oGmToolsObj = global.oGmToolsObj
    local br, mRet = safe_call(oGmToolsObj.SearchPlayerSummon, oGmToolsObj, lServers, mSearch)
    if br then
        interactive.Response(mRecord.source, mRecord.session, {errcode=0, data=mRet})
    else
        interactive.Response(mRecord.source, mRecord.session, {errcode=1, "server error"})
    end
end

function SearchOrg(mRecord, mData)
    local iOrg = mData["orgid"]
    local sName = mData["orgname"]
    local sServer = mData["serverid"]

    local oBackendObj = global.oBackendObj
    local oServer = oBackendObj:GetServer(sServer)
    if not oServer then
       interactive.Response(mRecord.source, mRecord.session, {errcode=1, "server not find"})
       return 
    end

    local mSearch = {}
    if iOrg then
        mSearch = {orgid = iOrg}
    else
        mSearch = {name = sName}
    end

    local oGmToolsObj = global.oGmToolsObj
    local br, mRet = safe_call(oGmToolsObj.SearchOrg, oGmToolsObj, oServer, mSearch)
    if br then
        interactive.Response(mRecord.source, mRecord.session, {errcode=0, data=mRet})
    else
        interactive.Response(mRecord.source, mRecord.session, {errcode=2, data={}})
    end
end

function SearchPlayerList(mRecord, mData)
    local oGmToolsObj = global.oGmToolsObj
    local br, mRet = safe_call(oGmToolsObj.SearchPlayerList, oGmToolsObj, mData)
    if br then
        interactive.Response(mRecord.source, mRecord.session, {errcode=0, data=mRet})
    else
        interactive.Response(mRecord.source, mRecord.session, {errcode=2, data={}}) 
    end
end

function SaveOrUpdateNotice(mRecord, mData)
    router.Send("cs", ".serversetter", "common", "SaveOrUpdateNotice", mData)
    interactive.Response(mRecord.source, mRecord.session, {})
end

function GetNoticeList(mRecord, mData)
    router.Request("cs", ".serversetter", "common", "GetNoticeList", mData, function (r, d)
        interactive.Response(mRecord.source, mRecord.session, d)
    end)
end

function DeleteNotice(mRecord, mData)
    router.Send("cs", ".serversetter", "common", "DeleteNotice", mData)
    interactive.Response(mRecord.source, mRecord.session, {})
end

function PublishNotice(mRecord, mData)
    router.Send("cs", ".serversetter", "common", "PublishNotice", mData)
    interactive.Response(mRecord.source, mRecord.session, {})
end

function GetLoopNoticeList(mRecord, mData)
    local oNoticeMgr = global.oNoticeMgr
    local lRet = oNoticeMgr:GetLoopNoticeList()
    interactive.Response(mRecord.source, mRecord.session, {errcode=0, data=lRet})
end

function SaveOrUpdateLoopNotice(mRecord, mData)
    local oNoticeMgr = global.oNoticeMgr
    oNoticeMgr:SaveOrUpdateLoopNotice(mData)
    interactive.Response(mRecord.source, mRecord.session, {})
end

function DeleteLoopNotice(mRecord, mData)
    local oNoticeMgr = global.oNoticeMgr
    local lId = mData["ids"]
    oNoticeMgr:DeleteLoopNotice({id = {['$in'] = lId}}, lId)
    interactive.Response(mRecord.source, mRecord.session, {})
end

function PublishLoopNotice(mRecord, mData)
    local oNoticeMgr = global.oNoticeMgr
    local lId = mData["ids"]
    oNoticeMgr:PublishLoopNotice({id = {['$in'] = lId}})
    interactive.Response(mRecord.source, mRecord.session, {})
end

function QueryFeedBackList(mRecord, mData)
    local oBackendObj = global.oBackendObj

    local iPlatform = mData["platform"]
    local iChannel = mData["channel"]
    local sServer = mData["serverid"]
    -- 起始时间 和 终止时间 戳 date = { starttime = , endtime = }
    local mDate = mData["date"]
    local iType = mData["type"]
    local mCond = {}
    mCond["info.type"] = iType
    mCond["info.playerinfo.platform"] = iPlatform
    mCond["info.playerinfo.channel"] = iChannel
    mCond["info.time"] = {["$gte"]=mDate.starttime, ['$lte'] = mDate.endtime}

    local lServers = {}
    if sServer then
        local lServerId = split_string(sServer, ",")
        if #lServerId > 0 then
            lServers = oBackendObj:GetServerListForGM(lServerId)
        end
    else
        lServers = oBackendObj:GetServerListForGM()
    end

    if #lServers <= 0 then
        interactive.Response(mRecord.source, mRecord.session, {errcode = 1, errmsg = "not find server"})
    end
    
    local oGmToolsObj = global.oGmToolsObj
    local br,mRet = safe_call(oGmToolsObj.QueryFeedBackList, oGmToolsObj, lServers, mCond)
    
    if br  then
        interactive.Response(mRecord.source, mRecord.session, {errcode = 0, data = mRet})
    else
        interactive.Response(mRecord.source, mRecord.session, {errcode = 1, errmsg = "server query error"})
    end
end

function SetCustomerServiceInfo(mRecord, mData)
    router.Send("cs", ".backendinfo", "common", "SetCustServInfo", mData.data)
    interactive.Response(mRecord.source, mRecord.session, {errcode = 0})
end

function GetSysSwitchInfo(mRecord, mData)
    router.Request("cs", ".backendinfo", "common", "GetSysSwitchInfoToBS", nil, function(r, d)
        interactive.Response(mRecord.source, mRecord.session, d)
    end)
end

function SetSysSwitchInfo(mRecord, mData)
    router.Send("cs", ".backendinfo", "common", "SetSysSwitchInfo", mData.data)
    interactive.Response(mRecord.source, mRecord.session, {errcode = 0})
end
