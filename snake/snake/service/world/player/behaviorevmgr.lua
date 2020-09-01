-- 行为事件管理，触发行为计数
local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBehaviorEvDef()
    return CBehaviorEvDef:New()
end

-- definer
CBehaviorEvDef = {}
CBehaviorEvDef.__index = CBehaviorEvDef
inherit(CBehaviorEvDef, logic_base_cls())

function CBehaviorEvDef:New()
    return super(CBehaviorEvDef).New(self)
end

-- {condiId = {iEv, mParam, fTriggerCntFunc}, ...}
local mBehavior2Ev = {
    -- 1: 师门任务完成1个
    [1] = {gamedefines.EVENT.SHIMEN_DONE, },
    -- 2: 金刚伏魔完成1个
    [2] = {gamedefines.EVENT.GHOST_DONE, },
    -- 3: 封妖完成1个
    -- [3] = {gamedefines.EVENT.SCHEDULE_DONE, {scheduleId = 1003}, },
    [3] = {gamedefines.EVENT.FENGYAO_DONE, },
    -- 4: 雷峰塔副本（侠影）通关1次
    [4] = {gamedefines.EVENT.FUBEN_DONE, {fubenId = 10001}},
    -- 5: 雷峰塔副本（仙途）通关1次
    [5] = {gamedefines.EVENT.FUBEN_DONE, {fubenId = 10001}},
    -- 6: 金山寺副本（侠影）通关1次
    [6] = {gamedefines.EVENT.FUBEN_DONE, {fubenId = 10002}},
    -- 7: 金山寺副本（仙途）通关1次
    [7] = {gamedefines.EVENT.FUBEN_DONE, {fubenId = 10002}},
    -- 8: 竞技场打完1场
    [8] = {gamedefines.EVENT.JJC_FIGHT_END, },
    -- 9: 异宝收集交付1个任务
    [9] = {gamedefines.EVENT.YIBAO_DONE_SUB, },
    -- 10: 跳舞活动完成1次
    [10] = {gamedefines.EVENT.SCHEDULE_DONE, {scheduleId = 1016} },
    -- 11: 欢乐骰子完成1次
    [11] = {gamedefines.EVENT.SCHEDULE_DONE, {scheduleId = 1017} },
    -- 12: 天魔来袭完成1次
    [12] = {gamedefines.EVENT.SCHEDULE_DONE, {scheduleId = 1009} },
    -- 13: 完成所有每日任务(这个行为不注册事件，仅每日任务内部使用)
    -- 14: 装备强化1次
    [14] = {gamedefines.EVENT.EQUIP_STRENGTHEN, },
    -- 15: 装备洗练1次
    [15] = {gamedefines.EVENT.EQUIP_WASH, },
    -- 16: 装备打造1次
    [16] = {gamedefines.EVENT.EQUIP_DAZAO, },
    -- 17: 伙伴使用初中高级辟谷丹
    [17] = {gamedefines.EVENT.PARTNER_USE_UPGRADE_PROP, },
    -- 18: 伙伴技能升级
    [18] = {gamedefines.EVENT.PARTNER_SKILL_UPGRADE, },
    -- 19: 伙伴突破
    [19] = {gamedefines.EVENT.PARTNER_INCREASE_UPPER, },
    -- 20: 伙伴进阶
    [20] = {gamedefines.EVENT.PARTNER_INCREASE_QUALITY, },
    -- 21: 宠物使用初中高级经验丹
    [21] = {gamedefines.EVENT.SUMMON_USE_EXP_BOOK, },
    -- 22: 宠物技能升级
    [22] = {gamedefines.EVENT.SUMMON_SKILL_LEVELUP, },
    -- 23: 宠物学习技能
    [23] = {gamedefines.EVENT.SUMMON_STICK_SKILL, },
    -- 24: 宠物合成
    [24] = {gamedefines.EVENT.SUMMON_COMBINE, },
    -- 25: 宠物洗练
    [25] = {gamedefines.EVENT.SUMMON_WASH, },
    -- 26: 宠物培养
    [26] = {gamedefines.EVENT.SUMMON_CULTIVATE_APTITUDE, },
    -- 27: 主角招式技能学习
    [27] = {gamedefines.EVENT.PLAYER_LEARN_ACTIVE_SKILL, nil, function(mEvData) return mEvData.newlv - mEvData.oldlv end},
    -- 28: 主角心法技能学习
    [28] = {gamedefines.EVENT.PLAYER_LEARN_PASSIVE_SKILL, nil, function(mEvData) return mEvData.newlv - mEvData.oldlv end},
    -- 29: 主角修炼技能学习
    [29] = {gamedefines.EVENT.PLAYER_LEARN_CULTIVATE_SKILL, },
    -- 30: 主角帮派技能学习
    [30] = {gamedefines.EVENT.PLAYER_LEARN_ORG_SKILL, },
    -- 31: 装备附魂1次
    [31] = {gamedefines.EVENT.EQUIP_FUHUN, },
    -- 32: 头衔晋升1次
    [32] = {gamedefines.EVENT.PLAYER_TOUXIAN_UPGRADE, },
    -- 33: 英雄试炼战胜1次
    [33] = {gamedefines.EVENT.TRIAL_FIGHT_START, },
}

