local global = require "global"
local extend = require "base.extend"
local interactive = require "base.interactive"
local res = require "base.res"
local record = require "public.record"
local router = require "base.router"
local loadtitle = import(service_path("title.loadtitle"))


function NewRankMgr(...)
    local o = CRankMgr:New(...)
    return o
end

CRankMgr = {}
CRankMgr.__index = CRankMgr
inherit(CRankMgr, logic_base_cls())

function CRankMgr:New()
    local o = super(CRankMgr).New(self)
    o.m_mShowRank = {}
    return o
end

function CRankMgr:PushDataToRank(sName, mData)
    local mInfo = {}
    mInfo.rank_name = sName
    mInfo.rank_data = mData
    interactive.Send(".rank", "rank", "PushDataToRank", mInfo)
end

function CRankMgr:PushDataToGSRank(sServerTag, iPid, sName, mData)
    local mInfo = {}
    mInfo.pid = iPid
    mInfo.rank_name = sName
    mInfo.rank_data = mData
    router.Send(sServerTag, ".world", "kuafu_gs", "KS2GSPushData2Rank", mInfo)
end

function CRankMgr:PushDataToGradeRank(oPlayer)
    local iLimitGrade = res["daobiao"]["open"]["RANK_SYS"]["p_level"]
    if oPlayer:GetGrade() < iLimitGrade then
        return
    end
    local mData = {}
    mData.pid = oPlayer:GetPid()
    mData.grade = oPlayer:GetGrade()
    mData.name = oPlayer:GetName()
    mData.school = oPlayer:GetSchool()
    mData.exp = oPlayer:GetExp()
    mData.time = get_time()
    self:PushDataToRank("grade", mData)
end

function CRankMgr:PushDataToUpvoteRank(oPlayer)
    local mData = {}
    mData.pid = oPlayer:GetPid()
    mData.upvote = oPlayer:GetUpvoteAmount()
    mData.time = get_time()
    mData.active_time = get_time()
    mData.name = oPlayer:GetName()
    mData.school = oPlayer:GetSchool()
    self:PushDataToRank("upvote", mData)
end

function CRankMgr:PushDataToSchoolScoreRank(oPlayer, iScore)
    local mData = {}
    mData.pid = oPlayer:GetPid()
    mData.score = iScore
    mData.name = oPlayer:GetName()
    mData.school = oPlayer:GetSchool()
    mData.time = get_time()
    mData.orgname = oPlayer:GetOrgName()
    self:PushDataToRank("score_school", mData)
end

function CRankMgr:PushDataToMengzhuPlayer(oPlayer)
    local mData = {}
    local iPid = oPlayer:GetPid()
    local oMengzhu = global.oHuodongMgr:GetHuodong("mengzhu")
    mData.point = oMengzhu:GetPlayerPoint(iPid)
    mData.grade = oPlayer:GetGrade()
    mData.time = get_time()
    mData.pid = oPlayer:GetPid()
    mData.name = oPlayer:GetName()
    mData.school = oPlayer:GetSchool()
    mData.orgid = oPlayer:GetOrgID()
    mData.orgname = oPlayer:GetOrgName()
    self:PushDataToRank("mengzhuplayer", mData)
end

function CRankMgr:PushDataToMengzhuOrg(oOrg)
    local mData = {}
    local oMengzhu = global.oHuodongMgr:GetHuodong("mengzhu")
    mData.orgid = oOrg:OrgID()
    mData.time = get_time()

    if oOrg:GetMemberCnt() > 0 then
        mData.orgname = oOrg:GetName()
        mData.chairman = oOrg:GetLeaderName()
        mData.point = oMengzhu:GetOrgPoint(oOrg:OrgID())
        mData.total = oMengzhu:GetOrgCount(oOrg:OrgID())
    else
        mData.orgname = ""
        mData.chairman = ""
        mData.point = 0
        mData.total = 0
    end
    self:PushDataToRank("mengzhuorg", mData)
end

function CRankMgr:SetUpvoteShowRank(sRankName, mShowRank)
    self.m_mShowRank[sRankName] = mShowRank
end

function CRankMgr:RequestRankShowData(sRankName, iLimit, callback)
    local mData = {rank_name = sRankName, rank_limit = iLimit}
    interactive.Request(".rank", "rank", "RequestRankShowData", mData,
    function(mRecord, mData)
        callback(mData.data)
    end)
end

