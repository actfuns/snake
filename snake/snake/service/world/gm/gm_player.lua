local global = require "global"
local res = require "base.res"
local router = require "base.router"
local record = require "public.record"

local loadpartner = import(service_path("partner/loadpartner"))
local loadsummon = import(service_path("summon.loadsummon"))
local loaditem = import(service_path("item.loaditem"))
local loadskill = import(service_path("skill/loadskill"))
local fabaotest = import(service_path("fabao.test"))
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

function GetTarget(oMaster, iTargetPid)
    if not iTargetPid or iTargetPid == 0 then
        return oMaster
    else
        return global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    end
end

Opens.playerop = true
Helpers.playerop = {
    "玩家测试指令",
    "playerop iFlag mArgs",
    "playerop 101 {point = 10000}",
}
function Commands.playerop(oMaster,iFlag,mArgs)
    local playertest = import(service_path("playerctrl/test"))
    playertest.TestOP(oMaster,iFlag,mArgs)
end

Opens.setname = true
Helpers.setname = {
    "设置名字",
    "setname 名字",
    "示例: setname '小强'",
}
function Commands.setname(oMaster, s)
    oMaster:SetData("name", s)
    oMaster:SyncSceneInfo({
        name = oMaster:GetName(),
    })
    oMaster:PropChange("name")
end

Opens.setshape = true
Helpers.setshape = {
    "设置造型",
    "setshape 造型",
    "示例: setshape 1",
}
function Commands.setshape(oMaster, iShape)
    local oNotifyMgr = global.oNotifyMgr
    if res["daobiao"]["modelfigure"][iShape] then
        oMaster.m_oBaseCtrl:ChangeShape(iShape)
        oNotifyMgr:Notify(oMaster:GetPid(),"设置完成")
        return
    end
    oNotifyMgr:Notify(oMaster:GetPid(),"不存在此造型")
end

Opens.setschool = true
Helpers.setschool={
    "更改门派",
    "setschool 门派id",
    "setschool 2"
}
function Commands.setschool(oMaster, schoolid)
    oMaster.m_oBaseCtrl:SetData("school", tonumber(schoolid))
end

Opens.getschool = true
Helpers.getschool={
    "查看门派",
    "getschool",
    "getschool"
}
function Commands.getschool(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster.m_iPid, "你的门派为" .. oMaster:GetSchool())
end

Opens.born = false
Helpers.born={
    "出生",
    "born",
    "born",
}
function Commands.born(oMaster)
    oMaster:Born()
end

Opens.toprole = true
Helpers.toprole = {
    "角色账号顶级配置",
    "toprole 玩家ID 备注：玩家ID为空表示当前账号",
    "示例:toprole 10001, toprole",
}
function Commands.toprole(oMaster, iPid)
    local iTruePid = iPid or oMaster:GetPid()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTruePid)
    if not oTarget then return end

    local iFromGrade = oTarget:GetGrade()
    local iGradeLimit = global.oWorldMgr:GetServerGradeLimit()
    iGradeLimit = math.min(80, iGradeLimit)
    for i = iFromGrade+1, iGradeLimit do
        oTarget:UpGrade()
    end
    oTarget:OnUpGradeEnd(iFromGrade)

    oTarget:RewardSilver(20000000, "top_role")
    oTarget:RewardGold(10000000, "top_role")
    local oProfile = oTarget:GetProfile()
    oProfile:AddRplGoldCoin(1000000, "top_role")

    local gmfile = import(service_path("gm/gm_open"))
    gmfile.Commands.skipopenchecktask(oTarget, 1)
    --equip
    local iStart, iEnd = 21000, 23000
    local iRoleType = oTarget:GetRoleType()
    local iRace = oTarget:GetRace()
    local iSex = oTarget:GetSex()
    local iLevelLimit = iGradeLimit // 10 * 10
    local mAllItem = res["daobiao"]["item"]

    for iSid = iStart, iEnd do
        local mItem = mAllItem[iSid]
        if mItem and mItem.roletype == iRoleType and mItem.equipLevel == iLevelLimit then
            local oItem = global.oItemLoader:Create(iSid)
            oTarget:RewardItem(oItem, "top_role")
            if oTarget.m_oItemCtrl:HasItem(oItem:ID()) then
                global.oItemHandler:Wield(oTarget, oItem)
            end
        end

        if mItem and (mItem.race == 0 or mItem.race == iRace) and (mItem.sex == 0 or mItem.sex == iSex) and mItem.equipLevel == iLevelLimit and mItem.roletype == 0 then
            local oItem = global.oItemLoader:Create(iSid)
            oTarget:RewardItem(oItem, "top_role")
            if oTarget.m_oItemCtrl:HasItem(oItem:ID()) then
                global.oItemHandler:Wield(oTarget, oItem)
            end
        end
    end

    --partner
    --local lPartnerList = {10001, 10004, 10005, 10007, 10009, 10011}
    local mAllPartner = table_get_depth(res["daobiao"], {"partner", "info"})
    for _, iSid in ipairs(table_key_list(mAllPartner)) do
        local oPartner = loadpartner.CreatePartner(iSid, iTruePid)
        if oPartner then
            local iMaxQuality = oPartner:GetMaxQuality()
            for i = 1, iMaxQuality do
                oPartner:IncreaseQuality(1)
            end
            local iMaxUpper = oPartner:GetMaxUpper()
            oPartner:IncreaseUpper(iMaxUpper)
            oTarget.m_oPartnerCtrl:AddPartner(oPartner)

            for iSk, oSk in pairs(oPartner.m_oSkillCtrl.m_List) do
                local iLevelLimit = oSk:LimitLevel()
                oSk:SetLevel(iLevelLimit - 1)
            end
        end
    end
    --summon
    for iSid = 2003, 2009 do
        local oSummon = loadsummon.CreateSummon(iSid, 0)
        oTarget.m_oSummonCtrl:AddSummon(oSummon)
        for i = 1, iGradeLimit + 5 do
            oSummon:UpGrade()
        end
        oSummon:AutoAssignPoint()
        oSummon:Setup()
        oSummon:FullState()
        oSummon:Refresh()
    end

    -- cultivate