function CBehaviorEvDef:GetBehaviorEvTypeParam(iBehavior)
    local mEvInfo = mBehavior2Ev[iBehavior]
    if mEvInfo then
        return table.unpack(mEvInfo)
    end
end

-- 注册事件的对象必须是player级别的，因为注册的callback闭包内含pid
function CBehaviorEvDef:GetBehaviorEvObj(oPlayer, iEvType)
    if iEvType == gamedefines.EVENT.SHIMEN_DONE then
        return oPlayer.m_oTaskCtrl
    elseif iEvType == gamedefines.EVENT.GHOST_DONE then
        return oPlayer.m_oTaskCtrl
    elseif iEvType == gamedefines.EVENT.YIBAO_DONE_SUB then
        return oPlayer.m_oTaskCtrl
    elseif iEvType == gamedefines.EVENT.FENGYAO_DONE then
        return oPlayer.m_oScheduleCtrl
    elseif iEvType == gamedefines.EVENT.SCHEDULE_DONE then
        return oPlayer.m_oScheduleCtrl
    elseif iEvType == gamedefines.EVENT.JJC_FIGHT_END then
        return oPlayer.m_oScheduleCtrl
    elseif iEvType == gamedefines.EVENT.FUBEN_DONE then
        return oPlayer.m_oBaseCtrl.m_oFubenMgr
    elseif iEvType == gamedefines.EVENT.EQUIP_STRENGTHEN then
        return oPlayer.m_oItemCtrl
    elseif iEvType == gamedefines.EVENT.EQUIP_WASH then
        return oPlayer.m_oItemCtrl
    elseif iEvType == gamedefines.EVENT.EQUIP_DAZAO then
        return oPlayer.m_oItemCtrl
    elseif iEvType == gamedefines.EVENT.EQUIP_FUHUN then
        return oPlayer.m_oItemCtrl
    elseif iEvType == gamedefines.EVENT.PARTNER_USE_UPGRADE_PROP then
        return oPlayer.m_oPartnerCtrl
    elseif iEvType == gamedefines.EVENT.PARTNER_SKILL_UPGRADE then
        return oPlayer.m_oPartnerCtrl
    elseif iEvType == gamedefines.EVENT.PARTNER_INCREASE_UPPER then
        return oPlayer.m_oPartnerCtrl
    elseif iEvType == gamedefines.EVENT.PARTNER_INCREASE_QUALITY then
        return oPlayer.m_oPartnerCtrl
    elseif iEvType == gamedefines.EVENT.SUMMON_USE_EXP_BOOK then
        return oPlayer.m_oSummonCtrl
    elseif iEvType == gamedefines.EVENT.SUMMON_SKILL_LEVELUP then
        return oPlayer.m_oSummonCtrl
    elseif iEvType == gamedefines.EVENT.SUMMON_STICK_SKILL then
        return oPlayer.m_oSummonCtrl
    elseif iEvType == gamedefines.EVENT.SUMMON_COMBINE then
        return oPlayer.m_oSummonCtrl
    elseif iEvType == gamedefines.EVENT.SUMMON_WASH then
        return oPlayer.m_oSummonCtrl
    elseif iEvType == gamedefines.EVENT.SUMMON_CULTIVATE_APTITUDE then
        return oPlayer.m_oSummonCtrl
    elseif iEvType == gamedefines.EVENT.PLAYER_LEARN_ACTIVE_SKILL then
        return oPlayer.m_oSkillCtrl
    elseif iEvType == gamedefines.EVENT.PLAYER_LEARN_PASSIVE_SKILL then
        return oPlayer.m_oSkillCtrl
    elseif iEvType == gamedefines.EVENT.PLAYER_LEARN_ORG_SKILL then
        return oPlayer.m_oSkillCtrl
    elseif iEvType == gamedefines.EVENT.PLAYER_LEARN_CULTIVATE_SKILL then
        return oPlayer.m_oSkillCtrl
    elseif iEvType == gamedefines.EVENT.PLAYER_TOUXIAN_UPGRADE then
        return oPlayer.m_oTouxianCtrl
    elseif iEvType == gamedefines.EVENT.TRIAL_FIGHT_START then
        return oPlayer.m_oScheduleCtrl
    end
end

--------------------------
function NewBehaviorEvCtrl(pid, fEvCallback)
    return CBehaviorEvCtrl:New(pid, fEvCallback)
