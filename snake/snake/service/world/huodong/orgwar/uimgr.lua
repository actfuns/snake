local global = require "global"
local extend = require "base.extend"


function NewUIMgr(...)
    return CUIMgr:New(...)
end

CUIMgr = {}
CUIMgr.__index = CUIMgr
inherit(CUIMgr, logic_base_cls())

function CUIMgr:New(...)
    local o = super(CUIMgr).New(self, ...)
    return o
end

function CUIMgr:GetScenePlayerInfo(oScene, iOrg)
    if not oScene then return end

    local mRecord = {}
    local lSingle = {}
    local lTeam = {}

    for iPid, _ in pairs(oScene.m_mPlayers) do
        if mRecord[iPid] then goto continue end

        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then goto continue end

        if oPlayer:GetOrgID() ~= iOrg then
            goto continue
        end

        local oTeam = oPlayer:HasTeam()
        if oTeam then
            for iMember, _ in pairs(oTeam:OnlineMember()) do
                mRecord[iMember] = 1
            end
            table.insert(lTeam, oTeam:PackTeamInfo())
        else
            mRecord[iPid] = 1
            table.insert(lSingle, self:PackSimpleInfo(oPlayer))
        end
        ::continue::
    end
    return lTeam, lSingle
end

function CUIMgr:PackSimpleInfo(oPlayer)
    local mInfo = {}
    mInfo.pid = oPlayer:GetPid()
    mInfo.name = oPlayer:GetName()
    mInfo.grade = oPlayer:GetGrade()
    mInfo.model_info = oPlayer:GetModelInfo()
    mInfo.icon = oPlayer:GetIcon()
    mInfo.school = oPlayer:GetSchool()
    return mInfo
end

function CUIMgr:OpenOrgWarTeamUI(oPlayer)
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iOrg = oPlayer:GetOrgID()
    local lTeam, lSingle = self:GetScenePlayerInfo(oScene, iOrg)
    local lTeamList = {}
    for _, mTeam in ipairs(lTeam) do
        local mTeamUnit = {}
        mTeamUnit.team_id = mTeam.teamid
        mTeamUnit.mem_list = mTeam.member
        mTeamUnit.leader = mTeam.leader
        table.insert(lTeamList, mTeamUnit)
    end

    local mNet = {}
    mNet.team_list = lTeamList
    mNet.single_list = lSingle
    oPlayer:Send("GS2COrgWarOpenTeamUI", mNet)
end

function CUIMgr:OpenOrgWarScoreUI(oPlayer, oScene)
    local lOrg = {}
    for _, iOrg in ipairs(oScene.m_lOrgList or {}) do
        local mOrg = self:PackSimpleWarScoreList(iOrg)
        table.insert(lOrg, mOrg)
--        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
--        if oOrg then
--            local mOrg = {}
--            mOrg.org_id = oOrg:OrgID()
--            mOrg.org_name = oOrg:GetName()
--            mOrg.org_score = oHuodong:GetOrgScoreByOrgId(iOrg, 0)
--            mOrg.score_list = self:PackOrgMemberWarScore(oOrg)
--            table.insert(lOrg, mOrg)
--        end
    end
    oPlayer:Send("GS2COrgWarOpenWarScoreUI", {org_list=lOrg})
end

function CUIMgr:PackSimpleWarScoreList(iOrg)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return {} end

    local mOrg = {}
    local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
    if oOrg then
        mOrg.org_id = oOrg:OrgID()
        mOrg.org_name = oOrg:GetName()
        mOrg.org_score = oHuodong:GetOrgScoreByOrgId(iOrg, 0)
        mOrg.score_list = self:PackOrgMemberWarScore(oOrg)
    end
    return mOrg
end

function CUIMgr:PackOrgMemberWarScore(oOrg)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    local mWarScoreTable = oHuodong:GetWarScoreTable()

    local lMember = {}
    for iMem, oMem in pairs(oOrg.m_oMemberMgr:GetMemberMap()) do
        if mWarScoreTable[iMem] then
            local mUnit = {}
            mUnit.score = mWarScoreTable[iMem]
            mUnit.pid = iMem
            mUnit.name = oMem:GetName()
            table.insert(lMember, mUnit)
        end
    end
--    table.sort(lMember, function(x,y)
--        if x.score == y.score then
--            return x.pid < y.pid
--        else
--            return x.score > y.score
--        end
--    end)
    return lMember
end

function CUIMgr:TryOpenMatchList(oPlayer, mMatchInfo, iWeekDay)
    local mMatchForward = mMatchInfo.match_forward
    local lMatchRet = mMatchInfo.match_ret

    local lMatchList = self:PackMatchInfo(mMatchForward, lMatchRet, iWeekDay)
    oPlayer:Send("GS2COrgWarOpenMatchList", {match_list=lMatchList})
end

function CUIMgr:PackMatchInfo(mMatchForward, lMatchRet, iWeekDay)
    local lMatchList = {}
    for iOrg1, iOrg2 in pairs(mMatchForward or {}) do
        local mMatchPair = {}
        local oOrg1 = global.oOrgMgr:GetNormalOrg(iOrg1)
        mMatchPair.org_unit1 = self:PackOrgMatchUnit(oOrg1, iWeekDay)
        local oOrg2 = global.oOrgMgr:GetNormalOrg(iOrg2)
        mMatchPair.org_unit2 = self:PackOrgMatchUnit(oOrg2, iWeekDay)
        table.insert(lMatchList, mMatchPair)
    end
    for _, iOrg in pairs(lMatchRet or {}) do
        local mMatchPair = {}
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        mMatchPair.org_unit1 = self:PackOrgMatchUnit(oOrg, iWeekDay)
        table.insert(lMatchList, mMatchPair)
    end
    
    return lMatchList
end

function CUIMgr:PackOrgMatchUnit(oOrg, iWeekDay)
    if not oOrg then return end

    return {
        org_id = oOrg:OrgID(),
        org_show_id = oOrg:ShowID(),
        org_name = oOrg:GetName(),
        org_boom = oOrg:GetBoom(),
        org_status = self:GetOrgStatus(oOrg, iWeekDay),
    }
end

function CUIMgr:GetOrgStatus(oOrg, iWeekDay)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    local mResult
    if iWeekDay == 2 then
        mResult = oHuodong:GetData("result2")
    elseif iWeekDay == 4 then
        mResult = oHuodong:GetData("result4")
    end

    if not mResult then return 0 end

    local iOrg = oOrg:OrgID()
    local iRet, iEnemy = oHuodong:GetEnemyOrgId(iOrg, iWeekDay)
    if not iEnemy then
        return 4
    end
    if mResult[iOrg] == 1 then
        return 1
    end
    if mResult[iOrg] == 2 then
        if mResult[iEnemy] == 2 then
            return 3
        else
            return 2
        end
    end
    return 0
end

