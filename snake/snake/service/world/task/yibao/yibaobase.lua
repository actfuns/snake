local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))
local stalldefines = import(service_path("stall.defines"))

local CULTIVATE_EXP = 1011

function GetTaskYibaoKind(taskid)
    return table_get_depth(res, {"daobiao", "task", "yibao", "task", taskid})["yibao_kind"]
end

-----------------------------------
CTask = {}
CTask.__index = CTask
CTask.m_sName = "yibao"
CTask.m_sTempName = "异宝任务"
CTask.m_sStatisticsName = "task_yibao"
inherit(CTask, taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:SeekHelpYibao(oPlayer)
    local iPid = oPlayer:GetPid()
    global.oNotifyMgr:Notify(iPid, self:GetTextData(70025)) -- 不可求助
    return false
end

function CTask:DoIntKeyDictLoad(sKey)
    local mDataSrc = self:GetData(sKey)
    if mDataSrc then
        local mDest = {}
        for k, v in pairs(mDataSrc) do
            mDest[tonumber(k)] = v
        end
        self:SetData(sKey, mDest)
    end
end

function CTask:Load(mData)
    super(CTask).Load(self, mData)
    self:DoIntKeyDictLoad("yibao_done_rec")
    self:DoIntKeyDictLoad("yibao_helper")
    self:DoIntKeyDictLoad("yibao_help_seeked_gather")
end

function CTask:RefreshRewardPreview()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    local iRewardId = self:GetRewardId()
    if iRewardId then
        -- local mEnv = self:GetRewardEnv(oPlayer)
        -- local mAddition = self:GetRewardAddition(oPlayer)
        -- if type(mAddition) == "table" then
        --     table_combine(mEnv, mAddition)
        -- end
        -- self.m_tmp_mReward = global.oRewardMgr:PreviewRewardByGroup(oPlayer, self.m_sName, iRewardId, mEnv)
        local mRewardPreview = self:PreviewReward(oPlayer, iRewardId)
        if mRewardPreview then
            self.m_tmp_mReward = mRewardPreview
            self.m_tmp_mRewardPreviewData = {
                items = self:PackRewardPreviewInfo(mRewardPreview.items),
                value = self:PackRewardPreviewInfo(mRewardPreview.value),
            }
        else
            self.m_tmp_mReward = nil
            self.m_tmp_mRewardPreviewData = nil
        end
    end
end

function CTask:Setup()
    super(CTask).Setup(self)
    self:RefreshRewardPreview()
end

function CTask:Refresh(mRefreshKeys)
    if not super(CTask).Refresh(self, mRefreshKeys) then
        return false
    end
    -- TODO 需要减少重新preview的频率
    self:RefreshRewardPreview()
    -- TODO 这些逻辑可以转移到ext_apply_info中
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        local mNet = {yibao_info = self:PackYibaoInfo()}
        oPlayer:Send("GS2CYibaoTaskRefresh", mNet)
    end
    return true
end

function CTask:GetCreateMorningDay()
    return get_morningdayno(self.m_iCreateTime)
end

function CTask:GetYibaoKind()
    local mData = self:GetTaskData()
    return mData.yibao_kind
end

function CTask:PackRewardPreviewInfo(mInfo)
    if not mInfo or not next(mInfo) then
        return nil
    end
    local mList = {}
    for iSid, iAmount in pairs(mInfo) do
        table.insert(mList, {sid = iSid, amount = iAmount})
    end
    return mList
end

function CTask:PackYibaoInfo(bSimple)
    local mNet = {
        taskid = self:GetId(),
        name = self:Name(),
        yibao_kind = self:GetYibaoKind(),
    }
    if not bSimple then
        -- 奖励预览，货币定义id映射，前端模块处理
        local mRewardPreview = self.m_tmp_mRewardPreviewData
        if mRewardPreview then
            mNet.valuereward_preview = mRewardPreview.value
            mNet.itemreward_preview = mRewardPreview.items
        end
    end
    return mNet
end

local CULTIVATE_ITEM_SID = 10007
local CULTIVATE_ITEM_REWARDIDX = 9999

function CTask:CanDoByRewardPreview(pid, sCbFunc, fArgGetter)
    -- 取消修炼经验满了不让交付的设定了
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return false
    end
    local iCultivateExp = table_get_depth(self, {"m_tmp_mReward", "value", CULTIVATE_EXP})
    if iCultivateExp and iCultivateExp > 0 then
        if not oPlayer.m_oSkillCtrl:CanAddCurrCulSkillExp(iCultivateExp) then
            if oPlayer.m_oSkillCtrl:CanAnyCulSkillAddExp(iCultivateExp) then
                local mNet = self:GetTextData(70028)
                global.oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
                    OnCurrCulSkillExpCannotAdd(oPlayer, mData)
                end)
                return false
            end
            local mNet
            if self:GetOwner() == pid then
                if oPlayer:GetTemp("yibao_culti_exp_overflow_confirm") then
                    return true
                end
                mNet = self:GetTextData(70024)
                mNet.sContent = global.oToolMgr:FormatColorString(mNet.sContent, {item = global.oItemLoader:GetItemData(CULTIVATE_ITEM_SID).name})
            else
                mNet = self:GetTextData(70029)
            end
            local fSelfGetter = self:GetCbSelfGetter()
            global.oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
                OnAllCulSkillExpCannotAdd(oPlayer, mData, fSelfGetter, sCbFunc, fArgGetter)
            end)
            return false
        end
    end
    return true
end

function OnCurrCulSkillExpCannotAdd(oPlayer, mData)
    if mData.answer == 1 then
        oPlayer:Send("GS2COpenCultivateUI", {})
    end
end

function OnAllCulSkillExpCannotAdd(oPlayer, mData, fSelfGetter, sCbFunc, fArgGetter)
    if mData.answer == 1 then
        oPlayer:SetTemp("yibao_culti_exp_overflow_confirm", true)
        local oTask = fSelfGetter()
        if not oTask then
            return
        end
        if fArgGetter then
            oTask[sCbFunc](oTask, oPlayer:GetPid(), fArgGetter())
        else
            oTask[sCbFunc](oTask, oPlayer:GetPid())
        end
    end
