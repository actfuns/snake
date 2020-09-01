--import module
local global = require "global"
local geometry = require "base.geometry"
local extend = require "base.extend"
local record = require "public.record"
local statistics = require "public.statistics"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))

local monster = import(service_path("monster"))
local loadsummon = import(service_path("summon.loadsummon"))
local loadpartner = import(service_path("partner/loadpartner"))
local analylog = import(lualib_path("public.analylog"))


local table = table
local string = string

local ITEM_SUMMON_EXP = 1007

CTempl = {}
CTempl.__index = CTempl
CTempl.m_sName = "templ"
CTempl.m_sTempName = "神秘玩法"
CTempl.m_sStatisticsName = ""
CTempl.m_iSysType= gamedefines.GAME_SYS_TYPE.SYS_TYPE_NONE
inherit(CTempl, datactrl.CDataCtrl)

function CTempl:New(sName)
    local o = super(CTempl).New(self)
    o.m_sName = sName
    return o
end

function CTempl:GetTollGateData(iFight)
    local res = require "base.res"
    return res["daobiao"]["fight"][self.m_sName]["tollgate"][iFight]
end

function CTempl:GetWarSpeekData(iSpeekId)
    local res = require "base.res"
    return res["daobiao"]["fight"][self.m_sName]["speek"][iSpeekId]
end

function CTempl:GetMonsterData(iMonsterIdx)
    local res = require "base.res"
    local mData = res["daobiao"]["fight"][self.m_sName]["monster"][iMonsterIdx]
    assert(mData,string.format("CTempl GetMonsterData err: %s %d", self.m_sName, iMonsterIdx))
    return mData
end

function CTempl:GetGlobalData(idx)
    local res = require "base.res"
    return res["daobiao"]["global"][idx]
end

function CTempl:GetRewardData(iReward)
    local res = require "base.res"
    local mData = res["daobiao"]["reward"][self.m_sName]["reward"][iReward]
    assert(mData,string.format("CTempl:GetRewardData err:%s %d", self.m_sName, iReward))
    return mData
end

function CTempl:GetItemRewardData(iItemReward)
    local res = require "base.res"
    local mData = res["daobiao"]["reward"][self.m_sName]["itemreward"][iItemReward]
    assert(mData,string.format("CTempl:GetItemRewardData err:%s %d", self.m_sName, iItemReward))
    return mData
end

function CTempl:GetSummonRewardData(iSummReward)
    local res = require "base.res"
    local mData = table_get_depth(res, {"daobiao", "reward", self.m_sName, "summonreward", iSummReward})
    assert(mData,string.format("CTempl:GetSummonRewardData err:%s %d", self.m_sName, iSummReward))
    return mData
end

function CTempl:GetItemFilterData(iFilterId)
    local res = require "base.res"
    local mData = res["daobiao"]["itemfilter"][iFilterId]
    assert(mData, string.format("CTempl:GetItemFilterData err:%s %d", self.m_sName, iFilterId))
    return mData
end

function CTempl:GetEventData()
    return {}
end

function CTempl:GetNpcObj(npcid)
end

function CTempl:RewardDie(iFight)
    return false
end

function CTempl:ValidFight(pid,npcobj,iFight)
    return true
end

function CTempl:GetSysType()
    return self.m_iSysType
end

function CTempl:SummonExpEffect()
    return true
end

function CTempl:PartnerExpEffect()
    return true
end

function CTempl:PlayerExpEffect()
    return true
end

function CTempl:TrueFight(pid, npcobj, iFight, mConfig, bSingle)
    if not self:ValidFight(pid,npcobj,iFight) then return end

    if bSingle and npcobj and npcobj:InWar() then return end

    local oWar = self:CreateWar(pid, npcobj, iFight, mConfig)
    if self:RewardDie(iFight) then
        oWar.m_RewardDie = true
    end

    if bSingle and npcobj then
        local oSceneMgr = global.oSceneMgr
        npcobj:SetNowWar(oWar.m_iWarId)
        oSceneMgr:NpcEnterWar(npcobj)
    end
    return oWar
end

function CTempl:GetWarPackFunc()
end

function CTempl:Fight(pid, npcobj, iFight, mConfig, bSingle)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if self:IsNeedConfirm(oPlayer, iFight, npcobj) then
        local fCbSelfGetter = self:GetCbSelfGetter()
        local npcid = npcobj.m_ID
        if fCbSelfGetter then
            local fCallback = function ()
                local oSelfObj = fCbSelfGetter()
                if oSelfObj then
                    oSelfObj:FightConfirm(pid, npcid, iFight, mConfig, bSingle)  
                end
            end
            global.oConfirmMgr:CreateTeamFightConfirm(oPlayer, npcobj:Name(), fCallback)    
        else
            self:TrueFight(pid, npcobj, iFight, mConfig, bSingle)    
        end
    else
        self:TrueFight(pid, npcobj, iFight, mConfig, bSingle)
    end
end

function CTempl:IsNeedConfirm(oPlayer, iFight, npcobj)
    local mData = self:GetTollGateData(iFight)
    if mData["war_confirm"] ~= 1 then return false end

    if oPlayer:IsSingle() then return false end
    local oTeam = oPlayer:HasTeam()
    if oTeam:IsWarConfirm() then return false end

    if not npcobj then return false end
    if not self:GetNpcObj(npcobj.m_ID) then return false end

    return true
end

function CTempl:FightConfirm(pid, iNpcid, iFight, mConfig, bSingle)
    local oNpc = self:GetNpcObj(iNpcid)    
    self:TrueFight(pid, oNpc, iFight, mConfig, bSingle)
end

function CTempl:SingleFight(pid,npcobj,iFight, mConfig)
    self:Fight(pid,npcobj,iFight, mConfig, true)
end

function CTempl:ParseWarriorData(oWar, npcobj, mMonsterData, mCampInfo)
    return mMonsterData, mCampInfo
end

function CTempl:PackWarriorsAttr(oWar, mMonsterData, npcobj,mArgs)
    local mWarriors = {}
    for _,mData in pairs(mMonsterData) do
        local iMonsterIdx = mData["monsterid"]
        local iCnt = mData["count"]
        for i=1,iCnt do
            local oMonster = self:CreateMonster(oWar, iMonsterIdx, npcobj)
            if oMonster then
                table.insert(mWarriors, self:PackMonster(oMonster))
                baseobj_delay_release(oMonster)
            else
                record.warning("monster table err:"..self.m_sName..iMonsterIdx)
            end
        end
    end
    return mWarriors
end

function CTempl:OnPackWarriorsAttr(mFriend,mEnemy,oWar,npcobj)
    return mFriend,mEnemy
end

function CTempl:PackMonster(oMonster)
    local mRet = oMonster:PackAttr()
    return mRet
end

-- @return: <map>mConfig {
--      record_add_npc.iMonsterIdx = true 记录战斗内添加过的npc数量
--  }
function CTempl:GetWarConfig()
    return nil
end

function CTempl:RandomFormation()
    local res = require "base.res"
    local mFormations = res["daobiao"]["formation"]["base_info"]
    local lFmtIDs = {}
    for k,_ in pairs(mFormations) do
        assert(k>0 and k<10, "illegal fmt config")
        if k ~= 1 then
            table.insert(lFmtIDs, k)
        end
    end
    if next(lFmtIDs) then
        return extend.Random.random_choice(lFmtIDs)
    end
end

function CTempl:InitWarInfo(mData)
    local mWarInfo = {
        tollgate_group = self.m_sName,
        tollgate_id = mData.id,
    }
    local iWeather = mData["weather"]
    if iWeather and iWeather ~= 0 then
        mWarInfo.weather = iWeather
    end
    local iSkyWar = mData["sky_war"]
    if iSkyWar and iSkyWar ~= 0 then
        mWarInfo.sky_war = iSkyWar
    end
    local iBossWarType = mData["boss_war_type"]
    if iBossWarType and iBossWarType ~= 0 then
        mWarInfo.is_bosswar = true
    end
    local iBarrageShow = mData["barrage_show"]
    if iBarrageShow and iBarrageShow ~= 0 then
        mWarInfo.barrage_show = iBarrageShow
    end
    local iBarrageSend = mData["barrage_send"]
    if iBarrageSend and iBarrageSend ~= 0 then
        mWarInfo.barrage_send = iBarrageSend
    end
    if self.m_iAutoFightOnStart then
        mWarInfo.auto_start = self.m_iAutoFightOnStart
    else
        mWarInfo.auto_start = mData["auto_start"] or gamedefines.WAR_AUTO_TYPE.USE_LAST
    end
    mWarInfo.GamePlay = self.m_sName
    return mWarInfo
end

function CTempl:InitCampInfo(mData)
    local mCampInfo = {}
    local iBossWarType = mData["boss_war_type"]
    if iBossWarType and iBossWarType ~= 0 then
        mCampInfo.boss_war_type = iBossWarType
    end
    mCampInfo.fmtinfo = self:InitWarLineup(mData["lineup"])

    if mData.monster_pos and #mData.monster_pos > 0 then
        mCampInfo.monster_pos = mData.monster_pos
    end
    return mCampInfo
end

function CTempl:InitWarLineup(mLineup)
    local mFmtInfo = {}
    if mLineup and next(mLineup) then
        local iFmtID = mLineup[1]
        if iFmtID then
            if iFmtID == -1 then
                mFmtInfo.fmt_id = self:RandomFormation()
            else
                assert(iFmtID>0 and iFmtID<10, "illegal fmt id")
                mFmtInfo.fmt_id = iFmtID
            end
        end

        if mFmtInfo.fmt_id then
            if #mLineup >= 2 then
                mFmtInfo.grade = mLineup[2]
            else
                mFmtInfo.grade = 1
            end
        end
    end
    return mFmtInfo
