-- 战斗喊话

local global = require "global"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local wardefines = import(service_path("fight/wardefines"))

-- local THIS_ACTION_NUM = 1002

local mTiming2Event = {
    -- WAR_START时机由玉良确认移除，合并到WAR_BOUT_START{1}情况
    -- [wardefines.WAR_TIMING.WAR_START] = gamedefines.EVENT.WAR_START,
    [wardefines.WAR_TIMING.ROUND_START] = gamedefines.EVENT.WAR_BOUT_START,
    [wardefines.WAR_TIMING.X_ROUND_START] = gamedefines.EVENT.WAR_BOUT_START,
    [wardefines.WAR_TIMING.ROUND_END] = gamedefines.EVENT.WAR_BOUT_END,
    [wardefines.WAR_TIMING.X_ROUND_END] = gamedefines.EVENT.WAR_BOUT_END,
    [wardefines.WAR_TIMING.BEFORE_ACT] = gamedefines.EVENT.WAR_BEFORE_ACT,
    [wardefines.WAR_TIMING.X_ROUND_BEFORE_ACT] = gamedefines.EVENT.WAR_BEFORE_ACT,
    [wardefines.WAR_TIMING.MONSTER_X_SUB_HP_TO_Y_PERCENT] = gamedefines.EVENT.WAR_MONSTER_HP_SUB_TO_PERCENT,
    [wardefines.WAR_TIMING.ESCAPE] = gamedefines.EVENT.WAR_ESCAPE,
}

function GetTiming2Event(iTimingType)
    return mTiming2Event[iTimingType]
end

-- 阻塞下一个喊话的时间
local mTiming2BlockSpeekSeqTime = {
    [wardefines.WAR_TIMING.ROUND_START] = 2000,
    [wardefines.WAR_TIMING.X_ROUND_START] = 2000,
    [wardefines.WAR_TIMING.ROUND_END] = 2000, --- 暂定一个对话2s
    [wardefines.WAR_TIMING.X_ROUND_END] = 2000,
}

-- 是否阻塞后面的行动
local mTiming2BlockAction = {
    [wardefines.WAR_TIMING.ROUND_END] = true,
    [wardefines.WAR_TIMING.X_ROUND_END] = true,
}

-- 这张表必须热更后不持有，热更后重新touch生成
local mEvent2Timing = nil

function GetEvent2Timing(iEvent)
    if not mEvent2Timing then
        mEvent2Timing = {}
        for iTiming, iEv in pairs(mTiming2Event) do
            local lTimings = table_get_set_depth(mEvent2Timing, {iEv})
            table.insert(lTimings, iTiming)
        end
    end
    return mEvent2Timing[iEvent]
end

--------------------------------

function NewWarSpeekCtrl(...)
    local o = CWarSpeekCtrl:New(...)
    return o
end

CWarSpeekCtrl = {}
CWarSpeekCtrl.__index = CWarSpeekCtrl
inherit(CWarSpeekCtrl, logic_base_cls())

function CWarSpeekCtrl:New(mSpeekData)
    local o = super(CWarSpeekCtrl).New(self)
    self.m_mTiming = {}
    o:Init(mSpeekData)
    return o
end

