local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local interactive = require "base.interactive"
local net = require "base.net"
local mongoop = require "base.mongoop"
local record = require "public.record"
local router = require "base.router"

require "skynet.manager"

local serverinfo = import(lualib_path("public.serverinfo"))
local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))

local iNo = ...

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()
    router.DispatchC(routercmd)

    local m = serverinfo.get_local_dbs()

    local oClient = mongoop.NewMongoClient({
        host = m.game.host,
        port = m.game.port,
        username = m.game.username,
        password = m.game.password,
    })
    global.oGameDb = mongoop.NewMongoObj()
    global.oGameDb:Init(oClient, "game")

    local oGameDb = global.oGameDb

    if is_cs_server() then
        local sShowIdTableName = "showid"
        oGameDb:CreateIndex(sShowIdTableName, {show_id = 1}, {unique=true, name="show_id_index"})

        local sIdCounterTableName = "idcounter"
        oGameDb:CreateIndex(sIdCounterTableName,{type = 1},{unique=true,name="idcounter_type_index"})

    elseif is_gs_server() then
        local sPlayerTableName = "player"
        oGameDb:CreateIndex(sPlayerTableName, {pid = 1}, {unique = true, name = "player_pid_index"})
        oGameDb:CreateIndex(sPlayerTableName, {name = 1}, {name="player_name_index"})
        oGameDb:CreateIndex(sPlayerTableName, {"account", "channel", name = "player_account_index"})
        
        local sOfflineTableName = "offline"
        oGameDb:CreateIndex(sOfflineTableName,{pid = 1},{unique=true,name="offline_pid_index"})
    
        local sNameCounterTableName = "namecounter"
        oGameDb:CreateIndex(sNameCounterTableName,{name = 1},{unique=true,name="namecounter_name_index"})
    
        local sOrgTableName = "org"
        oGameDb:CreateIndex(sOrgTableName, {orgid = 1}, {unique = true, name = "org_orgid_index"})
        oGameDb:CreateIndex(sOrgTableName, {name = 1}, {name="org_name_index"})
    
        local sOrgReadyTableName = "orgready"
        oGameDb:CreateIndex(sOrgReadyTableName, {orgid = 1}, {unique = true, name = "orgready_orgid_index"})
        oGameDb:CreateIndex(sOrgReadyTableName, {name = 1}, {name="orgready_name_index"})
    
        local sRankTableName = "rank"
        oGameDb:CreateIndex(sRankTableName, {name = 1}, {unique=true, name="rank_name_index"})

        local sGlobalTableName = "global"
        oGameDb:CreateIndex(sGlobalTableName, {name = 1}, {unique=true, name="global_name_index"})
    
        local sHuoDongTableName = "huodong"
        oGameDb:CreateIndex(sHuoDongTableName, {name = 1}, {unique=true, name="huodong_name_index"})
    
        local sGuildTableName = "guild"
        oGameDb:CreateIndex(sGuildTableName, {name = 1}, {unique=true, name="guild_name_index"})
        
        local sWarVideoTableName = "warvideo"
        oGameDb:CreateIndex(sWarVideoTableName, {video_id = 1}, {unique=true, name="warvideo_id_index"})
        
        local sPriceTableName = "price"
        oGameDb:CreateIndex(sPriceTableName , {name = 1}, {unique=true, name="price_name_index"})
        
        local sStallTableName = "stall"
        oGameDb:CreateIndex(sStallTableName, {pid = 1}, {unique=true, name="stall_pid_index"})
    
        local sBulletBarrageTableName = "bulletbarrage"
        oGameDb:CreateIndex(sBulletBarrageTableName, {"id", "type", unique = true, name = "bulletbarrage_id_index"})

        local sAuctionTableName = "auction"
        oGameDb:CreateIndex(sAuctionTableName, {pid = 1}, {unique=true, name="auction_pid_index"})

        local sInviteCodeTableName = "invitecode"
        oGameDb:CreateIndex(sInviteCodeTableName, {"account", "channel", unique = true, name = "invite_account_index"})
        oGameDb:CreateIndex(sInviteCodeTableName, {"invitecode", name = "invite_code_index"})
        
        local sFeedBackTableName = "feedback"
        oGameDb:CreateIndex(sFeedBackTableName, {"pid", "id", unique = true, name = "feedback_pid_index"})
        oGameDb:CreateIndex(sFeedBackTableName, {"time", name = "feedback_time_index"})
    end


    skynet.register(".gamedb"..iNo)
    interactive.Send(".dictator", "common", "Register", {
        type = ".gamedb",
        addr = MY_ADDR,
    })
    
    record.info("gamedb service booted")
end)
