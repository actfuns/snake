local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local taskobj = import(service_path("task/taskobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))
local summondefines = import(service_path("summon/summondefines"))
local analy = import(lualib_path("public.dataanaly"))

CTaskBase = {}
CTaskBase.__index = CTaskBase
CTaskBase.m_sName = "runring"
CTaskBase.m_sTempName = "三界历练"
CTaskBase.m_iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_RUNRING
inherit(CTaskBase, taskobj.CTask)

function CTaskBase:MonsterCreateExt(oWar, iMonsterIdx, oNpc)
    local mExtArgs = super(CTaskBase).MonsterCreateExt(self, oWar, iMonsterIdx, oNpc) or {}
    local mEnv = table_get_set_depth(mExtArgs, {"env"})
    mEnv.ring = self:GetRing()
    return mExtArgs
end

function CTaskBase:GetRewardEnv(oAwardee)
    local mEnv = super(CTaskBase).GetRewardEnv(self, oAwardee)
    mEnv.ring = self:GetRing()
    return mEnv
end

function CTaskBase:Config(pid, npcobj, mArgs)
    self:SetRing()
    super(CTaskBase).Config(self, pid, npcobj, mArgs)
end

function CTaskBase:SetRing()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    local iRing = global.oRunRingMgr:CurRing(oPlayer)
    self:SetData("ring", iRing)
end

function CTaskBase:GetRing()
    return self:GetData("ring", 0)
end

function CTaskBase:PackInfoName()
    return super(CTaskBase).PackInfoName(self) .. string.format("(%d/%d)", self:GetRing(), global.oRunRingMgr:MaxRing())
end

function CTaskBase:IsLogTaskWanfa()
    return true
end

function CTaskBase:NextRing(oPlayer)
    oPlayer:MarkGrow(54) --成长
    local oTargetNpc = self:GetNpcObjByType(self:Target())
    global.oRunRingMgr:GoOnRing(oPlayer, oTargetNpc, self.m_bNextNoAuto)
end

function CTaskBase:RandOutTarget(iNpcGroup, oGrantNpc)
    if not oGrantNpc then
        local iGrantNpctype = global.oRunRingMgr:DefaultGrantNpc()
        oGrantNpc = global.oNpcMgr:GetGlobalNpc(iGrantNpctype)
    end
    self:SetData("grant_npc", oGrantNpc:Type())
    local lNpcList = self:GetNpcGroupData(iNpcGroup)
    local mNpcs = list_key_table(lNpcList, 1)
    local iGrantNpctype = oGrantNpc:Type()
    mNpcs[iGrantNpctype] = nil
    lNpcList = table_key_list(mNpcs)
    return extend.Random.random_choice(lNpcList)
end

function CTaskBase:OtherScript(pid, npcobj, s, mArgs)
    local sScriptFunc = string.match(s, "^([$%a]+)")
    if not sScriptFunc then
        return false
    end
    local sArgs = string.sub(s, #sScriptFunc + 1, -1)
    if sScriptFunc == "$RTarget" then
        local iNpcGroup = tonumber(sArgs)
        local iTargetNpctype = self:RandOutTarget(iNpcGroup, npcobj)
        if iTargetNpctype then
            self:SetTarget(iTargetNpctype)
        end
        return true
    elseif sScriptFunc == "$ETarget" then
        local iEvent = tonumber(sArgs)
        local iTargetNpctype = self:Target()
        if iTargetNpctype then
            self:SetEvent(iTargetNpctype, iEvent)
        end
        return true
    elseif sScriptFunc == "$SetTargetFight" then
        self:SetTargetFight()
    elseif sScriptFunc == "$NextRing" then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:NextRing(oPlayer)
        end
        return true
    elseif sScriptFunc == "$FightTarget" then
        self:OpenTargetFight(pid, npcobj)
        return true
    elseif sScriptFunc == "$SkipFight" then
        local iGoldcoin = tonumber(sArgs) or 0
        self:SkipFight(pid, npcobj, iGoldcoin)
        return true
    elseif sScriptFunc == "$OrgHelp" then
        self:CallOrgHelp(pid)
        return true
    elseif sScriptFunc == "$RTargetSumm" then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:RandOutTargetSumm(oPlayer)
        end
        return true
    elseif sScriptFunc == "$RTargetItem" then
        self:RandOutTargetItem(pid)
        return true
    elseif sScriptFunc == "$InitLegend" then
        local iEvent = tonumber(sArgs) or 0
        self:InitLegend(pid, iEvent)
        return true
    elseif sScriptFunc == "$RewardLegend" then
        local iRewardId = tonumber(sArgs) or 0
        self:RewardLegend(pid, iRewardId, mArgs)
        return true
    end
end

function CTaskBase:TrySubmit(oPlayer)
    if oPlayer:InWar() then
        return
    end
    self:Click(oPlayer:GetPid())
end

function CTaskBase:InitLegend(pid)
end

function CTaskBase:RandOutTargetSumm(oPlayer)
end

function CTaskBase:RandOutTargetItem(pid)
end

function CTaskBase:GetTargetNpcObj()
    local iTargetNpctype = self:Target()
    return global.oNpcMgr:GetGlobalNpc(iTargetNpctype)
end

function CTaskBase:SetTargetFight()
    local iTargetNpctype = self:Target()
    if not iTargetNpctype or iTargetNpctype == 0 then
        return
    end
    local lTollgateIdList = table_get_depth(res, {"daobiao", "task", "runring", "target_fight", iTargetNpctype, "tollgateids"})
    if not lTollgateIdList then
        return
    end
    local iTollgateId = extend.Random.random_choice(lTollgateIdList)
    if not iTollgateId then
        return
    end
    self:SetData("fight_tollgate_id", iTollgateId)
end

function CTaskBase:OpenTargetFight(pid, npcobj)
    local iTollgateId = self:GetData("fight_tollgate_id")
    if not iTollgateId then
        return
    end
    self:Fight(pid, npcobj, iTollgateId)
end

function CTaskBase:SkipTaskWithGoldcoin(oPlayer, iGoldcoin, iNpcid)
    -- 扣钱
    if iGoldcoin > 0 then
        oPlayer:ResumeMoneyByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldcoin, "runring skip fight")
    end
    self:SkipWithPaid(oPlayer, iNpcid)
end

function CTaskBase:SkipWithPaid(oPlayer, iNpcid)
    local oNpc = self:GetNpcObj(iNpcid)
    self:MissionDone(oNpc)
end

function CTaskBase:SkipFight(pid, npcobj, iGoldcoin)
end

function CTaskBase:TransString(pid, npcobj, s)
    if string.find(s, "{grantnpc}") then
        local iGrantNpctype = self:GetData("grant_npc", 0)
        local oGrantNpc = global.oNpcMgr:GetGlobalNpc(iGrantNpctype)
        s = string.gsub(s, "{grantnpc}", oGrantNpc:Name())
    end
    if string.find(s, "{grantnpctype}") then
        local iGrantNpctype = self:GetData("grant_npc", 0)
        s = string.gsub(s, "{grantnpctype}", iGrantNpctype)
    end
    return super(CTaskBase).TransString(self, pid, npcobj, s)
end

function CTaskBase:RewardMissionDone(pid, npcobj, mRewardArgs)
    super(CTaskBase).RewardMissionDone(self, pid, npcobj, mRewardArgs)
    local iRing = self:GetRing()
    local iSpRewardId = table_get_depth(res, {"daobiao", "task", "runring", "sp_ring_rwd", iRing, "rewardid"})
    if iSpRewardId then
        mRewardArgs = table_deep_copy(mRewardArgs or {})
        mRewardArgs.sp_reward_type = "sp_ring"
        self:Reward(pid, iSpRewardId, mRewardArgs)
    end
end

function CTaskBase:GetCreateWeekMorningNo()
    return get_morningweekno(self:GetCreateTime())
end

function CTaskBase:ClickOpenShop(oPlayer)
    -- 回调自动流程
    local pid = oPlayer:GetPid()
    local iTaskId = self:GetId()
    local mNet = {taskid = iTaskId}
    global.oCbMgr:SetCallBack(pid, "GS2COpenShopForTask", mNet, nil, function(oPlayer, mData)
        global.oRunRingMgr:OnDoneShopBuy(oPlayer, mData, pid, iTaskId)
    end)
    return true
end

function CTaskBase:LogHelperRewardContent(oHelper, sIdx, mRewardContent, mArgs)
    local mLogData = oHelper:LogData()
    local mContentCopy = self:SimplifyReward(oHelper, mRewardContent or {}, mArgs)
    mLogData.reward = mContentCopy
    mLogData.owner = self:GetOwner() or 0
    mLogData.taskid = self:GetId()
    mLogData.rewardid = tonumber(sIdx)
    record.user("task", "runring_help_share_reward", mLogData)
end

function CTaskBase:LogReward(oPlayer, sIdx, mRewardContent, mArgs)
    if mArgs and mArgs.is_helper then
        self:LogHelperRewardContent(oPlayer, sIdx, mRewardContent, mArgs)
        return
    end
    super(CTaskBase).LogReward(self, oPlayer, sIdx, mRewardContent, mArgs)
end

function CTaskBase:GetRewardReason(mArgs)
    local sMyReason = mArgs and mArgs.my_reason
    if sMyReason then
        return sMyReason
    end
    return super(CTaskBase).GetRewardReason(self, mArgs)
end

function CTaskBase:GetDialogPlotCbFunc(pid, iTaskId, npcid)
    if global.oRunRingMgr:IsAutoTaskWithPlot() then
        return
    end
    -- TODO 设法实现displaymgr，让结构简单一些
    if self.m_tmp_sPlots ~= "acceptPlots" then
        return
    end
    if self:GetData("no_autostart") then
        return nil
    end
    -- 自动开始流程
    return function(oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskId, true)
        if not oTask then
            return
        end
        oTask:TrySubmit(oPlayer)
    end
end

--------------------------------------------------
CTaskFindNpc = {}
CTaskFindNpc.__index = CTaskFindNpc
inherit(CTaskFindNpc, CTaskBase)

--------------------------------------------------

ITEM_SP_TYPE = {
    LOW_EQUIP = 1, -- 低品质装备
    COOKED = 2, -- 烹饪
    MEDICINE = 3, -- 炼药
    GU_DONG = 4, -- 古董
    HUA_HUI = 5, -- 花卉
    LOW_SUMMON_SKILL_BOOK = 6, -- 低级兽诀
}

ORG_SKILL_ID = {
    COOK = 4101,
    MEDICINE = 4102,
}

EXTEND_UI_OPT = {
    BUY = 1,
    CALL_HELP = 2,
    RUN_LEGEND = 3,
    SUBMIT = 4,
}

EXTEND_TEXT_ID = {
    [EXTEND_UI_OPT.BUY] = 63012,
    [EXTEND_UI_OPT.CALL_HELP] = 63013,
    [EXTEND_UI_OPT.RUN_LEGEND] = 63014,
    [EXTEND_UI_OPT.SUBMIT] = 63015,
}

EXTEND_CB_FUNC = {
    [EXTEND_UI_OPT.BUY] = "ClickOpenShop",
    [EXTEND_UI_OPT.CALL_HELP] = "ClickCallOrgHelp",
    [EXTEND_UI_OPT.RUN_LEGEND] = "ClickRunLegend",
    [EXTEND_UI_OPT.SUBMIT] = "ClickSubmitTask",
}

CTaskFindItem = {}
CTaskFindItem.__index = CTaskFindItem
inherit(CTaskFindItem, CTaskBase)

function CTaskFindItem:Save()
    local mData = super(CTaskFindItem).Save(self)
    mData.item_sp_type = self.m_iItemSpType
    return mData
end

function CTaskFindItem:Load(mData)
    if not mData then
        return
    end
    super(CTaskFindItem).Load(self, mData)
    self.m_iItemSpType = mData.item_sp_type
end

function CTaskFindItem:RandChooseNeedItemType(mNeedItemConfigs, iGrade)
    local mRatios = {}
    for iTypeId, mInfo in pairs(mNeedItemConfigs) do
        local lGradeIn = mInfo.grade_in -- 导表处理过
        if not lGradeIn or (lGradeIn[1] <= iGrade and iGrade <= lGradeIn[2]) then
            mRatios[iTypeId] = mInfo.ratio
            goto continue
        end
        ::continue::
    end
    return table_choose_key(mRatios)
end

function CTaskFindItem:RandOutTargetItem(pid)
    local mNeedItemConfigs = table_get_depth(res, {"daobiao", "task", "runring", "need_items"})
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local iGrade = oPlayer:GetGrade()
    local iTypeId = self:RandChooseNeedItemType(mNeedItemConfigs, iGrade)
    assert(iTypeId, string.format("runring task randitem fail, pid:%d, grade:%d", pid, iGrade))

    local mDetail = mNeedItemConfigs[iTypeId]
    local iItemGroup = mDetail.itemgroup or 0
    local mItemSids = mDetail.itemsid_ratio
    local iSpType = mDetail.sp_type or 0
    local iIsGroup = mDetail.is_group or 0
    local bIsGroup = (iIsGroup ~= 0)
    local iAmount = 1
    if iSpType > 0 then
        self.m_iItemSpType = iSpType
    end
    if bIsGroup then
        assert(iItemGroup > 0, string.format("runring task itemgroup null, pid:%d, inputitemgroup:%d, sptype:%d", pid, iItemGroup, iSpType))
        self:SetNeedItemGroup({iItemGroup}, iAmount)
        return
    end
    if mItemSids and next(mItemSids) then
        local iItemSid = table_choose_key(mItemSids)
        self:SetNeedItem(iItemSid, iAmount)
        return
    end
    -- local iItemGroupParsed = self:ParseItemGroupBySpType(oPlayer, iSpType, iItemGroup, mItemSids)
    -- assert(iItemGroupParsed and iItemGroupParsed > 0, string.format("runring task parse itemgroup null, pid:%d, inputitemgroup:%d, sptype:%d", pid, iItemGroup, iSpType))
    if iItemGroup and iItemGroup > 0 then
        self:SetNeedItem(iItemGroup, iAmount)
        return
    end
    assert(nil, string.format("runring parse needitem randtype err, pid:%d, typeid:%d, sptype:%d", pid, iTypeId, iSpType))
end

-- function CTaskFindItem:ParseItemGroupBySpType(oPlayer, iSpType, iItemGroup, mItemSids)
--     if not iSpType or iSpType <= 0 then
--         return iItemGroup
--     end
--     local pid = oPlayer:GetPid()
--     assert(oPlayer, string.format("runring task init item but player offline, pid:%d, taskid:%d", pid, self:GetId()))
--     if iSpType == ITEM_SP_TYPE.LOW_EQUIP then
--         local iGrade = oPlayer:GetGrade()
--         local lItemGroups = self:SelectOutEquipGroups(iGrade)
--         assert(lItemGroups, string.format("runring task init item but null itemgroups, pid:%d, grade:%d, taskid:%d", pid, iGrade, self:GetId()))
--         return extend.Random.random_choice(lItemGroups) -- groupid
--     -- elseif iSpType == ITEM_SP_TYPE.COOKED then
--     --     local iSkillId = ORG_SKILL_ID.COOK
--     --     local oSkill = oPlayer.m_oSkillCtrl:GetOrgSkillById(iSkillId)
--     --     if not oSkill then
--     --         oSkill = global.oSkillLoader:GetLowestEffectiveOrgSkill(iSkillId)
--     --     end
--     --     return oSkill:RandomItem() -- itemsid
--     -- elseif iSpType == ITEM_SP_TYPE.MEDICINE then
--     --     local iSkillId = ORG_SKILL_ID.MEDICINE
--     --     local oSkill = oPlayer.m_oSkillCtrl:GetOrgSkillById(iSkillId)
--     --     if not oSkill then
--     --         oSkill = global.oSkillLoader:GetLowestEffectiveOrgSkill(iSkillId)
--     --     end
--     --     return oSkill:NormalRefine() -- itemsid
--     end
--     return iItemGroup
-- end

-- function CTaskFindItem:SelectOutEquipGroups(iGrade)
--     local mLvEquips = table_get_depth(res, {"daobiao", "task", "runring", "need_equip_by_lv"})
--     for id, mInfo in pairs(mLvEquips) do
--         if iGrade >= mInfo.lv_lower and iGrade <= mInfo.lv_upper then
--             return mInfo.item_groups
--         end
--     end
-- end

function CTaskFindItem:IsItemSubmitable(oPlayer, oItem)
    if not super(CTaskFindItem).IsItemSubmitable(self, oPlayer, oItem) then
        return false
    end
    local iSpType = self.m_iItemSpType
    if iSpType then
        if iSpType == ITEM_SP_TYPE.LOW_EQUIP then
            if oItem:Quality() > global.oRunRingMgr:GetGlobalConfig("need_equip_quality_max", 0) then
                return false
            end
        end
    end
    return true
end

function CTaskFindItem:BuildExtApplyInfo()
    local mExtInfo = super(CTaskFindItem).BuildExtApplyInfo(self)
    mExtInfo = mExtInfo or {}
    local iSpType = self.m_iItemSpType
    if iSpType then
        if iSpType == ITEM_SP_TYPE.LOW_EQUIP then
            mExtInfo.equip_quality_max = global.oRunRingMgr:GetGlobalConfig("need_equip_quality_max", 0) -- 最高品质
        end
        -- mExtInfo = mExtInfo or {}
        -- mExtInfo.sp_type = iSpType
    end
    local iLeftLegendTime = self:GetLegendLeftTime()
    if iLeftLegendTime > 0 then
        mExtInfo.legend_left_time = iLeftLegendTime -- 传说剩余时间
    end
    return mExtInfo
end

function CTaskFindItem:GetNeedItemSid()
    if not self.m_mNeedItem then
        return nil
    end
    for itemsid,iAmount in pairs(self.m_mNeedItem) do
        return itemsid
    end
end

function CTaskFindItem:GetNeedItemGroupId()
    if not self.m_mNeedItemGroup then
        return nil
    end
    for itemgroup,iAmount in pairs(self.m_mNeedItemGroup) do
        return itemgroup
    end
end

function CTaskFindItem:GetNeedItemName()
    local sNeedItemName, iNeedAmount
    if self.m_mNeedItem then
        for itemsid, iAmount in pairs(self.m_mNeedItem) do
            sNeedItemName, iNeedAmount = global.oItemLoader:GetItemNameBySid(itemsid), iAmount
        end
    end
    if self.m_mNeedItemGroup then
        for itemgroup, iAmount in pairs(self.m_mNeedItemGroup) do
            sNeedItemName, iNeedAmount = global.oItemLoader:GetItemGroupName(itemgroup), iAmount
        end
    end
    local sNameSuffix = self:GetItemNameSuffix()
    if sNameSuffix and #sNameSuffix then
        sNeedItemName = sNeedItemName .. sNameSuffix
    end
    return sNeedItemName, iNeedAmount
end

function CTaskFindItem:GetTaskItemName(pid, npcobj)
    local sItemName = super(CTaskFindItem).GetTaskItemName(self, pid, npcobj)
    local sNameSuffix = self:GetItemNameSuffix()
    if sNameSuffix and #sNameSuffix then
        sItemName = sItemName .. sNameSuffix
    end
    return sItemName
end

function CTaskFindItem:GetItemNameSuffix()
    local iSpType = self.m_iItemSpType
    if iSpType then
        if iSpType == ITEM_SP_TYPE.LOW_EQUIP then
            local iNeedMaxQuality = global.oRunRingMgr:GetGlobalConfig("need_equip_quality_max", 0)
            local lColorNames = {}
            for iColor = 0, iNeedMaxQuality do
                local sColorName = table_get_depth(res, {"daobiao", "itemcolor", iColor, "name"})
                if sColorName then
                    table.insert(lColorNames, sColorName)
                end
            end
            return string.format("（%s品质）", table.concat(lColorNames, "、"))
        end
    end
end

-- @Override
function CTaskFindItem:IsAnleiWarWinTouchMissionDone()
    return false
end

function CTaskFindItem:OnMissionDone(pid)
    local iHelper = self:GetData("done_helper")
    if iHelper then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
        global.oRunRingMgr:RecCallItemHelp(oPlayer)
        self.m_bNextNoAuto = true
    end
end

function CTaskFindItem:Reward(pid, iRewardId, mArgs)
    mArgs = mArgs or {}
    if not mArgs.sp_reward_type then
        local iHelper = self:GetData("done_helper")
        if iHelper then
            -- 协助者额外获得奖励
            local oHelper = global.oWorldMgr:GetOnlinePlayerByPid(iHelper)
            if oHelper then
                local mHelperArgs = table_deep_copy(mArgs or {})
                mHelperArgs.is_helper = true
                mHelperArgs.my_reason = "runring_help_rob_exp"
                super(CTaskFindItem).Reward(self, iHelper, iRewardId, mHelperArgs)
            end
        end
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if mArgs.sp_reward_type == "legend" then
        if pid == self:GetOwner() then
            local mRewardContent = super(CTaskFindItem).Reward(self, pid, iRewardId, mArgs)
            local oGotLegendItem = self:CheckRewardLegend(mRewardContent)
            if oGotLegendItem then
                self:NotifyGotLegend(oPlayer, oGotLegendItem)
                self:SetLegendGot(oPlayer)
            end
            return mRewardContent
        else
            return {}
        end
    end
    return super(CTaskFindItem).Reward(self, pid, iRewardId, mArgs)
end

function CTaskFindItem:GenRewardContent(oPlayer, rewardinfo, mArgs, bPreview)
    mArgs = mArgs or {}
    local iHelper = self:GetData("done_helper")
    if not mArgs.sp_reward_type and mArgs.is_helper then
        if not iHelper or iHelper ~= oPlayer:GetPid() then
            record.error("runring finditem reward helper error, helper:%s, owner:%d, taskid:%d, player:%d, sptype:%s", iHelper, self:GetOwner(), self:GetId(), oPlayer:GetPid(), mArgs.sp_reward_type)
        end
        local sExp = rewardinfo["exp"]
        local iExp = 0
        if self:IsRewardValueValid(sExp) then
            iExp = self:InitRewardExp(oPlayer, sExp, mArgs)
            if iExp > 0 then
                return {exp = iExp}
            end
        end
        record.warning("runring helper no reward, helper:%d, owner:%d, taskid:%d", iHelper, self:GetOwner(), self:GetId())
        return {}
    end
    local mContent = super(CTaskFindItem).GenRewardContent(self, oPlayer, rewardinfo, mArgs, bPreview)
    if not mArgs.sp_reward_type and iHelper and iHelper ~= oPlayer:GetPid() then
        mContent.exp = nil
    end
    return mContent
end

function CTaskFindItem:CheckTaskAlive(oHelper, iCreateWeekNo, iRing)
    if iCreateWeekNo ~= self:GetCreateWeekMorningNo() or iRing ~= self:GetRing() then
        local sMsg = self:GetTextData(63008)
        oHelper:NotifyMessage(sMsg)
        return false
    end
    return true
end

function CTaskFindItem:OnHelpTakeItemUICallback(oHelper, mData, iCreateWeekNo, iRing)
    if not self:CheckTaskAlive(oHelper, iCreateWeekNo, iRing) then
        return
    end
    if not global.oRunRingMgr:CheckCanGiveItemHelp(oHelper) then
        return
    end
    local iOwner = self:GetOwner()
    local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if not self:DoSubmitItem(oHelper, mData) then
        self:SendAnyoneTaskNeeds(oHelper)
        -- 回调自动流程
        local iTaskId = self:GetId()
        local mNet = {taskid = iTaskId, owner = iOwner}
        global.oCbMgr:SetCallBack(oHelper:GetPid(), "GS2COpenShopForTask", mNet, nil, function(oPlayer, mData)
            global.oRunRingMgr:OnDoneShopBuy(oPlayer, mData, iOwner, iTaskId)
        end)
        return
    end
    -- 次数记录
    global.oRunRingMgr:RecGiveItemHelp(oHelper)
    -- RecCallItemHelp(oOwner)在OnMissionDone内执行
    -- 任务完成
    self:SetData("done_helper", oHelper:GetPid())
    self:MissionDone()
end

-- 援助交物品
function CTaskFindItem:OnGiveHelp(oHelper, iCreateWeekNo, iRing, bSkipClickCheck)
    if not self:CheckTaskAlive(oHelper, iCreateWeekNo, iRing) then
        return
    end
    if not bSkipClickCheck then
        -- 以后可能加入点击频率限制
    end
    local iTaskId = self:GetId()
    local iOwner = self:GetOwner()
    if not self:ValidTakeItem(oHelper:GetPid()) then
        local sMsg = self:GetTextData(63011)
        oHelper:NotifyMessage(sMsg)
        self:SendAnyoneTaskNeeds(oHelper)
        local mNet = {
            taskid = iTaskId,
            owner = iOwner,
        }
        local cbFunc = function(oPlayer, mData)
            global.oRunRingMgr:OnGiveHelpBuyCallback(oPlayer, mData, iOwner, iTaskId, iCreateWeekNo, iRing)
        end
        global.oCbMgr:SetCallBack(oHelper:GetPid(), "GS2COpenShopForTask", mNet, nil, cbFunc)
        return
    end
    local mNet = {
        taskid = iTaskId,
        owner = iOwner,
    }
    local cbFunc = function(oPlayer, mData)
        global.oRunRingMgr:OnGiveItemHelpCallback(oPlayer, mData, iOwner, iTaskId, iCreateWeekNo, iRing)
    end
    self:SendAnyoneTaskNeeds(oHelper)
    global.oCbMgr:SetCallBack(oHelper:GetPid(), "GS2CHelpTaskGiveItem", mNet, nil, cbFunc)
end

-- function CTaskFindItem:GetSpItemName(iSpType)
--     return table_get_depth(res, {"daobiao", "task", "runring", "item_sp_type", iSpType, "name"}) or ""
-- end

function CTaskFindItem:ClickRunLegend(oPlayer)
    if self:IsLegendGot(oPlayer) then
        local sMsg = self:GetTextData(63016)
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    local iLeftSec = self:GetLegendLeftTime()
    if iLeftSec <= 0 then
        local sMsg = self:GetTextData(63017)
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    -- 开始巡逻
    self:SetLegendOn(oPlayer)
    return true
end

function CTaskFindItem:NotifyGotLegend(oPlayer, oGotLegendItem)
    local mNet = self:GetTextData(63020)
    mNet.sContent = global.oToolMgr:FormatColorString(mNet.sContent, {
        item = oGotLegendItem:Name(),
    })
    local pid = oPlayer:GetPid()
    global.oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet)
end

function CTaskFindItem:IsAnlei()
    return self.m_bAnleiDoing
end

function CTaskFindItem:TriggerAnLei(iMap)
    local pid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if self:IsLegendGot(oPlayer) then
        self:SetLegendOff(oPlayer)
        return
    end
    if self:GetLegendLeftTime() <= 0 then
        self:SetLegendOff(oPlayer)
        return
    end
    local iTollgateId = self:GetData("legend_fight")
    assert(iTollgateId, string.format("runring trigger legend no tollgate, pid:%d, taskid:%d", pid, self:GetId()))
    self:Fight(pid, nil, iTollgateId)
end

function CTaskFindItem:RewardLegend(pid, iRewardId, mArgs)
    if pid ~= self:GetOwner() then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local lPlayers = self:GetFighterList(oPlayer, mArgs)
    local mRewardArgs = table_deep_copy(mArgs or {})
    mRewardArgs.sp_reward_type = "legend"
    self:Reward(self:GetOwner(), iRewardId, mRewardArgs)
end

-- @Override
function CTaskFindItem:GetTriggerEvent()
    return self:GetData("legend_event")
end

-- @Override
-- 因为这个任务不是明暗雷战斗任务，是内建了暗雷战斗
function CTaskFindItem:IsWarTeamMembersShareDone(oWar, iWarCallerPid, npcobj, mWarCbArgs)
    return false
end

function CTaskFindItem:InitLegend(pid, iEvent)
    local mLegendMap = table_get_depth(res, {"daobiao", "task", "runring", "legend_map"})
    local mLegendFight = table_get_depth(res, {"daobiao", "task", "runring", "legend_fight"})
    local iRandMap = extend.Random.random_choice(table_key_list(mLegendMap))
    local iRandFight = extend.Random.random_choice(table_key_list(mLegendFight))
    assert(iRandMap, string.format("runring init legend no map, pid:%d, taskid:%d", pid, self:GetId()))
    assert(iRandFight, string.format("runring init legend no fight, pid:%d, taskid:%d", pid, self:GetId()))
    self:SetData("legend_map", iRandMap)
    self:SetData("legend_fight", iRandFight)
    self:SetData("legend_event", iEvent)
    local iLegendTime = global.oRunRingMgr:GetGlobalConfig("task_legend_time", 0)
    self:SetData("legend_timeout", get_time() + iLegendTime)
end

function CTaskFindItem:OnStopXunLuo(oPlayer)
    self:SetLegendOff(oPlayer)
end

function CTaskFindItem:Clear(iPid)
    super(CTaskFindItem).Clear(self, iPid)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    self:SetLegendOff(oPlayer)

    local iHelper = self:GetData("done_helper")
    if iHelper then
        -- 通知完成
        local oHelper = global.oWorldMgr:GetOnlinePlayerByPid(iHelper)
        if oHelper then
            local sPlayerName = oPlayer:GetName()
            local sHelperName = oHelper:GetName()
            local sTaskName = self:PackInfoName()
            local sKindShowName = self:GetKindShowName()
            local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(63033), {role = {sPlayerName, sHelperName}, task_name = sTaskName, task_kind = sKindShowName})
            global.oChatMgr:HandleOrgChat(oPlayer, sMsg, true)

            local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(63024), {role = sHelperName})
            oPlayer:NotifyMessage(sMsg)
        end
    end