function CRankMgr:GetUpvoteShowRank(iPid)
    local mInfo = self.m_mShowRank["upvote"] or {}
    return mInfo[iPid]
end

function CRankMgr:OnUpdateOrgName(iOrgId, iOrgName)
    local mData = {
        name = iOrgName,
        orgid = iOrgId,
    }
    interactive.Send(".rank", "rank", "OnUpdateOrgName", mData)
end

function CRankMgr:OnUpdateName(iPid, sName)
    local mData = {
        name = sName,
        pid = iPid,
    }
    interactive.Send(".rank", "rank", "OnUpdateName", mData)
end

function CRankMgr:OnLogin(oPlayer, bReEnter)
    self:RefreshRankByPid(oPlayer:GetPid())
    self:KS2GSLoginEveryDayRank(oPlayer, bReEnter)

    local mData = {
        pid = oPlayer:GetPid(),
        reenter = bReEnter,
    }
    interactive.Send(".rank", "rank", "OnLogin", mData)
end

function CRankMgr:OnLogout(oPlayer)
    local mData = {
        pid = oPlayer:GetPid(),
    }
    interactive.Send(".rank", "rank", "OnLogout", mData)
end

function CRankMgr:OnUpdateChairman(iOrg, sNewName)
    local mData = {
        org_id = iOrg,
        name = sNewName,
    }
    interactive.Send(".rank", "rank", "OnUpdateChairman", mData)
end

function CRankMgr:RankReward(mData)
    for _, mInfo in ipairs(mData) do
        global.oTitleMgr:AddTitle(mInfo.pid,mInfo.title)
    end
end

function CRankMgr:RemoveTitle(mData)
    if mData["plist"] then
        for _, mInfo in pairs(mData["plist"]) do
            global.oTitleMgr:RemoveOneTitle(mInfo.pid,mInfo.title)
        end
    end
end

function CRankMgr:NewHour(mNow)
    local iDay = mNow.date.wday
    local iHour = mNow.date.hour

    local mPlayer = global.oWorldMgr:GetOnlinePlayerList()
    local plist = table_key_list(mPlayer)
    local exec_cb = function (pid)
        self:RefreshRankByPid(pid)
    end
    local end_cb = function ()
        self:NewHourEnd(mNow)
    end
    global.oToolMgr:ExecuteList(plist, 500, 1000, 0, "rank_newhour", exec_cb, end_cb)
end