--    local loadskill = import(service_path("skill/loadskill"))
--    local mCultivateSkill = loadskill.GetCultivateSkill()
--    for iSkill, _ in pairs(mCultivateSkill) do
--        local oSk = oTarget.m_oSkillCtrl:GetSkill(iSkill)
--        if not oSk then goto continue end
--        oSk:SetData("level", oSk:MaxLevel(oTarget))
--        oSk:Dirty()
--        ::continue::
--    end

    --skill
    local oLearnMgr = global.oPubMgr:GetLearnSkillObj("passive")
    if oLearnMgr then
        oLearnMgr:FastLearn(oTarget)
    end
    for iSk, oSk in pairs(oTarget.m_oSkillCtrl:SkillList()) do
        if oSk.m_sType == "active" then
            local iTopLevel = oSk:LimitLevel(oTarget)
            oTarget.m_oSkillCtrl:SetLevel(iSk, iTopLevel, true)
        end
    end

    --item
    local gmfile = import(service_path("gm/gm_item"))
    gmfile.Commands.clone(oTarget, 11092, 999)
    gmfile.Commands.clone(oTarget, 11093, 999)
    gmfile.Commands.clone(oTarget, 11094, 999)
    gmfile.Commands.clone(oTarget, 11097, 999)
    gmfile.Commands.clone(oTarget, 10031, 1000)

    oTarget:ClientPropChange()
end    

Opens.toprole2 = true
Helpers.toprole2 = {
    "角色账号顶级配置",
    "toprole2 索引id, 玩家ID 备注：玩家ID为空表示当前账号",
    "示例:toprole2 3 10001",
}