end

function CTaskFindItem:IsNeedLoginAnleiXunluo()
    return self:IsAnlei()
end

function CTaskFindItem:SetLegendOff(oPlayer)
    local iPid = oPlayer:GetPid()
    local iTaskId = self:GetId()
    if self.m_bAnleiDoing then
        self.m_bAnleiDoing = false
        oPlayer:Send("GS2CXunLuo", {type=0})
    end
    oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:UnregWholeTask(iTaskId)
end

function CTaskFindItem:SetLegendOn(oPlayer)
    local iPid = oPlayer:GetPid()
    local iMap = self:GetData("legend_map")
    assert(iMap, string.format("runring run legend no map, pid:%d, taskid:%d", iPid, self:GetId()))
    local iTaskId = self:GetId()
    self.m_bAnleiDoing = true
    oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:RegTaskMap(iTaskId, iMap)
    self:RunXunLuo(oPlayer, iMap)
end

function CTaskFindItem:TrySubmit(oPlayer)
    if oPlayer:InWar() then
        return
    end
    if self:CanSubmit(oPlayer) then
        self:ToPopSubmit(oPlayer)
        return
    end
    -- self:Click(oPlayer:GetPid())
    self:ClickOpenShop(oPlayer)
end

function CTaskFindItem:ClickSubmitTask(oPlayer)
    if not self:CanSubmit(oPlayer) then
        local sNeedItemName, iNeedItemAmount = self:GetNeedItemName()
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(63018), {
            item = sNeedItemName,
        })
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    self:ToPopSubmit(oPlayer)
    return true