end

function CTask:IsMainTask()
    return false
end

function CTask:SendRewardContent(oPlayer, mRewardContent, mArgs)
    local pid = oPlayer:GetPid()
    local iCultivateExp = mRewardContent.cultivateexp

    if iCultivateExp and iCultivateExp > 0 and not oPlayer.m_oSkillCtrl:CanAddCurrCulSkillExp(iCultivateExp) then
        -- 折算成修炼经验丹
        mRewardContent.cultivateexp = nil
        local oMainTask
        if pid == self:GetOwner() then
            if self:IsMainTask() then
                oMainTask = self
            else
                oMainTask = global.oYibaoMgr:GetMainTask(oPlayer)
            end
        end
        local iOverflowCultivateExp = iCultivateExp
        if not oMainTask then
            -- record.warning("yibao reward without maintask, pid:%d, taskid:%d, cultivateexp:%d", pid, self:GetId(), iCultivateExp)
        else
            iOverflowCultivateExp = iOverflowCultivateExp + oMainTask:GetData("overflow_culti_exp", 0)
        end
        local EXP_PER_ITEM = 300
        local iItemCnt = iOverflowCultivateExp // EXP_PER_ITEM
        if oMainTask then
            oMainTask:SetData("overflow_culti_exp", iOverflowCultivateExp % EXP_PER_ITEM)
        end
        if iItemCnt > 0 then
            -- 要求策划填写一个特殊的项CULTIVATE_ITEM_REWARDIDX，仅此处拼接发奖
            local mVItemArgs = {
                argenv = {
                    add_amount = iItemCnt,
                }
            }
            local mItems = self:InitRewardItem(oPlayer, CULTIVATE_ITEM_REWARDIDX, mVItemArgs)
            if not mRewardContent.items then
                mRewardContent.items = {}
            end
            mRewardContent.items[CULTIVATE_ITEM_REWARDIDX] = mItems
        end
    end
    super(CTask).SendRewardContent(self, oPlayer, mRewardContent, mArgs)
end

function CTask:TrueDoNpcEvent(pid, npcid)
    return super(CTask).DoNpcEvent(self, pid, npcid)
end

function CTask:DoNpcEvent(pid, npcid)
    if not self:CanDoByRewardPreview(pid, "TrueDoNpcEvent", function() return npcid end) then
        return true
    end
    return self:TrueDoNpcEvent(pid, npcid)
end

function CTask:OnLogin(oPlayer, bReEnter)
    if is_ks_server() then return false end

    local bAlive = super(CTask).OnLogin(self, oPlayer, bReEnter)
    if not bAlive then
        return bAlive
    end
    self:RefreshRewardPreview()
    self:TouchIsHelpSeeked()
    return true
end

function CTask:TouchIsHelpSeeked()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    self.m_bIsHelpSeeked = global.oYibaoMgr:IsGatherHelpSeeked(oPlayer, self:GetId())
end