end

function CTempl:HasWarAssertMsg(pid, iFight)
    return ""
end

function CTempl:GetPartnerLimit(oWar)
    return nil
end

function CTempl:CreateWar(pid,npcobj,iFight)
    local oWarMgr = global.oWarMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    assert(oPlayer,string.format("CTempl:CreateWar player offline:%d %d",pid,iFight))
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    assert(not oNowWar, string.format("CreateWar err, has war, %s pid:%d,fightid:%d ", self.m_sName, pid, iFight) .. self:HasWarAssertMsg(pid, iFight))
    local mData = self:GetTollGateData(iFight)
    assert(mData,string.format("CreateWar %d err, null data",iFight))

    local mWarInfo = self:InitWarInfo(mData)
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVE_TYPE,
        self:GetSysType(),
        mWarInfo)
    oWar.m_iIdx = iFight
    oWar.PackFunc = self:GetWarPackFunc()
    oWar.m_sClassType = self.m_sName

    local ret
    local iWarId = oWar:GetWarId()
    local iLimit = self:GetPartnerLimit(oWar)
    if oPlayer:IsSingle() then
        ret = oWarMgr:EnterWar(oPlayer, iWarId, {camp_id = 1}, true, iLimit)
    else
        assert(oPlayer:IsTeamLeader(), string.format("attemp enter war as member, obj=%s", self.m_sName))
        ret = oWarMgr:TeamEnterWar(oPlayer, iWarId, {camp_id = 1}, true, iLimit)
    end
    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end

    local mCampInfo = self:InitCampInfo(mData)
    local mMonsterData = mData["monster"] or {}
    mMonsterData, mCampInfo = self:ParseWarriorData(oWar, npcobj, mMonsterData, mCampInfo)
    local mEnemy = self:PackWarriorsAttr(oWar, mMonsterData, npcobj,{pid=pid,bEnemy=true,fight=iFight})
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, mCampInfo)

    local mMonsterData = mData["friend"] or {}
    local mFriend = self:PackWarriorsAttr(oWar, mMonsterData, npcobj,{pid=pid,bFriend=true,fight=iFight})
    mFriend, mEnemy = self:OnPackWarriorsAttr(mFriend,mEnemy,oWar,npcobj)
    local mMonster = {
        [gamedefines.WAR_WARRIOR_SIDE.FRIEND] = mFriend,
        [gamedefines.WAR_WARRIOR_SIDE.ENEMY] = mEnemy,
    }

    oWarMgr:PrepareWar(iWarId, mMonster, self:GetWarConfig())
    if npcobj then
        oWar.m_iEvent = self:GetEvent(npcobj.m_ID)
    else
        oWar.m_iEvent = self:GetTriggerEvent()
    end
    local npcid
    if npcobj then
        npcid = npcobj.m_ID
    end
    local fCbSelfGetter = self:GetCbSelfGetter()
    local fCallback
    if fCbSelfGetter then
        fCallback = function (mArgs)
            local oSelfObj = fCbSelfGetter()
            if not oSelfObj then
                return
            end
            oSelfObj:OnWarFightEnd(iWarId, pid, npcid, mArgs)
        end
    end
    self:MarkWar(oWar,pid,npcobj)
    oWarMgr:SetCallback(iWarId,fCallback)
    self:SetOtherCallbacks(oWar, pid, npcobj)
    local mArgs = self:GetWarStartArgs(mData)
    oWarMgr:StartWar(iWarId, mArgs)

    self:LogWarInfo(oPlayer, iFight, 1)
    self:LogWarWanfaInfo(oPlayer, iFight, 1)
    return oWar
end

function CTempl:WarExceptionEnd(oWar, pid, npcobj, mArgs)
    record.error("war exception " .. self.m_sName)
    if npcobj then
        local oSceneMgr = global.oSceneMgr
        npcobj:ClearNowWar()
        oSceneMgr:NpcLeaveWar(npcobj)
    end
end

function CTempl:OnWarFightEnd(iWarId, pid, npcid, mArgs)
    local oWar = global.oWarMgr:GetWar(iWarId)
    if not oWar then
        return
    end
    local npcobj
    if npcid then
        npcobj = self:GetNpcObj(npcid)
    end
    if mArgs.war_exception then
        self:WarExceptionEnd(oWar, pid, npcobj, mArgs)
    else
        self:WarFightEnd(oWar, pid, npcobj, mArgs)
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local lPlayers = self:GetFighterList(oPlayer, mArgs)
    for _, iMemId in ipairs(lPlayers) do
        local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMemId)
        global.oTaskMgr:ResetPosForAnlei(oMem)
    end
end

-- @return {sKey = fCallback, ...}
function CTempl:DefineOtherCallbacks(oWar, pid, npcobj)
end

function CTempl:SetOtherCallbacks(oWar, pid, npcobj)
    if not oWar then return end
    local mDefs = self:DefineOtherCallbacks(oWar, pid, npcobj)
    if not mDefs then return end
    for sKey, fCallback in pairs(mDefs) do
        oWar:SetOtherCallback(sKey, fCallback)
    end
end

function CTempl:GetWarStartArgs(mTollgateData)
    local lActionIds = mTollgateData.action_id
    if type(lActionIds) == "number" then
        if lActionIds == 0 then
            lActionIds = nil
        else
            lActionIds = {lActionIds}
        end
    elseif type(lActionIds) == "table" then
        lActionIds = table_deep_copy(lActionIds)
    end
    local mArgs = {
        action_id = lActionIds,
    }
    mArgs = self:FillWarStartArgs(mTollgateData, mArgs)
    return mArgs
end

function CTempl:FillWarStartArgs(mTollgateData, mArgs)
    -- 喊话
    local iSpeekId = mTollgateData.speek_id or 0
    if iSpeekId ~= 0 then
        local mSpeekData = self:GetWarSpeekData(iSpeekId)
        assert(mSpeekData, string.format("fight speek err, speekid:%s, sName:%s", iSpeekId, self.m_sName))
        mArgs.speek = mSpeekData
    end
    -- local lActionIds = mArgs.action_id
    -- if lActionIds and type(lActionIds) ~= "table" then
    --     lActionIds = {lActionIds}
    --     mArgs.action_id = lActionIds
    -- end
    mArgs.speek_enable = true -- warspeek.CWarSpeekCtrl对象是否启用
    return mArgs
end

function CTempl:MarkWar(oWar,iPid,npcobj)
end

function CTempl:PackModelInfo(mData, oPlayer)
    local iFigureId = mData["figureid"]
    -- 玩家镜像特殊处理，需要oPlayer
    if iFigureId == gamedefines.ROLE_MODEL.PLAYER_MIRROR then
        assert(oPlayer, string.format("PackModel figureid call oPlayer.model_info err, figureid=%d", iFigureId))
        return table_deep_copy(oPlayer:GetModelInfo())
    end

    return global.oToolMgr:GetFigureModelData(iFigureId)
end

-- @Overrideable
function CTempl:GetPlayer2NpcConfig(npcobj)
    return npcobj:Name(), npcobj:ModelInfo()
end

-- @Overrideable
function CTempl:MakeMonsterModelByConfig(mMonsterData)
    return self:PackModelInfo(mMonsterData)
end

function CTempl:CreateMonster(oWar, iMonsterIdx, npcobj)
    local mExtArgs = self:MonsterCreateExt(oWar, iMonsterIdx, npcobj)
    local mData = self:GetMonsterData(iMonsterIdx)
    if not mData then
        record.warning("monster table err:"..self.m_sName..iMonsterIdx)
        return
    end

    local sName = mData["name"]
    local mModel

    local bMirror = false -- 镜像的定制度非常高，特殊处理
    local bSummon = false
    local mMirror
    if sName == "$npc" and npcobj then
        sName = npcobj:Name()
        mModel = npcobj:ModelInfo()
    elseif sName == "$player" and npcobj then
        sName, mModel = self:GetPlayer2NpcConfig(npcobj)
    elseif sName == "$mirror" then
        bMirror = true
        mMirror = self:GetMirrorMonsterData(mData, npcobj)
    elseif sName == "$mirror_summ" then
        mMirror = self:GetMirrorSummonMonsterData(mData, npcobj)
        if not mMirror then
            return nil
        end
        bMirror = true
        bSummon = true
    else
        mModel = self:MakeMonsterModelByConfig(mData)
    end
    local mAttrData = {}
    mAttrData["type"] = iMonsterIdx
    if mData["is_boss"] and mData["is_boss"] ~= 0 then
        mAttrData["is_boss"] = mData["is_boss"]
    end

    if bMirror then
        self:SetMirrorMonsterAttr(mAttrData, oWar, mData, mMirror, npcobj, bSummon)
    else
        -- 镜像可能使用了同样的逻辑
        mAttrData["name"] = sName
        mAttrData["model_info"] = mModel
        self:SetNormalMonsterGrade(mAttrData, oWar, mData)
        self:SetNormalMonsterAttr(mAttrData, oWar, mData, mExtArgs)
    end

    local oMonster = monster.NewMonster(mAttrData)
    self:OnMonsterCreate(oWar, oMonster, mData, npcobj)
    return oMonster
end

function CTempl:MonsterCreateExt(oWar, iMonsterIdx, oNpc)
    return {}
end

function CTempl:OnMonsterCreate(oWar, oMonster, mData, npcobj)
end

-- @Overrideable
-- 获取镜像母体
-- 不同的玩法生成镜像方式不同，高度定制
function CTempl:FindMirrorMonster(mMonsterData, npcobj)
end