end

function CTaskFindItem:ToPopSubmit(oPlayer)
    local npctype = self:Target()
    local pid = oPlayer:GetPid()
    if npctype then
        if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
            self:AutoFindNpcPath(pid, npctype)
        end
    else
        self:PopTakeItemUI(pid)
    end
end

function CTaskFindItem:IsCallHelpInCd(oPlayer)
    local iCallTimeout = self:GetData("item_call_help_timeout")
    if iCallTimeout and get_time() < iCallTimeout then
        return true
    end
end

function CTaskFindItem:ClickCallOrgHelp(oPlayer)
    local iOrgID = oPlayer:GetOrgID()
    if not iOrgID or iOrgID == 0 then
        local sMsg = self:GetTextData(63003)
        oPlayer:NotifyMessage(sMsg)
        return
    end
    if self:IsCallHelpInCd(oPlayer) then
        local sMsg = self:GetTextData(63019)
        oPlayer:NotifyMessage(sMsg)
        return
    end
    if not global.oRunRingMgr:CanCallItemHelp(oPlayer) then
        local iMaxCallTimes = global.oRunRingMgr:GetGlobalConfig("week_call_help_item_times", 0)
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(63007), {
            amount = iMaxCallTimes,
        })
        oPlayer:NotifyMessage(sMsg)
        return
    end
    local sNeedItemName, iNeedItemAmount = self:GetNeedItemName()
    local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(63006), {
        role = oPlayer:GetName(),
        item = sNeedItemName,
        amount = iNeedItemAmount,
        task_name = self:PackInfoName(),
        task_kind = self:GetKindShowName(),
    })
    local iTaskId = self:GetId()
    sMsg = sMsg .. string.format("{link30,%d,%d,%d,%d}", oPlayer:GetPid(), iTaskId, self:GetCreateWeekMorningNo(), self:GetRing())
    local oChatMgr = global.oChatMgr
    -- oChatMgr:HandleOrgChat(oPlayer, sMsg, true)
    global.oChatMgr:SendMsg2Org(sMsg, iOrgID, oPlayer)
    local iCd = global.oRunRingMgr:GetGlobalConfig("call_help_item_cd", 0)
    if iCd > 0 then
        if iCd > 3600 then
            iCd = 3600
        end
        self:SetData("item_call_help_timeout", get_time() + iCd)
        self:DelTimeCb("item_call_help_cd")
        local fCbSelfGetter = self:GetCbSelfGetter()
        if fCbSelfGetter then
            self:AddTimeCb("item_call_help_cd", iCd * 1000, function()
                local oTask = fCbSelfGetter()
                if oTask then
                    self:RefreshExtendUI()
                end
            end)
        end
    end
    return true
