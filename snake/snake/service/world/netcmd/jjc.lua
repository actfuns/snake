local global = require "global"

local max = math.max
local min = math.min


function C2GSOpenJJCMainUI(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end

    local oJJCMgr = global.oJJCMgr
    oJJCMgr:GetJJCMainInfo(oPlayer)
end

-- 设置竞技场上阵
function C2GSSetJJCFormation(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end

    local iFormation = mData.formation
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:SetJJCFormation(oPlayer, iFormation)
end

-- 设置竞技场上阵
function C2GSSetJJCSummon(oPlayer, mData)
    local iSummonId = mData.summonid
    
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:SetJJCSummon(oPlayer, iSummonId)
end

-- 设置竞技场上阵
function C2GSSetJJCPartner(oPlayer, mData)
    local lPartners = mData.partnerids
    
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:SetJJCPartner(oPlayer, lPartners)
end

-- 查看竞技场对手阵容
function C2GSQueryJJCTargetLineup(oPlayer, mData)
    local info = mData.target
    local iType = info.type
    local id = info.id

    local oJJCMgr = global.oJJCMgr
    oJJCMgr:QueryJJCTargetLineup(oPlayer, iType, id)
end

-- 竞技场挑战玩家
function C2GSJJCStartFight(oPlayer,mData)
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end

    local info = mData.target
    local iType = info.type
    local id = info.id

    local oJJCMgr = global.oJJCMgr
    oJJCMgr:StartFight(oPlayer, iType, id)
end

function C2GSJJCGetFightLog(oPlayer, mData)
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:GetJJCFightLog(oPlayer)
end

function C2GSJJCBuyFightTimes(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end

    local oJJCMgr = global.oJJCMgr
    oJJCMgr:JJCBuyFightTimes(oPlayer)
end

function C2GSJJCClearCD(oPlayer, mData)
    local oJJCMgr = global.oJJCMgr
    oJJCMgr:JJCClearCD(oPlayer)
end

function C2GSOpenChallengeUI(oPlayer, mData)
    do return end
    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:GetChallengeInfo(oPlayer)
end

-- 挑战玩法选择难度
function C2GSChooseChallenge(oPlayer, mData)
    local idx = mData.idx

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:ChooseChallengeLevel(oPlayer, idx)
end

function C2GSSetChallengeFormation(oPlayer, mData)
    local iFormation = mData.formation

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:SetChallengeFormation(oPlayer, iFormation)
end

function C2GSSetChallengeSummon(oPlayer, mData)
    local iSummId = mData.summonid

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:SetChallengeSummon(oPlayer, iSummId)
end

function C2GSSetChallengeFighter(oPlayer, mData)
    local lFighters = mData.fighters

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:SetChallengeFighter(oPlayer, lFighters)
end

-- 重设挑战玩法难度
function C2GSResetChallengeTarget(oPlayer, mData)
    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:ResetChallengeTarget(oPlayer)
end

-- 挑战玩法开始战斗
function C2GSStartChallenge(oPlayer, mData)
    local info = mData.target
    local iType = info.type
    local id = info.id

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:StartChallenge(oPlayer, iType, id)
end

-- 挑战玩法领取奖励
function C2GSGetChallengeReward(oPlayer, mData)
    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:GetChallengeReward(oPlayer)
end

-- 查看挑战玩法对手阵容
function C2GSChallengeTargetLineup(oPlayer, mData)
    local info = mData.target
    local iType = info.type
    local id = info.id

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:GetChallengeTargetLineup(oPlayer, iType, id)
end

function C2GSReceiveFirstGift(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end

    local oJJCMgr = global.oJJCMgr
    oJJCMgr:TryReceiveFirstGift(oPlayer)
end

function C2GSRefreshJJCTarget(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end

    local oJJCMgr = global.oJJCMgr
    oJJCMgr:C2GSRefreshJJCTarget(oPlayer)
end