-- @Overrideable
-- 取出镜像mData
function CTempl:GetMirrorMonsterData(mMonsterData, npcobj)
end

-- @Overrideable
-- 取出镜像宠物mData
function CTempl:GetMirrorSummonMonsterData(mMonsterData, npcobj)
end

-- @Overrideable
-- 设置镜像战斗属性
-- 不同的玩法生成镜像方式不同，高度定制
function CTempl:SetMirrorMonsterAttr(mAttrData, oWar, mData, mMirror, npcobj, bSummon)
    if npcobj then
        mAttrData["name"] = npcobj:Name()
        mAttrData["model_info"] = npcobj:ModelInfo()
    end
end

function CTempl:SetNormalMonsterGrade(mAttrData, oWar, mMonsterData)
    local mLevelArgs = {
        LV = oWar:GetTeamLeaderGrade(),
        ALV = oWar:GetTeamAveGrade(),
        MLV = oWar:GetTeamMaxGrade(),
        SLV = oWar:GetTeamMinGrade(),
        WLV = global.oWorldMgr:GetServerGrade(),
    }
    local sLevelFormula = mMonsterData["level"]
    local iLevel
    if tonumber(sLevelFormula) then
        iLevel = tonumber(sLevelFormula)
    else
        iLevel = math.floor(formula_string(sLevelFormula,mLevelArgs))
    end
    mAttrData["grade"] = iLevel
end

function CTempl:GetMonsterDataActiveSkills(mMonsterData, mExtArgs)
    return mMonsterData["activeSkills"] or {}
end

function CTempl:SetNormalMonsterAttr(mAttrData, oWar, mMonsterData, mExtArgs)
    local iLevel = mAttrData["grade"]
    mExtArgs = mExtArgs or {}

    local mPerform = {}
    local mAIPerform = {}
    local mActiveSkills = self:GetMonsterDataActiveSkills(mMonsterData, mExtArgs)

    for _,mSkill in pairs(mActiveSkills) do
        local iPerform = mSkill["pfid"]
        mPerform[iPerform] = extend.Table.clone(mSkill)
        mAIPerform[iPerform] = mSkill["ratio"]
    end

    for _, mSkill in pairs(mMonsterData["passiveSkills"] or {}) do
        local iPerform = mSkill["pfid"]
        mPerform[iPerform] = extend.Table.clone(mSkill)
    end

    mAttrData["perform"] = mPerform
    mAttrData["perform_ai"] = mAIPerform
    mAttrData["aitype"] = mMonsterData.aitype

    local mEnv = mExtArgs.env or {}
    mEnv["level"] = iLevel
    local mAttrs = {"phyAttack","magAttack","phyDefense","magDefense","speed","hp","mp","critRate","phy_hit_ratio", "phy_hit_res_ratio", "mag_hit_ratio", "mag_hit_res_ratio", "cure_power", "seal_ratio", "res_seal_ratio"}
    for _,sAttr in ipairs(mAttrs) do
        local sValue = mMonsterData[sAttr] or 0
        if tonumber(sValue) then
            mAttrData[sAttr] = tonumber(sValue)
        else
            local mArgs = {
                value = sValue,
                env = mEnv,
            }
            mAttrData[sAttr] = self:TransMonsterAble(oWar,sAttr,mArgs)
        end
        if extend.Table.find({"hp","mp"},sAttr) then
            local sMaxAttr = string.format("max%s",sAttr)
            mAttrData[sMaxAttr] = mAttrData[sAttr]
        end
    end
--    local mHitRatio = self:GetGlobalData(100)
--    mAttrData["hitRate"] = mHitRatio["value"]
    mAttrData["title"] = mMonsterData["title"]

    local mExpertFormula = mMonsterData["expertskill"] or {}
    local lExperts = {}
    local mLevelArgs = {
        LV = oWar:GetTeamLeaderGrade(),
        ALV = oWar:GetTeamAveGrade(),
        MLV = oWar:GetTeamMaxGrade(),
        SLV = oWar:GetTeamMinGrade(),
        WLV = global.oWorldMgr:GetServerGrade(),
        level  = iLevel,
    }
    for _, sFormula in pairs(mExpertFormula) do
        local iExpert = math.floor(formula_string(sFormula,mLevelArgs))
        table.insert(lExperts, iExpert)
    end
    mAttrData["expertskill"] = lExperts
end

function CTempl:NpcFuncGroup(sGroup)
    return string.format("%s.%s", sGroup, self.m_sName)
    -- return table_get_depth(gamedefines.NPC_FUNC_GROUP, {sGroup, self.m_sName})
end

function CTempl:GetEvent(npcid)
end

function CTempl:GetTriggerEvent()
end

function CTempl:WarFightEnd(oWar,pid,npcobj,mArgs)
    local win_side = mArgs.win_side
    if oWar.m_RewardDie then
        mArgs.m_RewardDie = true
    end
    -- npcobj可能是self对象内部所有npc，self在OnWarWin内可能Release，进而npcobj:Release
    if npcobj then
        local oSceneMgr = global.oSceneMgr
        npcobj:ClearNowWar()
        oSceneMgr:NpcLeaveWar(npcobj)
    end

    local sTempName = self.m_sName
    local lPlayer = mArgs.player[1]     --pve　camp=1为玩家
    if lPlayer and #lPlayer then
        local oWorldMgr = global.oWorldMgr
        for _, target in ipairs(lPlayer) do
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(target)
            local oTeam = oPlayer:HasTeam()
            if oTeam and oTeam:IsTeamMember(target) then
                pid = oTeam:Leader()
            else
                pid = target
            end
            break
        end
        mArgs = self:GetCustomArgs(mArgs, npcobj)
        if win_side == 1 then
            self:OnWarWin(oWar, pid, npcobj, {["warresult"]=mArgs})
        else
            self:OnWarFail(oWar, pid, npcobj, {["warresult"]=mArgs})
        end
    else
        record.error("no fighter, " .. sTempName)
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        if win_side == 1 then
            self:LogWarInfo(oPlayer, oWar.m_iIdx, 2)
            self:LogWarWanfaInfo(oPlayer, oWar.m_iIdx, 2)
        else
            self:LogWarInfo(oPlayer, oWar.m_iIdx, 3)
        end
    end
    -- TODO 考虑增加oTeamMgr:WarFightEnd处理入队
end

function CTempl:OnWarWin(oWar, pid, npcobj, mArgs)
    local iEvent = oWar.m_iEvent
    local mEvent = self:GetEventData(iEvent)
    self:DoScript(pid,npcobj,mEvent["win"],mArgs)
end

function CTempl:OnWarFail(oWar, pid, npcobj, mArgs)
    local iEvent = oWar.m_iEvent
    local mEvent = self:GetEventData(iEvent)
    self:DoScript(pid,npcobj,mEvent["fail"],mArgs)

    if not mArgs.silent then
        local oNotifyMgr = global.oNotifyMgr
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local lPlayer = self:GetFighterList(oPlayer,mArgs)
        for _,target in ipairs(lPlayer) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(target)
            if oTarget then
                oNotifyMgr:Notify(target,"战斗失败")
            end
        end
    end
end

function CTempl:DoScript(pid,npcobj,s,mArgs)
    if type(s) ~= "table" then
        return
    end
    for _,ss in pairs(s) do
        self:DoScript2(pid,npcobj,ss,mArgs)
    end
end

function CTempl:DoScriptCallbackList(pid,npcobj,s,mArgs)
    mArgs.forbidEvent = true
    self:DoScript(pid, npcobj, s, mArgs)
end

function CTempl:DoScriptCallbackUnit(pid,npcobj,s,mArgs)
    if type(s) ~= "string" then
        return
    end
    s = split_string(s, "|")
    self:DoScriptCallbackList(pid,npcobj,s,mArgs)
end