end

function CTaskFindItem:RefreshExtendUI()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        self:BuildExtendTaskUI(oPlayer)
        self:SendExtendTaskUI(oPlayer, true)
    end
end

function CTaskFindItem:TrueDoClick(oPlayer)
    self:BuildExtendTaskUI(oPlayer)
    self:SendExtendTaskUI(oPlayer)
end

function CTaskFindItem:GetLegendEndTime()
    return self:GetData("legend_timeout", 0)
end

function CTaskFindItem:GetLegendLeftTime()
    if self:IsLegendGot(oPlayer) then
        return 0
    end
    local iLeftLegendTime = self:GetLegendEndTime() - get_time()
    if iLeftLegendTime <= 0 then
        return 0
    end
    return iLeftLegendTime
end

function CTaskFindItem:IsLegendGot(oPlayer)
    return self:GetData("got_legend_reward")
end

function CTaskFindItem:SetLegendGot(oPlayer)
    self:SetData("got_legend_reward", true)
    self:SetLegendOff(oPlayer)
    self:Refresh({ext_apply_info = true})
end

function CTaskFindItem:CanRunLegend(oPlayer)
    if self:IsLegendGot(oPlayer) then
        return false
    end
    if self:GetLegendLeftTime() <= 0 then
        return false
    end
    return true
