-- module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local mongoop = require "base.mongoop"
local record = require "public.record"
local mongo = require "mongo"
local bson = require "bson"
local cjson = require "cjson"
local router = require "base.router"

local bkdefines = import(service_path("bkdefines"))
local backendobj = import(service_path("backendobj"))


function NewBusinessObj(...)
    local o = CBusinessObj:New(...)
    return o
end

CBusinessObj = {}
CBusinessObj.__index = CBusinessObj

function CBusinessObj:New()
    local o = setmetatable({}, self)
    return o
end

function CBusinessObj:Init()
end

function CBusinessObj:HandlePlayerBasicInfo(mPlayer, mOffline)
    local mRet = {}
    if not mPlayer or not mOffline then return mRet end

    local mBaseInfo = mPlayer.base_info or {}
    mRet["id"] = tostring(mPlayer.pid)
    mRet["nickName"] = mPlayer.name
    mRet["loginTime"] = bkdefines.FormatTimeToSec(mPlayer.active_info.login_time or 0)
    mRet["logoutTime"] = ""
    mRet["grade"] = mBaseInfo.grade or 0
    mRet["exp"] = mPlayer.active_info.exp
    
    --factionName
    local iSchool = mBaseInfo.school
    mRet["factionName"] = bkdefines.PLAYER_SCHOOL[iSchool]

    -- TODO
    mRet["guildName"] = ""

    local mOtherInfo = mBaseInfo.other_info or {}
    mRet["totalDeposit"] = mOtherInfo.rebate_gold_coin or 0

    --scene
    local mSceneInfo = mPlayer.active_info.scene_info or {}
    local mPos = mSceneInfo.pos or {}
    mRet["sceneId"] = mSceneInfo.map_id or 0
    mRet["x"] = mPos.x or 0
    mRet["y"] = mPos.y or 0

    -- title
    mRet["title"] = ""
    local mTitileInfo = mPlayer.title_info  or {}
    local iUseTitle = mTitileInfo.use_tid
    for _,mTitle in pairs(mTitileInfo.title_list or {}) do
        if mTitle.titleid == iUseTitle then
            mRet["title"] = mRet["title"]..mTitle.titleid.."-"..(mTitle.name or "").."--佩戴,"
        else
            mRet["title"] = mRet["title"]..mTitle.titleid.."-"..(mTitle.name or "")..","
        end
    end    
    return mRet
end

function CBusinessObj:HandlePlayerWealthInfo(mPlayer, mOffline)
    local mRet = {}
    if not mPlayer or not mOffline then return mRet end

    local mActiveInfo = mPlayer.active_info or {}
    mRet["ingot"] = mOffline.profile_info.GoldCoin or 0
    mRet["rpingot"] = mOffline.profile_info.RplGoldCoin or 0
    mRet["silver"] = mActiveInfo.silver or 0
    mRet["gold"] = mActiveInfo.gold or 0
    mRet["reserveExp"] = mActiveInfo.chubeiexp or 0
    mRet["orgoffer"] = mActiveInfo.org_offer or 0
    mRet["wuxun"] = mActiveInfo.wuxun or 0
    mRet["jjcpoint"] = mActiveInfo.jjcpoint or 0
    mRet["skpoint"] = mActiveInfo.sk_point or 0
    mRet["vigor"] = mActiveInfo.vigor or 0
    mRet["leaderpoint"] = mActiveInfo.leaderpoint or 0
    mRet["xiayipoint"] = mActiveInfo.xiayipoint or 0
    mRet["summonpoint"] = mActiveInfo.summonpoint or 0
    mRet["storypoint"] = mActiveInfo.storypoint or 0
    return mRet
end

function CBusinessObj:HandlePlayerWarInfo(mWar)
    return mWar or {}
end

