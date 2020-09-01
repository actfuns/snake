local global = require "global"
local res = require "base.res"
local extend = require "base/extend"
local testdefines = import(service_path("defines/testdefines"))

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Helpers.showlocks={
    "显示任务锁",
    "showlocks",
    "showlocks",
}
function Commands.showlocks(oMaster)
    local mUnlocks = oMaster.m_oTaskCtrl:GetAllUnlockedTags()
    local sMsg = table.concat(table_key_list(mUnlocks), ", ")
    if #sMsg == 0 then
        sMsg = "无"
    end
    oMaster:NotifyMessage("已解锁：" .. sMsg)
end

Helpers.locktag={
    "任务锁解锁",
    "locktag 锁编号(-1表示全部)",
    "locktag 10"
}
function Commands.locktag(oMaster, iTag)
    if not iTag then
        oMaster:NotifyMessage("参数错误")
        return
    end
    local res = require "base.res"
    local mDefinedTags = table_get_depth(res, {"daobiao", "task_ext", "taglock"})
    if not mDefinedTags then
        oMaster:NotifyMessage("没有配置任务锁")
        return
    end
    if iTag < 0 then
        for iGotTag, _ in pairs(oMaster.m_oTaskCtrl:GetAllUnlockedTags() or {}) do
            oMaster.m_oTaskCtrl:LockTag(iGotTag)
        end
        oMaster:NotifyMessage("已加锁全部")
        return
    end
    if not mDefinedTags[iTag] then
        oMaster:NotifyMessage("没有配置锁" .. iTag)
        return
    end
    oMaster.m_oTaskCtrl:LockTag(iTag)
    oMaster:NotifyMessage("已加锁：" .. iTag)
end

Helpers.unlocktag={
    "任务锁解锁",
    "unlocktag 锁编号(-1表示全部)",
    "unlocktag 10"
}
function Commands.unlocktag(oMaster, iTag)
    local res = require "base.res"
    local mDefinedTags = table_get_depth(res, {"daobiao", "task_ext", "taglock"})
    if not mDefinedTags then
        oMaster:NotifyMessage("没有配置任务锁")
        return
    end
    if iTag < 0 then
        for iDefTag, _ in pairs(mDefinedTags) do
            oMaster.m_oTaskCtrl:UnlockTag(iDefTag)
        end
        oMaster:NotifyMessage("已解锁全部")
        return
    end
    if not mDefinedTags[iTag] then
        oMaster:NotifyMessage("没有配置锁" .. iTag)
        return
    end
    oMaster.m_oTaskCtrl:UnlockTag(iTag)
    oMaster:NotifyMessage("已解锁：" .. iTag)
end

Helpers.opennewbieguide = {
    "开启新手指引",
    "opennewbieguide 是否开启",
    "opennewbieguide 0/1",
}
function Commands.opennewbieguide(oMaster, iIsSet)
    if iIsSet == 1 then
        oMaster.m_oBaseCtrl.m_oTestCtrl:DelTesterKey(testdefines.TESTER_KEY.NO_GUIDE)
        oMaster:NotifyMessage("已开启新手指引")
        local mNetNewbieInfo = global.oNewbieGuideMgr:PackNewbieGuideInfo(oMaster)
        oMaster:Send("GS2CNewbieGuideInfo", mNetNewbieInfo)
    elseif iIsSet == 0 then
        oMaster.m_oBaseCtrl.m_oTestCtrl:SetTesterKey(testdefines.TESTER_KEY.NO_GUIDE)
        oMaster:NotifyMessage("已关闭新手指引，重新登录生效")
    else
        oMaster:NotifyMessage(string.format("当前是/否开启新手指引:#G%s#n，用0/1参数关/开", oMaster.m_oBaseCtrl.m_oTestCtrl:GetTesterKey(testdefines.TESTER_KEY.NO_GUIDE) == nil))
    end
end

Helpers.openchecktask = {
    "open表检查任务锁",
    "openchecktask 是否设置",
    "openchecktask 0/1",
}
function Commands.openchecktask(oMaster, iIsSet)
    if iIsSet == 1 then
        oMaster:Set("open_check_task_lock", true)
        oMaster:NotifyMessage("已加检查")
    elseif iIsSet == 0 then
        oMaster:Set("open_check_task_lock", nil)
        oMaster:NotifyMessage("已移去检查")
    else
        oMaster:NotifyMessage(string.format("当前是/否检查:%s，用0/1参数关/开", oMaster:Query("open_check_task_lock", false)))
        return
    end
    global.oSysOpenMgr:RecheckAllSys(oMaster)
end

Helpers.skipopenchecktask = {
    "忽略open表检查任务锁",
    "skipopenchecktask 是否设置",
    "skipopenchecktask 0/1（关/开）",
}
function Commands.skipopenchecktask(oMaster, iIsSet)
    if iIsSet == 1 then
        oMaster:Set("skip_open_check_task_lock", true)
        oMaster:NotifyMessage("已加检查忽略")
    elseif iIsSet == 0 then
        oMaster:Set("skip_open_check_task_lock", nil)
        oMaster:NotifyMessage("已移去检查忽略")
    else
        oMaster:NotifyMessage(string.format("当前是/否忽略检查:%s，用0/1参数关/开", oMaster:Query("skip_open_check_task_lock", false)))
        return
    end
    global.oSysOpenMgr:RecheckAllSys(oMaster)
