local global = require "global"
local res = require "base.res"
local gamedefines = import(lualib_path("public.gamedefines"))

function NewTestMgr(...)
    local oMgr = CTestMgr:New(...)
    return oMgr
end

CTestMgr = {}
CTestMgr.__index = CTestMgr
inherit(CTestMgr, logic_base_cls())

function CTestMgr:New()
    local o = super(CTestMgr).New(self)
    return o
end

function CTestMgr:TestWar(oPlayer, mData, fCallback)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    -- assert(not oNowWar,string.format("TestWar err HasWar %d", oPlayer:GetPid()))
    if oNowWar then
        oPlayer:NotifyMessage("你已经在战斗中了")
        return
    end

--    if mData.fight_idx then
--        self:DoFightByIdx(oPlayer, mData.fight_idx)
--        return
--    end

    local mWarInfo = {}
    local iWeather = mData["weather"]
    if iWeather and iWeather ~= 0 then
        mWarInfo.weather = iWeather
    end
    local iSkyWar = mData["sky_war"]
    if iSkyWar and iSkyWar ~= 0 then
        mWarInfo.sky_war = iSkyWar
    end
    local iBossWarType, iBossSize, iBossCnt
    local sBossWarType = mData["bosswar_type"]
    if sBossWarType and sBossWarType ~= "0" then
        local mArg = split_string(sBossWarType, ",")
        iBossWarType = tonumber(mArg[1])
        if mArg[2] then
            iBossSize = tonumber(mArg[2])
        else
            iBossSize = 1
        end
        if mArg[3] then
            iBossCnt = tonumber(mArg[3])
        else
            iBossCnt = 1
        end
    end
    if iBossWarType then
        mWarInfo.is_bosswar = true
    end
    mWarInfo.auto_start = 2
    mWarInfo.test_perform = mData.test_perform
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVE_TYPE, 
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_NONE, 
        mWarInfo)
    local ret
    if oPlayer:HasTeam() and oPlayer:IsTeamLeader() then
        ret = oWarMgr:TeamEnterWar(oPlayer,oWar:GetWarId(),{camp_id=1},true)
    else
        ret = oWarMgr:EnterWar(oPlayer, oWar:GetWarId(), {camp_id = 1}, true)
    end
    if ret.errcode ~= gamedefines.ERRCODE.ok then
        return
    end

    local mEnemy = {}
    local iCnt = mData["count"]
    for i=1,iCnt do
        local iSize
        if iBossCnt and i <= iBossCnt then
            iSize = iBossSize
        end
        local oMonster = self:CreateMonster(oWar, mData, iSize, i)
        if oMonster then
            table.insert(mEnemy, oMonster:PackAttr())
        end
    end
    local mFriend = {}
    local mMonster = {
        [1] = mFriend,
        [2] = mEnemy,
    }

    local mCampInfo = {}
    if iBossWarType then
        mCampInfo.boss_war_type = iBossWarType
    end
    mCampInfo.fmtinfo = {fmt_id=mData.fmt_id or 1, grade=mData.fmt_grade or 1}
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, mCampInfo)
    oWarMgr:PrepareWar(oWar:GetWarId(),mMonster)
    local func = fCallback or function (mArgs)
    end
    oWarMgr:SetCallback(oWar:GetWarId(), func)
    oWarMgr:StartWar(oWar:GetWarId())
    return oWar
end