function CWarSpeekCtrl:Init(mSpeekData)
    local mTiming = {}
    for idx, mAction in pairs(mSpeekData) do
        local iActorType = mAction.actor_type
        local iActorId = mAction.actor_id
        local iSeq = mAction.seq
        if iActorId == 0 then
            iActorId = nil
        end
        local iTimingType = mAction.timing
        local lTimingArgs = mAction.timing_args
        local sContent = mAction.content
        local mTimingArgs = global.oSpeekMgr:ParseTimingArgs(iTimingType, lTimingArgs, iActorType, iActorId)
        if not mTimingArgs then
            goto continue
        end
        local sHashTimingStr = extend.Table.serialize(mTimingArgs)
        local sHashActorStr = string.format("%s:%s", iActorType, iActorId)

        local mHashTimingInfo = table_get_set_depth(mTiming, {iTimingType, sHashTimingStr})
        if not mHashTimingInfo.timing_args then
            mHashTimingInfo.timing_args = mTimingArgs
        end
        table_set_depth(mHashTimingInfo, {"actors"}, sHashActorStr, {
            actor_type = iActorType,
            actor_id = iActorId,
            seq = iSeq,
            content = sContent,
        })
        ::continue::
    end
    -- mTiming = {
    --   <iTimingType> = {
    --      <sHashTimgingStr> = {
    --          timing_args = {...},
    --          actors = {
    --              sHashActorStr = {
    --                actor_type = <int>,
    --                actor_id = <int/nil>,
    --                seq = <int/nil>,
    --                content = <string>,
    --              },
    --          },
    --      }, ...
    --   }
    -- }
    self.m_mTiming = mTiming
end

function CWarSpeekCtrl:GetWar()
    if self.m_iWarId then
        return global.oWarMgr:GetWar(self.m_iWarId)
    end
end

function CWarSpeekCtrl:RegisterWar(oWar)
    self.m_iWarId = oWar:GetWarId()
    local mEvs = {}
    for iTimingType, mTimingInfo in pairs(self.m_mTiming) do
        local iEv = GetTiming2Event(iTimingType)
        if iEv then
            mEvs[iEv] = true
        end
        for sHashTimgingStr, mHashTimingInfo in pairs(mTimingInfo) do
            local mTimingArgs = mHashTimingInfo.timing_args
            self:DoInitRegTimingInfo(oWar, iTimingType, mTimingArgs, sHashTimgingStr)
        end
    end
    -- 注册时机事件
    for iEv, _ in pairs(mEvs) do
        self:DoRegTimingEvent(oWar, iEv)
    end
end

function CWarSpeekCtrl:DoRegTimingEvent(oWar, iEvent)
    oWar:AddEvent(self, iEvent, function(iEvType, mData)
        OnEvCallback(iEvType, mData)
    end)
end

function CWarSpeekCtrl:DoInitRegTimingInfo(oWar, iTimingType, mTimingArgs, sHashTimingStr)
    if iTimingType == wardefines.WAR_TIMING.MONSTER_X_SUB_HP_TO_Y_PERCENT then
        -- TODO 注册指定掉血回调 | 指定怪物会是战斗中间召唤的么，那么会有monsterIdx属性么？如果是，改注册方式
        local iMonsterIdx = mTimingArgs.monster
        local iPercent = mTimingArgs.percent
        local mMonsterObjList = global.oSpeekMgr:GetMonster(oWar, iMonsterIdx)
        -- 特殊注册方式
        for _, oMonster in pairs(mMonsterObjList) do
            oMonster:RegSubHpToPercent(iPercent)
        end
    end
end

