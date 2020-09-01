local global = require "global"
local res = require "base.res"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Opens.teamop = true
Helpers.teamop = {
    "队伍测试指令",
    "teamop iFlag mArgs",
    "teamop 101 {5}",
}
function Commands.teamop(oMaster,iFlag,mArgs)
    local teamtest = import(service_path("team/test"))
    teamtest.TestOP(oMaster,iFlag,mArgs)
end

Helpers.setguildamount = {
    "设置商会道具数量",
    "setguildamount good_id amount",
    "setguildamount 10007 1",
}
function Commands.setguildamount(oMaster, iGood, iAmount)
    local oNotifyMgr = global.oNotifyMgr
    local oGuild = global.oGuild
    local oItem = oGuild:GetItem(iGood)
    if oItem then
        oItem:SetData("amount", iAmount)
        oNotifyMgr:Notify(oMaster:GetPid(), "设置成功,重新打开界面以刷新")
    else
        oNotifyMgr:Notify(oMaster:GetPid(), "道具不存在")
    end
end

Helpers.guildnewhour = {
    "商会刷时",
    "guildnewhour iDay, iHour",
    "guildnewhour 0 5",
}
function Commands.guildnewhour(oMaster, iDay, iHour)
    global.oGuild:NewHour(get_wdaytime({wday=iDay, hour=iHour}))
    global.oNotifyMgr:Notify(oMaster:GetPid(), "执行NewHour")
end

Helpers.guildresetprice = {
    "商会刷时",
    "guildnewhour 商品id 价格为0表示默认初始价格",
    "guildnewhour 1001 0",
}

function Commands.guildresetprice(oMaster, iGood, iPrice)
    local oProxyItem = global.oGuild:GetItem(iGood)
    if not oProxyItem then
        global.oNotifyMgr:Notify(oMaster:GetPid(), "没有该商品")
        return
    end
    if not iPrice or iPrice == 0 then
        oProxyItem:InitPrice()
        oProxyItem:DoStubDayPrice()
    else
        oProxyItem:SetPrice(iPrice)
        oProxyItem:DoStubDayPrice(iPrice)
    end
end

Helpers.newbulletbarrage = {
    "newbulletbarrage iVideo iType"
}
function Commands.newbulletbarrage(oMaster, iVideo, iType)
        global.oBulletBarrageMgr:AddWarBulletBarrage(iVideo,iType)
end

Helpers.savebulletbarrage = {
    "savebulletbarrage"
}
function Commands.savebulletbarrage(oMaster)
    global.oBulletBarrageMgr:_CheckSave()
end

Helpers.addbulletbarragecontents = {
    "addbulletbarragecontents iVideo iType iBout iSesc sName sMsg"
}
function Commands.addbulletbarragecontents(oMaster,...)
    local iVideo,iType,iBout,iSesc,sName,sMsg = ...
    local oBulletBarrageMgr = global.oBulletBarrageMgr
    local mContents = {}
    mContents.bout = tonumber(iBout)
    mContents.secs = tonumber(iSesc)
    mContents.name = sName
    mContents.msg = sMsg
    oBulletBarrageMgr:AddBulletBarrageContents(tonumber(iVideo),tonumber(iType),mContents)
end

function Commands.push(oMaster, pid, sTitle, sText)
    global.oGamePushMgr:Push(pid, sTitle, sText)
end

Helpers.sendsys = {
    "发送系统聊天信息",
    "sendsys 内容(非数字加上单引号) ",
    "sendsys 233333  ",
}
function Commands.sendsys(oMaster, sMsg, ...)
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleSysChat(tostring(sMsg), ...)
end

Opens.feedbackop = true
Helpers.feedbackop = {
    "客服反馈指令",
    "feedbackop iFlag mArgs",
    "feedbackop 100",
}

function Commands.feedbackop(oMaster, iFlag, mArgs)
    local oFeedBackCtrl = global.oWorldMgr:GetFeedBack(oMaster:GetPid())
    mArgs = mArgs or {}
    mArgs[#mArgs + 1] = oMaster:GetPid()
    if not oFeedBackCtrl  then return end
    oFeedBackCtrl:TestOp(iFlag, mArgs)
end
