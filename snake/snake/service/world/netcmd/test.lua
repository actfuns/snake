--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"
local netproto = require "base.netproto"

function C2GSTestWar(oPlayer, mData)
    local oTestMgr = global.oTestMgr
    oTestMgr:TestWar(oPlayer, mData)
end

function C2GSTestBigPacket(oPlayer, mData)
    local s = mData.s
    local iCnt = #s
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oPlayer.m_iPid, string.format("该包s字段长度为%d", iCnt))
end

function C2GSTestCopy(oPlayer, mData)
    local l1 = netproto.ProtobufFunc("copy_repeated", mData.a3, "c2")
    local l2 = netproto.ProtobufFunc("copy_repeated", mData.a3, "c3")
    record.debug("lxldebug1")
    for _, v in ipairs(l1) do
        record.debug(v)
    end
    record.debug("lxldebug2")
    for _, v in ipairs(l2) do
        record.debug(v)
    end
end

function C2GSTestOnlineUpdate(oPlayer, mData)
    print("lxldebug C2GSTestOnlineUpdate")
    print(mData.a)
    print(mData.b)
end