function CWarSpeekCtrl:OnEvCallback(iEvType, mData)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    local mExcutors = {}
    local lTimingTypes = GetEvent2Timing(iEvType)
    for _, iTimingType in ipairs(lTimingTypes) do
        local mTimingInfo = self.m_mTiming[iTimingType]
        if mTimingInfo then
            for sHashTimingStr, mHashTimingInfo in pairs(mTimingInfo) do
                local mTimingArgs = mHashTimingInfo.timing_args
                local iState = global.oSpeekMgr:CheckTimingArgs(iTimingType, mTimingArgs, mData)
                local mActorDatas = mHashTimingInfo.actors
                if iState ~= TIMING_CHECK_STATE.FAIL then
                    -- 时间有效，添加到mExcutors
                    for sHashActorStr, mActorInfo in pairs(mActorDatas) do
                        local iSeq = mActorInfo.seq or 0
                        local iActorType = mActorInfo.actor_type
                        local iActorId = mActorInfo.actor_id
                        local sContent = mActorInfo.content
                        local lActors = global.oSpeekMgr:GetActorsByType(oWar, iActorType, iActorId)
                        if lActors and next(lActors) then
                            if iState == TIMING_CHECK_STATE.CHECK_ACTOR then
                                -- 时间有效，但actor必须是mData.actor
                                local oActor = mData.actor
                                if oActor and extend.Array.find(lActors, oActor) then
                                    lActors = {oActor}
                                else
                                    lActors = nil
                                end
                            end
                            if lActors then
                                local lSeqActors = table_get_set_depth(mExcutors, {iSeq})
                                table.insert(lSeqActors, {
                                    warriors = lActors,
                                    content = sContent,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    if next(mExcutors) then
        self:SendAllSeqSpeek(mExcutors, lTimingTypes[1])
    end
end

function CWarSpeekCtrl:GenWarriorSpeekNet(mInfo, idx)
    local lOkWids = {}
    local lWarriors = mInfo.warriors
    for _, oWarrior in ipairs(lWarriors) do
        if not oWarrior then
            goto continue
        end
        if oWarrior:IsDead() then
            goto continue
        end
        local oWar = oWarrior:GetWar()
        if not oWar then
            goto continue
        end
        table.insert(lOkWids, oWarrior:GetWid())
        ::continue::
    end
    if next(lOkWids) then
        return {wids = lOkWids, content = mInfo.content}
    end
end

-- @param mExcutors: <mapping>{
--     <iSeq> = {
--        <list>{
--            warriors = <oWarriors>,
--            content = <string>,
--        }, ...
--     }
--   }
function CWarSpeekCtrl:SendAllSeqSpeek(mExcutors, iTimingType)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    local iSeqCnt = table_count(mExcutors)
    local iWaitMs = mTiming2BlockSpeekSeqTime[iTimingType] or 0
    local bBlockAction = mTiming2BlockAction[iTimingType]
    local iBlockAction = bBlockAction and 1 or 0
    if bBlockAction then
        oWar:AddAnimationTime(iWaitMs * iSeqCnt)
    end
    local lSeqList = table_key_list(mExcutors)
    table.sort(lSeqList)
    for _, iSeq in ipairs(lSeqList) do
        local lSpeekInfo = mExcutors[iSeq]
        local lWidsSpeekInfo = extend.Array.foreach(lSpeekInfo, function(mInfo, idx)
            return self:GenWarriorSpeekNet(mInfo, idx)
        end)
        if next(lWidsSpeekInfo) then
            local lNetSpeekInfo = {}
            for _, mInfo in ipairs(lWidsSpeekInfo) do
                local sContent = mInfo.content
                for _, iWid in ipairs(mInfo.wids) do
                    table.insert(lNetSpeekInfo, {wid = iWid, content = sContent})
                end
            end
            local mNet = {
                war_id = self.m_iWarId,
                speeks = lNetSpeekInfo,
                block_ms = iWaitMs,
                block_action = iBlockAction,
            }
            -- PS. 根据情况，可以考虑和GS2CWarriorSpeek合并
            oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
        end
    end
end

function OnEvCallback(iEvType, mData)
    local oWar = mData.war
    if not oWar then
        return
    end
    local oSpeekCtrl = oWar:GetWarSpeekCtrl()
    if oSpeekCtrl then
        safe_call(oSpeekCtrl.OnEvCallback, oSpeekCtrl, iEvType, mData)
    end
end
---------------------------

function NewSpeekMgr(...)
    local o = CSpeekMgr:New(...)
    return o
end

CSpeekMgr = {}
CSpeekMgr.__index = CSpeekMgr
inherit(CSpeekMgr, logic_base_cls())

function CSpeekMgr:New(...)
    local o = super(CSpeekMgr).New(self)
    return o
end

function CSpeekMgr:GenWarSpeek(mSpeekData, ...)
    -- TODO 喊话内容、喊话对象等信息如果完全读表可能无法在world服定制，暂时不改当前结构，仍然使用读表解析后的信息
    -- ...额外参数可以用来扩展定制功能，适应不同玩法的特殊喊话需求
    local oSpeekCtrl = NewWarSpeekCtrl(mSpeekData)
    return oSpeekCtrl
end

function CSpeekMgr:ParseTimingArgs(iTimingType, lTimingArgs, iActorType, iActorId)
    -- if iTimingType == wardefines.WAR_TIMING.WAR_START then
    --     return {}
    -- end
    if iTimingType == wardefines.WAR_TIMING.ROUND_START then
        return {}
    elseif iTimingType == wardefines.WAR_TIMING.ROUND_END then
        return {}
    elseif iTimingType == wardefines.WAR_TIMING.X_ROUND_START then
        local iRound = tonumber(lTimingArgs[1])
        if not iRound then
            return nil
        end
        return {round = iRound}
    elseif iTimingType == wardefines.WAR_TIMING.X_ROUND_END then
        local iRound = tonumber(lTimingArgs[1])
        if not iRound then
            return nil
        end
        return {round = iRound}
    elseif iTimingType == wardefines.WAR_TIMING.BEFORE_ACT then
        -- 执行者本身也是判断条件
        return {}
    elseif iTimingType == wardefines.WAR_TIMING.X_ROUND_BEFORE_ACT then
        local iRound = tonumber(lTimingArgs[1])
        if not iRound then
            return nil
        end
        return {round = iRound}
    elseif iTimingType == wardefines.WAR_TIMING.MONSTER_X_SUB_HP_TO_Y_PERCENT then
        local iMonsterIdx = tonumber(lTimingArgs[1])
        local iPercent = tonumber(lTimingArgs[2])
        if not iMonsterIdx or not iPercent then
            return nil
        end
        return {monster = iMonsterIdx, percent = iPercent}
    elseif iTimingType == wardefines.WAR_TIMING.ESCAPE then
        -- 执行者本身也是判断条件
        return {}
    end
end

TIMING_CHECK_STATE = {
    FAIL = 0,
    OK = 1,
    CHECK_ACTOR = 2,
}

function CSpeekMgr:CheckTimingArgs(iTimingType, mTimingArgs, mCheckData)
    -- if iTimingType == wardefines.WAR_TIMING.WAR_START then
    --     return TIMING_CHECK_STATE.OK
    -- end
    if iTimingType == wardefines.WAR_TIMING.ROUND_START then
        return TIMING_CHECK_STATE.OK
    elseif iTimingType == wardefines.WAR_TIMING.X_ROUND_START then
        if mCheckData.bout == mTimingArgs.round then
            return TIMING_CHECK_STATE.OK
        end
    elseif iTimingType == wardefines.WAR_TIMING.ROUND_END then
        return TIMING_CHECK_STATE.OK
    elseif iTimingType == wardefines.WAR_TIMING.X_ROUND_END then
        if mCheckData.bout == mTimingArgs.round then
            return TIMING_CHECK_STATE.OK
        end
    elseif iTimingType == wardefines.WAR_TIMING.BEFORE_ACT then
        return TIMING_CHECK_STATE.CHECK_ACTOR
    elseif iTimingType == wardefines.WAR_TIMING.X_ROUND_BEFORE_ACT then
        if mCheckData.bout == mTimingArgs.round then
            return TIMING_CHECK_STATE.CHECK_ACTOR
        end
    elseif iTimingType == wardefines.WAR_TIMING.MONSTER_X_SUB_HP_TO_Y_PERCENT then
        -- 可以考虑改为不注册监测点，而将全部怪的百分比from-to发出来
        if mCheckData.monster == mTimingArgs.monster and mCheckData.percent == mTimingArgs.percent then
            return TIMING_CHECK_STATE.OK
        end
    elseif iTimingType == wardefines.WAR_TIMING.ESCAPE then
        return TIMING_CHECK_STATE.CHECK_ACTOR
    end
    return TIMING_CHECK_STATE.FAIL
end

-- getters
function CSpeekMgr:GetFilteredWarriors(lWarriorList, fFilter, ...)
    local lRet = {}
    for idx, oWarrior in ipairs(lWarriorList) do
        if fFilter(oWarrior, ...) then
            table.insert(lRet, oWarrior)
        end
    end
    return lRet
end

function _FilterWarriorsByType(oWarrior, iWarriorType)
    return oWarrior:Type() == iWarriorType
end

function _FilterWarriorsBySid(oWarrior, iWarriorType, iWarriorTypeSid)
    return oWarrior:Type() == iWarriorType and oWarrior:GetTypeSid() == iWarriorTypeSid
end

function _FilterWarriorsByActorId(oWarrior, iWarriorType, iActorId)
    if oWarrior:Type() ~= iWarriorType then
        return false
    end
    if iActorId and oWarrior:GetTypeSid() ~= iActorId then
        return false
    end
    return true
end

function CSpeekMgr:GetMonster(oWar, iActorId)
    local lWarriors = oWar:GetWarriorList(gamedefines.WAR_WARRIOR_SIDE.FRIEND) or {}
    list_combine(lWarriors, oWar:GetWarriorList(gamedefines.WAR_WARRIOR_SIDE.ENEMY) or {})
    return self:GetFilteredWarriors(lWarriors, _FilterWarriorsByActorId, gamedefines.WAR_WARRIOR_TYPE.NPC_TYPE, iActorId)
end

function CSpeekMgr:GetPartner(oWar, iActorId)
    local lWarriors = oWar:GetWarriorList(gamedefines.WAR_WARRIOR_SIDE.FRIEND) or {}
    return self:GetFilteredWarriors(lWarriors, _FilterWarriorsByActorId, gamedefines.WAR_WARRIOR_TYPE.PARTNER_TYPE, iActorId)
end

function CSpeekMgr:GetPlayerLeaderSummon(oWar)
    local mPlayerList = self:GetPlayerLeader(oWar)
    local mSummons = {}
    for _, oPlayer in ipairs(mPlayerList) do
        local iCamp = oPlayer:GetCampId()
        local oCamp = oWar:GetCampObj(iCamp)
        local iPos = oCamp:GetSummonPos(oPlayer)
        local oSummon = oCamp:GetWarriorByPos(iPos)
        if oSummon then
            table.insert(mSummons, oSummon)
        end
    end
    return mSummons
end

function CSpeekMgr:GetPlayerLeader(oWar)
    local lRet = {}
    local lWarriorList = oWar:GetPlayerWarriorList()
    for idx, oWarrior in ipairs(lWarriorList) do
        local mData = oWarrior.m_mData
        local mTest = oWarrior.m_mTestData
        if oWarrior:GetData("is_leader") or oWarrior:GetData("is_single") then
            table.insert(lRet, oWarrior)
        end
    end
    return lRet
end

function CSpeekMgr:GetPlayer(oWar)
    return oWar:GetPlayerWarriorList()
end

function CSpeekMgr:GetSummon(oWar, iActorId)
    local lWarriors = oWar:GetWarriorList(gamedefines.WAR_WARRIOR_SIDE.FRIEND) or {}
    return self:GetFilteredWarriors(lWarriors, _FilterWarriorsByActorId, gamedefines.WAR_WARRIOR_TYPE.SUMMON_TYPE, iActorId)
end

local mActorGetters = {
    [wardefines.WAR_ACTOR_TYPE.PLAYER]  = "GetPlayer",
    [wardefines.WAR_ACTOR_TYPE.SUMMON]  = "GetSummon",
    [wardefines.WAR_ACTOR_TYPE.PARTNER] = "GetPartner",
    [wardefines.WAR_ACTOR_TYPE.MONSTER] = "GetMonster",
    [wardefines.WAR_ACTOR_TYPE.LEADER]  = "GetPlayerLeader",
    [wardefines.WAR_ACTOR_TYPE.LEADER_SUMMON]  = "GetPlayerLeaderSummon",
}

function CSpeekMgr:GetActorsByType(oWar, iActorType, iActorId)
    local sFunc = mActorGetters[iActorType]
    if not sFunc then
        return nil
    end
    return self[sFunc](self, oWar, iActorId)
end
