local global = require "global"
local extend = require "base.extend"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Helpers.rideop = {
    "玩家测试指令",
    "rideop iFlag mArgs",
    "rideop 101 ",
}
function Commands.rideop(oMaster,iFlag,mArgs)
    local ridetest = import(service_path("ride/test"))
    ridetest.TestOP(oMaster,iFlag,mArgs)
end

Opens.addride = true
Helpers.addride = {
    "增加坐骑",
    "addride 坐骑id 是否上马",
    "addride 1001 1",
}
function Commands.addride(oMaster, iRide, iFight)
    local oRideMgr = global.oRideMgr
    local oRide = oRideMgr:CreateNewRide(iRide)
    if not oRide then
        oMaster:NotifyMessage("坐骑不存在")
        return
    end
    oMaster.m_oRideCtrl:AddRide(oRide)
    if iFight then
        global.oRideMgr:UseRide(oMaster, iRide, 1)
    end
end

Opens.clearride = true
Helpers.clearride = {
    "清空坐骑",
    "clearride",
    "clearride",
}
function Commands.clearride(oMaster)
    oMaster.m_oRideCtrl:UnUseRide()
    for iRide, oRide in pairs(oMaster.m_oRideCtrl.m_mRides) do
        oMaster.m_oRideCtrl:DeleteRide(iRide, true)
    end
    oMaster:NotifyMessage("清空坐骑")
end

Opens.rideexp = true
Helpers.rideexp = {
    "坐骑经验",
    "rideexp 值",
    "rideexp 1000",
}
function Commands.rideexp(oMaster, iVal)
    oMaster.m_oRideCtrl:AddExp(iVal, "GM")
    oMaster:NotifyMessage("经验添加成功")
end

Opens.setrideexpire = true
Helpers.setrideexpire = {
    "设置坐骑过期时间",
    "setrideexpire 坐骑id 分钟",
    "setrideexpire 1001 30",
}
function Commands.setrideexpire(oMaster, iRide, iMin)
    local oRide = oMaster.m_oRideCtrl:GetRide(iRide)
    if not oRide then
        oMaster:NotifyMessage("坐骑不存在")
        return
    end

    oRide.m_iExpireTime = get_time() + iMin * 60
    oRide:Dirty()
    oRide:_CheckExpire()
    oRide:GS2CUpdateRide(oMaster)
    oMaster:NotifyMessage("设置成功")
end

Opens.clearrideskill = true
Helpers.clearrideskill = {
    "清空坐骑技能",
    "clearrideskill",
    "clearrideskill",
}
function Commands.clearrideskill(oMaster)
    local oRideCtrl = oMaster.m_oRideCtrl
    local iGrade = oRideCtrl:GetGrade()
    local iExp = oRideCtrl:GetExp()
    oMaster.m_oRideCtrl:ResetRideSkill(oMaster, iGrade, iExp)
end

Opens.addrideskill = true
Helpers.addrideskill = {
    "设置坐骑技能",
    "addrideskill id level",
    "addrideskill 5900 1",
}
function Commands.addrideskill(oMaster, iSk, iLevel)
    local oSkill = global.oRideMgr:CreatNewSkill(iSk)
    oSkill:AddLevel(iLevel)
    local bRet = oMaster.m_oRideCtrl:AddSkill(oSkill)
    if not bRet then
        oMaster:NotifyMessage("添加技能失败")
        return
    end
    oMaster.m_oRideCtrl:GS2CPlayerRideInfo("point", "skills", "score")
    oMaster:NotifyMessage("添加技能成功")
end

Opens.setwenshilast = true
Helpers.setwenshilast = {
    "设置纹饰耐久度",
    "setwenshilast ride pos last",
    "setwenshilast 1001 1　30",
}
function Commands.setwenshilast(oMaster, iRide, iPos, iLast)
    local oRide = oMaster.m_oRideCtrl:GetRide(iRide)
    if not oRide then
        oMaster:NotifyMessage("坐骑不存在")
        return
    end
    local oWenShi = oRide:GetWenShiByPos(iPos)
    if not oWenShi then
        oMaster:NotifyMessage("纹饰不存在")
        return
    end
    oWenShi:SetData("last", iLast)
    oRide:UpdateControlSummon()
    oRide:GS2CUpdateRide(oMaster)     
    oMaster:NotifyMessage("set成功")
end