end

function CTaskFindItem:TimeOutLegend()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if self:IsAnlei() then
        self:SetLegendOff(oPlayer)
    end
    self:Refresh({ext_apply_info = true})
    self:RefreshExtendUI()
end

function CTaskFindItem:SetupTimer()
    super(CTaskFindItem).SetupTimer(self)

    local iLeftLegendTime = self:GetLegendLeftTime()
    self:DelTimeCb("legend_timing")
    if iLeftLegendTime > 0 then
        -- TODO 需要改为cron
        if iLeftLegendTime <= 1 * 24 * 3600 then
            local fCbSelfGetter = self:GetCbSelfGetter()
            if fCbSelfGetter then
                self:AddTimeCb("legend_timing", iLeftLegendTime * 1000, function()
                    local oTask = fCbSelfGetter()
                    if oTask then
                        oTask:TimeOutLegend()
                    end
                end)
            end
        end
    end
end

function CTaskFindItem:CanSubmit(oPlayer)
    return self:ValidTakeItem(oPlayer:GetPid())
end

-- @return: iShape, sArgs
function CTaskFindItem:GetLegendRwdItem(oPlayer)
    local iNeedItemSid = self:GetNeedItemSid()
    local iNeedItemGroupId = self:GetNeedItemGroupId()
    if self.m_iItemSpType == ITEM_SP_TYPE.LOW_SUMMON_SKILL_BOOK then
        local iSpSid = global.oRunRingMgr:GetGlobalConfig("legend_rwd_summonskill", 0)
        if iNeedItemSid and iNeedItemSid ~= iSpSid then
            return iNeedItemSid
        end
        local lItemSids = global.oItemLoader:GetItemGroup(iNeedItemGroupId)
        if not extend.Array.find(lItemSids, iSpSid) then
            return extend.Random.random_choice(lItemSids)
        end
        return iSpSid
    end
    if not iNeedItemSid then
        local lItemSids = global.oItemLoader:GetItemGroup(iNeedItemGroupId)
        iNeedItemSid = extend.Random.random_choice(lItemSids)
    end
    if self.m_iItemSpType == ITEM_SP_TYPE.LOW_EQUIP then
        local iQuality = global.oRunRingMgr:GetGlobalConfig("legend_rwd_equip_quality", 0)
        return iNeedItemSid, string.format("equip_level=%d", iQuality)
    elseif self.m_iItemSpType == ITEM_SP_TYPE.MEDICINE then
        local iQuality = global.oRunRingMgr:GetGlobalConfig("legend_rwd_medicine_qualily", 0)
        return iNeedItemSid, string.format("quality=%d", iQuality)
    elseif self.m_iItemSpType == ITEM_SP_TYPE.COOKED then
        local iQuality = global.oRunRingMgr:GetGlobalConfig("legend_rwd_cooked_qualily", 0)
        return iNeedItemSid, string.format("quality=%d", iQuality)
    end
    return iNeedItemSid