function CTask:Reward(pid, iRewardId, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    if oRewardMonitor then
        if mArgs and mArgs.rob_reward_type then
            if not oRewardMonitor:CheckRewardGroup(pid, self.m_sName, mArgs.rob_reward_type, 1, mArgs) then
                return
            end
        else
            if not oRewardMonitor:CheckRewardGroup(pid, self.m_sName, "self_submit", 1, mArgs) then
                return
            end
        end
    end
    return super(CTask).Reward(self, pid, iRewardId, mArgs)
end

function CTask:GetHelpers()
    return self:GetData("yibao_helper")
end

function CTask:RecHelper(oHelper)
    local mHelpers = self:GetData("yibao_helper", {})
    mHelpers[oHelper:GetPid()] = oHelper:GetName()
    self:SetData("yibao_helper", mHelpers)
end

function CTask:CanHelpYibao(oHelper)
    local mHelpers = self:GetHelpers()
    if mHelpers then
        local iHelperPid = oHelper:GetPid()
        if mHelpers and mHelpers[iHelperPid] then
            global.oNotifyMgr:Notify(iHelperPid, self:GetTextData(70022)) -- 这个任务你已经协助过了
            return false
        end
    end
    return true
end

function CTask:Abandon()
    -- 不可放弃
    return
end

function CTask:Commit(npcobj, mArgs)
    return
end

function CTask:GetRewardId()
    local iRewardId
    local iRandGroupId = self:GetData("rand_group_id")
    if iRandGroupId then
        iRewardId = table_get_depth(res, {"daobiao", "yibao_config", "seekitem_group_data", iRandGroupId, "reward_id"})
        if not iRewardId then
            iRewardId = table_get_depth(res, {"daobiao", "yibao_config", "seekitem_group_old_ver", iRandGroupId, "reward_id"})
        end
        return iRewardId
    end
    -- local iRewardId = self:GetData("reward_id")
    -- if iRewardId then
    --     return iRewardId
    -- end
    local mData = self:GetTaskData()
    for _,s in pairs(mData["submitRewardStr"] or {}) do
        iRewardId = tonumber(string.match(s, 'R(%d+)'))
        if iRewardId then
            return iRewardId
        end
    end
    return nil
end

function CTask:GetHelpRewardType()
end

function CTask:RewardHelp(oHelper)
    -- 完成任务奖励表
    local iRewardId = self:GetRewardId()
    if not iRewardId then
        return
    end
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    if oRewardMonitor then
        local sRewardType = self:GetHelpRewardType()
        if sRewardType and not oRewardMonitor:CheckRewardGroup(oHelper:GetPid(), self.m_sName, sRewardType, 1, {}) then
            return
        end
    end
    local mRewardInfo = self:GetRewardData(iRewardId)
    self:GiveHelperReward(oHelper, mRewardInfo, iRewardId)
end

function CTask:GiveHelperReward(oPlayer, mRewardInfo, iRewardId)
    -- 读奖励表奖励
    local sHelpOrgOffer = mRewardInfo.help_org_offer
    local iHelpOrgOffer = 0
    if self:IsRewardValueValid(sHelpOrgOffer) then
        iHelpOrgOffer = self:InitRewardOrgOffer(oPlayer, sHelpOrgOffer)
        self:RewardOrgOffer(oPlayer, iHelpOrgOffer)
    end
    local sHelpExp = mRewardInfo.help_exp
    local iHelpExp = 0
    if self:IsRewardValueValid(sHelpExp) then
        iHelpExp = self:InitRewardExp(oPlayer, sHelpExp)
        self:RewardExp(oPlayer, iHelpExp)
    end
    local mLogData = oPlayer:LogData()
    mLogData.owner = self:GetOwner()
    mLogData.taskid = self:GetId()
    mLogData.reward = {org_offer = iHelpOrgOffer, exp = iHelpExp}
    mLogData.rewardid = iRewardId
    record.user("task", "yibao_help", mLogData)
end

function CTask:GiveHelpYibao(oHelper)
end

-- 数据中心
function CTask:LogAnalyInfo(oPlayer)
    if not oPlayer then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["category"] = self:TaskType()

    local mRec = global.oYibaoMgr:GetYibaoDoneInfo(oPlayer) or {}
    mAnalyLog["turn_times"] = table_count(mRec)
    mAnalyLog["is_help"] = self.m_bIsHelpSeeked or false
    mAnalyLog["win_mark"] = ""
    local mReward = oPlayer:GetTemp("reward_content", {})
    mAnalyLog["reward_detail"] = analy.table_concat(mReward)
    mAnalyLog["consume_detail"] = analy.table_concat(self:NeedItem())
    analy.log_data("TreasureCollect", mAnalyLog)
end


------------------------------
CSubTask = {}
CSubTask.__index = CSubTask
inherit(CSubTask, CTask)

function CSubTask:OnMissionDone(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    global.oYibaoMgr:RecYibaoDoneInfo(oPlayer, self)

    -- 记录统计次数
    safe_call(self.RecordPlayerCnt, self, {[pid]=true})

    oPlayer.m_oTaskCtrl:FireYibaoDoneSub()
end

function CSubTask:AfterMissionDone(pid)
    super(CSubTask).AfterMissionDone(self, pid)
    local taskid = self:GetId()
    -- local iYibaoKind = GetTaskYibaoKind(taskid)
    -- if iYibaoKind == taskdefines.YIBAO_KIND.MAIN then
    --     return
    -- end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer:MarkGrow(26)
    local mNet = {
        taskid = taskid,
        is_gather_help = self.m_tmp_done_player and 1 or 0,
    }
    oPlayer:Send("GS2CYibaoTaskDone", mNet)

    global.oYibaoMgr:CheckYibaoFinish(oPlayer)
end

------------------------------
CMainTask = {}
CMainTask.__index = CMainTask
inherit(CMainTask, CTask)

function CMainTask:New(taskid)
    local o = super(CMainTask).New(self,taskid)
    return o
end

function CMainTask:IsMainTask()
    return true
end

function CMainTask:PackYibaoInfo()
    local mNet = super(CMainTask).PackYibaoInfo(self)
    mNet.name = nil
    return mNet
end

function CMainTask:AbleInWarClick()
    return true
end

function CMainTask:AbleTeamMemberClick(pid)
    return true
end

function CMainTask:Click(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    global.oYibaoMgr:ToOpenUI(oPlayer, oPlayer)
end

function CMainTask:RecYibaoDoneInfo(mData)
    local mRec = self:GetData("yibao_done_rec", {})
    mRec[mData.taskid] = mData
    self:SetData("yibao_done_rec", mRec)
end

function CMainTask:RecYibaoHelpSeekedGathers(iTaskid)
    local mSeekedGather = self:GetData("yibao_help_seeked_gather", {})
    mSeekedGather[iTaskid] = true
    self:SetData("yibao_help_seeked_gather", mSeekedGather)
end

function CMainTask:GetYibaoHelpSeekedGathers()
    return self:GetData("yibao_help_seeked_gather")
end

function CMainTask:GetYibaoDoneRec()
    return self:GetData("yibao_done_rec")
end

function CMainTask:RewardYibaoMain()
    -- 领奖后完成删除任务，执行奖励逻辑，发异宝总奖励
    self:MissionDone()
end

function CMainTask:AfterMissionDone(pid)
    super(CMainTask).AfterMissionDone(self, pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer.m_oScheduleCtrl:AddByName("yibao")
    end
end

------------------------------
CExploreTask = {}
CExploreTask.__index = CExploreTask
inherit(CExploreTask, CSubTask)

function CExploreTask:New(taskid)
    local o = super(CExploreTask).New(self,taskid)
    return o
end

function CExploreTask:Setup()
    super(CExploreTask).Setup(self)
    if not self:GetData("name_idx") then
        self:SetNameIdx()
    end
end

function CExploreTask:SubConfig(pid)
    self:SetStar(math.random(1, 4))
end

function CExploreTask:GetStarBaseInfo()
    local mData = table_get_depth(res, {"daobiao", "yibao_config", "star_info"})
    return mData
end

function CExploreTask:SetNameIdx()
    local iStar = self:GetStar()
    local mNameList = self:GetStarBaseInfo()[iStar]["name"]
    local iNameIdx = math.random(1, #mNameList)
    self:SetData("name_idx", iNameIdx)
end

function CExploreTask:GetNameIdx()
    return self:GetData("name_idx", 1)
end

function CExploreTask:GetStar()
    return self:GetData("star", 0)
end

function CExploreTask:SetStar(iStar)
    return self:SetData("star", iStar)
end

function CExploreTask:AddStar()
    return self:SetData("star", self:GetStar() + 1)
end

function CExploreTask:Name()
    return global.oYibaoMgr:GetExploreName(self:GetStar(), self:GetNameIdx())
end

function CExploreTask:GiveHelpYibao(oHelper)
    if not self:CanHelpYibao(oHelper) then
        return
    end
    -- 确认扣钱
    if not oHelper:Query("yibao_help_explore_confirmed") then
        -- 弹窗并永久记录不再弹
        local iTargetPid = self:GetOwner()
        local oTargetPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
        assert(oTargetPlayer, "GiveHelpYibao target offline")
        local taskid = self:GetId()
        local iCreateDay = self:GetCreateMorningDay()
        local iCostSilver = self:GetHelpSilverCost()
        local mNet = self:GetTextData(70002)
        mNet.sContent = global.oToolMgr:FormatColorString(mNet.sContent, {silver = iCostSilver, role = oTargetPlayer:GetName()})
        global.oCbMgr:SetCallBack(oHelper:GetPid(), "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
            local oTask = global.oYibaoMgr:GetValidSubTask(oPlayer, iTargetPid, taskid, iCreateDay)
            if oTask then
                oTask:OnConfirmHelpYibaoWithSilver(oPlayer, mData)
            end
        end)
        return
    end
    self:HelpYibaoWithSilver(oHelper)
end

function CExploreTask:OnConfirmHelpYibaoWithSilver(oPlayer, mData)
    if mData.answer ~= 1 then
        return
    end
    oPlayer:Set("yibao_help_explore_confirmed", true)
    self:HelpYibaoWithSilver(oPlayer)
end

function CExploreTask:GetHelpSilverCost()
    local iStar = self:GetStar()
    return table_get_depth(self:GetStarBaseInfo(), {iStar, "cost_silver"})
end

function CExploreTask:GetHelpSuccRatio()
    local iStar = self:GetStar()
    return table_get_depth(self:GetStarBaseInfo(), {iStar, "succ_ratio"})
end

function CExploreTask:CanYibaoStarUp(oHelper)
    -- 满星级提醒
    if self:GetStar() >= taskdefines.YIBAO_INFO.MAX_EXPLORE_STAR then
        global.oNotifyMgr:Notify(oHelper:GetPid(), self:GetTextData(70023)) -- 已被其他玩家提升到5星
        return false
    end
    return true
end

function CExploreTask:CanHelpYibao(oHelper)
    local oNotifyMgr = global.oNotifyMgr
    if not self:CanYibaoStarUp(oHelper) then
        return false
    end
    if not super(CExploreTask).CanHelpYibao(self, oHelper) then
        return false
    end
    -- 5次检查
    if taskdefines.YIBAO_INFO.MAX_HELP_EXPLORE_TIMES <= oHelper.m_oTodayMorning:Query("yibao_help_explore_times", 0) then
        oNotifyMgr:Notify(oHelper:GetPid(), self:GetTextData(70019)) -- 协助次数达上限
        return false
    end
    -- 扣钱余额检查
    local iCostSilver = self:GetHelpSilverCost()
    if iCostSilver > 0 then
        if not oHelper:ValidMoneyByType(gamedefines.MONEY_TYPE.SILVER, iCostSilver, {tip = self:GetTextData(70008)}) then
            return false
        end
    end
    return true
end

function CExploreTask:HelpYibaoWithSilver(oHelper)
    if not self:CanHelpYibao(oHelper) then
        return
    end
    -- 扣钱
    local iCostSilver = self:GetHelpSilverCost()
    if iCostSilver > 0 then
        oHelper:ResumeMoneyByType(gamedefines.MONEY_TYPE.SILVER, iCostSilver, "异宝探险协助")
        local mLogData = oHelper:LogData()
        mLogData.silver = iCostSilver
        record.user("task", "yibao_help_cost", mLogData)
    end
    self:DealHelpYibao(oHelper)
end

function CExploreTask:GetHelpRewardType()
    return "help_explore"
end

function CExploreTask:DealHelpYibao(oHelper)
    local iTargetPid = self:GetOwner()
    local oTargetPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    assert(oTargetPlayer, "Deal yibao explore task player offline")
    -- 次数记录
    self:RecHelper(oHelper)
    oHelper.m_oTodayMorning:Add("yibao_help_explore_times", 1)
    -- 协助奖
    self:RewardHelp(oHelper)
    local iHelperPid = oHelper:GetPid()
    -- 概率判断并设置star
    if math.random(1, 100) <= self:GetHelpSuccRatio() then
        self:AddStar()
        self:Refresh()
        -- 发言
        if iHelperPid ~= iTargetPid then
            local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70005), {
                role = oHelper:GetName(),
                star = self:GetStar(),
                scene = self:TransStringFuncSubmitScene(iTargetPid),
            })
            if not self:IsFullStar() then
                sMsg = sMsg .. string.format("{link17,%d,%d,%d}", iTargetPid, self:GetId(), self:GetCreateMorningDay())
            end
            -- global.oChatMgr:HandleOrgChat(oTargetPlayer, sMsg, true)
            global.oChatMgr:SendMsg2Org(sMsg, oTargetPlayer:GetOrgID(), oTargetPlayer)
        end
    else
        -- 发言
        if iHelperPid ~= iTargetPid then
            local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70006), {
                role = oTargetPlayer:GetName(),
            })
            -- global.oChatMgr:HandleOrgChat(oHelper, sMsg, true)
            global.oChatMgr:SendMsg2Org(sMsg, oHelper:GetOrgID(), oHelper)
        end
    end
end

function CExploreTask:SeekHelpYibao(oPlayer)
    if not self:CanYibaoStarUp(oPlayer) then
        return false
    end
    local iNow = get_time()
    local iLast = self:GetData("help_seeked_times")
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    if iLast and iNow - iLast < 60 then
        oNotifyMgr:Notify(iPid, self:GetTextData(70007))
        return
    end
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID == 0 then
        oPlayer:Send("GS2COpenOrgUI", {})
        return
    end
    self:SetData("help_seeked_times", iNow)
    local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70003), {
        role = oPlayer:GetName(),
        star = self:GetStar(),
        scene = self:TransStringFuncSubmitScene(iPid),
    })
    sMsg = sMsg .. string.format("{link17,%d,%d,%d}", iPid, self:GetId(), self:GetCreateMorningDay())
    local oChatMgr = global.oChatMgr
    -- oChatMgr:HandleOrgChat(oPlayer, sMsg, true)
    global.oChatMgr:SendMsg2Org(sMsg, iOrgID, oPlayer)
    oPlayer:Send("GS2CYibaoSeekHelpSucc", {taskid = self:GetId()})
