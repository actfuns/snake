--import module

local global = require "global"
local skynet = require "skynet"


function C2GSActivateRide(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:ActivateRide(oPlayer, mData["ride_id"])
end

function C2GSUseRide(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:UseRide(oPlayer, mData["ride_id"], mData["flag"])
end

function C2GSUpGradeRide(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:UpGradeRide(oPlayer, mData.flag)
end

function C2GSBuyRideUseTime(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:BuyRideUseTime(oPlayer, mData["sell_id"])
end

function C2GSRandomRideSkill(oPlayer, mData)
    local iFlag = mData["flag"]
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:RandomRideSkill(oPlayer, iFlag)
end

function C2GSShowRandomSkill(oPlayer, mData)
    local oRideMgr = global.oRideMgr
    oRideMgr:ShowRandomSkill(oPlayer)
end

function C2GSLearnRideSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:LearnRideSkill(oPlayer, mData["skill_id"])
end

-- flag 字段用于便捷购买
function C2GSForgetRideSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oRideMgr = global.oRideMgr
    oRideMgr:ForgetRideSkill(oPlayer, mData["skill_id"], mData["flag"])
end

function C2GSSetRideFly(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_SYS", oPlayer) then return end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if mData.fly == 1 and oScene and oScene:IsForbidFlyHorse() then
        oPlayer:NotifyMessage("此地有飞行管制，禁止飞行")
        return
    end

    local oRideMgr = global.oRideMgr
    oRideMgr:SetRideFly(oPlayer, mData["ride_id"], mData["fly"])
end

function C2GSGetRideInfo(oPlayer, mData)
    oPlayer.m_oRideCtrl:GS2CPlayerRideInfo("ride_infos")
end

function C2GSResetSkillInfo(oPlayer, mData)
    global.oRideMgr:GS2CResetSKillInfo(oPlayer)
end

function C2GSResetRideSkill(oPlayer, mData)
    global.oRideMgr:ResetRideSkill(oPlayer)
end

function C2GSBreakRideGrade(oPlayer, mData)
    local iFlag = mData["flag"]
    global.oRideMgr:BreakRideGrade(oPlayer, iFlag)
end

function C2GSWieldWenShi(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("RIDE_TY", oPlayer) then return end

    local iItemId = mData.itemid
    local iRide = mData.rideid
    local iPos = mData.pos
    global.oRideMgr:WieldWenShi(oPlayer, iRide, iItemId, iPos)    
end

function C2GSUnWieldWenShi(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("RIDE_TY", oPlayer) then return end

    local iRide = mData.rideid
    local iPos = mData.pos
    global.oRideMgr:UnWieldWenShi(oPlayer, iRide, iPos)    
end

function C2GSControlSummon(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("RIDE_TY", oPlayer) then return end

    local iRide = mData.rideid
    local iSummon = mData.summonid
    local iPos = mData.pos
    global.oRideMgr:ControlSummon(oPlayer, iRide, iSummon, iPos)
end

function C2GSUnControlSummon(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("RIDE_TY", oPlayer) then return end

    local iRide = mData.rideid
    local iPos = mData.pos
    global.oRideMgr:UnControlSummon(oPlayer, iRide, iPos)
end
