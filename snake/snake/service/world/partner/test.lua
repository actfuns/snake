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
    if iFlag == 101 then --partnerop 101
        local oChatMgr=global.oChatMgr
        oChatMgr:HandleMsgChat(oPlayer,string.format("伙伴评分%s",oPlayer.m_oPartnerCtrl:GetScoreDebug()))
    end
    oNotifyMgr:Notify(pid,"指令执行完毕")
end