function Commands.toprole2(oMaster, idx, iPid)
    iPid = iPid or oMaster:GetPid()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oTarget then
        global.oNotifyMgr:Notify(oMaster:GetPid(), "玩家不在线")
        return
    end
    local mRole = res["daobiao"]["toprole"][idx]
    if not mRole then
        global.oNotifyMgr:Notify(oMaster:GetPid(), "参数错误")
        return
    end

    local iFromGrade = oTarget:GetGrade()
    local iGradeLimit = global.oWorldMgr:GetServerGradeLimit()
    iGradeLimit = math.min(mRole.grade, iGradeLimit)
    if iFromGrade < iGradeLimit then
        for i = iFromGrade+1, iGradeLimit do
            oTarget:UpGrade()
        end
        oTarget:OnUpGradeEnd(iFromGrade)
    end
    
    oTarget:RewardSilver(mRole.silver or 1000000, "top_role")
    oTarget:RewardGold(mRole.gold or 100000, "top_role")
    oTarget:RewardGoldCoin(mRole.goldcoin or 100000, "top_role")

    local gmfile = import(service_path("gm/gm_open"))
    gmfile.Commands.skipopenchecktask(oTarget, 1)

    --equip
    local iRoleType = oTarget:GetRoleType()
    local iRace = oTarget:GetRace()
    local iSex = oTarget:GetSex()
    local iLevelLimit = iGradeLimit // 10 * 10

    if #mRole.equip_list > 0 then
        local mEquipList = formula_string(mRole.equip_list, {})
        for iSid, mAttr in pairs(mEquipList) do
            local mArgs = {
                equip_level = mAttr.equip_level or 1,
                equip_make = mAttr.equip_make or true,
            }
            local oItem = global.oItemLoader:Create(iSid, mArgs)
            if not oItem then
                global.oNotifyMgr:Notify(oMaster:GetPid(), "道具id:"..iSid.."配置错误")
            else
                local iEquipLevel = oItem:EquipLevel()
                local iEquipPos = oItem:EquipPos()
                for _, iSK in pairs(mAttr.sk_list or {}) do
                    local oSK = loadskill.NewSkill(iSK)
                    if not oSK then
                        global.oNotifyMgr:Notify(oMaster:GetPid(), "特技id:"..iSK.."错误")
                    else
                        oSK:SetLevel(iEquipLevel)
                        oItem:AddSK(oSK)
                    end
                end
                for _, iSE in pairs(mAttr.se_list or {}) do
                    local oSE = loadskill.NewSkill(iSE)
                    if not oSE then
                        global.oNotifyMgr:Notify(oMaster:GetPid(), "特效id:"..iSE.."错误")
                    else
                        oSE:SetPos(iEquipPos)
                        oSE:SetLevel(iEquipLevel)
                        oItem:AddSE(oSE)
                    end
                end
                oTarget:RewardItem(oItem, "top_role")
                if oTarget.m_oItemCtrl:HasItem(oItem:ID()) then
                    global.oItemHandler:Wield(oTarget, oItem)
                end
            end
        end
    else
        local iStart, iEnd = 21000, 23000
        local mAllItem = res["daobiao"]["item"]
        for iSid = iStart, iEnd do
            local mItem = mAllItem[iSid]
            if mItem and mItem.roletype == iRoleType and mItem.equipLevel == iLevelLimit then
                local oItem = global.oItemLoader:Create(iSid)
                oTarget:RewardItem(oItem, "top_role")
                if oTarget.m_oItemCtrl:HasItem(oItem:ID()) then
                    global.oItemHandler:Wield(oTarget, oItem)
                end
            end
    
            if mItem and (mItem.race == 0 or mItem.race == iRace) and (mItem.sex == 0 or mItem.sex == iSex) and mItem.equipLevel == iLevelLimit and mItem.roletype == 0 then
                local oItem = global.oItemLoader:Create(iSid)
                oTarget:RewardItem(oItem, "top_role")
                if oTarget.m_oItemCtrl:HasItem(oItem:ID()) then
                    global.oItemHandler:Wield(oTarget, oItem)
                end
            end
        end
    end

    --partner
    local mAllPartner = table_get_depth(res["daobiao"], {"partner", "info"})
    if #mRole.partner_list > 0 then
        mAllPartner = mRole.partner_list
    end
    for _, iSid in ipairs(table_key_list(mAllPartner)) do
        local oPartner = loadpartner.CreatePartner(iSid, oTarget:GetPid())
        if oPartner then
            local iMaxQuality = oPartner:GetMaxQuality()
            for i = 1, iMaxQuality do
                oPartner:IncreaseQuality(1)
            end
            local iMaxUpper = oPartner:GetMaxUpper()
            oPartner:IncreaseUpper(iMaxUpper)
            oTarget.m_oPartnerCtrl:AddPartner(oPartner)
            for iSk, oSk in pairs(oPartner.m_oSkillCtrl.m_List) do
                local iLevelLimit = oSk:LimitLevel()
                oSk:SetLevel(iLevelLimit - 1)
            end
        end
    end
    
    --summon
    for _, iSid in pairs(mRole.summ_list or {}) do
        local oSummon = loadsummon.CreateSummon(iSid, 0)
        oTarget.m_oSummonCtrl:AddSummon(oSummon)
        for i = 1, iGradeLimit + 5 do
            oSummon:UpGrade()
        end
        oSummon:AutoAssignPoint()
        oSummon:Setup()
        oSummon:FullState()
        oSummon:Refresh()
    end
    
    --ride
    local mRideGrade = res["daobiao"]["ride"]["upgrade"]
    local iMaxGrade = table_count(mRideGrade)
    local iRideGrade = oTarget.m_oRideCtrl:GetGrade()
    if iRideGrade < iMaxGrade then
        for i = iRideGrade+1, iMaxGrade do
            oTarget.m_oRideCtrl:UpGrade()
            oTarget.m_oRideCtrl:Dirty()
        end
    end
    for _, iRide in pairs(mRole.ride_list or {}) do
        local mRide = global.oRideMgr:GetRideConfigDataById(iRide)
        if oTarget.m_oRideCtrl:GetRide(iRide) then
            goto continue
        end
        if mRide.player_level > oTarget:GetGrade() then
            goto continue
        end
        if mRide.ride_level > iMaxGrade then
            goto continue
        end
        local oRide = global.oRideMgr:CreateNewRide(iRide)
        oTarget.m_oRideCtrl:AddRide(oRide)
        ::continue::
    end

    -- cultivate
    local mCultivateSkill = loadskill.GetCultivateSkill()
    for iSkill, _ in pairs(mCultivateSkill) do
        local oSk = oTarget.m_oSkillCtrl:GetSkill(iSkill)
        if oSk then
            oSk:SetData("level", oSk:MaxLevel(oTarget))
            oSk:GS2CRefreshSkill(oTarget)
            oSk:Dirty()
        end
    end

    --skill
    for iSk, oSk in pairs(oTarget.m_oSkillCtrl:SkillList()) do
        if oSk.m_sType == "active" or oSk.m_sType == "passive" then
            local iTopLevel = oSk:LimitLevel(oTarget)
            oTarget.m_oSkillCtrl:SetLevel(iSk, iTopLevel, true)
        end
    end
    
    --orgskill
    local mOrgSkill = oTarget.m_oSkillCtrl:GetOrgSkills()
    for iSkill, oSkill in pairs(mOrgSkill) do
        local iLimit = oSkill:LimitLevel(oTarget)
        oSkill:SetLevel(iLimit)
        oSkill:SkillEffect(oTarget)
        oSkill:Dirty()
    end

    --strengthen
    for iPos = 1, 10 do
        local oItem = oTarget.m_oItemCtrl:GetItem(iPos)
        if oItem then
            oTarget:EquipStrength(oItem:EquipPos(), oTarget:GetGrade()-1)
            global.oItemHandler.m_oEquipStrengthenMgr:StrengthSuccess(oTarget, oItem)
        end
    end
