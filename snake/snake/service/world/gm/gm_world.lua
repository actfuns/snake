local global = require "global"
local record = require "public.record"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Opens.addopenday = false
Helpers.addopenday = {
    "添加开服天数",
    "addopenday 数目",
    "addopenday 2",
}
function Commands.addopenday(oMaster, iVal)
    if iVal > 0 then
        local oWorldMgr = global.oWorldMgr
        local iServerOpenDays = oWorldMgr:GetOpenDays()
        oWorldMgr:SetOpenDays(iServerOpenDays + iVal)
        oWorldMgr:CheckUpGrade()
    end
end

Opens.setopenday = false
Helpers.setopenday = {
    "设置开服天数",
    "setopenday 数目",
    "setopenday 2",
}
function Commands.setopenday(oMaster, iVal)
    if iVal >= 0 then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:SetOpenDays(iVal)
        oWorldMgr:CheckUpGrade()
    end
end

Opens.getserverinfo = true
Helpers.getserverinfo = {
    "获取服务器信息",
    "getserverinfo ",
    "getserverinfo ",
}
function Commands.getserverinfo(oMaster)
    local oWorldMgr = global.oWorldMgr
    local iOpenDays, iServerGrade = oWorldMgr:GetOpenDays(), oMaster:GetServerGrade()
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster:GetPid(), string.format("开服天数: %s, 服务器等级: %s.", iOpenDays, iServerGrade))
end

Opens.savedb = true
Helpers.savedb = {
    "触发存盘",
    "savedb ",
    "savedb ",
}
function Commands.savedb(oMaster)
    record.debug("-------------savedb")
    oMaster:DoSave()
end

Opens.mergesave = true
Helpers.mergesave = {
    "触发MERGE",
    "mergesave ",
    "mergesave ",
}
function Commands.mergesave(oMaster, iPid)
    local oWorldMgr = global.oWorldMgr
    local obj = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if obj then
        record.debug("-------------mergesave", oMaster:GetPid(), iPid)
        oMaster:AddSaveMerge(obj)
    end
end