function CTempl:DoScript2(pid,npcobj,s,mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if not sCmd then return end
    local sArgs = string.sub(s, #sCmd + 1, -1)
    if not mArgs then
        mArgs = {}
    end

    if sCmd == "F" then
        local iFight = tonumber(sArgs)
        self:Fight(pid,npcobj,iFight)
        return true
    elseif sCmd == "SF" then
        -- 锁npc的战斗(其他人不能开战斗)
        local iFight = tonumber(sArgs)
        self:SingleFight(pid,npcobj,iFight)
        return true
    elseif sCmd == "R" then
        if npcobj then
            mArgs.npc=npcobj:Name()
        end
        self:Reward(pid,sArgs,mArgs)
        return true
    elseif sCmd == "TR" then
        if npcobj then
            mArgs.npc=npcobj:Name()
            mArgs.npctype = npcobj:Type()
        end
        local sArgs = string.sub(s,3,-1)
        self:TeamReward(pid,sArgs,mArgs)
        return true
    end
end

-- 获取战斗回调信息中的fighters
-- @param mArgs: {warresult = <.war.Callback.mArgs>, includeDie = <bool>}
function CTempl:GetFighterList(oPlayer, mArgs)
    local lPlayers = {}
    if mArgs and mArgs.warresult then
        local warresult = mArgs.warresult
        lPlayers = table_copy(warresult.player[1])
        local lDie = warresult.die[1]
        if lDie then
            lPlayers = list_combine(lPlayers, lDie)
        end
    end
    return lPlayers
end

function CTempl:GetFightSummon(oPlayer, mArgs)
    if mArgs and mArgs.warresult and mArgs.warresult.entersummon then
        local summid = mArgs.warresult.entersummon[oPlayer:GetPid()]
        if not summid then
            return nil
        end
        return oPlayer.m_oSummonCtrl:GetSummon(summid)
    else
        return oPlayer.m_oSummonCtrl:GetFightSummon()
    end
end

function CTempl:GetFightPartnerList(oPlayer, mArgs)
    return oPlayer.m_oPartnerCtrl:GetCurrLineupPos()
end

function CTempl:IsRewardValueValid(sValue)
    return sValue and sValue ~= "" and sValue ~= "0"
end

function CTempl:GenRewardContent(oPlayer, rewardinfo, mArgs, bPreview)
    local mContent = {}
    local lIdxs = rewardinfo["item"]
    local mAllItems = self:InitRewardItemList(oPlayer, lIdxs, mArgs, bPreview)
    if next(mAllItems) then
        mContent.items = mAllItems
    end

    local sExp = rewardinfo["exp"]
    local iExp = 0
    if self:IsRewardValueValid(sExp) then
        iExp = self:InitRewardExp(oPlayer, sExp, mArgs)
        if iExp > 0 then
            mContent.exp = iExp
        end
    end

    local sGold = rewardinfo["gold"]
    local iGold = 0
    if self:IsRewardValueValid(sGold) then
        iGold = self:InitRewardGold(oPlayer, sGold, mArgs)
        if iGold > 0 then
            mContent.gold = iGold
        end
    end

    local sGoldCoin = rewardinfo["goldcoin"]
    local iGoldCoin = 0
    if self:IsRewardValueValid(sGoldCoin) then
        iGoldCoin = self:InitRewardGoldCoin(oPlayer, sGoldCoin, mArgs)
        if iGoldCoin > 0 then
            mContent.goldcoin = iGoldCoin
        end
    end

    local sSilver = rewardinfo["silver"]
    local iSilver = 0
    if self:IsRewardValueValid(sSilver) then
        iSilver = self:InitRewardSilver(oPlayer, sSilver, mArgs)
        if iSilver > 0 then
            mContent.silver = iSilver
        end
    end

    local sCultivateExp = rewardinfo["cultivateexp"]
    local iCultivateExp = 0
    if self:IsRewardValueValid(sCultivateExp) then
        iCultivateExp = self:InitRewardCultivateExp(oPlayer, sCultivateExp, mArgs)
        if iCultivateExp > 0 then
            mContent.cultivateexp = iCultivateExp
        end
    end

    local sOrgOffer = rewardinfo["org_offer"]
    local iOrgOffer = 0
    if self:IsRewardValueValid(sOrgOffer) then
        iOrgOffer = self:InitRewardOrgOffer(oPlayer, sOrgOffer, mArgs)
        if iOrgOffer > 0 then
            mContent.org_offer = iOrgOffer
        end
    end

    local sSummExp = rewardinfo["summexp"]
    if self:IsRewardValueValid(sSummExp) then
        -- 这个比较特殊，每个单位都要单独计算
        mContent.summexp = sSummExp
    end

    local lSummList = rewardinfo["summon"]
    if type(lSummList) ~= "table" then
        local sSummSid = lSummList
        if self:IsRewardValueValid(sSummSid) then
            local iSummSid = self:InitRewardSummonSid(oPlayer, sSummSid, mArgs)
            if iSummSid > 0 then
                local iSummFixed = rewardinfo.summon_fixed
                mContent.summsid = {iSummSid, iSummFixed}
            end
        end
    else
        local mAllSumms = self:InitRewardSummList(oPlayer, lSummList, mArgs)
        if next(mAllSumms) then
            mContent.summons = mAllSumms
        end
    end

    local sPartnerExp = rewardinfo["partnerexp"]
    if self:IsRewardValueValid(sPartnerExp) then
        -- 这个比较特殊，每个单位都要单独计算
        mContent.partnerexp = sPartnerExp
    end

    local sPartnerSid = rewardinfo["partner"]
    local iPartnerSid = 0
    if self:IsRewardValueValid(sPartnerSid) then
        iPartnerSid = self:InitRewardParnterSid(oPlayer, sPartnerSid, mArgs)
        if iPartnerSid > 0 then
            mContent.partnersid = iPartnerSid
        end
    end

    local sRideSid = rewardinfo["ride"]
    local iRideSid = 0
    if self:IsRewardValueValid(sRideSid) then
        iRideSid = self:InitRewardRideSid(oPlayer, sRideSid, mArgs)
        if iRideSid > 0 then
            mContent.ridesid = iRideSid
        end
    end

    local sWuXun = rewardinfo["wuxun"]
    local iWuXun = 0
    if self:IsRewardValueValid(sWuXun) then
        iWuXun = self:InitRewardWuXun(oPlayer, sWuXun, mArgs)
        if iWuXun > 0 then
            mContent.wuxun = iWuXun
        end
    end

    local sJJCPoint = rewardinfo["jjcpoint"]
    local iJJCPoint = 0
    if self:IsRewardValueValid(sJJCPoint) then
        iJJCPoint = self:InitRewardJJCPoint(oPlayer, sJJCPoint, mArgs)
        if iJJCPoint > 0 then
            mContent.jjcpoint = iJJCPoint
        end
    end

    local sOrgPrestige = rewardinfo["orgprestige"]
    local iOrgPrestige = 0
    if self:IsRewardValueValid(sOrgPrestige) then
        iOrgPrestige = self:InitRewardOrgPrestige(oPlayer, sOrgPrestige, mArgs)
        if iOrgPrestige > 0 then
            mContent.orgprestige = iOrgPrestige
        end
    end

    mContent.mail_id = rewardinfo["mail"]
    return mContent
end

function CTempl:RewardLeaderPoint(oPlayer,sSource,sReason,iTeamSize)
    local oTeam = oPlayer:HasTeam()
    if oTeam and oTeam:IsLeader(oPlayer:GetPid()) and iTeamSize > 1 then
        local sSource = sSource or self.m_sName
        local sReason = sReason or self.m_sName
        oPlayer:RawRewardLeaderPoint(sSource,iTeamSize,sReason)
    end
end

function CTempl:RewardXiayiPoint(oPlayer, sSource, sReason)
    if oPlayer then
        oPlayer:RawRewardXiayiPoint(sSource,sReason)
    end
end

function CTempl:RewardFighterFilter(iLeaderPid, lFighterPid, fun)
    if fun then
        return fun(iLeaderPid, lFighterPid)
    else
        return lFighterPid
    end
end

-- 活动实现自己的发奖励接口,对战斗人员进行过滤
function CTempl:TryRewardFighterXiayiPoint(iLeaderPid, lFighterPid, mArgs)
    -- 过滤符合条件的玩家
    -- 发送奖励
end

function CTempl:TeamReward(pid, sIdx, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local lPlayers = self:GetFighterList(oPlayer, mArgs)
    for _,pid in ipairs(lPlayers) do
        self:Reward(pid, sIdx, mArgs)
    end
end

function CTempl:IsRewardValueValid(sValue)
    return sValue and sValue ~= "" and sValue ~= "0"
end

function CTempl:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    return true
end

function CTempl:GetRewardReason(mArgs)
    return self.m_sTempName or self.m_sName
end

function CTempl:Reward(pid, sIdx, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local iRewardId = tonumber(sIdx)
    if not iRewardId then
        return
    end

    local iRewardCheckCnt = 1
    if mArgs then
        iRewardCheckCnt = mArgs.reward_check_cnt or 1
    end
    if not self:CheckRewardMonitor(pid, iRewardId, iRewardCheckCnt, mArgs) then
        return
    end

    local mRewardInfo = self:GetRewardData(iRewardId)
    local mRewardContent = self:GenRewardContent(oPlayer, mRewardInfo, mArgs)
    self:RecordRewardInfo(oPlayer, mRewardContent)

    self:SendRewardContent(oPlayer, mRewardContent, mArgs)
    safe_call(self.TriggerSendReward, self, oPlayer, iRewardId)
    return mRewardContent 
end

-- 与Reward是平行接口
function CTempl:RewardByContent(oPlayer, iRewardId, mRewardContent, mArgs)
    local iRewardCheckCnt = 1
    if mArgs then
        iRewardCheckCnt = mArgs.reward_check_cnt or 1
    end
    if not self:CheckRewardMonitor(oPlayer:GetPid(), iRewardId, iRewardCheckCnt, mArgs) then
        return false
    end

    self:RecordRewardInfo(oPlayer, mRewardContent)

    self:SendRewardContent(oPlayer, mRewardContent, mArgs)
    return true
end

function CTempl:SendRewardContent(oPlayer, mRewardContent, mArgs)
    local iMailId = mRewardContent.mail_id

    mArgs = mArgs or {}
    -- 是否直接使用邮件发送
    local lSupportType = {}
    if iMailId and iMailId > 0 then
        lSupportType = global.oMailMgr:GetSupportType()
        local mReward = {}
        for sType, _ in pairs(lSupportType) do
            if sType == "items" then
                local lItems = {}
                local mAllItems = mRewardContent[sType]
                if mAllItems then
                    for itemidx, mItems in pairs(mAllItems) do
                        lItems = list_combine(lItems, mItems["items"])
                    end
                end
                mReward[sType] = lItems
            elseif sType == "summexp" then
                --
            elseif sType == "summons" then
                local mSumms = mRewardContent[sType]
                local lSummons = mReward[sType] or {}
                if mSumms and next(mSumms) then
                    for _, mSumm in pairs(mSumms) do
                        table.insert(lSummons, mSumm.summ)
                    end
                end
                mReward[sType] = lSummons
            else
                mReward[sType] = mRewardContent[sType]
            end
        end
        self:SendMail(oPlayer:GetPid(), iMailId, mReward, mArgs.mail_replace)
    end

    local lRecStatisArgs = {{}, 0, 0, 0}
    for sType, rValue in pairs(mRewardContent) do
        if lSupportType[sType] then
            goto continue
        end

        if sType == "items" then
            self:RewardItems(oPlayer, rValue, mArgs)
            lRecStatisArgs[1] = rValue
        elseif sType == "gold" and rValue > 0 then
            self:RewardGold(oPlayer, rValue, mArgs)
            lRecStatisArgs[2] = rValue
        elseif sType == "silver" and rValue > 0 then
            self:RewardSilver(oPlayer, rValue, mArgs)
            lRecStatisArgs[3] = rValue
        elseif sType == "org_offer" and rValue > 0 then
            self:RewardOrgOffer(oPlayer, rValue, mArgs)
            lRecStatisArgs[4] = rValue
        elseif sType == "exp" and rValue > 0 then
            self:RewardExp(oPlayer, rValue, mArgs)
        elseif sType == "cultivateexp" and rValue > 0 then
            self:RewardCultivateExp(oPlayer, rValue, mArgs)
        elseif sType == "goldcoin" and rValue > 0 then
            self:RewardGoldCoin(oPlayer, rValue, mArgs)
        elseif sType == "summsid" then
            self:RewardSummon(oPlayer, rValue, mArgs)
        elseif sType == "summons" then
            self:RewardSummList(oPlayer, rValue, mArgs)
        elseif sType == "partnersid" then
            self:RewardPartner(oPlayer, rValue, mArgs)
        elseif sType == "ridesid" then
            self:RewardRide(oPlayer, rValue, mArgs)
        elseif sType == "summexp" then
            self:RewardSummonExp(oPlayer, rValue, mArgs)
        elseif sType == "partnerexp" then
            self:RewardPartnerExp(oPlayer, rValue, mArgs)
        elseif sType == "wuxun" then
            self:RewardWuXun(oPlayer, rValue, mArgs)
        elseif sType == "jjcpoint" then
            self:RewardJJCPoint(oPlayer, rValue, mArgs)
        elseif sType == "orgprestige" then
            self:RewardOrgPrestigeByPlayer(oPlayer, rValue, mArgs)
        end
        ::continue::
    end

    safe_call(self.RecordRewardStatistics, self, table.unpack(lRecStatisArgs))
end

function CTempl:SendMail(iPid, iMailId, mReward, mReplace)
    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(iMailId)
    if mReplace then
        mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
    end
    oMailMgr:SendMailNew(0, sName, iPid, mData, mReward)
end

function CTempl:LogAnalyInfo(oPlayer)
end

function CTempl:RecordRewardInfo(oPlayer, mRewardContent)
    if not oPlayer then return end

    local mReward = oPlayer:GetTemp("reward_content")
    if not mReward then
        oPlayer:RecordAnalyContent()
        mReward = oPlayer:GetTemp("reward_content")
    end

    for itemidx, mItems in pairs(mRewardContent.items or {}) do
        for _, oItem in ipairs(mItems["items"] or {}) do
            local iSid = oItem:SID()
            mReward[iSid] = (mReward[iSid] or 0) + oItem:GetAmount()
        end
    end

    local iValue = mRewardContent.silver
    if iValue and iValue > 0 then
        mReward[1002] = (mReward[1002] or 0) + iValue
    end
    local iValue = mRewardContent.exp
    if iValue and iValue > 0 then
        mReward[1005] = (mReward[1005] or 0) + iValue
    end
    local iValue = mRewardContent.gold
    if iValue and iValue > 0 then
        mReward[1001] = (mReward[1001] or 0) + iValue
    end
    local iValue = mRewardContent.goldcoin
    if iValue and iValue > 0 then
        mReward[1003] = (mReward[1003] or 0) + iValue
    end
    local iValue = mRewardContent.org_offer
    if iValue and iValue > 0 then
        mReward[1008] = (mReward[1008] or 0) + iValue
    end
end

function CTempl:RecordRewardStatistics(mAllItems, iGold, iSilver, iOrgOffer)
    local res = require "base.res"
    local mData = res["daobiao"]["log"]["gamesys"][self.m_sStatisticsName]
    if not mData then
        -- record.warning("templ no record reward..: " .. self.m_sStatisticsName)
        return
    end

    local mReward = {}
    if iGold and iGold > 0 then
        mReward[1001] = iGold
    end

    if iSilver and iSilver > 0 then
        mReward[1002] = iSilver
    end

    if iOrgOffer and iOrgOffer > 0 then
        mReward[1008] = iOrgOffer
    end

    for itemidx, mItems in pairs(mAllItems) do
        for _, oItem in ipairs(mItems["items"] or {}) do
            local sid = oItem:SID()
            mReward[sid] = (mReward[sid] or 0) + oItem:GetAmount()
        end
    end

    statistics.system_collect_reward(self.m_sStatisticsName, mReward)
end

function CTempl:RecordTeamCnt(iPid, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local lPlayers = self:GetFighterList(oPlayer, mArgs)
    local mPid = {}
    for _,pid in ipairs(lPlayers) do
        mPid[pid] = true
    end
    self:RecordPlayerCnt(mPid)
end

function CTempl:RecordPlayerCnt(mPid)
    local res = require "base.res"
    local mData = res["daobiao"]["log"]["gamesys"][self.m_sStatisticsName]
    if not mData then
        -- record.warning("templ no record playerCnt..: " .. self.m_sStatisticsName)
        return
    end
    for iPid, _ in pairs(mPid) do
        statistics.system_collect_cnt(self.m_sStatisticsName, iPid)
    end
end

function CTempl:InitRewardExp(oPlayer, sExp, mArgs)
    local iExp = self:TransReward(oPlayer, sExp, mArgs)
    assert(iExp, string.format("templ reward exp err: %s", sExp))
    iExp = math.floor(iExp)
    return iExp
end

function CTempl:RewardExp(oPlayer, iExp,mArgs)
    if iExp <= 0 then return end
    mArgs = mArgs or {}
    mArgs.bEffect = self:PlayerExpEffect()
    local mResult = oPlayer:RewardExp(iExp, self:GetRewardReason(mArgs), mArgs)
    return mResult
end

function CTempl:InitRewardGold(oPlayer, sGold, mArgs)
    local iGold = self:TransReward(oPlayer, sGold, mArgs)
    assert(iGold, string.format("templ reward sGold err: %s", sGold))
    iGold = math.floor(iGold)
    return iGold
end

function CTempl:InitRewardGoldCoin(oPlayer, sGoldCoin, mArgs)
    local iGoldCoin = self:TransReward(oPlayer, sGoldCoin, mArgs)
    assert(iGoldCoin, string.format("templ reward sGold err: %s", sGoldCoin))
    iGoldCoin = math.floor(iGoldCoin)
    return iGoldCoin
end

function CTempl:InitRewardSilver(oPlayer, sSilver, mArgs)
    local iSilver = self:TransReward(oPlayer, sSilver, mArgs)
    assert(iSilver, string.format("templ reward silver err: %s", sSilver))
    iSilver = math.floor(iSilver)
    return iSilver
end

function CTempl:InitRewardOrgOffer(oPlayer, sOrgOffer, mArgs)
    local iOrgOffer = self:TransReward(oPlayer, sOrgOffer, mArgs)
    assert(iOrgOffer, string.format("templ reward orgoffer err: %s", sOrgOffer))
    iOrgOffer = math.floor(iOrgOffer)
    return iOrgOffer
end

function CTempl:InitRewardCultivateExp(oPlayer, sCultivateExp, mArgs)
    local iCultivateExp = self:TransReward(oPlayer, sCultivateExp, mArgs)
    assert(iCultivateExp, string.format("templ reward cultivateexp err: %s", sCultivateExp))
    iCultivateExp = math.floor(iCultivateExp)
    return iCultivateExp
end

function CTempl:InitRewardSummonSid(oPlayer, sSummSid, mArgs)
    local iSummSid = self:TransReward(oPlayer, sSummSid, mArgs)
    assert(iSummSid, string.format("templ reward summon sid err: %s", sSummSid))
    iSummSid = math.floor(iSummSid)
    return iSummSid
end

function CTempl:InitRewardParnterSid(oPlayer, sPartnerSid, mArgs)
    local iPartnerSid = self:TransReward(oPlayer, sPartnerSid, mArgs)
    assert(iPartnerSid, string.format("templ reward parnter sid err: %s", sPartnerSid))
    iPartnerSid = math.floor(iPartnerSid)
    return iPartnerSid
end

function CTempl:InitRewardRideSid(oPlayer, sRideSid, mArgs)
    local iRideSid = self:TransReward(oPlayer, sRideSid, mArgs)
    assert(iRideSid, string.format("templ reward ride sid err: %s", sRideSid))
    iRideSid = math.floor(iRideSid)
    return iRideSid
end

function CTempl:GetFortune(iMoneyType, mArgs)
    return true
end

function CTempl:RewardOrgOffer(oPlayer, iOrgOffer, mArgs)
    if iOrgOffer <= 0 then return end
    oPlayer:AddOrgOffer(iOrgOffer, self.m_sName, mArgs)
end

function CTempl:RewardGold(oPlayer, iGold, mArgs)
    if iGold <= 0 then return end
    mArgs = mArgs or {}
    mArgs.fortune = self:GetFortune(gamedefines.MONEY_TYPE.GOLD, mArgs)
    oPlayer:RewardGold(iGold, self:GetRewardReason(mArgs), mArgs)
end

function CTempl:RewardGoldCoin(oPlayer, iGoldCoin, mArgs)
    if iGoldCoin <= 0 then return end
    oPlayer:RewardByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldCoin, self.m_sName, mArgs)
end

function CTempl:RewardSilver(oPlayer, iSilver, mArgs)
    if iSilver <= 0 then return end
    mArgs = mArgs or {}
    mArgs.fortune = self:GetFortune(gamedefines.MONEY_TYPE.SILVER, mArgs)
    oPlayer:RewardSilver(iSilver, self:GetRewardReason(mArgs), mArgs)
end

function CTempl:RewardCultivateExp(oPlayer, iCultivateExp, mArgs)
    if iCultivateExp <= 0 then return end
    oPlayer:RewardCultivateExp(iCultivateExp, self.m_sName, mArgs)
end

function CTempl:RewardSummList(oPlayer, mAllSumms, mArgs)
    if not mAllSumms or not next(mAllSumms) then
        return
    end
    for iUnitIdx, mSumm in pairs(mAllSumms) do
        local oSummon = mSumm.summ
        if oSummon then
            local bSucc = oPlayer.m_oSummonCtrl:AddSummon(oSummon, self.m_sName)
            if not bSucc then
                baseobj_delay_release(oSummon)
            else
                local sMsg = global.oToolMgr:FormatColorString("你获得了宠物#summon", {summon = oSummon:Name()})
                oPlayer:NotifyMessage(sMsg)
            end
        end
    end
end

function CTempl:RewardSummon(oPlayer, mSummon, mArgs)
    if not mSummon then return end

    local iSummSid, iSummFixed = table.unpack(mSummon)
    if not iSummSid or iSummSid <= 0 then return end

    local oSummon = nil
    if iSummFixed and iSummFixed > 0 then
        oSummon = loadsummon.CreateFixedPropSummon(iSummSid, iSummFixed)
    else
        oSummon = loadsummon.CreateSummon(iSummSid, 0)
    end
    if oSummon then
        local bSucc = oPlayer.m_oSummonCtrl:AddSummon(oSummon, self:GetRewardReason(mArgs))
        if not bSucc then
            baseobj_delay_release(oSummon)
        else
            local sMsg = global.oToolMgr:FormatColorString("你获得了宠物#summon", {summon = oSummon:Name()})
            oPlayer:NotifyMessage(sMsg)
        end
    end
end

function CTempl:RewardSummonExp(oPlayer, sSummExp, mArgs)
    local oSummon = self:GetFightSummon(oPlayer, mArgs)
    if oSummon then
        local iSummExp = self:TransReward(oSummon, sSummExp, mArgs)
        assert(iSummExp, string.format("templ reward exp err: %s", sSummExp))
        iSummExp = math.floor(iSummExp)
        if iSummExp > 0 then
            mArgs = mArgs or {}
            mArgs.bEffect = self:SummonExpEffect()
            oSummon:RewardExp(iSummExp, self:GetRewardReason(mArgs), mArgs)
        end
    end
end

function CTempl:RewardPartner(oPlayer, iPartnerSid, mArgs)
    if not iPartnerSid or iPartnerSid <= 0 then return end
    local oPartner = loadpartner.CreatePartner(iPartnerSid, oPlayer:GetPid())
    if oPartner then
        local bSucc = oPlayer.m_oPartnerCtrl:AddPartner(oPartner, self:GetRewardReason(mArgs))
        if not bSucc then
            -- 给一个信物
            local mConfig = oPartner:GetInfoData()
            local mCost = mConfig["cost"]
            if mCost then
                local iSid, iAmount = mCost["id"], mCost["amount"]
                oPlayer:RewardItems(iSid, iAmount, self:GetRewardReason(mArgs))
            end
            baseobj_delay_release(oPartner)
        else
            local sMsg = global.oToolMgr:FormatColorString("你获得了伙伴#partner", {partner = oPartner:GetName()})
            oPlayer:NotifyMessage(sMsg)
        end
    end
end

function CTempl:RewardRide(oPlayer, iRideSid, mArgs)
    if not iRideSid or iRideSid <= 0 then return end
    local mConfigData = global.oRideMgr:GetRideConfigDataById(iRideSid)
    if not mConfigData then
        return
    end
    local bSucc, iErr = oPlayer.m_oRideCtrl:ExtendRide(iRideSid, true, self:GetRewardReason(mArgs))
    if bSucc then
        local sMsg = global.oToolMgr:FormatColorString("你获得了坐骑#ride_name", {ride_name = mConfigData.name})
        oPlayer:NotifyMessage(sMsg)
    end
end

function CTempl:RewardPartnerExp(oPlayer, sPartnerExp, mArgs)
    local lPartner = self:GetFightPartnerList(oPlayer, mArgs)
    for _, iPartner in ipairs(lPartner or {}) do
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartner)
        if oPartner then
            local iExp = math.floor(self:TransReward(oPartner, sPartnerExp, mArgs))
            assert(iExp, string.format("templ reward exp err: %s", sPartnerExp))
            if iExp > 0 then
                mArgs = mArgs or {}
                mArgs.bEffect = self:PartnerExpEffect()
                oPartner:RewardExp(iExp, self:GetRewardReason(mArgs), mArgs)
            end
        end
    end
end

function CTempl:InitRewardWuXun(oPlayer, sWuXun, mArgs)
    local iWuXun = self:TransReward(oPlayer, sWuXun, mArgs)
    assert(iWuXun, string.format("templ reward wuxun err: %s", sWuXun))
    iWuXun = math.floor(iWuXun)
    return iWuXun
end

function CTempl:RewardWuXun(oPlayer, iWuXun,mArgs)
    if iWuXun <= 0 then return end
    oPlayer:RewardWuXun(iWuXun, self:GetRewardReason(mArgs),mArgs)
end

function CTempl:InitRewardJJCPoint(oPlayer, sJJCPoint, mArgs)
    local iJJCPoint = self:TransReward(oPlayer, sJJCPoint, mArgs)
    assert(iJJCPoint, string.format("templ reward jjcpoint err: %s", sJJCPoint))
    iJJCPoint = math.floor(iJJCPoint)
    return iJJCPoint
end

function CTempl:RewardJJCPoint(oPlayer, iJJCPoint,mArgs)
    if iJJCPoint <= 0 then return end
    oPlayer:RewardJJCPoint(iJJCPoint, self:GetRewardReason(mArgs),mArgs)
end

function CTempl:InitRewardOrgPrestige(oPlayer, sOrgPrestige, mArgs)
    local oOrg = oPlayer:GetOrg()
    if not oPlayer or not oOrg then return 0 end

    mArgs = mArgs or {}
    if mArgs.argenv then
        mArgs.argenv["orglv"] = oOrg:GetLevel()
    else
        mArgs.argenv = {orglv=oOrg:GetLevel()}    
    end
    local iOrgPrestige = self:TransReward(oPlayer, sOrgPrestige, mArgs)
    assert(iOrgPrestige, string.format("templ reward orgprestige err: %s", sOrgPrestige))
    return math.floor(iOrgPrestige)
end

function CTempl:RewardOrgPrestigeByPlayer(oPlayer, iOrgPrestige, mArgs)
    local oOrg = oPlayer:GetOrg()
    if not oPlayer or not oOrg then return end

    oOrg:RewardPrestigeByPlayer(oPlayer:GetPid(), iOrgPrestige, self:GetRewardReason(mArgs))
end

function CTempl:GetRandomMax(itemidx, mArgs)
    return 10000
end

function CTempl:ChooseRewardKey(oPlayer, mRewardInfo, itemidx, mArgs)
    local iLimit = self:GetRandomMax(itemidx, mArgs)
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    if oPlayer and oPlayer.GetServerGrade then
        iServerGrade = oPlayer:GetServerGrade()
    end
    local mBackRewardInfo = {}
    for _, mItemUnit in pairs(mRewardInfo) do
        if mItemUnit.grade and mItemUnit.grade>iServerGrade then
            iLimit =  iLimit - mItemUnit["ratio"]
        else
            table.insert(mBackRewardInfo,mItemUnit)
        end
    end
    if iLimit<= 0 then
        return
    end

    local iRandom = math.random(iLimit)
    local iTotal = 0
    for _, mItemUnit in pairs(mBackRewardInfo) do
        iTotal = iTotal + mItemUnit["ratio"]
        if iRandom <= iTotal then
            return mItemUnit
        end
    end
end

function CTempl:TransItemShape(oPlayer, itemidx, iShape, sShape)
    return iShape, sShape, mShapeArgs
end

function CTempl:FindItemInFilter(oPlayer, iFilterId)
    local mFilterData = self:GetItemFilterData(iFilterId)
    local iPSex = oPlayer:GetSex()
    local iPRoleType = oPlayer:GetRoleType()
    local iPSchool = oPlayer:GetSchool()
    for _, mItemData in pairs(mFilterData) do
        -- TODO 数据结构可以优化hash
        local iSex = mItemData.sex
        local iRoleType = mItemData.roletype
        local iSchool = mItemData.school
        if iSex and iSex ~= iPSex then
            goto continue
        end
        if iRoleType and iRoleType ~= iPRoleType then
            goto continue
        end
        if iSchool and iSchool > 0 and iSchool ~= iPSchool then
            goto continue
        end
        if true then
            return mItemData.sid, mItemData.fixedid
        end
        ::continue::
    end
    return nil
end

-- 更新lItems
function CTempl:InitRewardItem(oPlayer, itemidx, mArgs, bPreview)
    if itemidx == 0 then
        return
    end
    local mRewardInfo = self:GetItemRewardData(itemidx)
    if not mRewardInfo then
        return
    end
    local mItemInfo = self:ChooseRewardKey(oPlayer, mRewardInfo, itemidx, mArgs)
    if not mItemInfo then return end

    return self:InitRewardByItemUnit(oPlayer, itemidx, mItemInfo, mArgs, bPreview)
end

function CTempl:PickOutItemShape(sShape)
    local iShape = tonumber(sShape)
    if iShape then
        return iShape
    end
    sShape = string.match(sShape,"(%d+).*")
    return tonumber(sShape)
end

-- @return: {
--    items = <list>{oItem, ...},
--    info = rewardTblItemInfo,
-- }
function CTempl:InitRewardByItemUnit(oPlayer, itemidx, mItemInfo, mArgs, bPreview)
    local mItems = {}
    local iSidType = mItemInfo["type"]
    local sShape = mItemInfo["sid"]
    local mItemArgs = self:InitItemArgs(mItemInfo["args"])
    if type(sShape) ~= "string" then
        print(debug.traceback(""))
        return
    end
    -- xShape 支持 <int> / <string>iSid(key=value,)

    local iShape = self:PickOutItemShape(sShape)
    local mShapeArgs
    iShape, sShape, mShapeArgs = self:TransItemShape(oPlayer, itemidx, iShape, sShape)
    if mShapeArgs then
        table_combine(mItemArgs, mShapeArgs)
    end
    local iFix
    if iShape and iSidType == gamedefines.REWARD_ITEM_SIDTYPE.FILTER then
        -- 载入rewardItemFilter表id筛选真正sid
        iShape, iFix = self:FindItemInFilter(oPlayer, iShape)
    end
    if not iShape then
        return
    end
    local iAmount = mItemInfo["amount"]
    if type(iAmount) == "string" then
        iAmount = math.floor(self:TransReward(oPlayer, iAmount, mArgs))
    end

    if bPreview then
        return {prev = {sid = iShape, amount = iAmount}}
    end

    local iBind = mItemInfo["bind"]
    while (iAmount > 0) do
        local oItem
        if iFix then
            oItem = global.oItemLoader:CreateFixedItem(iShape, iFix)
        else
            oItem = global.oItemLoader:ExtCreate(sShape, mItemArgs)
        end
        local sid = oItem:SID()
        local bCheckEquipable = mItemInfo["check_equip_role"]
        if bCheckEquipable and bCheckEquipable ~= 0 and oItem.m_ItemType == "equip" then
            if not global.oItemHandler:ValidRoleWield(oPlayer, oItem, true) then
                baseobj_delay_release(oItem)
                return
            end
        end

        if sid == ITEM_SUMMON_EXP then
            local oSummon = self:GetFightSummon(oPlayer, mArgs)
            if oSummon then
                oItem:SetData("summid", oSummon.m_iID)
            end
        end
        local iAddAmount = math.min(oItem:GetMaxAmount(),iAmount)
        iAmount = iAmount - iAddAmount
        oItem:SetAmount(iAddAmount)
        if iBind ~= 0 then
            oItem:Bind(oPlayer:GetPid())
        end
        local lItems = mItems["items"]
        if not lItems then
            lItems = {}
            mItems["items"] = lItems
        end
        table.insert(lItems, oItem)
    end
    mItems["info"] = mItemInfo
    return mItems
end

function CTempl:InitItemArgs(sArgs)
    if not sArgs or #sArgs <= 0 then
        return {}
    end
    return formula_string(sArgs, {})
end

-- @return: {
--    <int>itemrewardIdx = {
--      items = <list>{oItem, ...},
--      info = rewardTblItemInfo,
--    },
-- }
function CTempl:InitRewardItemList(oPlayer, lIdxs, mArgs, bPreview)
    local mAllItems = {}
    for _, idx in ipairs(lIdxs) do
        if not mAllItems[idx] then
            local mItems = self:InitRewardItem(oPlayer, idx, mArgs, bPreview)
            if mItems then
                mAllItems[idx] = mItems
            end
        end
    end
    return mAllItems
end

-- @return: {
--    summ = oSumm,
--    info = rewardTblSummInfo,
-- }
function CTempl:InitRewardBySummonUnit(oPlayer, iUnitIdx, mSummInfo, mArgs)
    local mSumm = {}
    -- local iSidType = mSummInfo["type"]
    local iSid = mSummInfo["sid"]
    if not iSid or iSid <= 0 then
        return
    end
    local iFixedProp = mSummInfo["fixed_prop"]
    local oSummon
    if iFixedProp and iFixedProp > 0 then
        oSummon = loadsummon.CreateFixedPropSummon(iSid, iFixedProp)
    else
        oSummon = loadsummon.CreateSummon(iSid, 0)
    end
    if not oSummon then
        return
    end
    mSumm.summ = oSummon
    mSumm.info = mSummInfo
    return mSumm
end

function CTempl:InitRewardSummon(oPlayer, iUnitIdx, mArgs)
    if iUnitIdx == 0 then
        return
    end
    local mRewardInfo = self:GetSummonRewardData(iUnitIdx)
    if not mRewardInfo then
        return
    end
    local mUnitInfo = self:ChooseRewardKey(oPlayer, mRewardInfo, iUnitIdx, mArgs)
    if not mUnitInfo then return end

    return self:InitRewardBySummonUnit(oPlayer, iUnitIdx, mUnitInfo, mArgs)
end

-- @return: {summRwdIdx = {summ = oSummon, info = rwdUnitInfo}, ...}
function CTempl:InitRewardSummList(oPlayer, lSummList, mArgs)
    local mAllSummons = {}
    for _, idx in ipairs(lSummList) do
        if not mAllSummons[idx] then
            local mSumm = self:InitRewardSummon(oPlayer, idx, mArgs)
            mAllSummons[idx] = mSumm
        end
    end
    return mAllSummons
end

function CTempl:GetSimpleItemsInfo(lItems)
    local mItemAmounts = {}
    if not lItems then
        return mItemAmounts
    end
    for _, oItem in ipairs(lItems) do
        local sid = oItem:SID()
        local iAmount
        if sid < 10000 then
            iAmount = oItem:GetData("Value", 0)
        else
            iAmount = oItem:GetAmount() or 0
        end
        mItemAmounts[sid] = (mItemAmounts[sid] or 0) + iAmount
    end
    return mItemAmounts
end

function CTempl:SimplifySummonReward(oPlayer, mAllSummons, mArgs)
    local mRes = {}
    for iUnitIdx, mSumm in pairs(mAllSummons) do
        mRes[iUnitIdx] = {sid = mSumm.info.sid, fixed_prop = mSumm.info.fixed_prop}
    end
    return mRes
end

function CTempl:SimplifyReward(oPlayer, mRewardContent, mArgs)
    local mContent = {}
    for sKey, value in pairs(mRewardContent) do
        if value then
            if (type(value) == "table" and next(value)) or (value ~= 0 and value ~= "" and value ~= "0") then
                mContent[sKey] = value
            end
        end
    end
    if mContent.items and next(mContent.items) then
        mContent.items = self:SimplifyItemReward(oPlayer, mContent.items, mArgs)
    else
        mContent.items = nil
    end
    if mContent.summons then
        if next(mContent.summons) then
            mContent.summons = self:SimplifySummonReward(oPlayer, mContent.summons, mArgs)
        else
            mContent.summons = nil
        end
    end
    return mContent
end

local mRewardKey2VirtualItemSid = {
    gold = 1001,
    silver = 1002,
    goldcoin = 1003,
    exp = 1005,
    org_offer = 1008,
}

function CTempl:GetRewardKeyVirtualSid(sKey)
    return mRewardKey2VirtualItemSid[sKey]
end

-- 全部转为itemsid:amount形式
function CTempl:SimplifyRewardToItems(oPlayer, mRewardContent, mArgs)
    local mContent
    local mRewardItemsContent = mRewardContent.items
    if mRewardItemsContent and next(mRewardItemsContent) then
        mContent = self:SimplifyItemReward(oPlayer, mRewardItemsContent, mArgs)
    else
        mContent = {}
    end
    for sKey, value in pairs(mRewardContent) do
        local iVirtualSid = self:GetRewardKeyVirtualSid(sKey)
        if iVirtualSid then
            if type(value) == "number" and value > 0 then
                mContent[iVirtualSid] = (mContent[iVirtualSid] or 0) + value
            end
        end
    end
    return mContent
end

function CTempl:SimplifyItemReward(oPlayer, mAllItems, mArgs)
    local mItemAmounts = {}
    for itemidx, mItems in pairs(mAllItems) do
        local lItems = mItems["items"]
        local mLocalItemAmounts = self:GetSimpleItemsInfo(lItems)
        for iSid, iAmount in pairs(mLocalItemAmounts) do
            mItemAmounts[iSid] = (mItemAmounts[iSid] or 0) + iAmount
        end
    end
    return mItemAmounts
end

function CTempl:RewardItems(oPlayer, mAllItems, mArgs)
    local res = require "base.res"
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr

    local sRoleName = oPlayer:GetName()
    for itemidx, mItems in pairs(mAllItems) do
        local mItemAmounts = {}
        local mItemNames = {}
        local lItems = mItems["items"]
        for _, oItem in ipairs(lItems) do
            local sid = oItem:SID()
            local amount = oItem:GetAmount()
            mItemAmounts[sid] = (mItemAmounts[sid] or 0) + amount
            if not mItemNames[sid] then
                mItemNames[sid] = oItem:TipsName()
            end

            oPlayer:RewardItem(oItem, self:GetRewardReason(mArgs), mArgs)
        end

        local lMsg = {}
        local lCw = {}
        local iHorse
        local mItemInfo = mItems["info"]
        local iSys = mItemInfo["sys"]
        if iSys then
            local mChuanwen = res["daobiao"]["chuanwen"][iSys]
            if mChuanwen then
                iHorse = mChuanwen.horse_race
            end
            for sid, sName in pairs(mItemNames) do
                local iAmount = mItemAmounts[sid]
                -- local sMsg = oToolMgr:FormatColorString("获得#amount个#item", {amount = iAmount, item = sName})
                -- table.insert(lMsg, sMsg)
                if mChuanwen then
                    mArgs = mArgs or {}
                    local npc=mArgs.npc or ""
                    local sCw = oToolMgr:FormatColorString(mChuanwen.content, {role = sRoleName, amount = iAmount, item = sName,npc=npc,sid=sid})
                    table.insert(lCw, sCw)
                end
            end
        end
        -- local sMsg = table.concat(lMsg, ",")
        -- if #sMsg > 0 then
        --     oChatMgr:HandleMsgChat(oPlayer, sMsg)
        -- end
        local sMsg = table.concat(lCw, ",")
        sMsg = self:GetMsgAdditon(sMsg, mArgs)
        if #sMsg > 0 then
            oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
        end
    end
end

function CTempl:TransMonsterAble(oWar,sAttr,mArgs)
    mArgs = mArgs or {}
    if extend.Table.find({"phyAttack","magAttack","phyDefense","magDefense","hp","mp","critRate","speed","phy_hit_ratio","phy_hit_res_ratio","mag_hit_ratio","mag_hit_res_ratio", "cure_power", "seal_ratio", "res_seal_ratio"},sAttr) then
        local sValue = mArgs.value
        if not sValue then
            return 0
        end
        local mEnv = mArgs.env
        local iValue = math.floor(formula_string(sValue,mEnv))
        return iValue
    end
end

function CTempl:GetRewardAddition(oAwardee)
    return nil
end

function CTempl:GetRewardEnv(oAwardee)
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    if oAwardee and oAwardee.GetServerGrade then
        iServerGrade = oAwardee:GetServerGrade()
    end
    return {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
    }
end

function CTempl:PreviewReward(oPlayer, iRewardId, mArgs)
    local mRewardData = self:GetRewardData(iRewardId)
    if not mRewardData then
        return nil
    end
    local mRewardContent = self:GenRewardContent(oPlayer, mRewardData, mArgs, true)
    local mAllItems = mRewardContent.items
    local iSilver = mRewardContent.silver
    local iExp = mRewardContent.exp
    local iCultivateExp = mRewardContent.cultivateexp
    local iOrgOffer = mRewardContent.org_offer
    local iGold = mRewardContent.gold
    local sSummExp = mRewardContent.summexp
    local sPartnerExp = mRewardContent.partnerexp
    local mItems = {}
    if mAllItems then
        for itemidx, mItem in pairs(mAllItems) do
            local mItemPrev = mItem["prev"]
            if mItemPrev then
                mItems[mItemPrev.sid] = mItemPrev.amount
            end
        end
    end
    local mValues = {}
    if iGold and iGold > 0 then
        mValues[1001] = iGold
    end
    if iSilver and iSilver > 0 then
        mValues[1002] = iSilver
    end
    if iExp and iExp > 0 then
        mValues[1005] = iExp
    end
    if iSummExp and iSummExp > 0 then
        mValues[1007] = iSummExp
    end
    if iOrgOffer and iOrgOffer > 0 then
        mValues[1008] = iOrgOffer
    end
    if iCultivateExp and iCultivateExp > 0 then
        mValues[1011] = iCultivateExp
    end
    if iPartnerExp and iPartnerExp > 0 then
        mValues[1012] = iPartnerExp
    end
    if not next(mItems) then mItems = nil end
    if not next(mValues) then mValues = nil end
    return {items = mItems, value = mValues}
end

-- @param oAwardee: 执行奖励的对象，可能是oPlayer/oSumm/oPartner
function CTempl:TransReward(oAwardee, sReward, mArgs)
    local oWorldMgr = global.oWorldMgr
    local mEnv = self:GetRewardEnv(oAwardee)
    local mAddition = self:GetRewardAddition(oAwardee)
    if type(mAddition) == "table" then
        table_combine(mEnv, mAddition)
    end
    local mArgEnv = mArgs and mArgs.argenv or nil
    if type(mArgEnv) == "table" then
        table_combine(mEnv, mArgEnv)
    end
    local iValue = formula_string(sReward, mEnv)
    return iValue
end

function CTempl:SendSceneChuanwenMsg(sName, iMapId, iSys)
    local oSceneMgr = global.oSceneMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local res = require "base.res"

    local mTips = {}
    if 0 ~= iMapId then
        local sSceneName = oSceneMgr:GetSceneName(iMapId)
        mTips = {role = sName, submitscene = sSceneName}
    else
        mTips = {role = sName}
    end

    local mChuanwen = res["daobiao"]["chuanwen"][iSys]
    local sMsg = oToolMgr:FormatColorString(mChuanwen.content, mTips)
    oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
end

function CTempl:GetMsgAdditon(sMsg, mArgs)
    return sMsg
end

function CTempl:GetCustomArgs(mArgs, npcobj, mAddition)
    mArgs["custom"] = mAddition or {}
    return mArgs
end

-- @Overrideable
function CTempl:GetCbSelfGetter()
    return nil
end

-- 异步发放奖励接口
function CTempl:AsyncReward(pid, sIdx, cbfunc, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:_AsyncReward2(oPlayer, sIdx, cbfunc)
    else
        oWorldMgr:LoadProfile(pid, function(oPlayer)
            self:_AsyncReward2(oPlayer, sIdx, cbfunc)
        end)
    end
end

function CTempl:_AsyncReward2(oPlayer, sIdx, cbfunc)
    if not oPlayer then
        cbfunc({})
        return
    end
    local iRewardId = tonumber(sIdx)
    if not iRewardId or iRewardId == 0 then
        cbfunc({})
        return
    end
    local mRewardInfo = self:GetRewardData(iRewardId)
    local mRewardContent = self:GenRewardContent(oPlayer, mRewardInfo, mArgs)
    cbfunc(mRewardContent)
end

function CTempl:TriggerSendReward(oPlayer, iReward)
    local oHuodong = global.oHuodongMgr:GetHuodong("collect")
    if not oHuodong then return end

    oHuodong:TriggerCollectReward(oPlayer:GetPid(), self.m_sName, iReward)    
end

function CTempl:CountRewardItemProbableGrids(oPlayer, iRewardId, mArgs)
    local mRewardInfo = self:GetRewardData(iRewardId)
    local lIdxs = mRewardInfo.item
    local iTotalCnt = 0
    for _, iItemIdx in ipairs(lIdxs) do
        local iCnt = self:CountRewardProbableGridsByItem(oPlayer, iItemIdx, mArgs)
        iTotalCnt = iTotalCnt + iCnt
    end
    return iTotalCnt
end

function CTempl:CountRewardProbableGridsByItem(oPlayer, iRewardItemIdx, mArgs)
    local mRewardItemInfo = self:GetItemRewardData(iRewardItemIdx)
    if not mRewardItemInfo then
        return 0
    end
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    if oPlayer and oPlayer.GetServerGrade then
        iServerGrade = oPlayer:GetServerGrade()
    end
    local iMaxCnt = 0
    for _, mItemUnit in pairs(mRewardItemInfo) do
        if not mItemUnit.grade or mItemUnit.grade <= iServerGrade then
            local iCnt = self:CountItemUnitGrids(oPlayer, mItemUnit, mArgs)
            if iCnt > iMaxCnt then
                iMaxCnt = iCnt
            end
        end
    end
    return iMaxCnt
end

function CTempl:CountItemUnitGrids(oPlayer, mItemUnit, mArgs)
    local iAmount = mItemUnit.amount
    if type(iAmount) == "string" then
        iAmount = math.floor(self:TransReward(oPlayer, iAmount, mArgs or {}))
    end
    if iAmount <= 0 then
        return 0
    end
    -- 遍历group或者filter中的物品id
    local iMaxGrids = 0
    for _, iItemSid in ipairs(self:GetItemUnitSids(oPlayer, mItemUnit)) do
        local oItem = global.oItemLoader:GetItem(iItemSid)
        local iGrids = 0
        if not oItem then
            iGrids = 0
        elseif oItem:ItemType() == "virtual" then
            iGrids = 0
        else
            local iOverlay = oItem:GetMaxAmount()
            iGrids = math.ceil(iAmount / iOverlay)
        end
        if iGrids > iMaxGrids then
            iMaxGrids = iGrids
        end
    end
    return iMaxGrids
end

function CTempl:GetItemUnitSids(oPlayer, mItemUnit)
    local sShape = mItemUnit.sid
    local iShape = self:PickOutItemShape(sShape)
    local iSidType = mItemUnit.type
    local iFix
    if not iShape then
        return {}
    end
    if iSidType == gamedefines.REWARD_ITEM_SIDTYPE.FILTER then
        iShape, iFix = self:FindItemInFilter(oPlayer, iShape)
    end
    if iShape >= 1000 then
        return {iShape}
    end
    local lItemGroup = global.oItemLoader:GetItemGroup(iShape)
    return lItemGroup
end

function CTempl:LogWarInfo(oPlayer, iFight, iOperate)
    analylog.LogWarInfo(oPlayer, self:LogKey(), iFight, iOperate)
end

function CTempl:IsLogWarWanfa()
    return false
end

function CTempl:LogKey()
    return self.m_sName
end

function CTempl:LogWarWanfaInfo(oPlayer, iFight, iOperate)
    if self:IsLogWarWanfa() then
        analylog.LogWanFaInfo(oPlayer, self:LogKey(), iFight, iOperate)
    end
end


