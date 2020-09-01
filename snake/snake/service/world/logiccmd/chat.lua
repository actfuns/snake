--import module
local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

local analylog = import(lualib_path("public.analylog"))

function BanChatPlayer(mRecord, mData)
    local iPid = mData.pid
    local iTime = mData.time
    local iForbin = mData.forbin
    local sMsg = mData.msg
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData["forbidid"] = iForbin
        mLogData["msg"] = sMsg
        record.log_db("chat", "forbin_chat", mLogData)
        global.oBackendMgr:BanPlayerChat(oPlayer, get_time() + iTime)

        -- analylog.LogBanChat(oPlayer, sMsg, iForbin)
    end
end
