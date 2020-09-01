--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))

function DeleteRole(mRecord, mData)
    local iPid = mData.pid

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CLoginError", {pid = iPid, errcode = gamedefines.ERRCODE.kickout})
        oWorldMgr:Logout(iPid)
    end

    local mInfo = {
        module = "playerdb",
        cmd = "RemovePlayer",
        cond = {pid = iPid}
    }
    gamedb.LoadDb(iPid, "common", "DbOperate", mInfo,
    function (mr, md)
        if md.ok then
            router.Send("cs", ".datacenter", "common", "OnGSDeleteRole", {
                pid=iPid,
            })
        end
    end)
end