function CRankMgr:RefreshRankByPid(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return 
    end
    if not global.oToolMgr:IsSysOpen("RANK_SYS", oPlayer, true) then
        return
    end

    oPlayer:PushPlayerScoreRank()
    oPlayer:PushRoleScoreRank()
    oPlayer:PushSumScoreRank()
    self:PushDataToGradeRank(oPlayer)
    self:PushDataToSchoolScoreRank(oPlayer, oPlayer:GetScore())

    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHuodong then
        oHuodong:TryPushData2Rank(oPlayer)
    end
end

function CRankMgr:NewHourEnd(mNow)
    local oHD = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHD then
        oHD:PushOrgData2Rank()
    end

    local iDay = mNow.date.wday
    local iHour = mNow.date.hour
    interactive.Send(".rank", "rank", "NewHour", {day=iDay,hour = iHour})

    if oHD then
        oHD:CheckQueryRank(mNow)
    end
end

function CRankMgr:DeleteSummon(oSummon)
    local iOwner , iTraceNo = table.unpack(oSummon:GetData("traceno",{-1,-1}))
    iOwner = oSummon:GetOwner()
    if iTraceNo == -1 then
        record.warning(string.format("delete_sum_rank %s %s %s",iOwner,oSummon:GetName(),iTraceNo))
    end
    local sKey = string.format("%s_%s",math.floor(iOwner),math.floor(iTraceNo))
    interactive.Send(".rank", "rank", "RemoveItemByKey", {rank = 108,key = sKey})
    interactive.Send(".rank", "rank", "RemoveItemByKey", {rank = 203,key = db_key(iOwner)})
end

function CRankMgr:PushDataToOrgPrestige(oOrg, bDelete)
    local mData = {}
    if not oOrg:GetLeaderID() or bDelete then
        mData = {
            orgid = oOrg:OrgID(),
            prestige = 0,
        }
    else
        mData = {
            orgid = oOrg:OrgID(),
            prestige = oOrg:GetPrestige(),
            orgname = oOrg:GetName(),
            leadpid = oOrg:GetLeaderID(),
            leadname = oOrg:GetLeaderName(),
            orglv = oOrg:GetLevel(),
        }
    end
    self:PushDataToRank("org_prestige", mData)
end

function CRankMgr:MergeFinish()
    interactive.Send(".rank", "merger", "MergeFinish", {})
end


function CRankMgr:KS2GSLoginEveryDayRank(oPlayer, bReEnter)
    --跨服回原服的登录
    for _, sType in ipairs({"make_equip", "wash_summon", "kill_ghost", "kill_monster", "strength_equip"}) do
        local sKuafuKey = "kuafu_"..sType.."cnt"
        local iAdd = oPlayer.m_oTodayMorning:Query(sKuafuKey, 0)
        oPlayer.m_oTodayMorning:Delete(sKuafuKey)
        if iAdd > 0 then
            self:PushDataToEveryDayRank(oPlayer, sType, {cnt=iAdd})
        end
    end
end

function CRankMgr:KS2GSPushDataToEveryDayRank(mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("everydayrank")
    if not oHuodong or not oHuodong:InGameTime() then
        return
    end

    --防止时间误差导致数据重置
    local sType = mData.type
    local iDayNo = mData.dayno
    if not oHuodong:CanPushRankData(sType, iDayNo) then
        return
    end

    local iCnt = mData.old_cnt + mData.new_cnt
    local mData = {
        cnt = iCnt,
        score = mData.score,
        time = get_time(),
        pid = mData.pid,
        name = mData.name,
        school = mData.school,
    }
    self:PushDataToRank(sType, mData)
end

function CRankMgr:PushDataToEveryDayRank(oPlayer, sType, mArgs)
    if is_ks_server() and mArgs.cnt then
        local sKey = "kuafu_"..sType.."cnt"
        local iCnt = oPlayer.m_oTodayMorning:Query(sKey, 0) + mArgs.cnt
        oPlayer.m_oTodayMorning:Set(sKey, iCnt)
        local sKey = sType.."cnt"
        local iOld = oPlayer.m_oTodayMorning:Query(sKey, 0)
        local mArgs = {
            dayno = oPlayer.m_oTodayMorning:GetTimeNo(),
            old_cnt = iOld,
            new_cnt = iCnt,
            type = sType,
            score = oPlayer:GetScore(),
            pid = oPlayer:GetPid(),
            name = oPlayer:GetName(),
            school = oPlayer:GetSchool(),
        }
        local sServerTag = global.oWorldMgr:GetServerKey(oPlayer:GetPid())
        router.Send(sServerTag, ".world", "kuafu_gs", "KS2GSPushDataToEveryDayRank", mArgs)
        return
    end

    local oHuodong = global.oHuodongMgr:GetHuodong("everydayrank")
    if not oHuodong or not oHuodong:InGameTime() then
        return
    end

    --防止时间误差导致数据重置
    local iDayNo = oPlayer.m_oTodayMorning:GetTimeNo()
    if not oHuodong:CanPushRankData(sType, iDayNo) then
        return
    end
    if not mArgs.cnt then return end

    local sKey = sType.."cnt"
    local iCnt = oPlayer.m_oTodayMorning:Query(sKey, 0) + mArgs.cnt
    oPlayer.m_oTodayMorning:Set(sKey, iCnt)

    local mData = {
        cnt = iCnt,
        score = oPlayer:GetScore(),
        time = get_time(),
        pid = oPlayer:GetPid(),
        name = oPlayer:GetName(),
        school = oPlayer:GetSchool(),
    }
    self:PushDataToRank(sType, mData)
end

function CRankMgr:MailRankReward(mData)
    if not mData then return end
    for idx, mInfo in ipairs(mData.rank_list) do
        local iPid = tonumber(mInfo.pid)
        local iTitleSid = mInfo.title
        local oItem = global.oItemLoader:Create(iTitleSid)
        local mTitle = loadtitle.GetTitleDataByTid(oItem:CalItemFormula())
        local mMail, sName = global.oMailMgr:GetMailInfo(2055)
        local mReplace = {
            rank = mData.rank_name,
            title = mTitle.name,
        }
        mMail.context = global.oToolMgr:FormatColorString(mMail.context, mReplace)
        mMail.title = global.oToolMgr:FormatColorString(mMail.title, mReplace)
        global.oMailMgr:SendMailNew(0, sName, iPid, mMail, {items={oItem}})
    end
end