end

function CExploreTask:TrueClick(pid)
    super(CExploreTask).Click(self, pid)
end

function CExploreTask:DoClickTask(pid)
    if not self:CanDoByRewardPreview(pid, "TrueClick") then
        return
    end
    self:TrueClick(pid)
end

function CExploreTask:IsFullStar()
    return self:GetStar() >= taskdefines.YIBAO_INFO.MAX_EXPLORE_STAR
end

function CExploreTask:Click(pid)
    -- 若重新启用代码，修复闭包的热更问题
    -- if not self:IsFullStar() then
    --     local taskid = self:GetId()
    --     local iCreateDay = self:GetCreateMorningDay()
    --     local mNet = self:GetTextData(70001)
    --     global.oCbMgr:SetCallBack(pid, "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
    --         if mData.answer ~= 1 then
    --             return
    --         end
    --         local oTask = global.oYibaoMgr:GetValidSubTask(oPlayer, oPlayer:GetPid(), taskid, iCreateDay)
    --         if oTask then
    --             oTask:DoClickTask(pid)
    --         end
    --     end)
    --     return
    -- end
    self:DoClickTask(pid)
end

function CExploreTask:GetRewardAddition(oAwardee)
    return {
        star = self:GetStar(),
    }
end

-- function CExploreTask:PackTaskRefreshInfo()
--     local mNet = super(CExploreTask).PackTaskRefreshInfo(self)
--     local mExt = mNet.ext_apply_info or {}
--     table.insert(mExt, {key = "star", value = self:GetStar()})
--     mNet.ext_apply_info = mExt
--     return mNet
-- end

