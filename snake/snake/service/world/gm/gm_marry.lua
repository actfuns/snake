local global = require "global"
local extend = require "base.extend"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Helpers.marryop = {
    "玩家测试指令",
    "marryop iFlag mArgs",
    "marryop 101 ",
}
function Commands.marryop(oMaster,iFlag,mArgs)
end

Opens.doengage = true
Helpers.doengage = {
    "玩家测试指令",
    "doengage iType",
    "doengage 1",
}
function Commands.doengage(oMaster, iType)
    iType = iType or 1
    local iText, mReplace = global.oEngageMgr:ValidEngage(oMaster, iType)
    if iText ~= 1 then
        oMaster:NotifyMessage(global.oEngageMgr:GetText(iText, mReplace))
        return
    end
    local oMale, oFemale
    local iRunner = oMaster:GetPid()
    local iEngageNo = global.oEngageMgr:DispatchEngageNo()
    if oMaster:GetSex() == 1 then
        oMale = oMaster
        oFemale = global.oEngageMgr:GetEngageTarget(oMaster)
    else
        oFemale = oMaster
        oMale = global.oEngageMgr:GetEngageTarget(oMaster)
    end
    if not oMale or not oFemale then return end

    global.oEngageMgr:OnEngageSuccess(oMale, oFemale, iType, iEngageNo, "gmtest", "gmtest", iRunner)
    oMaster:NotifyMessage("订婚成功")
end

Opens.domarry = true
Helpers.domarry = {
    "玩家测试指令",
    "domarry",
    "domarry",
}
function Commands.domarry(oMaster)
    local bRet, sMsg = global.oMarryMgr:ValidMarry(oMaster)
    if not bRet then
        oMaster:NotifyMessage(sMsg)
        return
    end
    local oTarget = global.oMarryMgr:GetTeamOther(oMaster)
    if not oTarget then return end

    global.oMarryMgr:DoMarry(oMaster, oTarget)
    oMaster:NotifyMessage("marry成功")
end

Helpers.divorce = {
    "离婚",
    "divorce",
    "divorce",
}
function Commands.divorce(oMaster)
    local iCouplePid = oMaster.m_oMarryCtrl:GetCouplePid()
    if iCouplePid <= 0 then return end

    global.oMarryMgr:LogDivorceInfo(oMaster)
    global.oMarryMgr:OnSuccessDivorce(oMaster)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iCouplePid)
    if oTarget then
        global.oMarryMgr:OnSuccessDivorce(oTarget)
    else
        global.oMarryMgr:OnlineExecute(iCouplePid, "OnSuccessDivorce", {})
    end
end

Helpers.setmarryconfig = {
    "设置结婚参数",
    "setmarryconfig key value",
    "setmarryconfig can_divorce_time 0",
}
function Commands.setmarryconfig(oMaster, sKey, value)
    global.oMarryMgr.m_mTest[sKey] = value
    global.oMarryMgr:CheckDivorce()
    oMaster:NotifyMessage("设置成功") 
end

Helpers.getmarryconfig = {
    "获取参数",
    "getmarryconfig",
    "getmarryconfig",
}
function Commands.getmarryconfig(oMaster, sKey, value)
    for k,v in pairs(global.oMarryMgr.m_mTest) do
        global.oChatMgr:HandleMsgChat(oMaster, string.format("config %s %s", k, v))
    end 
end

Helpers.clearmarryconfig = {
    "delete参数",
    "clearmarryconfig",
    "clearmarryconfig",
}
function Commands.clearmarryconfig(oMaster)
    global.oMarryMgr.m_mTest = {}
end