function CBusinessObj:HandlePlayerTaskInfo(mTask)
    local mRet = {}
    local mTaskInfo = mTask or {}
    for _, mInfo in pairs(mTaskInfo) do
        local m = {}
        if mInfo.taskid then
            m.missionId = mInfo.taskid
            m.missionName = mInfo.name
            m.missionType = mInfo.tasktype
            m.acceptTime = bkdefines.FormatTimeToSec(mInfo.create_time) 
            table.insert(mRet, m)
        end
    end
    return mRet
end

function CBusinessObj:HandlePlayerSummonInfo(mSummon)
    local mRet = {}
    mSummon = mSummon or {}
    for _, mInfo in ipairs(mSummon.summondata or {}) do 
        local mPet = {}
        mPet.id = mInfo.sid
        mPet.level = mInfo.grade
        mPet.name = mInfo.name
        local res = require "base.res"
        local m = res["daobiao"]["summon"]["info"][mInfo.sid]
        if m then
            mPet.petname = m.name
        end
        mPet.status = 0
        local mFollow = mSummon.follow or {}
        local mTraceno = mInfo.traceno or {}
        if #mFollow >= 2 and #mTraceno >= 2 and mFollow[2] == mTraceno[2] then
            mPet.status = 1
        end
        
        mPet.skillInfo = cjson.encode(mInfo.skills or {})
        mPet.talent = cjson.encode(mInfo.talent or {})
        table.insert(mRet, mPet)
    end
    return mRet
end

function CBusinessObj:HandlePlayerSkillInfo(mPlayer)
    local mRet = {}
    local mSkillInfo = mPlayer.skill_info or {}
    for skid, mSk in pairs(mSkillInfo.skdata or {}) do
        table.insert(mRet, {id=skid, grade=mSk.level})
    end
    return mRet
end

function CBusinessObj:HandleWareHouseInfo(mPlayer)
    -- 仓库信息
    local mRet = {}
    local res = require "base.res"
    local mWareHouse = mPlayer.wh_info or {}
    for iWH, mWH in pairs(mWareHouse.warehouse or {}) do
        for iPos, mItem in pairs(mWH.itemdata or {}) do
            local m = {}
            local mInfo = res["daobiao"]["item"][mItem.sid]
            m.itemId = mItem.sid
            if mInfo then
                m.itemName = mInfo.name
            end
            m.amount = mItem.amount or 0
            m.data = cjson.encode(mItem.data) 
            m.itemIndex = iPos
            m.status = 1
            m.whIndex = iWH
            table.insert(mRet, m)
        end
    end
    return mRet
end

function CBusinessObj:HandleBackpackInfo(mPlayer)
    -- 背包信息
    local mRet = {}
    local res = require "base.res"
    local mItemInfo = mPlayer.item_info or {}
    for pos, mItem in pairs(mItemInfo.itemdata or {}) do
        local m = {}
        local mInfo = res["daobiao"]["item"][mItem.sid]
        m.itemId = mItem.sid
        if mInfo then
            m.itemName = mInfo.name
        end
        m.amount = mItem.amount or 0
        m.data = cjson.encode(mItem.data) 
        m.itemIndex = pos
        m.status = 1
        table.insert(mRet, m)
    end
    return mRet
end

function CBusinessObj:HandlePartnerInfo(mPlayer)
    -- 伙伴
    local mRet = {}
    local mPartner = mPlayer.partner_info or {}
    for pos, mInfo in pairs(mPartner.partnerdata or {}) do
        local m = {}
        m.crewName = mInfo.name
        m.crewId = mInfo.sid
        m.grade = mInfo.grade
        m.exp = mInfo.exp
        table.insert(mRet, m)
    end
    return mRet
end

function CBusinessObj:HandleFriendInfo(mFriend)
    local mRet = {}
    return mRet
end

