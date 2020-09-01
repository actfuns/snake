--import module
local global  = require "global"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local CHuodong = import(service_path("huodong.huodongbase")).CHuodong


function NewHuodong(sHuodongName)
    return CTrapMine:New(sHuodongName)
end

CTrapMine = {}
CTrapMine.__index = CTrapMine
inherit(CTrapMine, CHuodong)

function CTrapMine:New(sHuodongName)
    local o = super(CTrapMine).New(self, sHuodongName)
    o.m_sName = sHuodongName
    return o
end

function CTrapMine:Init()
    self:TryStartRewardMonitor()
end

function CTrapMine:Trigger(oPlayer, iMapID)
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        return
    end
    if oPlayer and (oPlayer:IsSingle() or oPlayer:IsTeamLeader()) then
        local pid = oPlayer:GetPid()
        local iMember = math.max(1,oPlayer:GetMemberSize())
        local res = require "base.res"
        local mSceneMonster = res["daobiao"]["scenemonster"][iMapID]
        assert(mSceneMonster, string.format("CTrapMine:Trigger, scenemonster config data not exist, id:%d", iMapID))
        local lMonsterID = mSceneMonster.monster
        local lWarMonster = {}
        if lMonsterID and next(lMonsterID) then
            local iMonsterAmount = self:GetMonsterAmount(iMember)
            assert(iMonsterAmount > 0, "monster amount >= 0")
            local lWarMonster = {}
            for iCount = 1, iMonsterAmount do
                local iRanIndex = math.random(1,#lMonsterID)
                table.insert(lWarMonster, lMonsterID[iRanIndex])
            end
            local mData = self:GetTollGateData(iMember)
            local mWarInfo = self:InitWarInfo(mData)
            local mWarCampInfo = self:InitCampInfo(mData)
            self:CreateWar(oPlayer, mWarInfo, mWarCampInfo, lWarMonster, mSceneMonster.event)
        end
    end
end

function CTrapMine:GetMonsterAmount(iFight)
    local iMonsterAmount = 0
    local mFight = self:GetTollGateData(iFight)
    if mFight then
        local iTotal = 0
        local lWeigth = mFight.monster
        local iRan = math.random(1,100)
        for _, mData in pairs(lWeigth) do
            iTotal = iTotal + mData.weight
            if iRan <= iTotal then
                iMonsterAmount = mData.monster_count
                break
            end
        end
    end
    return iMonsterAmount
end

function CTrapMine:CreateWar(oPlayer, mWarInfo, mWarCampInfo, lMonster, iEvent)
    local oWarMgr = global.oWarMgr
    local oWorldMgr = global.oWorldMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVE_TYPE, 
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_TRAPMINE, 
        mWarInfo)
    local iWarID = oWar:GetWarId()
    local ret
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    assert(not oNowWar,string.format("war trapmine err %d",oPlayer.m_iPid))
    if oPlayer:HasTeam() then
        if oPlayer:IsTeamLeader() then
            ret = oWarMgr:TeamEnterWar(oPlayer,iWarID,{camp_id=1},true)
        else
            ret = oWarMgr:EnterWar(oPlayer, iWarID, {camp_id = 1}, true)
        end
    else
        ret = oWarMgr:EnterWar(oPlayer, iWarID, {camp_id = 1}, true)
    end
    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end

    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, mWarCampInfo)

    local mFriend = {}
    local mEnemy = {}
    for _, iMonsterIdx in pairs(lMonster) do
        local oMonster = self:CreateMonster(oWar,iMonsterIdx)
        if oMonster then
            table.insert(mEnemy, oMonster:PackAttr())
        end
    end
    local tableop = import(lualib_path("base.tableop"))
    local mMonster = {
        [1] = mFriend,
        [2] = mEnemy,
    }
    oWar.m_iEvent = iEvent
    oWarMgr:PrepareWar(iWarID, mMonster)
    local iPid = oPlayer:GetPid()
    local fCallback = function (mArgs)
        self:OnTrapMineWarFightEnd(iWarID, iPid, mArgs)
    end
    oWarMgr:SetCallback(iWarID, fCallback)
    oWarMgr:StartWar(iWarID)
    return oWar
end

function CTrapMine:OnTrapMineWarFightEnd(iWar, pid, mArgs)
    local oWar = global.oWarMgr:GetWar(iWar)
    self:WarFightEnd(oWar, pid, nil, mArgs)
end
