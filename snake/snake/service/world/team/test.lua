--import module
local global = require "global"
local extend = require "base.extend"
local handleteam = import(service_path("team/handleteam"))

function TestOP(oPlayer, iFlag , mArgs)
    local oChatMgr=global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    mArgs = mArgs or {}
    --print("team mArgs：",extend.Table.serialize(mArgs))
    if type(mArgs) ~=  "table" then
        oNotifyMgr:Notify(pid,"参数格式不合法,格式：teamop 参数 {参数,参数,...}")
        return
    end
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not  oTeam then
        oNotifyMgr:Notify(pid,"队伍中才能操作")
        return
    end
    if iFlag == 101 then    --teamop 101 {size=5}
        local iSize = mArgs.size or 0
        if iSize>5 or iSize<0 then
            oNotifyMgr:Notify(pid,"队伍数字不合法")
            return
        end
        if iSize == 0 then
            oTeam.m_TestSize = nil
            oNotifyMgr:Notify(pid,"队伍大小恢复默认")
            return
        end
        oTeam.m_TestSize = iSize
        oNotifyMgr:Notify(pid,string.format("队伍大小设置:%s",iSize))
    elseif iFlag == 102 then --teamop 102
        if not oPlayer.m_apply_leader then
            oPlayer.m_apply_leader=1
            oNotifyMgr:Notify(pid,"申请队长CD无限制")
        else
            oPlayer.m_apply_leader=nil
            oNotifyMgr:Notify(pid,"申请队长有CD限制")
        end
    elseif iFlag == 103 then
        handleteam.LeaderNotActive(oTeam)
    elseif iFlag == 104 then
        local mExclude = {}
        mExclude.partner = true
        local sMsg = oTeam:GetScoreDebug(mExclude)
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
    end
    oNotifyMgr:Notify(pid,"指令执行完毕")
end