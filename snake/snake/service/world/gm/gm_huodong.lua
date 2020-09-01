local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.huodongop = true
Helpers.huodongop = {
    "活动测试指令",
    "huodongop sHuodongName, sOrder, mArgs",
    "huodongop fengyao refresh {0, 201000, 0, 15}",
}
function Commands.huodongop(oMaster, sHuodongName, sOrder, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong(sHuodongName)
    if not oHuodong then
        oNotifyMgr:Notify(oMaster:GetPid()," 活动不存在")
        return
    end
    mArgs = mArgs or {}
    table.insert(mArgs, oMaster:GetPid())
    oHuodong:TestOp(sOrder, mArgs)
end

Opens.kshuodongop = true
Helpers.kshuodongop = {
    "跨服活动指令",
    "kshuodongop sHuodongName, sOrder, mArgs",
    "kshuodongop fengyao refresh {0, 201000, 0, 15}",
}
function Commands.kshuodongop(oMaster, sHuodongName, sOrder, mArgs)
    if not is_gs_server() then
        global.oNotifyMgr:Notify(oMaster:GetPid(), "指令只能在GS使用")
        return
    end

    mArgs = mArgs or {}
    table.insert(mArgs, oMaster:GetPid())
    global.oKuaFuMgr:Send2KS("ks101", "GS2KSHuodongCmd", {
        data = mArgs,
        order = sOrder,
        hdname = sHuodongName,
    })
end

Opens.hdmgrop = true
Helpers.hdmgrop = {
    "活动管理指令",
    "hdmgrop iFlag mArgs",
    "hdmgrop 101 ",
}
function Commands.hdmgrop(oMaster,iFlag,mArgs)
    global.oHuodongMgr:TestOP(oMaster,iFlag,mArgs)
end

Opens.jjcfightend = true
Helpers.jjcfightend = {
    "模拟竞技场战斗结果",
    "jjcfightend 对手id 结果(赢1输2)",
    "jjcfightend 100001 1",
}
function Commands.jjcfightend(oMaster, iTarget, iResult)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oMaster:GetPid()
    if pid == iTarget then
        oNotifyMgr:Notify(pid, "对手不能是自己")
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oJJCMgr = global.oJJCMgr
    oWorldMgr:LoadJJC(iTarget, function (oTargetJJC)
        oJJCMgr:OnFightEnd(pid, gamedefines.WAR_WARRIOR_SIDE.FRIEND, iTarget, {win_side=iResult})
        oNotifyMgr:Notify(pid, "指令执行成功")
    end)
end

Opens.jjcrestart = true
Helpers.jjcrestart = {
    "模拟竞技场重新开启",
    "jjcrestart",
    "jjcrestart",
}
function Commands.jjcrestart(oMaster)
    local oJJCMgr = global.oJJCMgr
    local mTimeData = os.date("*t",get_time())
    oJJCMgr:NewGameSeason(mTimeData.month)
    oJJCMgr.m_iVersion = oJJCMgr.m_iVersion + 1
end

Opens.newjjcseason = true
Helpers.newjjcseason = {
    "竞技场新赛季",
    "newjjcseason",
    "newjjcseason",
}
function Commands.newjjcseason(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:NewGameSeason(1)
    oNotifyMgr:Notify(oMaster:GetPid(), "指令执行成功")
end

Opens.clearjjcbuytimes = true
Helpers.clearjjcbuytimes = {
    "清除竞技场购买次数限制",
    "clearjjcbuytimes",
    "clearjjcbuytimes",
}
function Commands.clearjjcbuytimes(oMaster)
    oMaster.m_oTodayMorning:Delete("jjc_buytimes")
    global.oNotifyMgr:Notify(oMaster:GetPid(), "已清除竞技场购买次数限制")
end

Opens.jjcfightrank = true
Helpers.jjcfightrank = {
    "竞技场选取排名作为挑战目标",
    "jjcfightrank iRank",
    "jjcfightrank 1",
}
function Commands.jjcfightrank(oMaster, iRank)
    local oJJCMgr = global.oJJCMgr
    oMaster.m_bGMFight = true
    oJJCMgr:FightTargetByRank(oMaster:GetPid(), iRank)
end

Opens.jjcseasonreward = true
Helpers.jjcseasonreward = {
    "模拟竞技场赛季奖励",
    "jjcseasonreward",
    "jjcseasonreward",
}
function Commands.jjcseasonreward(oMaster)
    local oJJCMgr = global.oJJCMgr
    interactive.Request(".rank", "rank", "GetJJCRankList", {}, function (mRecord, mData)
        local mPids = mData.data
        oJJCMgr:_SendSeasonReward(mPids)
    end)
end

Helpers.jjcdayreward = {
    "模拟竞技场22点奖励",
    "jjcdayreward",
    "jjcdayreward",
}
function Commands.jjcdayreward(oMaster)
    local oJJCMgr = global.oJJCMgr
    interactive.Request(".rank", "rank", "GetJJCRankList", {}, function (mRecord, mData)
        local mPids = mData.data
        oJJCMgr:_SendDayReward(mPids)
    end)
end

Opens.jjcsetresettime = true
Helpers.jjcsetresettime = {
    "竞技场设置玩家上次刷时间",
    "jjcsetresettime iHour",
    "jjcsetresettime 4",
}
function Commands.jjcsetresettime(oMaster, iHour)
    local oJJC = oMaster:GetJJC()
    oJJC.m_iResetTime = get_time() - iHour*3600
    oJJC:Dirty()
    oMaster:NotifyMessage("设置成功")
end

function Commands.redpacket(oMaster,iFlag,arg)
    local oRedPacketMgr=global.oRedPacketMgr
    oRedPacketMgr:TestOP(oMaster,iFlag,arg)
end

Opens.campfirestop = true
Helpers.campfirestop = {
    "篝火活动强制关闭",
    "campfirestop",
    "campfirestop",
}
function Commands.campfirestop(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgcampfire")
    oHuodong:Stop()
    oNotifyMgr:Notify(oMaster:GetPid(), "帮派篝火活动已关闭")
end

Opens.campfiresetup = true
Helpers.campfiresetup = {
    "篝火活动时间启动计划",
    "campfiresetup iPrepareSec iReadySec iOpenSec",
    "campfiresetup 0 300 900",
}
function Commands.campfiresetup(oMaster, iPrepareSec, iReadySec, iOpenSec)
    local oNotifyMgr = global.oNotifyMgr
    if not iPrepareSec or not iReadySec or not iOpenSec then
        oNotifyMgr:Notify(oMaster:GetPid(), "需要参数：准备时间 提前就绪时间 开启时间")
        return
    end
    if iReadySec < 0 or iOpenSec < 0 then
        oNotifyMgr:Notify(oMaster:GetPid(), "时间参数不能为负数")
        return
    end
    if not global.oToolMgr:IsSysOpen("ORG_CAMPFIRE") then
        oNotifyMgr:Notify(oMaster:GetPid(), "活动在open表中关闭")
        return
    end
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgcampfire")
    oHuodong:ClearSetup()
    oHuodong:SetupRun(iPrepareSec, iReadySec, iOpenSec)
    oNotifyMgr:Notify(oMaster:GetPid(), string.format("帮派篝火活动开始准备，%d秒后提醒入场，再%d秒后开启，持续%d秒后关闭", iPrepareSec, iReadySec, iOpenSec))
end

Opens.clearsche = true
Helpers.clearsche = {
    "日程清刷数据",
    "daysche pid(0表示自己) type('d'天日程/'w'周日程)",
    "daysche 0 'd'",
}
function Commands.clearsche(oMaster, iTargetPid, sType)
    local oTarget
    if not iTargetPid or iTargetPid == 0 then
        oTarget = oMaster
    else
        oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    end
    if not oTarget then
        oMaster:NotifyMessage("角色[" .. iTargetPid or 0 .. "]不在线")
        return
    end
    if sType == 'd' then
        oTarget.m_oScheduleCtrl:ResetDaily()
    elseif sType == 'w' then
        oTarget.m_oScheduleCtrl:ResetWeekly()
    else
        oMaster:NotifyMessage("daysche pid(0表示自己) type('d'天日程/'w'周日程)")
        return
    end
    oMaster:NotifyMessage("清理完成")
end

Opens.sethdcontrol = true
Helpers.sethdcontrol = {
    "设置活动时间(时间都是相对于当前时间)　",
    "sethdcontrol 活动类型　活动key 开启时间(当前分)　结束时间(当前分)",
    "sethdcontrol collect collect_key_1 0 60",
}
function Commands.sethdcontrol(oMaster, sHDType, sHDKey, iStart, iEnd)
    local mInfo = {}
    local iNowTime = get_time()
    mInfo["hd_id"] = iNowTime
    mInfo["hd_type"] = sHDType
    mInfo["hd_key"] = sHDKey
    mInfo["start_time"] = iNowTime + iStart * 60
    mInfo["end_time"] = iNowTime + iEnd * 60
    mInfo["desc"] = "gm"..oMaster:GetPid()
    
    local oYunYingMgr = global.oYunYingMgr
    if oYunYingMgr.m_mHuoDong[iNowTime] then
        return
    end

    local oYunYingMgr = global.oYunYingMgr
    oYunYingMgr:RegisterHD(mInfo)
    if oYunYingMgr.m_mHuoDong[iNowTime] then
        oMaster:NotifyMessage("添加成功")
    else
        oMaster:NotifyMessage("添加失败")
    end
end

Opens.gethdcontrol = true
Helpers.gethdcontrol = {
    "查看活动时间",
    "gethdcontrol",
    "gethdcontrol",
}
function Commands.gethdcontrol(oMaster)
    local oYunYingMgr = global.oYunYingMgr
    for id, m in pairs(oYunYingMgr.m_mHuoDong) do
        local sMsg = string.format("活动id:%s, 类型:%s KEY:%s 开始时间:%s 结束时间:%s　描述:%s", 
            m.hd_id, m.hd_type, m.hd_key, get_format_time(m.start_time), get_format_time(m.end_time), m.desc)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end

Opens.delhdcontrol = true
Helpers.delhdcontrol = {
    "删除活动时间",
    "delhdcontrol id",
    "delhdcontrol 1513064638",
}
function Commands.delhdcontrol(oMaster, id)
    local oYunYingMgr = global.oYunYingMgr
    oYunYingMgr:UnRegisterHD({id})
    oMaster:NotifyMessage("删除成功")
end


Opens.hottopicop = true
Helpers.hottopicop = {
    "热门活动公告",
    "hottopicop op",
    "hottopicop 100"
}
function Commands.hottopicop(oMaster, sOrder, mArgs)
    mArgs = mArgs or {}
    table.insert(mArgs, oMaster:GetPid())
    global.oHotTopicMgr:TestOp(sOrder, mArgs)
end

Helpers.hdreward = {
    "活动奖励",
    "hdreward hdname rewardidx",
    "hdreward moneytree 1001"
}
function Commands.hdreward(oMaster, sHuodong, iReward)
    local oHuodong = global.oHuodongMgr:GetHuodong(sHuodong)
    if not oHuodong then
        oMaster:NotifyMessage("没有活动"..sHuodong)
        return
    end
    oHuodong:Reward(oMaster:GetPid(), iReward, {})
end

