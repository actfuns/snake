local global = require "global"
local skynet = require "skynet"
local net = require "base.net"
local interactive = require "base.interactive"
local basehook = require "base.basehook"
local servicetimer = require "base.servicetimer"
local texthandle = require "base.texthandle"
local router = require "base.router"
local res = require "base.res"
local record = require "public.record"
local serverdefines = require "public.serverdefines"

require "skynet.manager"
local netcmd = import(service_path("netcmd.init"))
local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))
local demisdk = import(lualib_path("public.demisdk"))
local worldobj = import(service_path("kuafu.worldobj"))
local sceneobj = import(service_path("sceneobj"))
local warobj = import(service_path("warobj"))
local gmobj = import(service_path("gmobj"))
local publicobj = import(service_path("publicobj"))
local npcobj = import(service_path("npcobj"))
local effectobj = import(service_path("effect/effectobj"))
local cbobj = import(service_path("cbobj"))
local notify = import(service_path("notify"))
local uiobj = import(service_path("uiobj"))
local yibaomgr = import(service_path("task/yibao/yibaomgr"))
local runringmgr = import(service_path("task/runring/runringmgr"))
local interfacemgr = import(service_path("interfacemgr"))
local team = import(service_path("team"))
local chat = import(service_path("chat"))
local huodong = import(service_path("kuafu.huodong"))
local mailmgr = import(service_path("kuafu.mailmgr"))
local rewardmgr = import(service_path("rewardmgr"))
local friendobj = import(service_path("kuafu.friendobj"))
local toolmgr = import(service_path("toolobj"))
local orgmgr = import(service_path("orgmgr"))
local newbieguide = import(service_path("newbieguide"))
local sysopenmgr = import(service_path("sysopenmgr"))
local titlemgr = import(service_path("titlemgr"))
local rankmgr = import(service_path("rankmgr"))
local testmgr = import(service_path("testmgr"))
local rename = import(service_path("rename"))
local jjcmgr = import(service_path("jjcmgr"))
local challengemgr = import(service_path("challengemgr"))
local guildmgr = import(service_path("shop.guild"))
local showidmgr = import(service_path("showidmgr"))
local stallmgr = import(service_path("stallmgr"))
local catalogmgr = import(service_path("stall.stallcatalog"))
local redpacketmgr = import(service_path("redpacket.redpacketmgr"))
local fubenmgr = import(service_path("fubenmgr"))
local summonmgr = import(service_path("summonmgr"))
local videomgr = import(service_path("warvideo"))
local shimenmgr = import(service_path("task.shimenmgr"))
local handleghost = import(service_path("task/ghost/handleghost"))
local handleschoolpass = import(service_path("task/schoolpass/handleschoolpass"))
local bulletbarragemgr = import(service_path("bulletbarrage"))
local ridemgr = import(service_path("ridemgr"))
local auction = import(service_path("auction.auction"))
local taskmgr = import(service_path("task.taskmgr"))
local loadtask = import(service_path("task.loadtask"))
local handletask = import(service_path("task.handletask"))
local loaditem = import(service_path("item.loaditem"))
local handleitem = import(service_path("item.handleitem"))
local playerloadskill = import(service_path("skill.loadskill"))
local lottery = import(service_path("lottery"))
local backendmgr = import(service_path("backendmgr"))
local derivedfilemgr = import(lualib_path("public.derivedfile"))
local loginmonitor = import(service_path("loginmonitor"))
local equipmgr = import(service_path("equipmgr"))
local gamepush = import(service_path("gamepush"))
local paymgr = import(service_path("paymgr"))
local confirmmgr = import(service_path("confirmmgr"))
local versionmgr = import(service_path("versionmgr"))
local redeemcodemgr = import(service_path("redeemcodemgr"))
local behaviorevmgr = import(service_path("player/behaviorevmgr"))
local shopmgr = import(service_path("shopmgr"))
local mailaddrmgr = import(service_path("mailaddrmgr"))
local scorecache = import(service_path("scorecache"))
local offsetmgr = import(service_path("onlineoffset"))
local yunyingmgr = import(service_path("yunyingmgr"))
local mergermgr = import(service_path("mergermgr"))
local engagemgr = import(service_path("engagemgr"))
local fastbuymgr = import(service_path("kuafu.fastbuymgr"))
local gamedb = import(lualib_path("public.gamedb"))
local fabaomgr = import(service_path("fabaomgr"))
local artifactmgr = import(service_path("artifactmgr"))
local wingmgr = import(service_path("wingmgr"))
local hottopic = import(service_path("huodong.yunying.hottopic"))
local marrymgr = import(service_path("marrymgr"))
local mentoring = import(service_path("kuafu.mentoring"))
local servermgr = import(service_path("servermgr"))