function CBusinessObj:HandlePlayerDetailInfo(mInfo, sServer, mBody, sFunc)
    local iPid = mInfo["pid"]

    local mRet, mPlayer, mOffline, mWar, mTask = {}
    if not mBody["online"] then
        local oBackendObj = global.oBackendObj
        local oServer =  oBackendObj:GetServer(sServer)
        local oGameDb = oServer.m_oGameDb:GetDb()
        mOffline = oGameDb:FindOne("offline", {pid = iPid}, {profile_info = true})
        mPlayer = oGameDb:FindOne("player", {pid = iPid}, {
            pid = true, name = true, create_time = true, title_info = true,
            base_info = true, active_info = true, item_info = true, wh_info = true,
            skill_info = true, summon_info = true, partner_info = true, ride_info = true, 
            summon_ck_info = true,
            })
        mongoop.ChangeAfterLoad(mOffline)
        mongoop.ChangeAfterLoad(mPlayer)
        
        local oBackendDb = oBackendObj.m_oBackendDb
        local m = oBackendDb:FindOne("player", {["pid"] = iPid, ["type"] = "warinfo"}, {["data"] = true})
        if m then
            mWar = m.data
        end
        m = oBackendDb:FindOne("player", {["pid"] = iPlayerIdx, ["type"] = "taskinfo"}, {["data"] = true})
        if m then
            mTask = m.data
        end
    else
        mOffline = mBody["offline"]
        mPlayer = mBody["player"]
        mWar = mBody["war"]
        mTask = mBody["task"]
    end
    -- 基础信息
    mRet["playerInfo"] = self:HandlePlayerBasicInfo(mPlayer, mOffline)
    -- 货币信息
    mRet["wealthInfo"] = self:HandlePlayerWealthInfo(mPlayer, mOffline)
    -- 战斗信息
    mRet["fightPropertyInfo"] = self:HandlePlayerWarInfo(mWar)
    -- 任务信息
    mRet["playerMissionList"] = self:HandlePlayerTaskInfo(mTask)
    -- 宠物信息
    mRet["playerPetList"] = self:HandlePlayerSummonInfo(mPlayer.summon_info)
    -- 宠物仓库
    mRet["playerCkPetList"] = self:HandlePlayerSummonInfo(mPlayer.summon_ck_info)
    -- 技能信息
    mRet["playerSkillList"] = self:HandlePlayerSkillInfo(mPlayer)
    -- 仓库信息
    mRet["playerWarehouseList"] = self:HandleWareHouseInfo(mPlayer)
    -- 背包信息
    mRet["playerBackpackList"] = self:HandleBackpackInfo(mPlayer)
    -- 伙伴信息
    mRet["playerCrewList"] = self:HandlePartnerInfo(mPlayer)
    -- 朋友信息
    -- mRet["playerFriendList"] = self:HandleFriendInfo(mFriend)
    sFunc({errcode=0, data=mRet})
end

function CBusinessObj:RequestPlayerDetailInfo(mInfo, sFunc)
    local iPid = mInfo["pid"]
    local sServerTag = mInfo["serverid"]
    local oBackendObj = global.oBackendObj

    local sServer = string.format("%s_%s", get_server_cluster(), sServerTag)
    local oServer = oBackendObj:GetServer(sServer)
    if not iPid or not oServer then sFunc({errcode=2, data={}}) return end

    local mData = {cmd="SearchPlayerInfo", data={pid=iPid}}
    router.Request(sServerTag, ".world", "gmtools", "Forward", mData, function (mRecord, mData)
        self:HandlePlayerDetailInfo(mInfo, sServer, mData, sFunc)
    end)
end

function CBusinessObj:GetPlayerDetailInfo(mArgs, sFunc)
    local iShowId = mArgs["playerId"]
    local lServerId = mArgs["servers"] 
    if not iShowId then sFunc({errcode=1, data={}}) return end 

    local mInfo = {}
    local oDataCenterDb = global.oBackendObj:GetDataCenterDb()
    if not oDataCenterDb then
        record.warning(string.format("CBusinessObj:GetPlayerDetailInfo not find datacenter db"))
        sFunc({errcode=1, data={}, errmsg="not find center db"})
        return
    end

    local m = oDataCenterDb:FindOne("roleinfo", {pid=iShowId}, {pid=true, name=true, account=true, channel=true, now_server=true})
    mongoop.ChangeAfterLoad(m)
    if not m or not m["now_server"] then
        sFunc({errcode=1, errmsg="can't find player", data={}})
        return
    end

    mInfo["pid"] = iShowId
    mInfo["serverid"] = m["now_server"]
    self:RequestPlayerDetailInfo(mInfo, sFunc)
