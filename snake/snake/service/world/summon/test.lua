--import module
local global = require "global"
local extend = require "base.extend"

function TestOP(oPlayer, iFlag , mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr=global.oChatMgr
    local pid = oPlayer:GetPid()
    mArgs = mArgs or {}
    if type(mArgs) ~=  "table" then
        oNotifyMgr:Notify(pid,"参数格式不合法,格式：teamop 参数 {参数,参数,...}")
        return
    end
    if iFlag == 101 then
        local iScore = oPlayer.m_oSummonCtrl:GetScore()
        local lScore = {}
        local sMsg = ""
        for _, oSummon in pairs(oPlayer.m_oSummonCtrl.m_mSummons) do
            table.insert(lScore,{oSummon:GetScore(),oSummon})
        end
        table.sort(lScore,function (a,b)
            return a[1]>b[1]
        end)
        for i , lInfo in ipairs(lScore) do
            if i<=3 then
                sMsg = sMsg .. " + " .. lInfo[2]:GetScoreDebug()
            end
        end
        oChatMgr:HandleMsgChat(oPlayer,string.format("当前宠物评分%s=%s",iScore,sMsg))
    end
    oNotifyMgr:Notify(pid,"指令执行完毕")
end