local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local httpuse = require "public.httpuse"
local record = require "public.record"
local netproto = require "base.netproto"

local shareobj = import(lualib_path("base.shareobj"))
local serverinfo = import(lualib_path("public.serverinfo"))
local gm_item = import(service_path("gm/gm_item"))

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.setonlinelimit = false
Helpers.setonlinelimit = {
    "设置在线人数上限",
    "setonlinelimit iMaxOnline",
    "示例: setonlinelimit 8000",
}
function Commands.setonlinelimit(oMaster, iOnlineLimit)
    interactive.Send(".login", "login", "SetOnlinePlayerLimit", {limit = tonumber(iOnlineLimit)})
end

Opens.getonlinecnt = true
Helpers.getonlinecnt = {
    "获取当前服务器在线人数",
    "getonlinecnt",
    "getonlinecnt",
}
function Commands.getonlinecnt(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local lOnlinePlayers = oWorldMgr:GetOnlinePlayerList()
    oNotifyMgr:Notify(oMaster:GetPid(), "当前服务器人数为"..table_count(lOnlinePlayers))
end

Opens.update_cs_common = false
Helpers.update_cs_common = {
    "更新cs_common",
    "update_cs_common",
    "示例: update_cs_common",
}
function Commands.update_cs_common(oMaster)
    os.execute("svn update cs_common")
    oMaster:NotifyMessage("已更新cs_common")
end

Opens.daobiao = false
Helpers.daobiao = {
    "导表",
    "daobiao",
    "示例: daobiao",
}
function Commands.daobiao(oMaster)
    os.execute("svn update daobiao")
    os.execute("svn update")
    interactive.Send(".dictator", "common", "UpdateRes", {})
    oMaster:NotifyMessage("已更新导表")
end

-- 更新本地导表
function Commands.updateparse(oMaster)
    interactive.Send(".dictator", "common", "UpdateRes", {})
    oMaster:NotifyMessage("已更新本地表")
end


function Commands.opengate(oMaster, iFlag)
    local mStatus = {0, 1, 2}
    if not table_in_list(mStatus, iFlag) then
        local sMsg = string.format("网关状态只能设置为{0-维护状态、1-白名单登陆状态、2-所有玩家登陆状态}")
        global.oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
        return
    end
    interactive.Send(".login", "login", "SetGateOpenStatus", {status = iFlag})
end

function Commands.runstring(oMaster, sExecute)
    local cmdenv = setmetatable({oMaster=oMaster, global=global}, {__index = _G})
    local func, err = load(sExecute, "@test", "bt", cmdenv)
    if not func then
        record.debug('runstring load err', err)
        return
    end
    func()
end

function Commands.runtest(oMaster)
    local cmdenv = setmetatable({oMaster=oMaster}, {__index = _G})
    local sPath = string.format("service/%s/test.lua", MY_SERVICE_NAME)
    local f = io.open(sPath, "rb")
    assert(f, sPath)
    local source = f:read "*a"
    f:close()
    local func, err = load(source, "@test", "bt", cmdenv)
    if not func then
        record.debug('load script fail, err', err)
        return
    end
    func()
end

function Commands.testprotoencode(oMaster, iCnt)
    local netproto = require "base.netproto"
    local fTime = get_time(true)
    local sData
    for i = 1, iCnt do
        sData = netproto.ProtobufFunc("encode", "GS2CTestEncode", {
            a = 100,
            b = "bbb",
        })
    end
    print("protobuf encode time:", iCnt, get_time(true) - fTime)
    fTime = get_time(true)
    for i = 1, iCnt do
        netproto.ProtobufFunc("decode", "GS2CTestEncode", sData)
    end
    print("protobuf decode time:", iCnt, get_time(true) - fTime)
end

function Commands.testidpool(oMaster)
    local idpool = import(lualib_path("base.idpool"))
    local oIDPool = idpool.CIDPool:New(2)
    local lTest = {}
    local iCount = 100
    local bFinish = false

    local f1
    f1 = function ()
        oMaster:DelTimeCb("_IDPoolProduce")
        if iCount <= 0 then
            bFinish = true
            return
        end
        oMaster:AddTimeCb("_IDPoolProduce", 10*1000, f1)
        oIDPool:Produce()
        iCount = iCount - 1
    end
    f1()

    local f2
    f2 = function ()
        oMaster:DelTimeCb("_IDPoolGain")
        if bFinish then
            return
        end
        oMaster:AddTimeCb("_IDPoolGain", math.random(1,3)*1000, f2)
        local id = oIDPool:Gain()
        table.insert(lTest, id)
        print("testidpool lxldebug701", oIDPool.m_iBaseId, id)
    end
    f2()

    local f3
    f3 = function ()
        oMaster:DelTimeCb("_IDPoolFree")
        if bFinish then
            return
        end
        oMaster:AddTimeCb("_IDPoolFree", math.random(1,3)*1000, f3)
        local iChooseIndex = math.random(1, #lTest)
        local id = lTest[iChooseIndex]
        table.remove(lTest, iChooseIndex)
        oIDPool:Free(id)
    end
    f3()
end

function Commands.testluaencode(oMaster, iCnt)
    local skynet = require "skynet"
    local fTime = get_time(true)
    local sData
    for i = 1, iCnt do
        sData = skynet.packstring({
            a = 100,
            b = "bbb",
        })
    end
    print("lua encode time:", iCnt, get_time(true) - fTime)
    fTime = get_time(true)
    for i = 1, iCnt do
        skynet.unpack(sData)
    end
    print("lua decode time:", iCnt, get_time(true) - fTime)
end

function Commands.testmerge(oMaster, iTotal, iSingle)
    local iCnt = 0
    local iIndex = 1
    local l = {}
    for i = 1, iTotal do
        local m = {
            a = math.random(10000),
            b = math.random(10000),
            c = math.random(10000),
            d = math.random(10000),
            e = math.random(10000),
            f = math.random(10000),
        }
        iCnt = iCnt + 1
        table.insert(l, m)
        if iCnt >= iSingle then
            interactive.Send(".dictator", "common", "TestMerge", {total = iTotal, index = iIndex, count = iCnt, data = l})
            iIndex = iIndex + 1
            iCnt = 0
            l = {}
        end
    end
    if next(l) then
        interactive.Send(".dictator", "common", "TestMerge", {total = iTotal, index = iIndex, count = iCnt, data = l})
    end
end

function Commands.testexecute(oMaster, iCnt)
    local it = get_time(true)
    for i = 1, iCnt do
        local a, b, c, d, e, f, s = 10, 8, 7, 4, 12, 9, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        local b1 = ((a+b)*c/d-e^f) > 100
        local b2 = "ghj" >= s
    end
    print(get_time(true) - it)
end

function Commands.testhandleteam(oMaster, iCnt)
    local measure = require "measure"
    local m = import(service_path("netcmd.team"))
    local it = measure.timestamp()
    for i = 1, iCnt do
        m.C2GSCreateTeam(oMaster, {})
        m.C2GSLeaveTeam(oMaster, {})
    end
    print(measure.timestamp() - it)
end

function Commands.testprotoonlineupdate(oMaster)
    print("lxldebug GS2CTestOnlineUpdate")
    oMaster:Send("GS2CTestOnlineUpdate", {
        a = 10,
        b = "bbb",
        c = 100,
    })
end

function Commands.testprotoonlineadd(oMaster)
    print("lxldebug GS2CTestOnlineAdd")
    oMaster:Send("GS2CTestOnlineAdd", {
        a = 10,
    })
end

function Commands.testclient2cs(oMaster, iCnt)
    local iStart, iTotal = get_time(), 0
    for i = 1, iCnt do
        local sHost = string.format("%s:80", serverinfo.get_cs_host())
        local sUrl = "/loginverify/verify_account"
        local mContent = {demi_channel=0, cps="CPS_300036", account="xy101"}
        local sContent = httpuse.mkcontent_json(mContent)
        local mHeader = {host="csh7.demigame.com"}
        httpuse.post(sHost, sUrl, sContent, function(sBody, mData)
            iTotal = iTotal + 1
            if iTotal >= iCnt then
                record.info("request cnt:%d, start:%d, end:%d, cost:%s", iCnt, iStart, get_time(), get_time()-iStart)
            end
        end, mHeader)
    end
end

function Commands.testproto(oMaster)
    local sMessage = "C2GSTestProto"

    local m1 = {
        b = "22",
        c = 11,
    }
    local m2 = net.Mask(sMessage, m1)
    record.debug("lxldebug1")
    for k, v in pairs(m2) do
        record.debug("%s %s", k, v)
    end
    local m3 = netproto.ProtobufFunc("encode", sMessage, m2)
    local m4 = netproto.ProtobufFunc("decode", sMessage, m3)
    record.debug("lxldebug2 %s %s %s %s", m4.mask, m4.a, m4.b, m4.c)
    local m5 = net.UnMask(sMessage, {
        mask = m4.mask,
        a = m4.a,
        b = m4.b,
        c = m4.c,
    })
    record.debug("lxldebug3")
    for k, v in pairs(m5) do
        record.debug("%s %s", k, v)
    end
end

function Commands.checklfs(oMaster)
    local lfs = require "lfs"
    local sRoot = "./"
    for n in lfs.dir(sRoot) do
        local sPath = sRoot..n
        record.debug("lxldebug", n, lfs.attributes(sPath, "mode"))
    end
end

function Commands.ctrl_monitor(oMaster, bOpen)
    assert(type(bOpen) == "boolean", "gm ctrl_monitor fail")
    interactive.Send(".dictator", "common", "CtrlMonitor", {
        is_open = bOpen,
    })
end

function Commands.ctrl_measure(oMaster, bOpen)
    assert(type(bOpen) == "boolean", "gm ctrl_measure fail")
    interactive.Send(".dictator", "common", "CtrlMeasure", {
        is_open = bOpen,
    })
end

function Commands.dump_measure(oMaster)
    interactive.Send(".dictator", "common", "DumpMeasure", {})
end

function Commands.start_mem_monitor(oMaster)
    interactive.Send(".dictator", "common", "StartMemMonitor", {})
end

function Commands.stop_mem_monitor(oMaster)
    interactive.Send(".dictator", "common", "StopMemMonitor", {})
end

function Commands.dump_mem_monitor(oMaster)
    interactive.Send(".dictator", "common", "DumpMemMonitor", {})
end

function Commands.clear_mem_monitor(oMaster)
    interactive.Send(".dictator", "common", "ClearMemMonitor", {})
end

function Commands.mem_purgeunused(oMaster)
    local memory = require "memory"
    memory.purgeunused()
end

function Commands.mem_resetunused(oMaster)
    local memory = require "memory"
    memory.resetunused()
end

function Commands.mem_decayunused(oMaster)
    local memory = require "memory"
    memory.decayunused()
end

function Commands.mem_printmalloc(oMaster)
    local memcmp = require "base.memcmp"
    memcmp.printjemalloc()
end

function Commands.mem_checkglobal(oMaster)
    interactive.Send(".dictator", "common", "MemCheckGlobal", {})
end

function Commands.mem_diff(oMaster)
    interactive.Send(".dictator", "common", "MemDiff", {})
end

function Commands.mem_current(oMaster)
    interactive.Send(".dictator", "common", "MemCurrent", {})
end

function Commands.mem_showtrack(oMaster)
    interactive.Send(".dictator", "common", "MemShowTrack", {})
end

function Commands.mem_snapshot(oMaster)
    interactive.Send(".dictator", "common", "MemSnapshot", {})
end

function Commands.dump_monitor(oMaster)
    skynet.send(".rt_monitor", "lua", "Dump")
end

function Commands.clear_monitor(oMaster)
    skynet.send(".rt_monitor", "lua", "Clear")
end

function Commands.client_res(oMaster)
    interactive.Send(".dictator", "common", "ClientRes", {
        pid = oMaster:GetPid(),
    })
end

function Commands.client_code(oMaster)
    interactive.Send(".dictator", "common", "ClientCode", {
        pid = oMaster:GetPid(),
    })
end

function Commands.update_code(oMaster, s, flag)
    -- os.execute("./shell/update.sh")
    local bUpdateProto = false
    if flag and tonumber(flag) > 0 then
        bUpdateProto = true
    end
    interactive.Send(".dictator", "common", "UpdateCode", {
        pid = oMaster:GetPid(),
        str_module_list = s,
        is_update_proto = bUpdateProto,
    })
end

function Commands.update_fix(oMaster, s)
    interactive.Send(".dictator", "common", "UpdateFix", {
        pid = oMaster:GetPid(),
        func = s,
    })
end

function Commands.gc(oMaster)
    interactive.Send(".dictator", "common", "CheckGC", {})
end

function Commands.testinterface(oMaster, iTest)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:RefreshOrgAnswer(iTest)
end

function Commands.testrecord(oMaster)
    local record = require "public.record"
    
    record.user("test", "test_test", {pid=1, name="hehe", other=11})
    record.user("test", "test_test", {pid=1})
    record.user("test", "test_test", {pid=1, name="hehe"})

    record.error("test error %d %s", 1, "haha")
    record.info("test info %d %s", 1, "haha")
    record.warning("test warning %d %s", 1, "haha")
    record.debug("test debug %d %s", 1, "haha")
end

function Commands.teststatistics(oMaster)
    local statistics = require "public.statistics"

    statistics.system_cost("test", 1, {[10001] = 2}, {[10002] = 3}, 1)
    statistics.system_cost("test", 1, {[10001] = 2}, {[10002] = 3})
    statistics.system_player_cnt("test", 1)
    statistics.system_cost("test", 2, {[10001] = 2}, {[10002] = 3}, 1)
end

function Commands.testlogfile(oMaster)
    local analy = import(lualib_path("public.dataanaly"))
    -- local s = create_folder("/home/nucleus-n1/log/dev_gs10001/Test")
    -- print(s)
    -- os.execute(string.format("mkdir /home/nucleus-n1/log/dev_gs10001/Test",sFold))
    -- analy.log_data("Test", {test="test", time=get_time()})
end

function Commands.testhttp(oMaster)
    local sHost = "127.0.0.1:10003"
    local sUrl = "/backend"
    local mParam = httpuse.mkcontent_json({
            module = "common",
            cmd = "Test",
            args = {
                year = 2017,
                month = 5,
                server = 1,
            }
        })
    httpuse.post(sHost, sUrl, mParam, function (body, header)
        local mData = httpuse.content_json(body)
        table_print_pretty(mData)
    end)
end

function Commands.checktest(oMaster)
    local servicetimer = require "base.servicetimer"
    local net = require "base.net"
    local interactive = require "base.interactive"

    local lNetKey = table_key_list(net.testmap)
    table.sort(lNetKey, function (a, b)
        return net.testmap[a] > net.testmap[b]
    end)
    local s = "\n"
    s = string.format("%s%s\n", s, "net")
    for _, k in ipairs(lNetKey) do
        s = string.format("%s%s\n", s, string.format("%s:%s", k, net.testmap[k]))
    end
    local lInteractive = table_key_list(interactive.testmap)
    table.sort(lInteractive, function (a, b)
        return interactive.testmap[a] > interactive.testmap[b]
    end)
    s = string.format("%s%s\n", s, "interactive")
    for _, k in ipairs(lInteractive) do
        s = string.format("%s%s\n", s, string.format("%s:%s", k, interactive.testmap[k]))
    end
    local lTimerKey = table_key_list(servicetimer.testmap)
    table.sort(lTimerKey, function (a, b)
        return servicetimer.testmap[a] > servicetimer.testmap[b]
    end)
    s = string.format("%s%s\n", s, "servicetimer")
    for _, k in ipairs(lTimerKey) do
        s = string.format("%s%s\n", s, string.format("%s:%s", k, servicetimer.testmap[k]))
    end

    oMaster:Send("GS2CGMMessage", {
        msg = s,
    })
end

function Commands.checkcost(oMaster)
    local servicetimer = require "base.servicetimer"
    local net = require "base.net"
    local interactive = require "base.interactive"
    local s = "\n"
    s = string.format("%s%s\n", s, "net")
    for k, v in pairs(net.costtime) do
        s = string.format("%s%s\n", s, string.format("%s:%s", k, serialize_table(v)))
    end
    s = string.format("%s%s\n", s, "interactive")
    for k, v in pairs(interactive.costtime) do
        s = string.format("%s%s\n", s, string.format("%s:%s", k, serialize_table(v)))
    end
    s = string.format("%s%s\n", s, "servicetimer")
    for k, v in pairs(servicetimer.costtime) do
        s = string.format("%s%s\n", s, string.format("%s:%s", k, serialize_table(v)))
    end

    oMaster:Send("GS2CGMMessage", {
        msg = s,
    })
end

function Commands.cleartest(oMaster)
    local servicetimer = require "base.servicetimer"
    local net = require "base.net"
    local interactive = require "base.interactive"
    servicetimer.testmap = {}
    servicetimer.testtime = {}
    servicetimer.costtime = {}
    net.testmap = {}
    net.testtime = {}
    net.costtime = {}
    interactive.testmap = {}
    interactive.testtime = {}
    interactive.costtime = {}
end

function Commands.testsnapshot(oMaster)
    local snapshot = require "snapshot"

    local s1 = snapshot()

    local a2 = {}

    local s2 = snapshot()

    for k, v in pairs(s2) do
        if s1[k] == nil then
            print(k, v)
        end
    end
end

function Commands.testshareobj(oMaster)
    interactive.Request(".dictator", "common", "TestShareObj", {},
        function(mRecord, mData)
            local oRemote = mData.shareobj
            local oLocal = CTestShareObj:New()
            oLocal:Init(oRemote)

            local iCount = 0
            local iPid = oMaster:GetPid()
            local f1
            f1 = function ()
                iCount = iCount + 1
                local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
                if oPlayer then
                    oPlayer:DelTimeCb("_TestShareObj")

                    if iCount > 10 then
                        oLocal = nil
                        return
                    end

                    oPlayer:AddTimeCb("_TestShareObj", 6*1000, f1)

                    oLocal:Update()
                    print("lxldebug testshareobj testint")
                    print(oLocal.m_iTestInt)
                    print("lxldebug testshareobj teststr")
                    print(oLocal.m_sTestStr)
                    print("lxldebug testshareobj testmap")                
                    print(oLocal.m_mTestMap)
                end
            end
            f1()

        end)
end

function Commands.testmongoop(oMaster)
    local mongoop = require "base.mongoop"
    local bson = require "bson"

    local _show_type
    _show_type = function (t)
        for k, v in pairs(t) do
            print(string.format("k:%s k-type:%s", k, type(k)))
            print(string.format("v:%s v-type:%s", v, type(v)))
            if type(v) == "table" then
                _show_type(v)
            end
        end
    end

    local mTest = {
        a = 1,
        b = "bbb",
        map1 = {m1 = 1, m2 = 2},
        map2 = {[10001] = 1, [10002] = 2},
        map3 = {k1 = 1, k2 = 2, [20001] = 10, [20002] = 20,},
        list = {'l1', 'l2', 'l3',},
    }

    print("TEST1")
    local s = bson.encode(mTest)
    local m = bson.decode(s)
    print("TEST1 result")
    print(m)
    print("TEST1 type")
    _show_type(m)

    print("TEST2")
    mongoop.ChangeBeforeSave(mTest)
    local s = bson.encode(mTest)
    local m = bson.decode(s)
    mongoop.ChangeAfterLoad(m)
    print("TEST2 result")
    print(m)
    print("TEST2 type")
    _show_type(m)
end

function Commands.testendless(oMaster)
    local iNow = os.time()
    local iCnt = 10000000000
    for i = 1, iCnt do
        local a = 1 + 2
    end
    record.debug("lxldebug testendless", os.time()-iNow)
end

function Commands.testformula(oMaster)
    local sf = "a + b"
    print("lxldebug101", formula_string(sf, {a = 1, b = 2}))
    print("lxldebug102", formula_string(sf, {a = 1}))
end

function Commands.testcrypt(oMaster)
    local cbc = require("base.crypt.pattern.cbc")
--    local des = require("base.crypt.algo.des")
    local des = require("base.crypt.algo.des-c")
    local padding = require("base.crypt.padding.pkcs5")
    local array = require("base.crypt.common.array")
    local httpuse = require("public.httpuse")

    local o = cbc.Create(des, padding, "!~btusd.")
    local sEncode = o:Encode(string.lower(httpuse.urlencode("tesfd12345宝宝")))
    local sDecode = o:Decode(sEncode)

    print("lxldebug700", array.toHex(array.fromString(sEncode)), httpuse.urldecode(sDecode))
end

function Commands.testtimer(oMaster, bTestOverflow)
    local measure = require "measure"
    local servicetimer = require "base.servicetimer"

    print("testtimer", measure.timestamp())

    oMaster:AddTimeCb("testtimer1", 10, function ()
        print("testtimer1", measure.timestamp())
    end)

    oMaster:AddTimeCb("testtimer2", 100, function ()
        print("testtimer2", measure.timestamp())
    end)

    oMaster:AddTimeCb("testtimer3", 1000, function ()
        print("testtimer3", measure.timestamp())
    end)

    oMaster:AddTimeCb("testtimer4", 10000, function ()
        print("testtimer4", measure.timestamp())

        if bTestOverflow then
            servicetimer.TestOverflow(2^32-1)
            oMaster:AddTimeCb("testtimer_overflow", (2^32-1)*10, function ()
                print("testtimer_overflow")

                print("testtimer_after", measure.timestamp())

                oMaster:AddTimeCb("testtimer1_after", 10, function ()
                    print("testtimer1_after", measure.timestamp())
                end)

                oMaster:AddTimeCb("testtimer2_after", 100, function ()
                    print("testtimer2_after", measure.timestamp())
                end)

                oMaster:AddTimeCb("testtimer3_after", 1000, function ()
                    print("testtimer3_after", measure.timestamp())
                end)

                oMaster:AddTimeCb("testtimer4_after", 10000, function ()
                    print("testtimer4_after", measure.timestamp())
                end)
            end)
        end
    end)
end

function Commands.testrouter(oMaster)
    local router = require "base.router"
    local sBig = string.rep("b", 20*1024)

    router.Send("cs", ".datacenter", "common", "TestRouterSend", {
        a = 1,
        b = sBig,
        c = {1, 2, 3,}
    })
    router.Request("cs", ".datacenter", "common", "TestRouterRequest", {
        a = 2,
        b = sBig,
        c = {e = 1, f = 2, g = 3,},
    }, function (mRecord, mData)
        print("lxldebug .world TestRouterRequest")
        print("show record")
        print(mRecord)
        print("show data")
        print(mData)
    end)
end

function Commands.testhook(oMaster, iCnt, iMode)
    local oNotifyMgr = global.oNotifyMgr

    if iMode == 1 then
        local function C()
            local a, b, c = 1, 2, 3
            local d = (a+b)*b/c
            local f = d^d
            local g = f*f
        end

        local measure = require "measure"
        measure.start()
        for i = 1, iCnt do
            C()
        end

        oNotifyMgr:Notify(oMaster:GetPid(), string.format("耗时:%f", measure.stop()))
    else
        local measure = require "measure"
        measure.start()
        for i = 1, iCnt do
            local a, b, c = 1, 2, 3
            local d = (a+b)*b/c
            local f = d^d
            local g = f*f
        end

        oNotifyMgr:Notify(oMaster:GetPid(), string.format("耗时:%f", measure.stop()))
    end
end

function Commands.testsecondprop(oMaster)
    local mPropInfo = {}
    local lSecondProp = {"speed","mag_defense","phy_defense","mag_attack","phy_attack","max_hp", "max_mp"}
    for _, sProp in pairs(lSecondProp) do
        local mData = {}
        mData.extra = oMaster:GetAttrAdd(sProp) * 1000
        mData.ratio = oMaster:GetBaseRatio(sProp) * 1000
        mData.name = sProp
        table.insert(mPropInfo, mData)
    end
    local mNet = {}
    mNet["prop_info"] = mPropInfo
    oMaster:Send("GS2CGetSecondProp", mNet)
end

function Commands.log_stat(oMaster, sTime)
    -- log_stat '2017-07-04'
    local year,month,day = string.match(sTime,"(%d+)-(%d+)-(%d+)")
    -- print("xxx", sTime, year,month,day)
    year,month,day = tonumber(year),tonumber(month),tonumber(day)
    local iTime = os.time({year = year,month = month,day = day,hour=0,min=0,sec=0})
    interactive.Send(".logstatistics","system","DoLogStatistics", {time=iTime})
end

function Commands.init_item_robot(oMaster, lItems, mArgs)
    oMaster.m_oBaseCtrl:SetData("grade", 49)
    local iSize = oMaster.m_oItemCtrl:GetSize()
    local iMaxSize = oMaster.m_oItemCtrl:MaxSize()
    if iSize < iMaxSize then
        oMaster.m_oItemCtrl:AddExtendSize(iMaxSize - iSize)
    end
    for _, info in ipairs(lItems) do
        gm_item.Commands.clone(oMaster, info[1], info[2], mArgs)
    end
end

function Commands.trigger_save(oMaster)
    print("xiong--trigger_save")
    local record = require "public.record"
    record.log_db("player", "delconnection", {pid=oMaster:GetPid(), reason="trigger_save"})
    save_all()
end

function Commands.trigger_read(oMaster)
    print("xiong--trigger_read")
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:FindFriendByName(oMaster, "南荣康巴")
end

-- 仅特定服务器使用，禁止开发服、外服使用
function Commands.date_reboot(oMaster, sDate)
    local sTime = string.match(sDate, "^(%d+%-%d+%-%d+ %d+:%d+)$")
    if sTime then
        local sCmd = string.format([[./shell/date_reboot.py "%s"]], sTime)
        print("date_reboot", sDate, os.execute(sCmd))
    end
end

-- 调时间服 使用指令更新svn
function Commands.svn_update(oMaster)
    if get_server_key() == "devd_gs10002" then
        local sCmd = "./shell/update.sh"
        print("svn_update", os.execute(sCmd))
        global.oNotifyMgr:Notify(oMaster:GetPid(), "更新完成")
    end
end

function Commands.staticitemandmail(oMaster)
    local iMailTotal = 0
    local iMailCount = 0
    local iMailMax = 0
    local iMailMin = 500
    local lMessage = {}
    for iPid, oMailBox in pairs(global.oWorldMgr.m_mMailBoxs) do
        local iMailCnt = #oMailBox.m_lMails
        iMailCount = iMailCount + 1
        iMailTotal = iMailTotal + iMailCnt
        iMailMax = math.max(iMailCnt, iMailMax)
        iMailMin = math.min(iMailCnt, iMailMin)
    end
    table.insert(lMessage, string.format([[邮件总数:%s, 
邮箱个数:%s,
最大邮件数:%s,
最小邮件数:%s,
平均邮件数:%s]], iMailTotal, iMailCount, iMailMax, iMailMin, iMailTotal//iMailCount))

    local iItemTotal = 0
    local iItemCount = 0
    local iItemMax = 0
    local iItemMin = 500
    for iPid, oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        local iItemCnt = table_count(oPlayer.m_oItemCtrl.m_Item)
        iItemCnt = iItemCnt + table_count(oPlayer.m_mTempItemCtrl.m_Item)
        iItemTotal = iItemTotal + iItemCnt
        iItemCount = iItemCount + 1
        iItemMax = math.max(iItemMax, iItemCnt)
        iItemMin = math.min(iItemMin, iItemCnt)
    end
    table.insert(lMessage, string.format([[道具总数:%s, 
玩家个数:%s,
最大道具数:%s,
最小道具数:%s,
平均道具数:%s]], iItemTotal, iItemCount, iItemMax, iItemMin, iItemTotal//iItemCount))

    oMaster:Send("GS2CGMMessage", {msg = table.concat(lMessage, "\n======\n"),})
end

function Commands.updatelocal(oMaster)
        local t = io.popen("cd service && svn st")
        local states = t:read("*all")
        for _, v in ipairs(split_string(states, "\n")) do
            local sOp = string.sub(v,1,1)
            local sPath = "service."..string.sub(v,9,-5)
            sPath = string.gsub(sPath,"/",".")
            if (sOp == "M" or  sOp == "?" or sOp == "A") and string.sub(v,-4) == ".lua" then
                interactive.Send(".dictator", "common", "UpdateCode", {
                pid = oMaster:GetPid(),
                str_module_list = sPath,
                })
            end
        end
end

CTestShareObj = {}
CTestShareObj.__index = CTestShareObj
inherit(CTestShareObj, shareobj.CShareReader)

function CTestShareObj:New()
    local o = super(CTestShareObj).New(self)
    return o
end

function CTestShareObj:Unpack(m)
    self.m_iTestInt = m.testint
    self.m_sTestStr = m.teststr
    self.m_mTestMap = m.testmap
end