end

CBehaviorEvCtrl = {}
CBehaviorEvCtrl.__index = CBehaviorEvCtrl
inherit(CBehaviorEvCtrl, logic_base_cls())

function CBehaviorEvCtrl:New(pid, fEvCallback)
    local o = super(CBehaviorEvCtrl).New(self)
    o.m_iPid = pid
    o.m_fEvCallback = fEvCallback
    -- 注册 事件-行为 {iEvType = {iBehavior = 1, ...}, ..}
    o.m_mRegBehaviorEvs = {}
    -- 反查 行为-事件 {iBehavior = {iEvType = 1, ...}, ...}
    o.m_mLookupRegBehaviors = {}
    return o
end

function CBehaviorEvCtrl:Release()
    if next(self.m_mRegBehaviorEvs) then
        self:Clear()
    end
    super(CBehaviorEvCtrl).Release(self)
end

function CBehaviorEvCtrl:Clear()
    for iEvType, _ in pairs(self.m_mRegBehaviorEvs) do
        self:UnRegEv(iEvType)
    end
    self.m_mRegBehaviorEvs = {}
    self.m_mLookupRegBehaviors = {}
end

function CBehaviorEvCtrl:GetPid()
    return self.m_iPid
end

function CBehaviorEvCtrl:TouchRegBehaviorEvs(lBehaviors)
    for _, iBehavior in ipairs(lBehaviors) do
        self:TryRegBehavior(iBehavior)
    end
end

function CBehaviorEvCtrl:TryRegBehavior(iBehavior)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then
        return
    end
    local iEvType, mParam = global.oBehaviorEvDef:GetBehaviorEvTypeParam(iBehavior)
    if iEvType then
        if not self.m_mRegBehaviorEvs[iEvType] then
            self:RegEv(iEvType)
        end
        table_set_depth(self.m_mRegBehaviorEvs, {iEvType}, iBehavior, 1)
        table_set_depth(self.m_mLookupRegBehaviors, {iBehavior}, iEvType, 1)
    end
end

function CBehaviorEvCtrl:TouchUnRegBehaviorEvs(lBehaviors)
    for _, iBehavior in ipairs(lBehaviors) do
        self:TryUnRegBehavior(iBehavior)
    end
end

function CBehaviorEvCtrl:TryUnRegBehavior(iBehavior)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then
        return
    end
    local mRegedBehaviorEvs = self.m_mLookupRegBehaviors[iBehavior]
    if not mRegedBehaviorEvs then
        return
    end
    local mDropEvCondis = {}
    self.m_mLookupRegBehaviors[iBehavior] = nil
    for iEvType, _ in pairs(mRegedBehaviorEvs) do
        local mEvBehaviors = self.m_mRegBehaviorEvs[iEvType]
        if mEvBehaviors then
            mEvBehaviors[iBehavior] = nil
        end
        if not mEvBehaviors or not next(mEvBehaviors) then
            self.m_mRegBehaviorEvs[iEvType] = nil
            self:UnRegEv(iEvType)
        end
    end
end

function CBehaviorEvCtrl:TriggerBehaviorEvent(iEvType, mEvData)
    local mTriggered = {}
    local mEvBehaviors = self.m_mRegBehaviorEvs[iEvType]
    for iBehavior, _ in pairs(mEvBehaviors) do
        local iEv, mParam, fTriggerCntFunc = global.oBehaviorEvDef:GetBehaviorEvTypeParam(iBehavior)
        if iEvType ~= iEv then
            goto continue_condi
        end
        if mParam then
            -- TODO 如果条件变复杂或者事件参数简介，可以改为filterFunc
            for sKey, iValue in pairs(mParam) do
                if mEvData[sKey] ~= iValue then
                    goto continue_condi
                end
            end
        end
        local iTimes = 1
        if fTriggerCntFunc then
            iTimes = fTriggerCntFunc(mEvData)
        end
        mTriggered[iBehavior] = iTimes
        ::continue_condi::
    end
    return mTriggered
end

-- 注册事件都是当前角色的钩子，因此量级与在线角色数无关
function CBehaviorEvCtrl:RegEv(iEvType)
    local fEvCallback = self.m_fEvCallback
    if not fEvCallback then
        return
    end
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oRegObj = global.oBehaviorEvDef:GetBehaviorEvObj(oPlayer, iEvType)
    if oRegObj then
        oRegObj:AddEvent(self, iEvType, function(iEv, mData)
            fEvCallback(iEv, mData, iPid)
        end)
    end
end

function CBehaviorEvCtrl:UnRegEv(iEvType)
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oRegObj = global.oBehaviorEvDef:GetBehaviorEvObj(oPlayer, iEvType)
    if oRegObj then
        oRegObj:DelEvent(self, iEvType)
    end
end
