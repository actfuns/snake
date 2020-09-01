local global = require "global"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"

local taskobj = import(service_path("task.taskobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "zhenmo"
CTask.m_sTempName = "镇魔塔"
CTask.m_sStatisticsName = "zhenmo"
inherit(CTask,taskobj.CTask)

function CTask:OtherScript(iPid, npcobj, s, mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if not sCmd then return end
    local sArgs = string.sub(s, #sCmd+1, -1)

    --最后一关，特殊处理
    if sCmd == "SPER" then
        if npcobj then
            mArgs.npc = npcobj:Name()
        end
        mArgs.is_special = true
        mArgs.refresh = 1
        self:Reward(iPid, sArgs, mArgs)
        return true
    elseif sCmd == "LAYERDONE" then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:LayerDone()
        end
    end
end

function CTask:SendRewardContent(oPlayer, mRewardContent, mArgs)
    local bItemReward = self:CheckItemReward(oPlayer)
    local bExpReward = self:CheckExpReward(oPlayer)

    --都已超过限制次数，不发奖励
    if not bItemReward and not bExpReward then 
        return
    end

    if mRewardContent["items"] then
        if bItemReward then
            self:RecordItemReward(oPlayer)
        else
            mRewardContent["items"] = nil --有物品奖励，但超限制了，剔除
        end
    end

    if bExpReward then
        self:RecordExpReward(oPlayer)
        oPlayer.m_oScheduleCtrl:HandleRetrieve(1040, 1)
    else
        --经验等奖励超限制，只保留物品奖励，没物品奖励的直接返回
        if not mRewardContent["items"] then
            return
        end
        local mNewContent = {
            mail_id = mRewardContent.mail_id,
            items = mRewardContent.items
        }
        mRewardContent = mNewContent
    end
    super(CTask).SendRewardContent(self, oPlayer, mRewardContent, mArgs)
end

function CTask:RecordItemReward(oPlayer)
    local mWeek = oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:GetWeek()
    local iWeekCnt = mWeek["zhenmo_item_cnt"] or 0
    mWeek["zhenmo_item_cnt"] = iWeekCnt + 1

    local iTaskId = self:GetId()
    local mWeekReward = mWeek["zhenmo_item_reward"] or {}
    mWeekReward[iTaskId] = true
    mWeek["zhenmo_item_reward"] = mWeekReward
end

function CTask:RecordExpReward(oPlayer)
    local mDay = oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:GetDay()
    local iDayCnt = mDay["zhenmo_exp_cnt"] or 0
    mDay["zhenmo_exp_cnt"] = iDayCnt + 1

    local iTaskId = self:GetId()
    local mDayReward = mDay["zhenmo_exp_reward"] or {}
    mDayReward[iTaskId] = true
    mDay["zhenmo_exp_reward"] = mDayReward
end

function CTask:CheckItemReward(oPlayer)
    local mWeek = oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:GetWeek()
    local iItemCnt = mWeek["zhenmo_item_cnt"] or 0
    local mWeekReward = mWeek["zhenmo_item_reward"] or {} --记录每周奖励过的任务
    local iTaskId = self:GetId()
    if iItemCnt >= 10 or mWeekReward[iTaskId] then
        return false
    end
    return true
end

function CTask:CheckExpReward(oPlayer)
    local mDay = oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:GetDay()
    local iExpCnt = mDay["zhenmo_exp_cnt"] or 0
    local mDayReward = mDay["zhenmo_exp_reward"] or {} --记录每天奖励过的任务
    local iTaskId = self:GetId()
    if iExpCnt >= 10 or mDayReward[iTaskId] then
        return false
    end
    return true
end

function CTask:RewardItems(oPlayer, mAllItems, mArgs)
    if mArgs and mArgs.is_special then
        local mReward = {}
        for iRewardId, mData in pairs(mAllItems) do
            for _, oItem in ipairs(mData["items"]) do
                local iSid = oItem:SID()
                local iItemCnt = oItem:GetAmount()
                local iValue = oItem:GetData("Value")
                if iValue then
                    iItemCnt = iValue
                end
                local mTmp = { id = iSid, amount = iItemCnt }
                table.insert(mReward, mTmp)
            end
        end
        mArgs = table_deep_copy(mArgs)
        mArgs.cancel_tip = true
        mArgs.cancel_chat = true
        mArgs.cancel_quick = true
        oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:SpecialReward(mReward)
    end
    super(CTask).RewardItems(self, oPlayer, mAllItems, mArgs)
end

function CTask:OnWarWin(oWar, pid, npcobj, mArgs)
    local iWarTime = mArgs["warresult"]["war_time"] or 0
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:OnWarWin(iWarTime)
    end
    super(CTask).OnWarWin(self, oWar, pid, npcobj, mArgs)
end

function CTask:OnMissionDone(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local iTaskId = self:GetId()
        oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:OnTaskDone(iTaskId)
    end
end

function CTask:ValidFight(iPid,npcobj,iFight)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return false end

    local oZhenmoCtrl = oPlayer.m_oBaseCtrl.m_oZhenmoCtrl
    if not oZhenmoCtrl then return false end

    if oPlayer:InWar() then return false end

    local oLayer = oZhenmoCtrl:GetCurLayer()
    local iLayer = oLayer:GetLayer()
    return oZhenmoCtrl:ValidCondition(iLayer)    
end

function CTask:WarFightEnd(oWar,pid,npcobj,mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:WarFightEnd()
    end
    super(CTask).WarFightEnd(self, oWar,pid,npcobj,mArgs)
end

function CTask:OnAddDone(oPlayer)
    super(CTask).OnAddDone(self, oPlayer)
    oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:OnAddDone(self)
end

function CTask:SayText(pid,npcobj,sText, mArgs, mMenuArgs, iMenuType)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer and oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:IsLastWarWin() then
        local npcid = npcobj.m_ID
        local mData = {
            ["answer"] = 1,
        }
        self:OnSayRespondCallback(oPlayer, npcid, mData)
        return
    end
    super(CTask).SayText(self, pid,npcobj,sText, mArgs, mMenuArgs, iMenuType)
end

function CTask:IsLogWarWanfa()
    return true
end
