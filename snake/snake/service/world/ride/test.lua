--import module
local global = require "global"
local extend = require "base.extend"

function TestOP(oPlayer, iFlag , mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    mArgs = mArgs or {}
    if type(mArgs) ~=  "table" then
        oNotifyMgr:Notify(pid,"参数格式不合法,格式：teamop 参数 {参数,参数,...}")
        return
    end
    if iFlag == 101 then --rideop 101
        local iScore = oPlayer.m_oRideCtrl:GetScore()
        local iBasicScore = oPlayer.m_oRideCtrl:GetBasicScore()
        local oRide = oPlayer.m_oRideCtrl:GetUseRide()
        local sRideScore = "无坐骑"
        local iRideScore = 0
        if oRide then
            sRideScore = oRide:GetScoreDebug()
            iRideScore = oRide:GetScore()
        end
        local iSkillScore = iScore - iRideScore - iBasicScore
        oNotifyMgr:Notify(pid,string.format("坐骑评分%s=%s(属性)+%s(领悟技能)+%s",iScore,iBasicScore,iSkillScore,sRideScore))
    end
    oNotifyMgr:Notify(pid,"指令执行完毕")
end