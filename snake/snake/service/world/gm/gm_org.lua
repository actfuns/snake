local global = require "global"
local extend = require "base.extend"
local res = require "base.res"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Opens.orgcreate = true
Helpers.orgcreate = {
    "创建帮派",
    "orgcreate",
    "orgcreate",
}
function Commands.orgcreate(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    if oMaster:GetOrgID() ~= 0 then
        oNotifyMgr:Notify(oMaster:GetPid(), "你已有帮派")
        return
    end
    local sName, sAim = string.format("帮派%d", math.random(1, 10000)), string.format("内容%d", math.random(1, 10000))
    local oOrgMgr = global.oOrgMgr
    -- TODO new createorg
    oOrgMgr:CreateNormalOrg(oMaster, sName, sAim, true)
    -- oOrgMgr:CreateReadyOrg(oMaster, sName, sAim, true)
    oNotifyMgr:Notify(oMaster:GetPid(), "创建帮派成功")
end

Opens.orgresponse = true
Helpers.orgresponse = {
    "响应帮派",
    "orgresponse",
    "orgresponse",
}
function Commands.orgresponse(oMaster)
    local oOrgMgr = global.oOrgMgr
    local oNotifyMgr = global.oNotifyMgr
    for orgId, org in pairs(oOrgMgr.m_mReadyOrgs) do
        if org:GetLeader() == oMaster:GetPid() then
            oOrgMgr:CreateNormalOrg_old(org)
            break
        end
    end
    oNotifyMgr:Notify(oMaster:GetPid(), "响应帮派成功")
end

Opens.clearorg = true
Helpers.clearorg = {
    "清理帮派",
    "clearorg",
    "clearorg",
}
function Commands.clearorg(oMaster)
    local oOrgMgr = global.oOrgMgr
    local lDelOrg = {}
    for iOrg, oOrg in pairs(oOrgMgr.m_mNormalOrgs) do
        if oOrg:GetMemberCnt() <= 0 then
            table.insert(lDelOrg, iOrg)
        end
    end
    for _, iOrg in pairs(lDelOrg) do
        oOrgMgr:DismissNormalOrg(iOrg)
    end 
    oOrgMgr:GenerateCache()
    oMaster:NotifyMessage("清理帮派")
end

Opens.addorg = true
Helpers.addorg = {
    "加入帮派",
    "addorg 帮派Id",
    "addorg orgid",
}
function Commands.addorg(oMaster, orgid)
    local oOrgMgr = global.oOrgMgr
    local oNotifyMgr = global.oNotifyMgr
    local oOrg = oOrgMgr:GetNormalOrg(orgid)
    if not oOrg then
        oNotifyMgr:Notify(oMaster:GetPid(), "帮派不存在")
        return
    end
    oOrgMgr:AddForceMember(orgid, oMaster)
    oNotifyMgr:Notify(oMaster:GetPid(), "加入帮派成功")
end

Opens.addorgoffer = true
Helpers.addorgoffer = {
    "增加帮贡",
    "addorgoffer 值",
    "addorgoffer 1000",
}
function Commands.addorgoffer(oMaster, iVal)
    oMaster:AddOrgOffer(iVal, "gm增加帮贡")
    oMaster:NotifyMessage("增加帮贡成功", "gm")
end

Opens.addorglog = true
Helpers.addorglog = {
    "增加log",
    "addorglog sMsg",
    "addorglog sMsg",
}
function Commands.addorglog(oMaster, sMsg)
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end
    oOrg:AddLog(oMaster:GetPid(), sMsg)
    oMaster:NotifyMessage("增加帮派日志成功")
end

Opens.addorghuoyue = true
Helpers.addorghuoyue = {
    "增加帮派活跃点",
    "addorghuoyue 值",
    "addorghuoyue 1000",
}
function Commands.addorghuoyue(oMaster, iVal)
    if not oMaster:GetOrg() then
        return
    end
    oMaster:AddOrgHuoYue(iVal)
    oMaster:NotifyMessage("增加帮派活跃点成功")
end

Opens.addorgcash = true
Helpers.addorgcash = {
    "增加帮派资金",
    "addorgcash 值",
    "addorgcash 1000",
}
function Commands.addorgcash(oMaster, iVal)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    oOrg:AddCash(iVal, oMaster:GetPid())
    oOrg:GS2COrgInfoChange(oMaster:GetPid(), {cash=oOrg:GetCash()})
    oMaster:NotifyMessage("增加帮派资金成功")
end

Opens.quickorgbuild = true
Helpers.quickorgbuild = {
    "加速帮派建造时间",
    "quickorgbuild 建造id 秒",
    "quickorgbuild  101 1000",
}
function Commands.quickorgbuild(oMaster, iBid, iVal)
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end

    local oBuild = oOrg.m_oBuildMgr:GetHasBuilding(iBid)
    if not oBuild then return end

    oBuild:QuickBuild(oMaster:GetPid(), iVal, true)
    oMaster:Send("GS2CGetBuildInfo", {infos={oBuild:PackBuildInfo(oMaster:GetPid())}})
    if iBid == 101 then
        oOrg:GS2COrgInfoChange(oMaster:GetPid(), {level=oBuild:Level()})    
    end
end

Opens.setmuljoinorg = true
Helpers.setmuljoinorg = {
    "设置一键申请时间",
    "setmuljoinorg",
    "setmuljoinorg",
}
function Commands.setmuljoinorg(oMaster)
    local oOrgMgr = global.oOrgMgr
    oOrgMgr:Dirty()
    oOrgMgr.m_mMulApplyTime[oMaster:GetPid()] = nil
    oMaster:NotifyMessage("设置一键申请时间成功")
end

Opens.addorgboom = true
Helpers.addorgboom = {
    "增加帮派繁荣度",
    "addorgboom 值",
    "addorgboom 1000",
}
function Commands.addorgboom(oMaster, iVal)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    oOrg:AddBoom(iVal)
    oMaster:NotifyMessage("增加帮派繁荣度成功")
end

Opens.setboomhwdays = true
Helpers.setboomhwdays = {
    "设置帮派繁荣度荒芜天数",
    "setboomhwdays 天",
    "setboomhwdays 10",
}
function Commands.setboomhwdays(oMaster, iVal)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    oOrg.m_oBaseMgr:ClearHwDay()
    oOrg.m_oBaseMgr:AddHwDay(iVal)
    oMaster:NotifyMessage("设置帮派繁荣度荒芜天数"..oOrg.m_oBaseMgr:GetHwDay())
end

Opens.setorgleaderlogouttime = true
Helpers.setorgleaderlogouttime = {
    "设置帮主最后上线时间",
    "setorgleaderlogouttime 天",
    "setorgleaderlogouttime 7",
}
function Commands.setorgleaderlogouttime(oMaster, iDay)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    local iTime = get_time() - iDay * 24 * 60 * 60
    oOrg:SyncMemberData(oOrg:GetLeaderID(), {logout_time=iTime})
    oMaster:NotifyMessage("设置帮主最后上线时间成功")
end

Opens.setorgmemberlogouttime = true
Helpers.setorgmemberlogouttime = {
    "设置帮派成员最后上线时间",
    "setorgmemberlogouttime pid 天",
    "setorgmemberlogouttime 1001 7",
}
function Commands.setorgmemberlogouttime(oMaster, iPid, iDay)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    local iTime = get_time() - iDay * 24 * 60 * 60
    oOrg:SyncMemberData(iPid, {logout_time=iTime})
    oMaster:NotifyMessage("设置帮派成员最后上线时间")
end

Opens.orgnewhour = true
Helpers.orgnewhour = {
    "帮派定点逻辑",
    "orgnewhour hour 是否周一",
    "orgnewhour 5 1",
}
function Commands.orgnewhour(oMaster, iHour, bMonday)
    local oOrgMgr = global.oOrgMgr
    oOrgMgr:PushOrgStatistics()
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end
        
    oOrg.m_oBaseMgr:SetData("daymorning", 0)
    oOrg:NewHour(get_daytime({anchor=iHour}))
    if bMonday == 1 then
        oOrg:WeekMaintain()
    end
    oMaster:NotifyMessage("执行帮派定点逻辑成功")
end

Opens.orgachieve = true
Helpers.orgachieve = {
    "触发某个成就",
    "orgachieve type 参数",
    "orgachieve 5 {}",
}
function Commands.orgachieve(oMaster, type, mArgs)
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end
        
    oOrg.m_oAchieveMgr:HandleEvent(type, mArgs)
    oMaster:NotifyMessage("触发某个成就成功")
end

Opens.orgapplyleadersuccess = false
Helpers.orgapplyleadersuccess = {
    "执行自荐成功",
    "orgapplyleadersuccess",
    "orgapplyleadersuccess",
}
function Commands.orgapplyleadersuccess(oMaster, iHour)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    -- 暂时这样执行
    oOrg:_ApplyLeaderSuccess()
    oMaster:NotifyMessage("执行自荐成功")
end

Opens.orgsettest = false
Helpers.orgsettest = {
    "帮派设置测试数据",
    "orgsettest key value",
    "orgsettest xuetucnt 20",
}
function Commands.orgsettest(oMaster, sKey, sValue)
    local oOrg = oMaster:GetOrg()
    if not oOrg then
        return
    end
    oOrg:SetTest(sKey, sValue)
end

Opens.orggettest = false
Helpers.orggettest = {
    "帮派设置测试数据",
    "orggettest",
    "orggettest",
}
function Commands.orggettest(oMaster)
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end

    for sKey, value in pairs(oOrg.m_mTest) do
        global.oChatMgr:HandleMsgChat(oMaster, string.format("org %s %s", sKey, value))    
    end
end

Opens.orgsetglobaltest = false
Helpers.orgsetglobaltest = {
    "帮派设置other表测试数据",
    "orgsetglobaltest key value",
    "orgsetglobaltest apply_valid_time 20",
}
function Commands.orgsetglobaltest(oMaster, sKey, sValue)
    global.oOrgMgr:SetTestData(sKey, sValue)
end

Opens.orggetglobaltest = false
Helpers.orggetglobaltest = {
    "帮派设置other表测试数据",
    "orggetglobaltest",
    "orggetglobaltest",
}
function Commands.orggetglobaltest(oMaster)
    for sKey, value in pairs(global.oOrgMgr.m_mTestData) do
        global.oChatMgr:HandleMsgChat(oMaster, string.format("org %s %s", sKey, value))    
    end
end

Opens.orgclearglobaltest = false
Helpers.orgclearglobaltest = {
    "clear other表测试数据",
    "orgclearglobaltest",
    "orgclearglobaltest",
}
function Commands.orgclearglobaltest(oMaster)
    global.oOrgMgr.m_mTestData = {}
end

Opens.addorgprestige = true
Helpers.addorgprestige = {
    "增加帮贡",
    "addorgprestige 值",
    "addorgprestige 1000",
}
function Commands.addorgprestige(oMaster, iVal)
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end
        
    oOrg:AddPrestige(iVal)
    oMaster:NotifyMessage("增加成功")
end

Opens.setjoinorgtime = true
Helpers.setjoinorgtime = {
    "设置入帮时间",
    "setjoinorgtime 小时 玩家id(玩家自己可不填)",
    "setjoinorgtime -60 ",
}
function Commands.setjoinorgtime(oMaster, iVal, iTarget)
    local oTarget = oMaster
    if iTarget and iTarget > 0 then
        oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if not oTarget then
            oMaster:NotifyMessage("玩家不在线")
            return
        end
    end
    local oOrg = oTarget:GetOrg()
    if not oOrg then
        oMaster:NotifyMessage("玩家没有帮派")
        return
    end

    local oMember = oOrg.m_oMemberMgr:GetMember(oTarget:GetPid())
    local iJoinTime = oMember:GetJoinTime()
    local iSetTime = iJoinTime + iVal*3600
    oMember:SetData("jointime", iSetTime)
    oMaster:NotifyMessage("设置成功，当前入帮时间为"..get_time_format_str(iSetTime, "%Y-%m-%d %H:%M:%S"))
end

Opens.orgrename = true
Helpers.orgrename = {
    "增加帮贡",
    "orgrename sName",
    "orgrename xx",
}
function Commands.orgrename(oMaster, sName)
    local oOrg = oMaster:GetOrg()
    if not oOrg then return end

    local oOrgMgr = global.oOrgMgr
    if oOrgMgr:HasSameName(sName) then
        oMaster:NotifyMessage(oOrgMgr:GetOrgText(1068))
        return
    end
    oOrgMgr:ForceRenameOrg(oOrg:OrgID(), sName)
    local mNet = oOrg:PackMaskOrgMainInfo({name=oOrg:GetName()})
    oMaster:Send("GS2COrgMainInfo", mNet)
end