end

function CTaskFindItem:TransItemShape(oPlayer, itemidx, iShape, sShape)
    if sShape == "999999" then
        local iShape, sArgs = self:GetLegendRwdItem(oPlayer)
        if sArgs then
            sShape = string.format("%d(%s)", iShape, sArgs)
        else
            sShape = tostring(iShape)
        end
        return iShape, sShape
    end
    return super(CTaskFindItem).TransItemShape(self, oPlayer, itemidx, iShape, sShape)
end

function CTaskFindItem:CheckRewardLegend(mRewardContent)
    if not mRewardContent then
        return
    end
    local iNeedItemSid = self:GetNeedItemSid()
    local iNeedItemGroupId = self:GetNeedItemGroupId()
    local lNeedItemSids = {iNeedItemSid}
    if iNeedItemGroupId and (not lNeedItemSids or not next(lNeedItemSids)) then
        lNeedItemSids = global.oItemLoader:GetItemGroup(iNeedItemGroupId)
    end
    local mAllItems = mRewardContent.items
    if mAllItems then
        for itemidx, mItems in pairs(mAllItems) do
            for _, oItem in ipairs(mItems["items"] or {}) do
                local iSid = oItem:SID()
                if extend.Array.find(lNeedItemSids, iSid) then
                    return oItem
                end
            end
        end
    end
end