end


Opens.addstate = true
Helpers.addstate = {
    "增加buff",
    "addstate 状态id",
    "addstate 1001",
}
function Commands.addstate(oMaster,iState,...)
    local mArgs = {}
    oMaster.m_oStateCtrl:AddState(iState,mArgs)
end

Opens.clearstate = true
Helpers.clearstate = {
    "清空buff",
    "clearstate",
    "clearstate",
}
function Commands.clearstate(oMaster)
    for iState,oState in pairs(oMaster.m_oStateCtrl.m_List) do
        oMaster.m_oStateCtrl:RemoveState(iState)
    end
end

Opens.setstate = false
Helpers.setstate = {
    "设置state信息",
    "setstate state_id 属性 属性值",
    "setstate 121 key value",
}
function Commands.setstate(oMaster,iState,key,value)
    local oNotifyMgr = global.oNotifyMgr
    local oState = oMaster.m_oStateCtrl:GetState(iState)
    if oState then
        oState:SetData(key,value)
        oState:Refresh(oMaster:GetPid())
        oNotifyMgr:Notify(oMaster:GetPid(), "指令执行成功")
    else
        oNotifyMgr:Notify(oMaster:GetPid(), "没有此state")
    end
end

Opens.cleardayctrl = false
Helpers.cleardayctrl = {
    "给自己刷天",
    "cleardayctrl",
    "cleardayctrl",
}
function Commands.cleardayctrl(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    oMaster.m_oToday:Dirty()
    oMaster.m_oToday.m_mData = {}
    oMaster.m_oToday.m_mKeepList = {}
    oMaster:NewDay(get_daytime({}))
    oNotifyMgr:Notify(oMaster:GetPid(), "玩家刷天成功")
end

Opens.cleardaymorning = false
Helpers.cleardaymorning = {
    "给自己刷5点",
    "cleardaymorning",
    "cleardaymorning",
}
function Commands.cleardaymorning(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oMaster:GetPid()
    oMaster.m_oTodayMorning:Dirty()
    oMaster.m_oTodayMorning.m_mData = {}
    oMaster.m_oTodayMorning.m_mKeepList = {}
    oMaster.m_oScheduleCtrl:ResetDaily()
    local mDoublePoint = oMaster.m_oBaseCtrl:GetData("double_point", {})
    mDoublePoint["day"] = get_morningdayno() - 1
    oMaster.m_oBaseCtrl:SetData("double_point", mDoublePoint)
    local oTask = oMaster.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if oTask then
        oTask.m_iCreateTime = oTask.m_iCreateTime - 24 * 3600
        oTask:Abandon()
    end
    oMaster:NewHour5(get_daytime({day=0, anchor=5}))
    global.oYibaoMgr:ClearTasks(oMaster)
    local oRewardMonitor = global.oTaskMgr:GetStoryTaskRewardMonitor()
    if oRewardMonitor then
        oRewardMonitor:ClearPlayerRecord(iPid)
    end
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    if oRewardMonitor then
        oRewardMonitor:ClearPlayerRecord(iPid)
    end
    local oJJCCtrl = oMaster:GetJJC()
    oJJCCtrl.m_iResetTime = get_time() - 3600*24

    local oProfile = oMaster:GetProfile()
    oProfile.m_mTodayMorning = {}
    oProfile:Dirty()
    oNotifyMgr:Notify(oMaster:GetPid(), "玩家刷5点成功")
end

Opens.clearweekctrl = false
Helpers.clearweekctrl = {
    "给自己刷周",
    "clearweekctrl",
    "clearweekctrl",
}
function Commands.clearweekctrl(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    oMaster.m_oThisWeek:Dirty()
    oMaster.m_oThisWeek.m_mData = {}
    oMaster.m_oThisWeek.m_mKeepList = {}
    oMaster.m_oScheduleCtrl:ResetWeekly()
    oNotifyMgr:Notify(oMaster:GetPid(), "玩家刷周成功")
end

Opens.clearweekmorning = false
Helpers.clearweekmorning = {
    "给自己清周5点",
    "clearweekmorning",
    "clearweekmorning",
}
function Commands.clearweekmorning(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    oMaster.m_oWeekMorning:Dirty()
    oMaster.m_oWeekMorning.m_mData = {}
    oMaster.m_oWeekMorning.m_mKeepList = {}
    oMaster:NewHour5(get_wdaytime({wday=1}))
    oNotifyMgr:Notify(oMaster:GetPid(), "玩家清周5点成功")
end

Opens.set = true
Helpers.set = {
    "设置玩家基础属性",
    "set key value",
    "set 'testman' 99",
}
function Commands.set(oMaster, sKey, value)
    oMaster:Set(sKey, value)
end

Opens.get = true
Helpers.get = {
    "获取玩家基础属性",
    "get key",
    "get 'testman'",
}
function Commands.get(oMaster, sKey)
    local oNotifyMgr = global.oNotifyMgr
    local value = oMaster:Query(sKey, 0)
    local sMsg = string.format("查询到的%s 值为%s", sKey, tostring(value))
    oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
end

Opens.setshowid = true
Helpers.setshowid = {
    "靓号设置指令",
    "setshowid showid, pid",
    "setshowid 5201314, 12041",
}
function Commands.setshowid(oMaster, iShowId, iPid)
    iPid = iPid or oMaster:GetPid()
    local oShowIdMgr = global.oShowIdMgr
    if iShowId == iPid then
        oShowIdMgr:SetShowId(iPid)
    else
        local oNotifyMgr = global.oNotifyMgr
        local mData = {pid = iPid, show_id = iShowId}
        
        router.Request("cs", ".idsupply", "common", "CheckShowId", mData, function (mRecord, mData)
            local iRet = mData.ret
            if iRet == 1 then
                oNotifyMgr:Notify(oMaster:GetPid(), iShowId .. " 不是靓号")
            elseif iRet == 2 then
                oNotifyMgr:Notify(oMaster:GetPid(), "新旧ID一致")
            elseif iRet == 3 then
                oNotifyMgr:Notify(oMaster:GetPid(), "旧靓号ID未过期")
            elseif iRet == 4 then
                oNotifyMgr:Notify(oMaster:GetPid(), iShowId .. " 被占用")
            else
                oShowIdMgr:SetShowId(iPid, iShowId)
            end
        end)
    end
end

Opens.getshowid = true
Helpers.getshowid = {
    "靓号设置指令",
    "getshowid",
    "getshowid",
}
function Commands.getshowid(oMaster)
    local iShowId = oMaster:GetShowId()
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster:GetPid(), "当前靓号为"..iShowId)
end

Opens.setofflinetime = true
Helpers.setofflinetime = {
    "设置离线判断时间模式",
    "setofflinetime 模式(1为永不下线,2为很久下线(10min左右),3为正常下线(3min左右),4为尽快下线(10s以内))",
    "示例: setofflinetime 1",
}
function Commands.setofflinetime(oMaster, iMode)
    local oNotifyMgr = global.oNotifyMgr
    if table_in_list({1, 2, 3, 4}, iMode) then
        oMaster:SetTestLogoutJudgeTimeMode(iMode)
        oNotifyMgr:Notify(oMaster.m_iPid, string.format("你设置的离线判断时间模式为%s", iMode))
    else
        oNotifyMgr:Notify(oMaster.m_iPid, "只有1 2 3 4模式")
    end
end

Opens.getofflinetime = true
Helpers.getofflinetime = {
    "获取离线判断时间模式",
    "getofflinetime",
    "示例: getofflinetime",
}
function Commands.getofflinetime(oMaster)
    local i = oMaster:GetTestLogoutJudgeTimeMode()
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster.m_iPid, string.format("你设置的离线判断时间模式为%s", i))
end

Opens.logoutplayer = true
Helpers.logoutplayer = {
    "登出",
    "logoutplayer",
    "示例: logoutplayer 1001",
}
function Commands.logoutplayer(oMaster, iPid)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:Logout(iPid)
end

Helpers.addschedule = {
    "完成一次日程",
    "addschedule 日程id",
    "addschedule 1001",
}
function Commands.addschedule(oMaster, sid)
    oMaster.m_oScheduleCtrl:Add(sid)
end

Helpers.addallschedule = {
    "完成所有日程",
    "addallschedule",
}
function Commands.addallschedule(oMaster)
    for sid,oSchedule in pairs(oMaster.m_oScheduleCtrl.m_mSchedules) do
        record.debug("[GM TestCmd] %s %s",oMaster:GetPid(),sid)
        oMaster.m_oScheduleCtrl:Add(sid)
    end
end

Helpers.clearschedule = {
    "清除日程",
    "clearschedule",
    "clearschedule",
}
function Commands.clearschedule(oMaster)
    for sid, oSchedule in pairs(oMaster.m_oScheduleCtrl.m_mSchedules) do
        baseobj_delay_release(oSchedule)
    end
    oMaster.m_oScheduleCtrl.m_mSchedules = {}
    oMaster.m_oTodayMorning:Set("shootcraps_num", 0)
end

Helpers.printpoint = {
    "输出基础属性点",
    "printfirstattr",
    "printfirstattr",
}
function Commands.printfirstattr(oMaster, iSid, iVal)
    local mMsg = {}
    table.insert(mMsg, "体质："..oMaster:GetAttr("physique"))
    table.insert(mMsg, ",力量："..oMaster:GetAttr("strength"))
    table.insert(mMsg, ",魔力："..oMaster:GetAttr("magic"))
    table.insert(mMsg, ",耐力："..oMaster:GetAttr("endurance"))
    table.insert(mMsg, ",敏捷："..oMaster:GetAttr("agility"))
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleMsgChat(oMaster, table.concat(mMsg))
end

Helpers.addculskillexp = {
    "增加修炼技能的经验",
    "addculskillexp 技能ID 经验值",
    "addculskillexp 4000 200000",
}
function Commands.addculskillexp(oMaster, iSid, iVal)
    local oNotifyMgr = global.oNotifyMgr
    if iSid < 4000 and iSid > 4008 then
        return
    end
    local oSkill = oMaster.m_oSkillCtrl:GetSkill(iSid)
    oSkill:AddExp(oMaster, iVal)
end

function Commands.resetculskill(oMaster)
    local oSk = oMaster.m_oSkillCtrl:GetCurrCulSKill()
    if not oSk then
        oMaster:NotifyMessage("未设置当前技能")
        return
    end
    oSk:SetData("level", 0)
    oSk:SetData("exp", 0)    
    oSk:Dirty()
    oSk:GS2CRefreshSkill(oMaster)
end

Helpers.addskillpoint = {
    "增加技能点数",
    "addskillpoint 点数",
    "addskillpoint 10",
}
function Commands.addskillpoint(oMaster, iPoint)
    local oNotifyMgr = global.oNotifyMgr
    oMaster.m_oActiveCtrl:AddSkillPoint(iPoint, "gm指令")
    oNotifyMgr:Notify(oMaster:GetPid(), "添加技能点数成功")
end

Helpers.getskillpoint = {
    "打印技能点数",
    "getskillpoint",
    "getskillpoint",
}
function Commands.getskillpoint(oMaster)
    local oNotifyMgr = global.oNotifyMgr
    local iPoint = oMaster.m_oActiveCtrl:GetData("sk_point")
    oNotifyMgr:Notify(oMaster:GetPid(), string.format("技能点数：%d", iPoint))
end

Helpers.addtitle = {
    "增加称谓",
    "addtitle tid name",
    "addtitle 999 xx",
}
function Commands.addtitle(oMaster, tid, name)
    if type(tid) ~= "number" then
        return
    end
    local oTitleMgr = global.oTitleMgr
    oTitleMgr:AddTitle(oMaster:GetPid(), tid, name)
end

Helpers.deltitle = {
    "删除称谓",
    "deltitle tid",
    "deltitle 900",
}
function Commands.deltitle(oMaster, tid)
    if type(tid) ~= "number" then
        return
    end
    local oTitleMgr = global.oTitleMgr
    oTitleMgr:RemoveTitles(oMaster:GetPid(), {tid})
end

Helpers.useredeemcode = {
    "兑换码",
    "useredeemcode code",
    "useredeemcode 'GZ4EDGGO00000001'",
}
function Commands.useredeemcode(oMaster, sCode)
    global.oToolMgr:UseRedeemCode(oMaster, sCode)
end

Helpers.getexpratio = {
    "服务器加成",
    "getexpratio",
    "getexpratio",
}
function Commands.getexpratio(oMaster)
    local iRatio = oMaster.m_oStateCtrl:GetAddServerExpRatio()
    oMaster:NotifyMessage(string.format("服务器exp加成: %s", iRatio))
end

Helpers.addstorypoint = {
    "添加剧情点",
    "addstorypoint",
    "addstorypoint",
}
function Commands.addstorypoint(oMaster, iVal)
    if iVal > 0 then
        oMaster.m_oActiveCtrl:RewardStoryPoint(iVal, "gm")
    else
        oMaster.m_oActiveCtrl:ResumeStoryPoint(-iVal, "gm")
    end
end

Helpers.setuporgskill = {
    "初始化帮派技能",
    "setuporgskill",
    "setuporgskill",
}
function Commands.setuporgskill(oMaster)
    oMaster.m_oSkillCtrl:SetupOrgSkill()
    oMaster:NotifyMessage("OK")
end

Opens.fullactivepoint = true
Helpers.fullactivepoint = {
    "满日程活跃",
    "fullactivepoint id",
    "fullactivepoint 1001",
}
function Commands.fullactivepoint(oMaster, iSchedule)
    local mSchedule = res["daobiao"]["schedule"]["schedule"]
    if not iSchedule then
        for iSchedule, mInfo in pairs(mSchedule) do
            local iTimes = mInfo.maxtimes
            for i = 1, iTimes do
                oMaster.m_oScheduleCtrl:Add(iSchedule)
            end
        end
    else
        if not mSchedule[iSchedule] then
            oMaster:NotifyMessage("id 错误")
        else
            local iTimes = mSchedule[iSchedule].maxtimes
            for i = 1, iTimes do
                oMaster.m_oScheduleCtrl:Add(iSchedule)
            end
        end
    end
end

function Commands.channelchat(oMaster, iType, sMsg)
    if iType == gamedefines.CHANNEL_TYPE.WORLD_TYPE then
        global.oChatMgr:SendMsg2World(sMsg, oMaster)
    elseif iType == gamedefines.CHANNEL_TYPE.CURRENT_TYPE then
        local oWar = oMaster.m_oActiveCtrl:GetNowWar()
        if oWar then
            self:SendMsg2War(oMaster, oWar, sMsg, iType)
            return
        end
    
        local oSceneMgr = global.oSceneMgr
        local oScene = oMaster.m_oActiveCtrl:GetNowScene()
        if oScene then
            global.oChatMgr:SendMsg2Scene(oMaster, oScene, sMsg, iType)
        end
    end
end

Opens.godeyes = true
Helpers.godeyes = {
    "千里眼",
    "godeyes scene x y  x,y不填表示随机坐标",
    "godeyes 10 41.12 12.23",
}
function Commands.godeyes(oMaster, iScene, iX, iY)
    local iOldScene = oMaster.m_iGodEyes
    oMaster.m_iGodEyes = iScene
    if not iScene then
        local oScene = global.oSceneMgr:GetScene(iOldScene)
        oScene:LeaveGMPlayer(oMaster)
        global.oSceneMgr:ReEnterScene(oMaster)
        oMaster:NotifyMessage("已取消天眼")
        return
    end
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then
        oMaster:NotifyMessage("场景不存在")
        return
    end
    if not iX or not iY then
        iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    end
    if not iX or not iY then
        oMaster:NotifyMessage("无法生成随机坐标")
        return
    end
    local mInfo = {
        pos = {
            x = iX,
            y = iY,
            v = 0,
            face_x = 0,
            face_y = 0,
        }
    }
    global.oSceneMgr:GMEnterScene(oMaster, iScene, mInfo)
end

Opens.follow = true
Helpers.follow = {
    "跟随",
    "follow pid;  pid不填表示取消跟随",
    "follow 10001",
}
function Commands.follow(oMaster, iTarget)
    if not iTarget then
        oMaster.m_iFollow = nil
        oMaster:DelTimeCb("FollowPlayer")
        oMaster:NotifyMessage("取消跟随")
        Commands.godeyes(oMaster)
        return
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        oMaster:NotifyMessage(iTarget.."不在线")
        return
    end
    local iPid = oMaster:GetPid()
    oMaster.m_iFollow = iTarget
    RefreshFollow(iPid, iTarget)
end

function RefreshFollow(iPid, iTarget)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    oPlayer:DelTimeCb("FollowPlayer")

    if not iTarget or oPlayer.m_iFollow ~= iTarget then
        return
    end

    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        oPlayer.m_iFollow = nil
        oPlayer:NotifyMessage(iTarget.."已下线, 取消跟随")
        Commands.godeyes(oPlayer)
        return
    end
    if oPlayer.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.NO_WAR then
        local oScene = oTarget.m_oActiveCtrl:GetNowScene()
        local mPos = oTarget.m_oActiveCtrl:GetNowPos()
        Commands.godeyes(oPlayer, oScene:GetSceneId(), mPos.x, mPos.y)
    end

    oPlayer:AddTimeCb("FollowPlayer", 5000, function()
        RefreshFollow(iPid, iTarget)
    end)
end

Opens.ghosteye = true
Helpers.ghosteye = {
    "天眼通",
    "ghosteye targetid [open]",
    "ghosteye 10001 [0/1/nil]",
}
function Commands.ghosteye(oMaster, iTargetPid, iOpen)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    if not iOpen then
        local iCurOpen = oTarget.m_oActiveCtrl.m_oVisualMgr:SetGhostEye(oTarget, iOpen)
        oMaster:NotifyMessage(string.format("目标[%d]的天眼通状态为:%d", oTarget:GetPid(), iCurOpen or 0))
        return
    end
    oTarget.m_oActiveCtrl.m_oVisualMgr:SetGhostEye(oTarget, iOpen)
    oMaster:NotifyMessage("已设置")
end

Opens.onlineoffset = true
Helpers.onlineoffset = {
    "在线修复版本号",
    "onlineoffset targetid [number]",
    "onlineoffset 10001 [interger/nil]",
}
function Commands.onlineoffset(oMaster, iTargetPid, iOffset)
    local oTarget = GetTarget(oMaster, iTargetPid)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTargetPid))
        return
    end
    local iTargetPid = oTarget:GetPid()
    if not iOffset then
        oMaster:NotifyMessage(string.format("目标玩家[%s]的在线修复版本号：%d", iTargetPid, oTarget.m_oActiveCtrl:GetData("offset", 0)))
        return
    end
    oTarget.m_oActiveCtrl:SetData("offset", iOffset)
    oMaster:NotifyMessage(string.format("目标玩家[%s]的在线修复版本号已设为：%d", iTargetPid, iOffset))
