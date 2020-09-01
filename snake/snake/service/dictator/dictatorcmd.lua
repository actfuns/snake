--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function update_res(fd, print_back)
    local sResponse = string.format("%s dictator execute update_res", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:ReloadRes()

    return sResponse
end

function client_res(fd, print_back)
    local sResponse = string.format("%s dictator execute client_res", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:ClientRes()

    return sResponse
end

function client_code(fd, print_back)
    local sResponse = string.format("%s dictator execute client_code", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:ClientCode()

    return sResponse
end

function mem_purgeunused(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_purgeunused", fd)

    local memory = require "memory"
    memory.purgeunused()

    return sResponse
end

function mem_resetunused(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_resetunused", fd)

    local memory = require "memory"
    memory.resetunused()

    return sResponse
end

function mem_decayunused(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_decayunused", fd)

    local memory = require "memory"
    memory.decayunused()

    return sResponse
end

function mem_checkglobal(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_checkglobal", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:MemCheckGlobal()

    return sResponse
end

function mem_current(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_current", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:MemCurrent()

    return sResponse
end

function mem_snapshot(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_snapshot", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:MemSnapshot()

    return sResponse
end

function mem_showtrack(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_showtrack", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:MemShowTrack()

    return sResponse
end

function mem_diff(fd, print_back)
    local sResponse = string.format("%s dictator execute mem_diff", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:MemDiff()

    return sResponse
end

function dump_measure(fd, print_back)
    local sResponse = string.format("%s dictator execute dump_measure", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:DumpMeasure()

    return sResponse
end

function ctrl_measure(fd, print_back, flag)
    local sResponse = string.format("%s dictator execute ctrl_measure %s", fd, flag)

    local oDictatorObj = global.oDictatorObj
    flag = tonumber(flag)
    local bOpen = false
    if flag > 0 then
        bOpen = true
    end
    oDictatorObj:CtrlMeasure(bOpen)

    return sResponse
end

function ctrl_monitor(fd, print_back, flag)
    local sResponse = string.format("%s dictator execute ctrl_monitor %s", fd, flag)

    local oDictatorObj = global.oDictatorObj
    flag = tonumber(flag)
    local bOpen = false
    if flag > 0 then
        bOpen = true
    end
    oDictatorObj:CtrlMonitor(bOpen)

    return sResponse
end

function dump_monitor(fd, print_back)
    local sResponse = string.format("%s dictator execute dump_monitor", fd)
    skynet.send(".rt_monitor", "lua", "Dump")
    return sResponse
end

function clear_monitor(fd, print_back)
    local sResponse = string.format("%s dictator execute clear_monitor", fd)
    skynet.send(".rt_monitor", "lua", "Clear")
    return sResponse
end

function mem_printmalloc(fd,print_back)
    local memcmp = require "base.memcmp"
    memcmp.printjemalloc()
end

function start_mem_monitor(fd, print_back)
    local sResponse = string.format("%s dictator execute start_mem_monitor", fd)
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:StartMemMonitor()
    return sResponse
end

function stop_mem_monitor(fd, print_back)
    local sResponse = string.format("%s dictator execute stop_mem_monitor", fd)
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:StopMemMonitor()
    return sResponse
end

function dump_mem_monitor(fd, print_back)
    local sResponse = string.format("%s dictator execute dump_mem_monitor", fd)
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:DumpMemMonitor()
    return sResponse
end

function clear_mem_monitor(fd, print_back)
    local sResponse = string.format("%s dictator execute clear_mem_monitor", fd)
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:ClearMemMonitor()
    return sResponse
end

function start_mem_rtmonitor(fd, print_back)
    local sResponse = string.format("%s dictator execute start_mem_monitor", fd) 
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:StartRtMemMonitor()
    return sResponse
end

function stop_mem_rtmonitor(fd, print_back)
    local sResponse = string.format("%s dictator execute stop_mem_monitor", fd) 
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:StopRtMemMonitor()
    return sResponse
end

function dump_mem_rtmonitor(fd, print_back)
    local sResponse = string.format("%s dictator execute dump_mem_monitor", fd)
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:DumpRtMemMonitor()
    return sResponse
end

function clear_mem_rtmonitor(fd, print_back)
    local sResponse = string.format("%s dictator execute clear_mem_monitor", fd)
    local oDictatorObj = global.oDictatorObj
    oDictatorObj:ClearRtMemMonitor()
    return sResponse
end

function update_code(fd, print_back, sModuleList, flag)
    local sResponse = string.format("%s dictator execute update_code", fd)

    local oDictatorObj = global.oDictatorObj
    local bUpdateProto = false
    if flag and tonumber(flag) > 0 then
        bUpdateProto = true
    end
    local bSucc, sErr = oDictatorObj:UpdateCode(sModuleList, bUpdateProto)
    if not bSucc then
        sResponse = sResponse .. "\n" .. sErr
    else
        sResponse = sResponse .. "\n" .. "update all ok"
    end

    return sResponse
end

function uc(fd, print_back, sModuleList, flag)
    return update_code(fd, print_back, sModuleList, flag)
end

function update_fix(fd, print_back, sFunc)
    local sResponse = string.format("%s dictator execute update_fix", fd)

    local oDictatorObj = global.oDictatorObj
    local bSucc, sErr = oDictatorObj:UpdateFix(sFunc)
    if not bSucc then
        sResponse = sResponse .. "\n" .. sErr
    else
        sResponse = sResponse .. "\n" .. "update_fix ok"
    end

    return sResponse
end

function close_gs(fd, print_back, notify)
    local sResponse = string.format("%s dictator execute close_gs", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:CloseGS(notify)

    return sResponse
end

function close_cs(fd, print_back)
    local sResponse = string.format("%s dictator execute close_cs", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:CloseCS()

    return sResponse
end

function close_bs(fd, print_back)
    local sResponse = string.format("%s dictator execute close_bs", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:CloseBS()

    return sResponse
end

function close_ks(fd, print_back)
    local sResponse = string.format("%s dictator execute close_ks", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:CloseGS()

    return sResponse
end

function list_service(fd, print_back)
    local sResponse = string.format("%s dictator execute list_service", fd)

    local sMsg = ""
    for k, v in pairs(global.mServiceNote) do
        sMsg = string.format("%s%s:\n", sMsg, k)
        for _, v2 in ipairs(v) do
            sMsg = string.format("%s%s\n", sMsg, v2)
        end
    end

    return sMsg
end

function open_gate(fd, print_back, sStatus)
    local sResponse = string.format("%s dictator execute open_gate %s", fd, sStatus)

    local oDictatorObj = global.oDictatorObj
    local iStatus = tonumber(sStatus)
    oDictatorObj:OpenGate(iStatus)

    return sResponse
end

function start_merger(fd, print_back, sMergeTimes)
    local sResponse = string.format("%s dictator execute start_merger %s", fd, sMergeTimes)
    local iMergeTimes = tonumber(sMergeTimes)
    if iMergeTimes and iMergeTimes > 0 then
        local oDictatorObj = global.oDictatorObj
        oDictatorObj:StartMerger(iMergeTimes)
    end
    return sResponse
end


function checkqrcodecnt(fd, print_back, sStatus)
    interactive.Send(".qrcode", "common", "PrintConnectCnt", {})
end

function testclientconnect(fd, print_back, ip , port , cnt)
    ip = tostring(ip)
    port = tonumber(port)
    cnt = tonumber(cnt)
    interactive.Send(".testclient", "common", "TestConnectCnt", {ip=ip,port=port,cnt=cnt})
end

function cleartbpool(fd, print_back)
    local sResponse = string.format("%s dictator execute cleartbpool", fd)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:ClearTbPool()

    return sResponse
end

function kick_ks_player(fd, print_back, server)
    local sResponse = string.format("%s dictator execute kick_ks_player %s", fd, server)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:KickKSPlayer(server)

    return sResponse
end

function set_ks_login(fd, print_back, status)
    local sResponse = string.format("%s dictator execute set_ks_login %s", fd, status)

    local oDictatorObj = global.oDictatorObj
    oDictatorObj:SetKSLogin(status)

    return sResponse
end