skynet.start(function()
    skynet.priority(true)
    skynet.change_gc_size(512)

    net.Dispatch(netcmd)
    interactive.Dispatch(logiccmd)
    texthandle.Dispatch()
    router.DispatchC(routercmd)

    global.oDerivedFileMgr = derivedfilemgr.NewDerivedFileMgr()
    global.oGlobalTimer = servicetimer.NewTimer()
    global.oGMMgr = gmobj.NewGMMgr()
    global.oNotifyMgr = notify.NewNotifyMgr()
    global.oChatMgr = chat.NewChatMgr()
    global.oToolMgr = toolmgr.NewToolMgr()
    global.oNewbieGuideMgr = newbieguide.NewNewbieGuideMgr()
    global.oSysOpenMgr = sysopenmgr.NewSysOpenMgr()
    global.oRankMgr = rankmgr.NewRankMgr()
    -- global.oRenameMgr = rename.NewRenameMgr()
    -- global.oShowIdMgr = showidmgr.NewShowIdMgr()
    -- global.oCatalogMgr = catalogmgr.NewCatalogMgr()
    global.oFubenMgr = fubenmgr.NewFubenMgr()
    global.oSummonMgr = summonmgr:NewSummonMgr()
    global.oRideMgr = ridemgr:NewRideMgr()
    global.oBackendMgr = backendmgr.NewBackendMgr()
    global.oEquipMgr = equipmgr.NewEquipMgr(0)
    -- global.oDemiSdk = demisdk.NewDemiSdk(true)
    -- global.oPayMgr = paymgr.NewPayMgr()
    -- global.oVersionMgr = versionmgr.NewVersionMgr()
    -- global.oRedeemCodeMgr = redeemcodemgr.NewRedeemCodeMgr()
    -- global.oMergerMgr = mergermgr.NewMergerMgr()
    global.oArtifactMgr = artifactmgr.NewArtifactMgr()
    global.oWingMgr = wingmgr.NewWingMgr()

    -- world服
    global.oWorldMgr = worldobj.NewWorldMgr()
    global.oWorldMgr:Schedule()
    global.oWorldMgr:ConfiglSumDaoBiao()

    local iCount
    iCount = SCENE_SERVICE_COUNT
    local lSceneRemote = {}
    for i = 1, iCount do
        local iAddr = skynet.newservice("scene")
        table.insert(lSceneRemote, iAddr)
    end
    global.oSceneMgr = sceneobj.NewSceneMgr(lSceneRemote)

    iCount = WAR_SERVICE_COUNT
    local lWarRemote = {}
    for i = 1, iCount do
        local iAddr = skynet.newservice("war")
        table.insert(lWarRemote, iAddr)
    end
    global.oWarMgr = warobj.NewWarMgr(lWarRemote)

    for iNo = 1, PLAYER_SEND_COUNT do
        skynet.newservice("player_send_proxy",iNo)
    end
    global.oMailAddrMgr = mailaddrmgr.NewMailAddrMgr()

    skynet.newservice("autoteam")
    skynet.newservice("recommend")
    skynet.newservice("rank")
    -- skynet.newservice("version")

    --lxldebug add some temp scene
    local mScene = res["daobiao"]["scene"]
    for k, v in pairs(mScene) do
        local iCnt = v.line_count
        local bHasAnlei = false
        if v.anlei == 1 then
            bHasAnlei = true
        end
        for i = 1, iCnt do
            global.oSceneMgr:CreateScene({
                map_id = v.map_id,
                is_durable = true,
                has_anlei = bHasAnlei,
                url = {"scene", k},
            })
        end
    end

    global.oBehaviorEvDef = behaviorevmgr.NewBehaviorEvDef()
    global.oPubMgr = publicobj.NewPubMgr()
    local oPubMgr = global.oPubMgr
    oPubMgr:InitConfig()
    global.oNpcMgr = npcobj.NewNpcMgr()
    local oNpcMgr = global.oNpcMgr
    oNpcMgr:LoadInit()
    global.oEffectMgr = effectobj.NewEffectMgr()
    global.oCbMgr = cbobj.NewCBMgr()
    global.oUIMgr = uiobj.NewUIMgr()
    global.oTaskMgr = taskmgr.NewTaskMgr()
    global.oTaskLoader = loadtask.NewTaskLoader()
    global.oTaskHandler = handletask.NewTaskHandler()
    global.oItemLoader = loaditem.NewItemLoader()
    global.oItemHandler = handleitem.NewItemHandler()
    global.oPlayerSkillLoader = playerloadskill.NewSkillLoader()
    global.oInterfaceMgr = interfacemgr.NewInterfaceMgr()
    global.oTeamMgr = team.NewTeamMgr()
    global.oHuodongMgr = huodong.NewHuodongMgr()
    local oHuodongMgr = global.oHuodongMgr
    oHuodongMgr:Init()

    global.oMailMgr = mailmgr.NewMailMgr()
    global.oRewardMgr = rewardmgr.NewRewardMgr()
    global.oFriendMgr = friendobj.NewFriendMgr()
    global.oTitleMgr = titlemgr.NewTitleMgr()
    global.oTestMgr = testmgr.NewTestMgr()
    -- global.oJJCMgr = jjcmgr.NewJJCMgr()
    -- local oJJCMgr = global.oJJCMgr
    -- oJJCMgr:LoadDb()
    -- wait_load("jjc", oJJCMgr)

    -- global.oChallengeMgr = challengemgr.NewChallengeMgr()
    -- global.oRedPacketMgr=redpacketmgr.NewRedPacketMgr()
    -- local oRedPacketMgr = global.oRedPacketMgr
    -- oRedPacketMgr:LoadDb()
    -- wait_load("redpacket", oRedPacketMgr)

    -- global.oOrgMgr = orgmgr.NewOrgMgr()
    -- local oOrgMgr = global.oOrgMgr
    -- oOrgMgr:LoadAllOrg()
    -- wait_load("org", oOrgMgr)

    -- global.oGuild = guildmgr.NewGuildObj()
    -- local oGuild = global.oGuild
    -- oGuild:InitCatalog()
    -- oGuild:LoadDb()
    -- wait_load("guild", oGuild)

    -- global.oStallMgr = stallmgr.NewStallMgr()
    -- local oStallMgr = global.oStallMgr
    -- oStallMgr:LoadDb()
    -- wait_load("stall", oStallMgr)

    -- oStallMgr.m_oPriceMgr:LoadDb()
    -- wait_load("price",  oStallMgr.m_oPriceMgr)

    global.oVideoMgr = videomgr.NewWarVideoMgr()
    global.oShimenMgr = shimenmgr.NewShimenMgr()
    global.oGhostHandler = handleghost.NewGhostHandler()
    -- global.oSchoolPassHandler = handleschoolpass.NewSchoolPassHandler()
    -- global.oYibaoMgr = yibaomgr.NewYibaoMgr()
    global.oRunRingMgr = runringmgr.NewRunRingMgr()
    global.oBulletBarrageMgr = bulletbarragemgr.NewBulletBarrageMgr()
    -- global.oAuction = auction.NewAuction()
    -- local oAuction = global.oAuction
    -- oAuction:LoadDb()
    -- wait_load("auction",  oAuction)

    -- global.oLotteryMgr = lottery.NewLotteryMgr()
    global.oLoginMonitor = loginmonitor:NewLoginMonitor()
    global.oGamePushMgr = gamepush.NewGamePushMgr()
    global.oConfirmMgr = confirmmgr.NewConfirmMgr()
    global.oShopMgr = shopmgr.NewShopMgr()
    global.oScoreCache = scorecache.NewScoreCache()
    -- global.oOffsetMgr = offsetmgr.NewOnlineOffsetMgr()
    -- global.oYunYingMgr = yunyingmgr.NewYunYingMgr()
    -- local oYunYingMgr = global.oYunYingMgr
    -- oYunYingMgr:LoadDb()
    -- wait_load("yunying",  oYunYingMgr)
    -- global.oEngageMgr = engagemgr.NewEngageMgr()
    -- local oEngageMgr = global.oEngageMgr
    -- oEngageMgr:LoadDb()
    -- wait_load("engage",  oEngageMgr)
    global.oFastBuyMgr = fastbuymgr.NewFastBuyMgr()
    global.oFaBaoMgr = fabaomgr.NewFaBaoMgr()
    -- global.oHotTopicMgr = hottopic.NewHotTopic()
    -- global.oMarryMgr = marrymgr.NewMarryMgr()
    -- local oMarryMgr = global.oMarryMgr
    -- oMarryMgr:LoadDb()
    -- wait_load("marry", oMarryMgr)

    global.oMentoring = mentoring.NewMentoring()
    -- local oMentoring = global.oMentoring
    -- global.oMentoring:LoadDb()
    -- wait_load("mentoring",  oMentoring)

    global.iNetRecvProxyAddr = skynet.newservice("net_recv_proxy", MY_ADDR, "handlenrp")
    global.oServerMgr = servermgr.NewServerMgr()

    basehook.set_logic(function ()
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:WorldDispatchFinishHook()
    end)

    global.oWorldMgr:OnServerStartEnd()
    interactive.Send(".dictator", "common", "AllServiceBooted", {type = "world"})

    skynet.register ".world"
    interactive.Send(".dictator", "common", "Register", {
        type = ".world",
        addr = MY_ADDR,
    })

    record.info("world service booted")
end)