-- function CExploreTask:PackTaskInfo()
--     local mNet = super(CExploreTask).PackTaskInfo(self)
--     local mExt = mNet.ext_apply_info or {}
--     table.insert(mExt, {key = "star", value = self:GetStar()})
--     mNet.ext_apply_info = mExt
--     return mNet
-- end

function CExploreTask:PackYibaoInfo()
    local mNet = super(CExploreTask).PackYibaoInfo(self)
    mNet.star = self:GetStar()
    return mNet
end

function CExploreTask:TryRewardShare(mHelpers, iRewardId, lItems, sItemNames, mArgs)
    -- local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    -- 道具clone发邮件给helpers
    for iHelperPid, sPlayerName in pairs(mHelpers) do
        -- if oRewardMonitor then
        --     if not oRewardMonitor:CheckShareRewardGroup(iHelperPid, self.m_sName, "share", 1, mArgs) then
        --         goto continue
        --     end
        -- end
        local lNewItems = extend.Table.filtermap(lItems, function(_, oItem)
            return global.oItemLoader:CloneItem(oItem, iHelperPid)
        end)
        self:HelperShareItems(pid, iHelperPid, sPlayerName, lNewItems, sItemNames)
        ::continue::
    end
end

function CExploreTask:Reward(pid, iRewardId, mArgs)
    -- super(CExploreTask).Reward(self, pid, iRewardId, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mRewardContent = super(CExploreTask).Reward(self, pid, iRewardId, mArgs)
    if not mRewardItems then
        return
    end

    local mRewardItems = mRewardContent.items
    if not mRewardItems or not next(mRewardItems) then
        return mRewardContent
    end
    local mHelpers = self:GetHelpers()
    if not mHelpers or not next(mHelpers) then
        return mRewardContent
    end
    local lItems = self:ArrangeRewardItems(mRewardItems)
    local lItemNames = self:GetItemNames(lItems)
    local sItemNames = table.concat(lItemNames, "、")
    local sHelperNames = table.concat(table_value_list(mHelpers), "、")
    self:TryRewardShare(mHelpers, iRewardId, lItems, sItemNames, mArgs)
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID > 0 then
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70011), {
            role = oPlayer:GetName(),
            helper = sHelperNames,
            item = sItemNames,
        })
        -- global.oChatMgr:HandleOrgChat(oPlayer, sMsg, true)
        global.oChatMgr:SendMsg2Org(sMsg, iOrgID, nil) -- 系统传闻
    end
    return mRewardContent
end

function CExploreTask:HelperShareItems(pid, iHelperPid, sPlayerName, lItems, sItemNames)
    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(taskdefines.YIBAO_INFO.HELP_EXPLORE_REWARD_MAIL)
    if not mData then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        sPlayerName = oPlayer:GetName()
    elseif not sPlayerName then
        sPlayerName = ""
    end
    local mLogData = {
        pid = iHelperPid,
        items = self:GetSimpleItemsInfo(lItems),
        record.user("task", "yibao_help_share_reward", mLogData)
    }
    mData.context = global.oToolMgr:FormatColorString(mData.context, {
        role = sPlayerName,
        item = sItemNames,
    })
    oMailMgr:SendMail(0, name, iHelperPid, mData, 0, lItems)
end

function CExploreTask:GetItemNames(lItemList)
    local fItemName = function(_, oItem)
        return oItem:Name()
    end
    return extend.Table.filtermap(lItemList, fItemName)
end

function CExploreTask:ArrangeRewardItems(mRewardItems)
    local lItems = {}
    for itemidx, mItems in pairs(mRewardItems) do
        lItems = list_combine(lItems, mItems["items"])
    end
    return lItems
end

function CExploreTask:MonsterCreateExt(oWar, iMonsterIdx, oNpc)
    local iOwner = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    local result = {}
    if oPlayer and oNpc then
        local iStar = self:GetStar()
        if iStar <= 0 then iStar = 1 end
        result = {
            env = {star = iStar}
        }
    end
    return result
end

------------------------------
CGatherTask = {}
CGatherTask.__index = CGatherTask
inherit(CGatherTask, CSubTask)

function CGatherTask:New(taskid)
    local o = super(CGatherTask).New(self,taskid)
    return o
end

function CGatherTask:Name()
    -- return super(CGatherTask).Name(self) .. self:TransStringFuncItem(self:GetOwner())
    return self:GetTaskItemName(self:GetOwner())
end