--- 暂时将扩展菜单部分放在这里做为特殊定制逻辑，有需要再移到base
function CTaskFindItem:BuildExtendTaskUI(oPlayer)
    local lOptions = {}
    -- 购买
    if not self:ValidTakeItem(oPlayer:GetPid()) then
        table.insert(lOptions, {
            opt = EXTEND_UI_OPT.BUY,
            state = taskdefines.EXTEND_OPTION_STATE.NORMAL,
        })
    end
    -- 求助
    local iState = taskdefines.EXTEND_OPTION_STATE.NORMAL
    if self:IsCallHelpInCd(oPlayer) then
        iState = taskdefines.EXTEND_OPTION_STATE.GREY
    elseif not global.oRunRingMgr:CanCallItemHelp(oPlayer) then
        iState = taskdefines.EXTEND_OPTION_STATE.GREY
    end
    table.insert(lOptions, {
        opt = EXTEND_UI_OPT.CALL_HELP,
        state = iState,
    })
    -- 传说获取（去做暗雷）
    local iState = taskdefines.EXTEND_OPTION_STATE.NORMAL
    if not self:CanRunLegend(oPlayer) then
        iState = taskdefines.EXTEND_OPTION_STATE.GREY
    end
    table.insert(lOptions, {
        opt = EXTEND_UI_OPT.RUN_LEGEND,
        state = iState,
    })
    -- 交付
    local iState = taskdefines.EXTEND_OPTION_STATE.GREY
    if self:CanSubmit(oPlayer) then
        iState = taskdefines.EXTEND_OPTION_STATE.HIGHLIGHT
    end
    table.insert(lOptions, {
        opt = EXTEND_UI_OPT.SUBMIT,
        state = iState,
    })

    self.m_lExtendOptions = lOptions
end

function CTaskFindItem:GetExtendOptionText(iOpt)
    return self:GetTextData(EXTEND_TEXT_ID[iOpt] or 0) or ""
end

function CTaskFindItem:SendExtendTaskUI(oPlayer, bRefresh)
    if not self.m_lExtendOptions then
        return
    end
    local lPackedOptions = {}
    for _, mOptionInfo in ipairs(self.m_lExtendOptions) do
        table.insert(lPackedOptions, {
            text = self:GetExtendOptionText(mOptionInfo.opt),
            state = mOptionInfo.state,
        })
    end
    self.m_iExtendSessionIdx = (self.m_iExtendSessionIdx or 0) + 1
    local iTaskId = self:GetId()
    local mNet = {
        taskid = iTaskId,
        options = lPackedOptions,
        sessionidx = self.m_iExtendSessionIdx,
        refresh = bRefresh and 1 or 0,
    }
    oPlayer:Send("GS2CExtendTaskUI", mNet)
end

function CTaskFindItem:DealExtendTaskUICallback(oPlayer, mData)
    if not self.m_lExtendOptions then
        return true
    end
    if mData.sessionidx ~= self.m_iExtendSessionIdx then
        return true
    end
    local iAnswer = mData.answer
    local mOptionInfo = self.m_lExtendOptions[iAnswer]
    if not mOptionInfo then
        return true
    end
    local iOpt = mOptionInfo.opt
    local sCbFunc = EXTEND_CB_FUNC[iOpt]
    if sCbFunc then
        return self[sCbFunc](self, oPlayer)
    end
end

function CTaskFindItem:OnExtendTaskUICallback(oPlayer, mData)
    local bDone = self:DealExtendTaskUICallback(oPlayer, mData)
    if bDone then
        oPlayer:Send("GS2CExtendTaskUIClose", {taskid = self:GetId()})
        return
    end
end
--- end of ExtendTaskUI

--------------------------------------------------
CTaskFindSummon = {}
CTaskFindSummon.__index = CTaskFindSummon
inherit(CTaskFindSummon, CTaskBase)

function CTaskFindSummon:GetAvailableSumms(oPlayer)
    local mAllSummonInfo = table_get_depth(res, {"daobiao", "summon", "info"})
    local lSummCarryLvSeq = table_get_depth(res, {"daobiao", "summon", "sorted_carry_lv", "seq"})
    local mSummCarryLvDetail = table_get_depth(res, {"daobiao", "summon", "sorted_carry_lv", "detail"})
    local iPlayerGrade = oPlayer:GetGrade()
    local mAvailableSumms = {}
    for _, iLv in ipairs(lSummCarryLvSeq) do
        if iLv <= iPlayerGrade then
            local mSummSids = mSummCarryLvDetail[iLv]
            for iSid, _ in pairs(mSummSids) do
                local mInfo = mAllSummonInfo[iSid]
                if mInfo.type <= summondefines.TYPE_NORMALBB then
                    mAvailableSumms[iSid] = 1
                end
            end
        end
    end
    if next(mAvailableSumms) then
        return mAvailableSumms
    end
end

function CTaskFindSummon:RandOutTargetSumm(oPlayer)
    local mAvailableSumms = self:GetAvailableSumms(oPlayer)
    local pid = oPlayer:GetPid()
    assert(mAvailableSumms, string.format("runring target summ none matched, pid:%d, grade:%d", oPlayer:GetPid(), oPlayer:GetGrade()))
    local lSummSids = table_key_list(mAvailableSumms)
    local iSummSid = extend.Random.random_choice(lSummSids)
    self:SetNeedSummonSid(pid, iSummSid)
end

-- @Override
-- 交付可以包含非野生宠(宝宝)
function CTaskFindSummon:IsSummonSubmitable(oPlayer, oSummon)
    local oFightSummon = oPlayer.m_oSummonCtrl:GetFightSummon()
    if oFightSummon == oSummon or oSummon:IsBind() then
        return false
    end
    if not oSummon:IsWild() and not oSummon:IsNormalBB() then
        return false
    end
    if oSummon:IsNormalBB() and oSummon:GetIsZhenPinState() then
        return false
    end
    return true
end

-- @Override
function CTaskFindSummon:OnClickTaskFindSummon(oPlayer)
    local npctype
    if not self:ValidTakeSummon(oPlayer:GetPid()) then
        -- 回调自动流程
        self:ClickOpenShop(oPlayer)
        return true
    else
        npctype = self:Target()
    end
    return false, npctype
end

function CTaskFindSummon:BuildExtApplyInfo()
    local mExtInfo = super(CTaskFindSummon).BuildExtApplyInfo(self)
    mExtInfo = mExtInfo or {}
    mExtInfo.summon_allow_bb = 1 -- 允许交普通宝宝
    -- mExtInfo.summon_allow_zhenpin = 0 -- 不允许交珍品宠(默认0)
    return mExtInfo
end

--------------------------------------------------
CTaskNpcFight = {}
CTaskNpcFight.__index = CTaskNpcFight
inherit(CTaskNpcFight, CTaskBase)

-- @Override
function CTaskNpcFight:CanCallOrgHelp(oPlayer)
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID == 0 then
        local sMsg = self:GetTextData(63003)
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if oTeam and not oTeam:IsLeader(pid) then
        local sMsg = self:GetTextData(63004)
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    return true
end