end

function CBusinessObj:GetOrgInfoList(mData, sFunc)
    local lServerId = mData["servers"]
    local oBackendObj = global.oBackendObj
    local mServer = oBackendObj:GetServersByIds(lServerId)
    if table_count(mServer) > 20 then
        local sMsg = "GetOrgInfoList search limit 20 servers"
        sFunc({errcode=1, errmsg=sMsg})
        record.warning(sMsg)
        return
    end

    local lOrgInfo = {}
    for _, oServer in pairs(mServer) do
        local oGameDb = oServer.m_oGameDb:GetDb()
        local m = oGameDb:Find("org", {}, {orgid=1, name=1, showid=1, base_info=1, member_info=1})
        while m:hasNext() do
            local mOrg = m:next()
            mongoop.ChangeAfterLoad(mOrg)
            table.insert(lOrgInfo, self:PackOrgInfo(oServer:ServerID(), mOrg)) 
        end
 
    end
    sFunc({data=lOrgInfo})
end

function CBusinessObj:PackOrgInfo(sServer, mOrg)
    local mRet = {}
    mRet["id"] = mOrg.orgid
    mRet["showid"] = mOrg.showid
    mRet["name"] = mOrg.name
    mRet["level"] = mOrg.base_info.level
    mRet["aim"] = mOrg.base_info.aim
    mRet["boom"] = mOrg.base_info.boom
    mRet["cash"] = mOrg.base_info.cash

    local mMember = mOrg.member_info.member
    local mXueTu = mOrg.member_info.xuetu
    local iLeader = mOrg.member_info.leader
    local mLeader = mMember[db_key(leader)] or {}
    mRet["leaderpid"] = iLeader 
    mRet["leadername"] = mLeader.name
    mRet["membercnt"] = table_count(mMember)
    mRet["xuetucnt"] = table_count(mXueTu)
    mRet["server"] = sServer
    return mRet
end

function CBusinessObj:GetOrgMemberList(mData, sFunc)
    local sServer = mData.server
    local iOrg = mData.orgid

    local oBackendObj = global.oBackendObj
    local oServer = oBackendObj:GetServerObj(sServer)
    if not oServer then
        local sMsg = string.format("GetOrgMemberList not find server:%s", sServer)
        sFunc({errcode=1, errmsg=sMsg})
        record.warning(sMsg)
        return
    end

    local oGameDb = oServer.m_oGameDb:GetDb()
    local mOrg = oGameDb:FindOne("org", {orgid=iOrg}, {orgid=1, name=1, member_info=1, xuetu_info=1})
    mongoop.ChangeAfterLoad(mOrg)
    local mMember = mOrg.member_info.member
    local mXueTu = mOrg.member_info.xuetu

    local lMember = {}
    for _,m in pairs(mMember) do
        table.insert(lMember, self:PackMemberInfo(m))
    end
    for _,m in pairs(mXueTu) do
        table.insert(lMember, self:PackMemberInfo(m))
    end
    sFunc({data=lMember})
end

function CBusinessObj:PackMemberInfo(mMember)
    local mRet = {}
    mRet["pid"] = mMember.pid
    mRet["name"] = mMember.name
    mRet["grade"] = mMember.grade
    mRet["school"] = mMember.school
    mRet["offer"] = mMember.offer
    mRet["logout_time"] = mMember.logout_time
    mRet["position"] = mMember.position
    mRet["huoyue"] = mMember.huoyue
    return mRet
end