function CTestMgr:CreateMonster(oWar, mData, iSize, idx)
    local extend = require "base/extend"
    local monster = import(service_path("monster"))

    local iLevel
    local mAttrData = {}
    if mData["level"] then
        iLevel = tonumber(mData["level"])
    else
        iLevel = oWar:GetTeamLeaderGrade()
    end
    mAttrData["grade"] = iLevel
    mAttrData["phy_hit_ratio"] = math.floor(100 + iLevel*0.5) 
    mAttrData["phy_hit_res_ratio"] = math.floor(5 + iLevel*0.5)
    mAttrData["name"] = "毛毛"..idx
    mAttrData["model_info"] = {
        shape = (mData.shape and mData.shape ~= 0) and mData.shape or 1110,
        scale = iSize
    }
    if iSize then
        mAttrData["is_boss"] = 1
    end

    local mPerform = {}
    local mAIPerform = {}
    local iAIType = mData.aitype
    if mData["active_skills"] then
        local mArg = split_string(mData["active_skills"], ",")
        for _,sPerform in ipairs(mArg) do
            if sPerform == "-1" then
                iAIType = gamedefines.AI_TYPE.DEFENSE
                break
            end
            if sPerform and sPerform ~= "0" then
                local pfinfo = split_string(sPerform, "|")
                local iPerform = tonumber(pfinfo[1])
                local mInfo = {
                    ai_target = tonumber(pfinfo[3]) or 2,
                    lv = tonumber(pfinfo[2]) or 1,
                }
                if #pfinfo < 4 or tonumber(pfinfo[4]) == idx then
                    mPerform[iPerform] = mInfo
                    mAIPerform[iPerform] = 1
                end
            end
        end
    end

    if mData["passive_skills"] then
        local mArg = split_string(mData["passive_skills"], ",")
        for _, sPerform in ipairs(mArg) do
            if sPerform and sPerform ~= "0" then
                local pfinfo = split_string(sPerform, "|")
                local iPerform = tonumber(pfinfo[1])
                if not iPerform then break end
                
                local lv = 1
                if #pfinfo >= 2 then
                    lv = tonumber(pfinfo[2])
                end
                if #pfinfo < 3 or tonumber(pfinfo[3]) == idx then
                    mPerform[iPerform] = lv
                end 
            end
        end
    end

    mAttrData["perform"] = mPerform
    mAttrData["perform_ai"] = mAIPerform
    if iAIType and iAIType > 0 then
        mAttrData["aitype"] = iAIType
    end

    local mAttrs = {
        phyAttack = "phy_attack",
        magAttack = "mag_attack",
        phyDefense = "phy_defense",
        magDefense = "mag_defense",
        speed = "speed",
        critRate = "crit_rate",
        dodgeRate = "dodge_rate",
        hp = "hp",
        mp = "mp"
    }
    for sAttr, sKey in pairs(mAttrs) do
        local sValue = mData[sKey]
        if tonumber(sValue) then
            mAttrData[sAttr] = tonumber(sValue)
        else
            local mEnv = {
                level  = iLevel,
                lv = iLevel,
            }
            mAttrData[sAttr] = math.max(0, formula_string(sValue, mEnv))
        end
        if extend.Table.find({"hp","mp"}, sAttr) then
            local sMaxAttr = string.format("max%s",sAttr)
            mAttrData[sAttr] = math.max(1, mAttrData[sAttr])
            mAttrData[sMaxAttr] = mAttrData[sAttr]
        end
    end

    local oMonster = monster.NewMonster(mAttrData)
    return oMonster
end

function CTestMgr:TryDoFightByIdx(oPlayer, sType, iFight)
    local mFight = res["daobiao"]["fight"][sType]
    if not mFight then
        oPlayer:NotifyMessage(string.format("cann't find %s", sType))
        return
    end
    local mTollgate = mFight["tollgate"][iFight]
    if not mTollgate then
        oPlayer:NotifyMessage(string.format("cann't find %s fight:%d", sType, iFight))
        return
    end

    local templ = import(service_path("templ"))
    local oFightTempl = templ.CTempl:New(sType)
    safe_call(self.DoFightByIdx, self, oPlayer, oFightTempl, iFight)
    baseobj_delay_release(oFightTempl)
end

function CTestMgr:DoFightByIdx(oPlayer, oFightTempl, iFight)
    local oNpc = global.oNpcMgr:GetGlobalNpc(5227)
    if not oNpc then return end

    oFightTempl:CreateWar(oPlayer:GetPid(), oNpc, iFight)
end