function CGatherTask:RandOutGroup(iYibaoLv)
    local mRatio = table_get_depth(res, {"daobiao", "yibao_config", "seekitem_group_ratio", iYibaoLv})
    local iRandGroupId = table_choose_key(mRatio)
    return iRandGroupId
end

function CGatherTask:SubConfig(pid, mArgs)
    assert(mArgs)
    local iYibaoLv = mArgs.yibao_lv
    assert(iYibaoLv, string.format("yibao_lv null, pid:%d, taskid:%d", pid, self:GetId()))
    local iRandGroupId = self:RandOutGroup(iYibaoLv)
    assert(iRandGroupId, string.format("yibao gather randgroupid null, pid:%d, taskid:%d", pid, self:GetId()))
    local mRandGroupInfo = table_get_depth(res, {"daobiao", "yibao_config", "seekitem_group_data", iRandGroupId})
    assert(mRandGroupInfo , string.format("yibao gather randgroup null, pid:%d, taskid:%d, randgroup:%d", pid, self:GetId(), iRandGroupId))
    local iItemGroup = mRandGroupInfo.itemgroup
    assert(iItemGroup and iItemGroup > 0, string.format("yibao gather itemgroup null, pid:%d, taskid:%d, randgroup:%d", pid, self:GetId(), iRandGroupId))
    local iAmount = mRandGroupInfo.itemamount
    assert(iAmount and iAmount > 0, string.format("yibao gather item_amount null, pid:%d, taskid:%d, randgroup:%d", pid, self:GetId(), iRandGroupId))
    self:SetNeedItem(iItemGroup, iAmount)
    self:SetData("rand_group_id", iRandGroupId)
end

function CGatherTask:ValidSubmitUnderControl(pid)
    if self:ValidTakeItem(pid) then
        local npctype = self:Target()
        if not npctype or npctype == 0 then
            return true
        end
    end
end

function CGatherTask:AbleTeamMemberClick(pid)
    return true
end

function CGatherTask:AbleInWarClick(pid)
    local bFlag = self:ValidSubmitUnderControl(pid)
    if not bFlag then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            for sid,iAmount in pairs(self.m_mNeedItem) do
                for _, oItem in ipairs(oPlayer.m_oItemCtrl:GetShapeItem(sid)) do
                    if oItem:IsLocked() then
                        local sMsg = self:GetTextData(1105)
                        sMsg = global.oToolMgr:FormatColorString(sMsg, {item = oItem:Name()})
                        oPlayer:NotifyMessage(sMsg)
                        return bFlag
                    end
                end
            end
        end
    end
    return bFlag
end

-- 直接上交
function CGatherTask:Click(pid)
    local npctype
    if not self:ValidTakeItem(pid) then
        -- 出售商店npc
        npctype = self:GetNeedItemShopNpc()
    else
        npctype = self:Target()
        if not npctype or npctype == 0 then
            self:PopTakeItemUI(pid)
            return
        end
    end
    if npctype then
        self:AutoFindNpcPath(pid, npctype)
    end
end

function CGatherTask:SeekHelpYibao(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local iTaskid = self:GetId()
    local iPid = oPlayer:GetPid()
    if not global.oYibaoMgr:CanSeekGatherHelp(oPlayer, iTaskid) then
        oNotifyMgr:Notify(iPid, self:GetTextData(70009))
        return
    end
    local iNow = get_time()
    local iLast = self:GetData("help_seeked_times")
    if iLast and iNow - iLast < 60 then
        oNotifyMgr:Notify(iPid, self:GetTextData(70007))
        return
    end
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID == 0 then
        oPlayer:Send("GS2COpenOrgUI", {})
        return
    end
    self:SetData("help_seeked_times", iNow)
    global.oYibaoMgr:RecGatherHelpSeeked(oPlayer, iTaskid)
    local iNeedItemSid = self:GetNeedItemSid()
    local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70004), {
        role = oPlayer:GetName(),
        item = global.oItemLoader:GetItemNameBySid(iNeedItemSid),
    })
    sMsg = sMsg .. string.format("{link18,%d,%d,%d}", iPid, iTaskid, self:GetCreateMorningDay())
    local oChatMgr = global.oChatMgr
    -- oChatMgr:HandleOrgChat(oPlayer, sMsg, true)
    global.oChatMgr:SendMsg2Org(sMsg, iOrgID, oPlayer)
    oPlayer:Send("GS2CYibaoSeekHelpSucc", {taskid = self:GetId()})
end

function CGatherTask:GiveHelpYibao(oHelper)
    if not global.oToolMgr:IsSysOpen("XIU_LIAN_SYS", oHelper, true) then
        global.oNotifyMgr:Notify(oHelper:GetPid(), self:GetTextData(70027))
        return
    end
    local iOwner = self:GetOwner()
    local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if not self:CanHelpYibao(oHelper) then
        return
    end
    global.oYibaoMgr:ToOpenUI(oHelper, oOwner)
end

function CGatherTask:HelpSubmitYibao(oHelper)
    if not self:CanHelpYibao(oHelper) then
        return
    end
    if not self:HasYibaoNeetItem(oHelper) then
        return
    end
    -- 交付UI
    self:PopTakeItemUI(oHelper:GetPid())
end

function CGatherTask:GetRewardEnv(oAwardee)
    local mEnv = super(CGatherTask).GetRewardEnv(self, oAwardee)
    mEnv.stallprice = self:GetNeedItemStallPrice()
    return mEnv
end

function CGatherTask:GetNeedItemStallPrice()
    local iNeedItemSid = self:GetNeedItemSid()
    if not iNeedItemSid then
        return 0
    end
    local iQuality = 20 -- 固定查询品质20的数据
    local oTempItem = global.oItemLoader:GetItem(iNeedItemSid)
    if not oTempItem then
        return 0
    end
    if oTempItem:ItemType() ~= "pellet" then
        iQuality = 1
    end
    local iStallQueryIdx = stalldefines.EncodeSid(iNeedItemSid, iQuality)
    local oPriceMgr = global.oStallMgr.m_oPriceMgr
    local iStallPrice = oPriceMgr:GetLastPrice(iStallQueryIdx)
    return iStallPrice
end