end

Helpers.tester = {
    "设置角色永久测试效果",
    "tester [flag]",
    "tester 1",
}
function Commands.tester(oMaster, iFlag)
    local sMsg = [[设置角色做为测试者的效果：
    0: -恢复正常
    1: +无新手指引
    2: +系统全开
    3: +系统全开+无新手指引
    -1: 查看当前设置 ]]
    if not iFlag then
        oMaster:NotifyMessage(sMsg)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
        return
    end
    if iFlag == 0 then
        oMaster.m_oBaseCtrl.m_oTestCtrl:ClearTesterKeys()
        oMaster:NotifyMessage("已移去tester设置")
    elseif iFlag == 1 then
        oMaster.m_oBaseCtrl.m_oTestCtrl:SetTesterKey(testdefines.TESTER_KEY.NO_GUIDE)
        oMaster:NotifyMessage("已设置玩家tester信息 NO_GUIDE")
    elseif iFlag == 2 then
        oMaster.m_oBaseCtrl.m_oTestCtrl:SetTesterKey(testdefines.TESTER_KEY.ALL_SYS_OPEN)
        oMaster:NotifyMessage("已设置玩家tester信息 ALL_SYS_OPEN")
    elseif iFlag == 3 then
        oMaster.m_oBaseCtrl.m_oTestCtrl:SetTesterKey(testdefines.TESTER_KEY.NO_GUIDE)
        oMaster.m_oBaseCtrl.m_oTestCtrl:SetTesterKey(testdefines.TESTER_KEY.ALL_SYS_OPEN)
        oMaster:NotifyMessage("已设置玩家tester信息 NO_GUIDE+ALL_SYS_OPEN")
    else
        local lKeys = oMaster.m_oBaseCtrl.m_oTestCtrl:GetTesterAllKeys()
        local sKeyList = table.concat(lKeys, ",")
        if #sKeyList == 0 then
            sKeyList = "无"
        end
        oMaster:NotifyMessage(string.format("当前已设置的玩家tester信息：[%s]", sKeyList))
        return
    end
    oMaster:SyncTesterKeys()
end

Helpers.cleargotsrec = {
    "清除已执行记录",
    "cleargotsrec 玩法名/?用以查询全部",
    "cleargotsrec gradegift",
}
function Commands.cleargotsrec(oMaster, sName)
    local lAllSysNames = {
        gradegift = "升级礼包",
        preopengift = "功能预览礼包",
        sysopened = "新功能开启提示",
        newbie = "新手指引",
    }
    if not sName or sName == "?" then
        goto not_executable
        return
    end
    if sName == "gradegift" then
        oMaster.m_oActiveCtrl.m_oGiftMgr:Dirty()
        oMaster.m_oActiveCtrl.m_oGiftMgr.m_mGradeRewarded = {}
        oMaster.m_oActiveCtrl.m_oGiftMgr:OnLogin(oMaster, true)
    elseif sName == "preopengift" then
        oMaster.m_oActiveCtrl.m_oGiftMgr:Dirty()
        oMaster.m_oActiveCtrl.m_oGiftMgr.m_mPreopenRewarded = {}
        oMaster.m_oActiveCtrl.m_oGiftMgr:OnLogin(oMaster, true)
    elseif sName == "sysopened" then
        oMaster:Set("sys_open_nofitied", {})
        global.oNewbieGuideMgr:OnLogin(oMaster, true)
    elseif sName == "newbie" then
        oMaster:Set("newbie_guide", {})
        oMaster:Set("newbie_summon", nil)
        oMaster:Set("newbie_rwd_upgrade", nil)
        oMaster:Set("mailed_upgrade", nil)
        global.oNewbieGuideMgr:OnLogin(oMaster, true)
    else
        goto not_executable
        return
    end
    if true then
        oMaster:NotifyMessage("已清空，请重新登录查看效果")
        return
    end
    ::not_executable::
    oMaster:NotifyMessage("清空玩法记录。可用玩法指令：" .. extend.Table.serialize(lAllSysNames))
end

Helpers.setsysopen = {
    "设置系统开放",
    "setsysopen sys flag",
    "setsysopen 'PAY_SYS' 1",
}
function Commands.setsysopen(oMaster, sSys, iOpen)
    if not global.oToolMgr:GetSysOpenConfig()[sSys] then
        oMaster:NotifyMessage("not sys")
        return
    end
    iOpen = tonumber(iOpen)
    if not iOpen then
        oMaster:NotifyMessage("flag error")     
        return
    end
    global.oToolMgr:SetSysOpenStatus({sSys}, iOpen)
    oMaster:NotifyMessage("设置成功")    
end


