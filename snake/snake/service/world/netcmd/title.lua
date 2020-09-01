--import module

local global = require "global"
local skynet = require "skynet"


function C2GSUseTitle(oPlayer, mData)
    local iTid = mData.tid
    local iFlag = mData.flag
    local oTitleMgr = global.oTitleMgr

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene and oScene:IsForbidTitleOp() then
        oPlayer:NotifyMessage("当前场景不可切换称谓")
        return
    end

    if iFlag == 1 then
        oTitleMgr:UseTitle(oPlayer, iTid)
    else
        oTitleMgr:UnUseTitle(oPlayer)
    end
end