function CGatherTask:GetNeedItemSid()
    for itemsid,iAmount in pairs(self.m_mNeedItem) do
        return itemsid
    end
    return nil
end

function CGatherTask:DoPopTakeItemUI(pid, npcid)
    if pid == self:GetOwner() then
        local npcobj = global.oNpcMgr:GetObject(npcid)
        super(CGatherTask).PopTakeItemUI(self, pid, npcobj)
        return
    end
    local taskid = self:GetId()
    local iOwner = self:GetOwner()
    local iCreateDay = self:GetCreateMorningDay()
    local mNet = {taskid = taskid, owner = iOwner}
    local cbFunc = function (oPlayer,mData)
        local oTask = global.oYibaoMgr:GetValidSubTask(oPlayer, iOwner, taskid, iCreateDay)
        if not oTask then
            return
        end
        oTask:OnHelpTakeItemUICallback(oPlayer, mData)
    end
    local oCbMgr = global.oCbMgr
    oCbMgr:SetCallBack(pid,"GS2CPopTaskItem",mNet,nil,cbFunc)
end

function CGatherTask:PopTakeItemUI(pid, npcobj)
    local npcid
    if npcobj then
        npcid = npcobj:ID()
    end
    if not self:CanDoByRewardPreview(pid, "DoPopTakeItemUI", function() return npcid end) then
        return
    end
    self:DoPopTakeItemUI(pid, npcid)
end

function CGatherTask:GetHelpRewardType()
    return "help_gather"
end

function CGatherTask:OnHelpTakeItemUICallback(oPlayer, mData)
    -- if oPlayer:GetPid() == self:GetOwner() then
    --     super(CGatherTask).OnTakeItemUICallback(self, oPlayer, mData)
    --     return
    -- end
    if not self:CanHelpYibao(oPlayer) then
        return
    end
    if not self:DoSubmitItem(oPlayer, mData) then
        return
    end
    -- 次数记录
    oPlayer.m_oTodayMorning:Add("yibao_help_gather_times", 1)
    -- 协助奖
    self:RewardHelp(oPlayer)
    -- 任务完成
    self.m_tmp_done_player = oPlayer:GetPid()

    self:MissionDone()

    self:SendHelpOrgMsg(oPlayer:GetPid())
end

function CGatherTask:SendHelpOrgMsg(iHelpPid)
    local oHelper = global.oWorldMgr:GetOnlinePlayerByPid(iHelpPid)
    local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oHelper or not oOwner then return end

    local iNeedItemSid = self:GetNeedItemSid()
    local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70030), {
        player = oHelper:GetName(),
        role = oOwner:GetName(),
        item = self:GetItemName(iNeedItemSid),
    })
    local oChatMgr = global.oChatMgr
    global.oChatMgr:SendMsg2Org(sMsg, oHelper:GetOrgID())

    local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70031), {
        role = oHelper:GetName(),
        item = self:GetItemName(iNeedItemSid)
    })
    global.oNotifyMgr:Notify(self.m_Owner, sMsg)
end

function CGatherTask:GiveCompenReward(oPlayer, iRewardId)
    local mArgs = {}
    -- local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    -- if oRewardMonitor then
    --     if not oRewardMonitor:CheckRewardGroup(oPlayer:GetPid(), self.m_sName, "compen", 1, mArgs) then
    --         return
    --     end
    -- end
    local rewardinfo = self:GetRewardData(iRewardId)
    local sCompenExp = rewardinfo.compen_exp
    local iCompenExp = 0
    if self:IsRewardValueValid(sCompenExp) then
        iCompenExp = self:InitRewardExp(oPlayer, sCompenExp, mArgs)
        if iCompenExp > 0 then
            self:RewardExp(oPlayer, iCompenExp)
        end
    end
    local sCompenCultivateExp = rewardinfo.compen_cultivateexp
    local iCompenCultivateExp = 0
    if self:IsRewardValueValid(sCompenCultivateExp) then
        iCompenCultivateExp = self:InitRewardCultivateExp(oPlayer, sCompenCultivateExp, mArgs)
        if iCompenCultivateExp > 0 then
            self:RewardCultivateExp(oPlayer, iCompenCultivateExp)
        end
    end
    local mLogData = oPlayer:LogData()
    mLogData.taskid = self:GetId()
    mLogData.owner = self:GetOwner()
    mLogData.reward = {exp = iCompenExp, culti_exp = iCompenCultivateExp}
    mLogData.rewardid = iRewardId
    record.user("task", "yibao_compen_reward", mLogData)
end

function CGatherTask:RewardMissionDone(pid, npcobj, mArgs)
    local iRewardId = self:GetRewardId()
    if iRewardId then
        self:Reward(pid, iRewardId, mArgs)
    end
end

function CGatherTask:Reward(pid, iRewardId, mArgs)
    local iHelperPid = self.m_tmp_done_player
    if not iHelperPid then
        local mRewardContent = super(CGatherTask).Reward(self, pid, iRewardId, mArgs)
        return mRewardContent
    end
    -- 协助完成的角色抢走奖励并给owner补偿
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local oHelper = oWorldMgr:GetOnlinePlayerByPid(iHelperPid)
    assert(oPlayer, string.format("yibao reward gather with player offline, pid:%d,taskid:%d", pid, self:GetId()))
    assert(oHelper, string.format("yibao reward gather with helper offline, pid:%d,taskid:%d", iHelperPid, self:GetId()))
    iRewardId = tonumber(iRewardId)
    if not mArgs then
        mArgs = {}
    end
    mArgs.rob_reward_type = "rob_gather"
    local mRewardContent = super(CGatherTask).Reward(self, iHelperPid, iRewardId, mArgs)
    if mRewardContent then
        -- local mRewardContent = self:GenRewardContent(oHelper, rewardinfo, mArgs)
        -- self:SendRewardContent(oHelper, mRewardContent)
        local mLogData = oHelper:LogData()
        mLogData.owner = self:GetOwner()
        mLogData.taskid = self:GetId()
        local mContentCopy = self:SimplifyReward(oHelper, mRewardContent, mArgs)
        mContentCopy.compen_exp = nil
        mContentCopy.compen_cultivateexp = nil
        mLogData.reward = mContentCopy
        mLogData.rewardid = iRewardId
        record.user("task", "yibao_help_gather_rob_reward", mLogData)
    end
    if iRewardId then
        self:GiveCompenReward(oPlayer, iRewardId)
    end
    return mRewardContent