end

Opens.fabaoop = true
Helpers.fabaoop = {
    "法宝测试指令",
    "fabaoop iFlag , mArgs",
    "fabaoop 100",
}
function Commands.fabaoop(oMaster, iFlag, mArgs)
    fabaotest.TestOp(oMaster,iFlag, mArgs)
end

function Commands.setshowwing(oMaster, iWing)
    oMaster.m_oWingCtrl:SetShowWing(iWing)
end

function Commands.setfuhun(oMaster, iEquipPos)
    local gm_item = import(service_path("gm.gm_item"))
    for iSid = 21000, 23000 do
        local mInfo = res["daobiao"]["item"][iSid]
        if not mInfo or mInfo.equipLevel <= 40 then
            goto continue
        end
        if mInfo.equipPos ~= iEquipPos then
            goto continue
        end
        if mInfo.roletype ~= 0 and mInfo.roletype ~= oMaster:GetRoleType() then
            goto continue
        end
        if mInfo.sex ~= 0 and oMaster:GetSex() ~= mInfo.sex then
            goto continue
        end
        if mInfo.school ~= 0 and oMaster:GetSchool() ~= info.school then
            goto continue
        end
        gm_item.Commands.clone(oMaster, iSid, 1, {lv=4})
        local oItem = oMaster.m_oItemCtrl:GetItemObj(iSid)
        if not oItem then
            goto continue
        end

        
        local oOldEquip = oMaster.m_oItemCtrl:GetItem(iEquipPos)
        if oOldEquip then
            oOldEquip:UnWield(oMaster)
            oItem:SetData("fh_sid", 12106)
            oMaster.m_oItemCtrl:ItemChange(oOldEquip, oItem)
        else
            oItem:SetData("fh_sid", 12106)
            oMaster.m_oItemCtrl:ChangeToPos(oItem, iEquipPos)
        end
        oMaster:ChangeWeapon()
        break
        ::continue::
    end
