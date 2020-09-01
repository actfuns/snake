--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"

function NewRankMgr(...)
    local o = CRankMgr:New(...)
    return o
end

local RANK_LIST = {
    ["baike"] = "baike",
    ["biwu"] = "biwu",
    ["flower"] = "flower",
    ["grade"] = "grade",
    ["grade_school"] = "grade_school",
    ["jjc"] = "jjc" ,
    ["mengzhuorg"] = "mengzhuorg",
    ["mengzhuplayer"] = "mengzhuplayer",
    ["org_prestige"] = "org_prestige",
    ["player_score"] = "player_score",
    ["role_score"] = "role_score",
    ["score_school"] = "score_school",
    ["summon_score"] = "summon_score",
    ["upvote"] = "upvote",
    ["kaifu_grade"] = "kaifu_grade",
    ["kaifu_score"] = "kaifu_score",
    ["kaifu_summon"] = "kaifu_summon",
    ["kaifu_org"] = "kaifu_org",
    ["school_shushan"] = "school_shushan",
    ["school_jinshan"] = "school_jinshan",
    ["school_taichu"] = "school_taichu",
    ["school_yaochi"] = "school_yaochi",
    ["school_qingshan"] = "school_qingshan",
    ["school_yaoshen"] = "school_yaoshen",
    ["jubaopen_score"] = "jubaopen_score",
    ["fuyuan_box"] = "fuyuan_box",
    ["kill_ghost"] = "kill_ghost",
    ["kill_monster"] = "kill_monster",
    ["make_equip"] = "make_equip",
    ["resume_goldcoin"] = "resume_goldcoin",
    ["send_flower"] = "send_flower",
    ["strength_equip"] = "strength_equip",
    ["treasure_find"] = "treasure_find",
    ["wash_summon"] = "wash_summon",
    ["threebiwu"] = "threebiwu",
    ["luanshimoying_score"] = "luanshimoying_score",
    ["singlewar"] = "singlewar",
    ["imperialexam_firststage"] = "imperialexam_firststage",
    ["imperialexam_secondstage"] = "imperialexam_secondstage",
    ["worldcup"] = "worldcup",
}

CRankMgr = {}
CRankMgr.__index = CRankMgr
inherit(CRankMgr, logic_base_cls())


function CRankMgr:New()
    local o = super(CRankMgr).New(self)
    o.m_mRankObj = {}
    o.m_mName2RankObj = {}
    return o
end

function CRankMgr:GetRankObj(idx)
    if self.m_mRankObj[idx] then
        return self.m_mRankObj[idx]
    end

    local sName = self:GetRankName(idx)
    if not sName then return nil end

    local sPath = self:GetRankPath(sName)
    local sModule = import(service_path(sPath))
    local oRank = sModule.NewRankObj(idx, sName)
    oRank:OnLoaded()
    self.m_mRankObj[idx] = oRank
    self.m_mName2RankObj[sName] = oRank
    return oRank
end

function CRankMgr:GetRankObjByName(sName)
    return self.m_mName2RankObj[sName]
end

function CRankMgr:GetRankName(idx)
    local res = require "base.res"
    for id, mInfo in pairs(res["daobiao"]["rank"]) do
        if mInfo.idx == idx then
            return mInfo.name
        end
    end
end

function CRankMgr:GetAllRankInfo()
    local res = require "base.res"
    return res["daobiao"]["rank"]
end

function CRankMgr:NewHour(iHour,iDay)
    for idx, oRank in pairs(self.m_mRankObj) do
        safe_call(oRank.NewHour, oRank,iDay,iHour)
        if iHour == 0 then
            safe_call(oRank.NewDay, oRank, iDay)
        end
    end
end

function CRankMgr:OnUpdateName(iPid, sName)
    for idx, oRank in pairs(self.m_mRankObj) do
        safe_call(oRank.OnUpdateName, oRank, iPid, sName)
    end
end

function CRankMgr:OnUpdateOrgName(iOrgId, sName)
    for idx, oRank in pairs(self.m_mRankObj) do
        safe_call(oRank.OnUpdateOrgName, oRank, iOrgId, sName)
    end
end

function CRankMgr:OnLogin(iPid, bReEnter)
    for idx, oRank in pairs(self.m_mRankObj) do
        safe_call(oRank.OnLogin, oRank, iPid, bReEnter)
    end
end

function CRankMgr:OnLogout(iPid)
    for idx, oRank in pairs(self.m_mRankObj) do
        safe_call(oRank.OnLogout, oRank, iPid)
    end
end

function CRankMgr:GetRankPath(sName)
    assert (global.oDerivedFileMgr:ExistFile("common", sName), string.format("doesn't exist rank:%s", sName))
    return "common." .. sName
end

function CRankMgr:LoadAllRank()
    local mAllInfo = self:GetAllRankInfo()
    for id, mInfo in pairs(mAllInfo) do
        local idx, sName = mInfo.idx, mInfo.name
        if RANK_LIST[sName] then
            local sPath = self:GetRankPath(sName)
            local sModule = import(service_path(sPath))
            local oRank = sModule.NewRankObj(idx, sName)
            oRank:LoadDb()
            self.m_mRankObj[idx] = oRank
            self.m_mName2RankObj[sName] = oRank
        else
            record.warning(string.format("%s rank no register",sName))
        end
    end
end

function CRankMgr:Release()
    for idx, oRank in pairs(self.m_mRankObj) do
        baseobj_safe_release(oRank)
    end
    self.m_mRankObj = nil
    self.m_mName2RankObj = nil
    super(CRankMgr).Release(self)
end

function CRankMgr:CloseGS()
    for idx, oRank in pairs(self.m_mRankObj) do
        oRank:SaveDb()
    end

    baseobj_delay_release(self)
end

function CRankMgr:GetScoreSchoolConfigIdx(iSchool)
    local lSchoolIdx = {205, 206, 207, 208, 210, 209} --rank配表中的idx
    if table_in_list(lSchoolIdx, iSchool) then
        return iSchool
    elseif table_in_list(table_key_list(lSchoolIdx), iSchool) then
        return lSchoolIdx[iSchool]
    end
end