end

function CGatherTask:HasYibaoNeetItem(oHelper)
    local iHelperPid = oHelper:GetPid()
    local bPass, iLackSid = self:ValidTakeItem(iHelperPid)
    if not bPass then
        assert(iLackSid, "invalid take needitem, no item sid return")
        local sItemName = self:GetItemName(iLackSid)
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(70026), {item = sItemName})
        global.oNotifyMgr:Notify(iHelperPid, sMsg) -- 没有指定物品
        return false
    end
    return true
end

function CGatherTask:HasHelpTimes(oHelper)
    -- 10次检查
    if taskdefines.YIBAO_INFO.MAX_HELP_GATHER_TIMES <= oHelper.m_oTodayMorning:Query("yibao_help_gather_times", 0) then
        global.oNotifyMgr:Notify(oHelper:GetPid(), self:GetTextData(70019)) -- 协助次数达上限
        return false
    end
    return true
end

function CGatherTask:CanHelpYibao(oHelper)
    if not super(CGatherTask).CanHelpYibao(self, oHelper) then
        return false
    end
    local iPid = oHelper:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    if iPid == self:GetOwner() then
        oNotifyMgr:Notify(iPid, self:GetTextData(70020)) -- 不能协助自己
        return false
    end
    local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    assert(oOwner, "yibao gather task player offline")
    if not global.oYibaoMgr:IsGatherHelpSeeked(oOwner, self:GetId()) then
        oNotifyMgr:Notify(iPid, self:GetTextData(70021)) -- 此任务未被求助
        return false
    end
    if not self:HasHelpTimes(oHelper) then
        return false
    end
    return true
end

function CGatherTask:PackYibaoInfo()
    local mNet = super(CGatherTask).PackYibaoInfo(self)
    mNet.needitem = self:PackNeedItem()
    -- needitemgroup = self:PackNeedItemGroup(),
    -- needsum = self:PackNeedSummon(),
    return mNet
end

------------------------------
CQteTask = {}
CQteTask.__index = CQteTask
inherit(CQteTask, CSubTask)

function CQteTask:New(taskid)
    local o = super(CQteTask).New(self,taskid)
    return o
end

function CQteTask:OnLogin()
    if self:GetData("yibao_qte_id") then
        self:MissionDone()
        return false
    end
    return super(CQteTask).OnLogin(self)
end

function CQteTask:DoShowQte(pid, npcid, iQteId)
    self:Dirty()
    self:SetData("yibao_qte_id", iQteId)
    local iCreateDay = self:GetCreateMorningDay()
    local taskid = self:GetId()
    local mQteData = self:GetQteData(iQteId)
    assert(mQteData, string.format("qte task do qteid no data, taskid:%d, qteId:%s", taskid, iQteId))
    local fCallBack = function(oPlayer, mData)
        local oTask = global.oYibaoMgr:GetValidSubTask(oPlayer, pid, taskid, iCreateDay)
        if oTask then
            oTask:OnQteCallback(oPlayer, npcid, iQteId, mData)
        end
    end
    local mNet = {
        qteid = iQteId,
        -- lasts = iLasts, -- 若指令支持配置时间，填充非配置文件的时间
    }
    global.oCbMgr:SetCallBack(pid, "GS2CPlayQte", mNet, nil, fCallBack)
end

function CQteTask:DoQte(pid, npcobj, iQteId)
    local npcid = npcobj:ID()
    if not self:CanDoByRewardPreview(pid, "DoShowQte", function() return npcid, iQteId end) then
        return
    end
    self:DoShowQte(pid, npcid, iQteId)
end

function CQteTask:OnQteFailAnimeCallback(oPlayer, npcid, iQteId, mData)
    self:MissionDone()
end

function CQteTask:OnQteCallback(oPlayer, npcid, iQteId, mData)
    super(CQteTask).OnQteCallback(self, oPlayer, npcid, iQteId, mData)
    -- 回复的每个选项都是完成任务
    -- if iAnswer == 1 then
    -- else
    --     local mQteData = self:GetQteData(iQteId)
    --     assert(mQteData, string.format("qte task do qteid no data, taskid:%d, qteId:%s", taskid, iQteId))
    --     local iFailAnime = mQteData.fail_anime
    --     if iFailAnime then
    --         local taskid = self:GetId()
    --         local npcid = npcobj.m_ID
    --         local iCreateDay = self:GetCreateMorningDay()
    --         local fCallBack = function(oPlayer, mData)
    --             local oTask = global.oYibaoMgr:GetValidSubTask(oPlayer, pid, taskid, iCreateDay)
    --             if oTask then
    --                 oTask:OnQteFailAnimeCallback(oPlayer, npcid, iQteId, mData)
    --             end
    --         end
    --         local mNet = {
    --             anime_id = iFailAnime,
    --         }
    --         global.oCbMgr:SetCallBack(pid, "GS2CPlayAnime", mNet, nil, fCallBack)
    --     end
    -- end
end


-------------------
local mYibaoKindObjectBase = {
    [taskdefines.YIBAO_KIND.MAIN] = "CMainTask",
    [taskdefines.YIBAO_KIND.EXPLORE] = "CExploreTask",
    [taskdefines.YIBAO_KIND.FIND_ITEM] = "CGatherTask",
    [taskdefines.YIBAO_KIND.QTE] = "CQteTask",
}

function GetTaskClass(taskid)
    local iYibaoKind = GetTaskYibaoKind(taskid)
    local sClass = mYibaoKindObjectBase[iYibaoKind]
    return sClass
end

function NewTask(taskid)
    local sClass = GetTaskClass(taskid)
    assert(sClass, "yibao task nil class, taskid:" .. taskid)
    local cClass = _ENV[sClass]
    local o = cClass:New(taskid)
    return o
end

