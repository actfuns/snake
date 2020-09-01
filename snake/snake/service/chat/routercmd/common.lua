--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"
local extend = require "base.extend"


function RouterTest(mRecord, mData)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        data = {},
    })
end

function SyncForbinInfo(mRecord, mData)
    global.oChatMgr:UpdateForbinInfo(mData.data)
end

function RemoveForbinInfo(mRecord, mData)
    for _, id in pairs(mData.ids or {}) do
        global.oChatMgr:RemoveForbinInfo(id)
    end
end