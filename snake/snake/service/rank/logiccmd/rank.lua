--import module
local global = require "global"
local skynet = require "skynet"
local playersend = require "base.playersend"
local interactive = require "base.interactive"
local extend = require "base.extend"
local netproto = require "base.netproto"
local net = require "base.net"

ForwardNetcmds = {}

function ForwardNetcmds.C2GSGetRankInfo(iPid, mData, mExt)
    local idx = mData.idx
    local iPage = mData.page
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObj(idx)
    if oRankObj then
        local mNet = oRankObj:PackShowRankData(iPid, iPage, mExt)
        playersend.Send(iPid, "GS2CGetRankInfo", mNet)
    end
end

function ForwardNetcmds.C2GSGetRankTop3(iPid, mData)
    local idx = mData.idx
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObj(idx)
    if oRankObj then
        local mNet = oRankObj:PackTop3RankData(iPid)
        playersend.Send(iPid, "GS2CGetRankTop3", mNet)
    end
end

function ForwardNetcmds.CleanRank(iPid, mData)
    local idx = mData.idx
    print("cg_debug CleanRank",idx)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObj(idx)
    if oRankObj then
        oRankObj.m_mRankData = {}
        oRankObj.m_lSortList = {}
        oRankObj.m_mShowData = {}
        oRankObj.m_mShowRank = {}
        oRankObj.m_mTop3Data = {}
        oRankObj.m_iFirstStub = 1
        oRankObj.m_lTitleList  = {}
    end
end

function ForwardNetcmds.C2GSGetRankSumInfo(iPid, mData)
    local oRankMgr = global.oRankMgr
    local iRankIdx = mData.idx
    local iRank = mData.rank
    local oRankObj = oRankMgr:GetRankObj(iRank)
    if oRankObj then
        local mNet = oRankObj:GetSumInfo(iRankIdx)
        if mNet then
            if not safe_call(playersend.Send,iPid,"GS2CSumBasciInfo",mNet) then
                print("cg_debug\n",mNet)
            end
        end
    end
end

function Forward(mRecord, mData)
    local oRankMgr = global.oRankMgr
    assert(oRankMgr, "there not exist rankmgr")

    local sCmd = mData.cmd
    local iPid = mData.pid
    local m = mData.data
    local mExt = mData.ext
    if sCmd ~= "CleanRank" and sCmd ~= "C2GSGetRankSumInfo" then
        local m = netproto.ProtobufFunc("default", sCmd, mData.data)
    end
    local func = ForwardNetcmds[sCmd]
    if func then
        func(iPid, m, mExt)
    end
end

function PushDataToRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rank_name
    local lNameList = {sRankName}
    if sRankName == "grade" then
        table.insert(lNameList, "grade_school")
    end
    
    if sRankName == "score_school" then
        local iSchool = mData.rank_data.school
        local lSchoolIdx = oRankMgr:GetScoreSchoolConfigIdx(iSchool)
        local oRankObj = oRankMgr:GetRankObj(lSchoolIdx)
        if oRankObj then
            oRankObj:PushDataToRank(mData.rank_data)
        end
        return
    end

    for _, sName in ipairs(lNameList) do
        local oRankObj = oRankMgr:GetRankObjByName(sName)
        if oRankObj then
            oRankObj:PushDataToRank(mData.rank_data)
        end
    end
end

function RemoveItemByKey(mRecord, mData)
    local iRank = mData.rank
    local key = mData.key
     local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObj(iRank)
    if oRankObj then
        oRankObj:RemoveItemByKey(key)
    end
end

function NewHour(mRecord,mData)
    local iHour = mData.hour
    local iDay = mData.day
    local oRankMgr = global.oRankMgr
    oRankMgr:NewHour(iHour,iDay)
end

function OnUpdateOrgName(mRecord, mData)
    local iOrgId = mData.orgid
    local sName = mData.name
    local oRankMgr = global.oRankMgr
    oRankMgr:OnUpdateOrgName(iOrgId, sName)