-- @Override
function CTaskNpcFight:GetOrgHelpMsg(oPlayer)
    local sPlayerName = oPlayer:GetName()
    local iRing = self:GetRing()
    local iTeamID = oPlayer:TeamID()
    local sKindShowName = self:GetKindShowName()
    local sMsg =  self:GetTextData(63002)
    return global.oToolMgr:FormatColorString(sMsg, {role = sPlayerName, task_kind = sKindShowName, amount = iRing, teamid = iTeamID})
end

function CTaskNpcFight:SkipFight(pid, npcobj, iGoldcoin)
    local iTaskId = self:GetId()
    local iNpcid = npcobj:ID()
    local mNet = self:GetTextData(63005)
    global.oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
        global.oRunRingMgr:OnAnswerSkipFight(oPlayer, mData, iGoldcoin, iTaskId, iNpcid)
    end)
end

function CTaskNpcFight:SkipWithPaid(oPlayer, iNpcid)
    local oNpc = self:GetNpcObj(iNpcid)
    if iNpcid then
        local iEvent = self:GetEvent(iNpcid)
        local mEvent = self:GetEventData(iEvent)
        if mEvent then
            self:DoScript(oPlayer:GetPid(), oNpc, mEvent["win"])
            return
        end
    end
    super(CTaskNpcFight).SkipWithPaid(self, oPlayer, iNpcid)
end

function CTaskNpcFight:Reward(pid, iRewardId, mArgs)
    mArgs = mArgs or {}
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local mRewardContent = super(CTaskNpcFight).Reward(self, pid, iRewardId, mArgs)
    if not mArgs.sp_reward_type then
        local lFighters = self:GetFighterList(oPlayer, mArgs)
        local iFighterCnt = #lFighters
        if iFighterCnt > 1 then
            local iRewardExp = mRewardContent.exp or 0
            if iRewardExp > 0 then
                local iOwner = self:GetOwner()
                local iTaskId = self:GetId()
                -- 公式读表
                local sHelpExp = global.oRunRingMgr:GetGlobalConfig("help_fight_exp_rwd", "0")
                local iHelpExp = math.floor(formula_string(sHelpExp, {
                    exp = iRewardExp,
                    helpfighercnt = iFighterCnt - 1,
                }))
                local mHelperArgs = table_deep_copy(mArgs or {})
                mHelperArgs.my_reason = "runring_help_share_exp"
                mHelperArgs.helper_exp = iHelpExp
                mHelperArgs.is_helper = true
                for _, iFighterId in ipairs(lFighters) do
                    if iFighterId ~= pid then
                        local oFighter = global.oWorldMgr:GetOnlinePlayerByPid(iFighterId)
                        if oFighter then
                            if global.oRunRingMgr:CanRewardFightHelp(oFighter) then
                                global.oRunRingMgr:RecRewardFightHelp(oFighter)
                                super(CTaskNpcFight).Reward(self, iFighterId, iRewardId, mHelperArgs)
                            end
                            global.oRunRingMgr:TryNotifyRewardFightHelpFull(oFighter)
                        end
                    end
                end
            end
        end
    end
    return mRewardContent
end

function CTaskNpcFight:DealBeforeOnWarWin(oWar, pid, npcobj, mWarCbArgs)
    -- 存储最后一次战斗参与的玩家，在任务提交时，发送侠义值
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oLeader  and self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        local mWarResult = {}
        mWarResult.lLastFighterPid = self:GetFighterList(oLeader, mWarCbArgs)
        mWarResult.iLastLeaderPid = pid
        self.m_mLastWarResult = mWarResult
    end
end

function CTaskNpcFight:MissionDone(npcobj, mArgs)
    if self.m_mLastWarResult and self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        local mWarResult = self.m_mLastWarResult
        self:TryRewardFighterXiayiPoint(mWarResult.iLastLeaderPid, mWarResult.lLastFighterPid, nil)
        self.m_mLastWarResult = nil
    end
    super(CTaskNpcFight).MissionDone(self,npcobj, mArgs)
end

function CTaskNpcFight:TryRewardFighterXiayiPoint(iLeaderPid, lFighterPid, mArgs)
    local function FilterFighter(iLeaderPid, lFighterPid)
        local lRetPid = {}
        for _, pid in pairs(lFighterPid) do
            if pid ~= iLeaderPid then
                table.insert(lRetPid,pid)
            end
        end
        return lRetPid
    end
    local lRewardPid = self:RewardFighterFilter(iLeaderPid, lFighterPid, FilterFighter)
    for _,pid in pairs(lRewardPid) do
        local oFighter = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oFighter then
            self:RewardXiayiPoint(oFighter, "runring", "三界历练")
        end
    end
end

function CTaskNpcFight:GenRewardContent(oPlayer, rewardinfo, mArgs, bPreview)
    mArgs = mArgs or {}
    if mArgs.is_helper then
        local iHelperExp = mArgs.helper_exp
        if iHelperExp > 0 then
            return {exp = iHelperExp}
        end
        record.warning("runring helper no reward, helper:%d, owner:%d, taskid:%d", oPlayer:GetPid(), self:GetOwner(), self:GetId())
        return {}
    end
    local mContent = super(CTaskNpcFight).GenRewardContent(self, oPlayer, rewardinfo, mArgs, bPreview)
    return mContent
end

--------------------------------

local mTaskType2ObjectBase = {
    [gamedefines.TASK_TYPE.TASK_FIND_NPC] = "CTaskFindNpc",
    [gamedefines.TASK_TYPE.TASK_FIND_ITEM] = "CTaskFindItem",
    [gamedefines.TASK_TYPE.TASK_FIND_SUMMON] = "CTaskFindSummon",
    [gamedefines.TASK_TYPE.TASK_NPC_FIGHT] = "CTaskNpcFight",
}

function GetTaskType(iTaskId)
    return global.oTaskLoader:GetTaskBaseData(iTaskId)["tasktype"]
end

function GetTaskClass(iTaskId)
    local iTaskType = GetTaskType(iTaskId)
    -- local sClass = mTaskType2ObjectBase[iTaskType]
    -- return sClass
    if iTaskType == gamedefines.TASK_TYPE.TASK_FIND_NPC then
        return CTaskFindNpc
    elseif iTaskType == gamedefines.TASK_TYPE.TASK_FIND_ITEM then
        return CTaskFindItem
    elseif iTaskType == gamedefines.TASK_TYPE.TASK_FIND_SUMMON then
        return CTaskFindSummon
    elseif iTaskType == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        return CTaskNpcFight
    end
end

function NewTask(iTaskId)
    -- local sClass = GetTaskClass(iTaskId)
    -- assert(sClass, "runring task nil class, taskid:" .. iTaskId)
    -- local cClass = _ENV[sClass]
    local cClass = GetTaskClass(iTaskId)
    local o = cClass:New(iTaskId)
    return o
end