end

function Commands.clonerole(oMaster, iTarget)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        oMaster:NotifyMessage(string.format("目标玩家[%s]不在线", iTarget))
        return
    end
    if oTarget:GetSchool() ~= oMaster:GetSchool() then
        oMaster:NotifyMessage(string.format("与目标玩家[%s]不属相同职业", iTarget))
        return
    end

    --copy grade
    local playertest = import(service_path("playerctrl.test"))
    local iGrade = oTarget:GetGrade()
    playertest.TestOP(oMaster, 101, {grade=iGrade})

    --copy fmt
    local mFmt = oTarget.m_oBaseCtrl.m_oFmtMgr:Save()
    oMaster.m_oBaseCtrl.m_oFmtMgr.m_mFmtObj = {}
    oMaster.m_oBaseCtrl.m_oFmtMgr.m_mData = {}
    oMaster.m_oBaseCtrl.m_oFmtMgr:Load(mFmt)
    oMaster.m_oBaseCtrl.m_oFmtMgr:Dirty()
    
    --copy wield
    for i = 1, 8 do
        local oItem = oTarget.m_oItemCtrl.m_Item[i]
        if not oItem then goto continue end

        local mItem = oItem:Save()
        mItem.TraceNo = nil
        local oNewItem = global.oItemLoader:LoadItem(mItem.sid, mItem)
        if i <= 6 then
            oMaster.m_oItemCtrl:AddItem(oNewItem)
            global.oItemHandler:Wield(oMaster, oNewItem)
        else
            oMaster.m_oItemCtrl:AddToPos(oNewItem, i, {})
        end
        ::continue::
    end
    oTarget.m_oItemCtrl:Dirty()

    --copy active
    local mActive = oTarget.m_oActiveCtrl:Save()
    local mMyActive = oMaster.m_oActiveCtrl:Save()
    mActive.orgtask_taskinfo = mMyActive.orgtask_taskinfo
    mActive.visual_info = mMyActive.visual_info
    mActive.gift_info = mMyActive.gift_info
    oMaster.m_oActiveCtrl:Load(mActive)
    oMaster.m_oActiveCtrl:Dirty()

    --copy wield data
    local mEquip = oTarget.m_oEquipCtrl:Save()
    oMaster.m_oEquipCtrl:Load(mEquip)

    --copy skill
    local mSkill = oTarget.m_oSkillCtrl:Save()
    local mMySkill = oMaster.m_oSkillCtrl:Save()
    mSkill.marry_skill = mMySkill.marry_skill
    oMaster.m_oSkillCtrl:Load(mSkill)
    oMaster.m_oSkillCtrl:Dirty()

    --copy partner
    local mPartner = oTarget.m_oPartnerCtrl:Save()
    oMaster.m_oPartnerCtrl.m_mPartners = {}
    oMaster.m_oPartnerCtrl:Load(mPartner)
    oMaster.m_oPartnerCtrl:Dirty()

    --copy ride
    local mRideCtrl = oTarget.m_oRideCtrl:Save()
    mRideCtrl.bianshen = nil
    for iSk, mRide in pairs(mRideCtrl.rides or {}) do
        mRide.summons = nil
    end
    oMaster.m_oRideCtrl:Load(mRideCtrl)
    oMaster.m_oRideCtrl:Dirty()

    --copy wing
    local mWing = oTarget.m_oWingCtrl:Save()
    oMaster.m_oWingCtrl:Load(mWing)
    oMaster.m_oWingCtrl:Dirty()

    --copy artifact
    local mArtifact = oTarget.m_oArtifactCtrl:Save()
    oMaster.m_oArtifactCtrl:Load(mArtifact)
    oMaster.m_oArtifactCtrl:Dirty()

    --copy fabao
    local mFabao = oTarget.m_oFaBaoCtrl:Save()
    oMaster.m_oFaBaoCtrl:Load(mFabao)
    oMaster.m_oFaBaoCtrl:Dirty()

    --copy summon
    local mSummon = oTarget.m_oSummonCtrl:Save()
    local mMySummon = oMaster.m_oSummonCtrl:Save()
    mSummon.traceno = mMySummon.traceno
    oMaster.m_oSummonCtrl.m_mSummons = {}
    oMaster.m_oSummonCtrl:SetData("extendsize", mSummon.extendsize or 0)
    for _, data in pairs(mSummon.summondata or {}) do
        data.traceno = nil
        data.bind = nil
        data.bind_ride = nil
        local oSummon = loadsummon.LoadSummon(data.sid, data)
        oMaster.m_oSummonCtrl:AddSummon(oSummon, "gm")
    end
    oMaster.m_oSummonCtrl:Dirty()
   
    --copy touxian
    oMaster.m_oTouxianCtrl.m_iLevel = oTarget.m_oTouxianCtrl.m_iLevel 
    oMaster.m_oTouxianCtrl:Dirty()

    --copy task
    --local mTask = oTarget.m_oTaskCtrl:Save()
    --mTask.TaskData = nil
    --oMaster.m_oTaskCtrl:Load(mTask)

    --refresh all
    oMaster:OnLogin()
end

