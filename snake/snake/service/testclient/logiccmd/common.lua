--import module
local global = require "global"
local skynet = require "skynet"
local socket = require "socket"

function TestConnectCnt(mRecord, mData)
    local sIP = mData.ip
    local iPort = mData.port
    local iCnt = mData.cnt
    local iResult = 0
    for iNo=1,iCnt do
        local iFd = socket.open(sIP, iPort)
        if iFd then
            iResult = iResult + 1
            print ("连接成功----",iResult)
        end
    end
end