end

function OnUpdateName(mRecord, mData)
    local iPid = mData.pid
    local sName = mData.name
    local oRankMgr = global.oRankMgr
    oRankMgr:OnUpdateName(iPid, sName)
end

function OnLogin(mRecord, mData)
    local iPid = mData.pid
    local bReEnter = mData.reenter
    local oRankMgr = global.oRankMgr
    oRankMgr:OnLogin(iPid, bReEnter)
end

function OnLogout(mRecord, mData)
    local iPid = mData.pid
    local oRankMgr = global.oRankMgr
    oRankMgr:OnLogout(iPid)
end

function OnUpdateChairman(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("mengzhuorg")
    if oRankObj then
        local iOrg = mData.org_id
        local sName = mData.name
        oRankObj:OnUpdateChairman(iOrg, sName)
    end
end

function RequestRankShowData(mRecord, mData)
    local sRankName = mData.rank_name
    local iLimit = mData.rank_limit
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        local lResult = oRankObj:GetRankShowDataByLimit(iLimit)
        local mData = {data = lResult}
        interactive.Response(mRecord.source, mRecord.session, mData)
    else
        interactive.Response(mRecord.source, mRecord.session, {})
    end
end

function RequestJJCTarget(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    if oRankObj then
        local lTargets = oRankObj:RequestJJCTarget(mData.pid, mData.targets)
        interactive.Response(mRecord.source, mRecord.session, {
            targets = lTargets,
        })
    end
end

function RequestJJCRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    if oRankObj then
        local iRank = oRankObj:GetJJCRank(mData.pid, mData.type)
        interactive.Response(mRecord.source, mRecord.session, {
            rank = iRank,
        })
    end
end

function PushJJCInitData(mRecord, mData)
    local mInit = mData.data
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    if oRankObj then
        oRankObj:ResetRankData(mInit)
    end
end

function PushJJCDataToRank(mRecord, mData)
    local data = mData.data
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    if oRankObj then
        local iDefeatRank, iRank, bChange = oRankObj:PushDataToRank(data)
        interactive.Response(mRecord.source, mRecord.session, {
            defeaterank = iDefeatRank,
            rank = iRank,
            change = bChange,
        })
    end
end

function GetJJCRankList(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    if oRankObj then
        local mPids = oRankObj:GetJJCRankList()
        interactive.Response(mRecord.source, mRecord.session, {
            data = mPids,
        })
    end
end

function GS2CMengzhuOpenPlayerRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("mengzhuplayer")
    if oRankObj then
        oRankObj:GS2CMengzhuOpenPlayerRank(mData)
    end
end

function GS2CMengzhuOpenOrgRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("mengzhuorg")
    if oRankObj then
        oRankObj:GS2CMengzhuOpenOrgRank(mData)
    end
end

function MengzhuGetPlunderList(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("mengzhuplayer")
    if oRankObj then
        local lPlayerList = oRankObj:FilterPlunderList(mData)
        interactive.Response(mRecord.source, mRecord.session, {player_list=lPlayerList})
    end
end

function ClearMengzhuRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local lNameList = {"mengzhuplayer", "mengzhuorg"}
    for _, sName in ipairs(lNameList) do
        local oRankObj = oRankMgr:GetRankObjByName(sName)
        local iIdx = oRankObj.m_iRankIndex
        local sRankName = oRankObj.m_sRankName
        oRankObj:Init(iIdx, sRankName)
        oRankObj:Dirty()
    end
end

function MengzhuGetRankList(mRecord, mData)
    local mArgs = {}
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("mengzhuorg")
    mArgs.mengzhuorg = oRankObj.m_lSortList
    local oRankObj = oRankMgr:GetRankObjByName("mengzhuplayer")
    mArgs.mengzhuplayer = oRankObj.m_lSortList
    interactive.Response(mRecord.source, mRecord.session, mArgs)
end

function GetRankSortList(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sName = mData.rank_name
    local oRankObj = oRankMgr:GetRankObjByName(sName)
    local lSortList = oRankObj and oRankObj.m_lSortList or {}
    local mArgs = {sort_list = lSortList}
    interactive.Response(mRecord.source, mRecord.session, mArgs)
end

function GetTargetByRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    if oRankObj then
        local mRet = oRankObj:GetTargetByRank(mData.rank)
        interactive.Response(mRecord.source, mRecord.session, mRet)
    end
end

function GetJJCTop3(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("jjc")
    local mRet = {}
    if oRankObj and oRankObj:IsLoaded() then
        mRet = {data=oRankObj:GetJJCTop3()}
    end
    interactive.Response(mRecord.source, mRecord.session, mRet)
end

function GetScoreSchoolRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local iSchool = mData.school
    local lSchoolIdx = oRankMgr:GetScoreSchoolConfigIdx(iSchool)
    local oRankObj = oRankMgr:GetRankObj(lSchoolIdx)
    local lSortList = oRankObj and oRankObj.m_lSortList or {}
    local mArgs = {sort_list = lSortList}
    interactive.Response(mRecord.source, mRecord.session, mArgs)
end

function GetGradeSchoolRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("grade_school")
    local iSchool = mData.school
    local lSortList = oRankObj and oRankObj:GetSortListBySchool(iSchool) or {}
    local mArgs = {sort_list = lSortList, school = iSchool}
    interactive.Response(mRecord.source, mRecord.session, mArgs)
end

function SendHfdmRank(mRecord, mData)
    -- 画舫灯谜用的是baike的排行总榜
    local mPids = mData.pids
    local mOnePid = mData.one_pid
    local oRankObj = global.oRankMgr:GetRankObjByName("baike")
    local mArgs = {}
    if oRankObj then
        if mOnePid then
            oRankObj:SendHfdmRankForOne(mOnePid)
        elseif mPids then
            oRankObj:SendHfdmRank(mPids)
        end
    end
end

function GetBaikeWeekRankTop(mRecord, mData)
    local oRankObj = global.oRankMgr:GetRankObjByName("baike")
    local mArgs = {}
    if oRankObj then
        mArgs.net = oRankObj:PackBaikeWeekRankTop()
    else
        mArgs.net = {}
    end
    interactive.Response(mRecord.source, mRecord.session, mArgs)
end

function GetBaikeWeekRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("baike")
    local mArgs = {}
    if oRankObj then
        mArgs.net = oRankObj:PackWeekRankData2()
    else
        mArgs.net = {}
    end
    interactive.Response(mRecord.source, mRecord.session, mArgs)
end

function UpdateBaikeWeekRank(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("baike")
    if oRankObj then
        oRankObj:DoStubShowData()
    end
end

function GS2COrgPrestigeInfo(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("org_prestige")
    if oRankObj then
        oRankObj:GS2COrgPrestigeInfo(mData)
    end
end

function PushKaiFuDianLi(mRecord, mNet)
    local oRankMgr = global.oRankMgr
    local iFlag = mNet.flag
    local mData = mNet.data
    local mOrgData = mNet.kaifu_org or {}
    -- print("PushKaiFuDianLi\n")
    -- print(iFlag,mData)
    -- print(mOrgData)
    -- print("PushKaiFuDianLi\n")
    if iFlag == 1 then
        for _,sRankName in pairs({"kaifu_grade","kaifu_score","kaifu_summon"}) do
            if mData[sRankName] then
                local oRankObj = oRankMgr:GetRankObjByName(sRankName)
                if oRankObj and not oRankObj.m_bFrozen then
                    oRankObj:PushDataToRank(mData)
                end
            end
        end
    elseif iFlag == 2 then
        local oRankObj = oRankMgr:GetRankObjByName("kaifu_org")
        if oRankObj then
            for _,mSubData in pairs(mOrgData) do
                oRankObj:PushDataToRank(mSubData)
            end
        end
        for _, mSubData in ipairs(mData) do
            for _,sRankName in pairs({"kaifu_grade","kaifu_score","kaifu_summon"}) do
                local oRankObj = oRankMgr:GetRankObjByName(sRankName)
                if not oRankObj or oRankObj.m_bFrozen then
                    goto continue
                end
                if not mSubData[sRankName] then
                    goto continue
                end
                oRankObj:PushDataToRank(mSubData)
                ::continue::
            end
        end
    end
end

function GetKaiFuData(mRecord,mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rankname
    local mRespond = {}
    mRespond.rankname = sRankName
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        oRankObj.m_bFrozen = mData.frozen and true or false
        mRespond.rewarddata = oRankObj:PackRewardData()
    end
    interactive.Response(mRecord.source, mRecord.session, mRespond)
end

function GetJuBaoPenData(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rankname
    local mRespond = {}
    mRespond.rankname = sRankName
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        mRespond.rewarddata = oRankObj:PackRewardData()
    end
    interactive.Response(mRecord.source, mRecord.session, mRespond)
end

function ClearJuBaoOpen(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rankname
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        local iIdx = oRankObj.m_iRankIndex
        local sRankName = oRankObj.m_sRankName
        oRankObj:Init(iIdx, sRankName)
        oRankObj:Dirty()
    end
end

function RefreshJuBaoOpen(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rankname
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        oRankObj:NewHour()
    end
end

function RefreshSingleWarInfo(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rank_name
    local mRefresh = mData.refresh
    local iPid = mData.pid
    local iGroup = mData.group
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        mRefresh.rank = oRankObj:GetRankByPid(iGroup, iPid)
        local mNet = net.Mask("SingleWarInfo", mRefresh)
        playersend.Send(iPid, "GS2CSingleWarInfo", {info=mNet})
    end
end

function ClearSingleWarRankInfo(mRecord, mData)
    local oRankObj = global.oRankMgr:GetRankObjByName("singlewar")
    local mRank = {}
    if oRankObj then
        for iGroup, oRank in pairs(oRankObj.m_mRankMgr) do
            mRank[iGroup] = oRank:PackRankData()
            local iIdx = oRank.m_iRankIndex
            local sRankName = oRank.m_sRankName
            oRank:Init(iIdx, sRankName)
            oRank:Dirty()
        end
    end
    interactive.Response(mRecord.source, mRecord.session, {rank = mRank})
end

function RefreshRankByGroup(mRecord, mData)
    local iPid = mData.pid
    local iGroup = mData.group
    local oRankObj = global.oRankMgr:GetRankObjByName("singlewar")
    if oRankObj then
        local oRank = oRankObj.m_mRankMgr[iGroup]
        if oRank then
            local mData = oRank:PackRankData()
            local mNet = {
                group_id = iGroup,
                rank_info = mData.singlewar,
            }
            playersend.Send(iPid, "GS2CSingleWarRank", {rank=mNet})
        else
            playersend.Send(iPid, "GS2CSingleWarRank", {rank={group_id=iGroup}})
        end
    end
end

function GetImperialexamData(mRecord, mData)
    local oRankMgr = global.oRankMgr
    local sRankName = mData.rankname
    local mRespond = {}
    mRespond.rankname = sRankName
    local oRankObj = oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        mRespond.rankdata = oRankObj:PackImperialexamData()
    end
    interactive.Response(mRecord.source, mRecord.session, mRespond)
end

function RefreshWorldCup(mRecord, mData)
    local sRankName = mData.rank_name
    local oRankObj = global.oRankMgr:GetRankObjByName(sRankName)
    if oRankObj then
        oRankObj:DoStubShowData()
        oRankObj:RemoteGetTop3Profile()
        oRankObj:RemoveTitle()
        oRankObj:RewardTitle()
        oRankObj:Dirty()
    end
end