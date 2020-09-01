local skynet = require "skynet"
local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"
local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl
local defines = import(service_path("offline.defines"))
local analy = import(lualib_path("public.dataanaly"))

CFriendCtrl = {}
CFriendCtrl.__index = CFriendCtrl
inherit(CFriendCtrl, CBaseOfflineCtrl)

function CFriendCtrl:New(pid)
    local o = super(CFriendCtrl).New(self, pid)
    o.m_sDbFlag = "Friend"
    o.m_mFriends = {}
    o.m_mChats = {}
    o.m_mBlackList = {}
    o.m_mRelations = {}
    o.m_iExtendCnt = 0
    o.m_iChatPush = 0
    o.m_iRefuseToggle = 0
    o.m_iVerifyToggle = 1
    o.m_iStrangerMsgToggle = 1
    o.m_iVerifyRefused = 0
    o.m_mVerifyApply = {}
    o.m_iMentoringCD = 0
    return o
end

function CFriendCtrl:Save()
    local mData = {}
    mData.friends = self.m_mFriends or {}
    mData.chats = self.m_mChats or {}
    mData.black = self.m_mBlackList or {}
    mData.relation = self.m_mRelations or {}
    mData.cnt = self.m_iExtendCnt or 0
    mData.chatpush = self.m_iChatPush or 0
    mData.refuse_toggle = self.m_iRefuseToggle or 0
    mData.verify_toggle = self.m_iVerifyToggle or 1
    mData.stranger_msg_toggle = self.m_iStrangerMsgToggle or 1
    mData.verify_refused = self.m_iVerifyRefused or 0
    mData.verify_apply = self.m_mVerifyApply or {}
    mData.cd_mentoring = self.m_iMentoringCD
    return mData
end

function CFriendCtrl:Load(mData)
    mData = mData or {}
    self.m_mFriends = mData.friends or {}
    self.m_mChats = mData.chats or {}
    self.m_mBlackList = mData.black or {}
    self.m_mRelations = mData.relation or {}
    self.m_iExtendCnt = mData.cnt or 0
    self.m_iChatPush = mData.chatpush or 0
    self.m_iRefuseToggle = mData.refuse_toggle or 0
    self.m_iVerifyToggle = mData.verify_toggle or 1
    self.m_iStrangerMsgToggle = mData.stranger_msg_toggle or 1
    self.m_iVerifyRefused = mData.verify_refused or 0
    self.m_mVerifyApply = mData.verify_apply or {}
    self.m_iMentoringCD = mData.cd_mentoring or 0
end

function CFriendCtrl:SaveDb()
    if self:IsDirty() then
        local m = {}
        local mFriends = self:GetFriends()
        for k, v in pairs(mFriends) do
            m[tonumber(k)] = 1
        end
        interactive.Send(".recommend","friend","UpdateOneDegreeFriends", {pid = self:GetPid(), data = m})
    end
    super(CFriendCtrl).SaveDb(self)
end

function CFriendCtrl:GetProtectFriends(lFriends)
    if not lFriends then
        lFriends = table_key_list(self.m_mFriends)
        extend.Array.append (lFriends, table_key_list(self.m_mRelations))
    end
    local mProtect = {}
    for k, _ in pairs(self:GetRelation(defines.RELATION_COUPLE)) do
        if not mProtect[k] then
            mProtect[k] = 500 + self:GetFriendDegree(k) // 100
        end
    end
    for k, _ in pairs(self:GetRelation(defines.RELATION_MASTER)) do
        if not mProtect[k] then
            mProtect[k] = 300 + self:GetFriendDegree(k) // 100
        end
    end
    for k, _ in pairs(self:GetRelation(defines.RELATION_APPRENTICE)) do
        if not mProtect[k] then
            mProtect[k] = 300 + self:GetFriendDegree(k) // 100
        end
    end
    for k, _ in pairs(self:GetRelation(defines.RELATION_BROTHER)) do
        if not mProtect[k] then
            mProtect[k] = 200 + self:GetFriendDegree(k) // 100
        end
    end
    for _, k in pairs(lFriends) do
        if self:IsBothFriend(k) and k ~= self:GetPid() and not mProtect[k] then
            local iDegree = self:GetFriendDegree(k)
            if iDegree >= defines.DEGREE_PROTECT then
                mProtect[k] = 100 + iDegree // 100
            end
        end
    end
    return mProtect
end

function CFriendCtrl:SetRelation(iPid, iRelation)
    if not iPid or iPid == 0 then
        return
    end
    self:Dirty()
    local sPid = db_key(iPid)
    local r = self.m_mRelations[sPid] or 0
    self.m_mRelations[sPid] = r | 2 ^ (iRelation - 1)
end

function CFriendCtrl:ResetRelation(iPid, iRelation)
    if not iPid or iPid == 0 then
        return
    end
    local sPid = db_key(iPid)
    local r = self.m_mRelations[sPid]
    if not r then
        return
    end
    self:Dirty()
    self.m_mRelations[sPid] = r & ~ (2 ^ (iRelation - 1))
    if self.m_mRelations[sPid] == 0 then
        self.m_mRelations[sPid] = nil
    end
end

function CFriendCtrl:HasRelation(iPid, iRelation)
    if not iPid or iPid == 0 then
        return false
    end
    local sPid = db_key(iPid)
    local r = self.m_mRelations[sPid] or 0
    return r & 2 ^ (iRelation - 1) ~= 0
end

function CFriendCtrl:GetRelation(iRelation)
    local mPid = {}
    for sPid, r in pairs(self.m_mRelations) do
        if r & 2 ^ (iRelation - 1) ~= 0 then
            mPid[tonumber(sPid)] = iRelation
        end
    end
    return mPid
end

function CFriendCtrl:GetRelations()
    return self.m_mRelations
end

function CFriendCtrl:GetFriendRelation(iPid)
    if not iPid or iPid == 0 then
        return 0
    end
    local sPid = db_key(iPid)
    return self.m_mRelations[sPid] or 0
end

function CFriendCtrl:FriendsMaxCnt()
    return self.m_iExtendCnt + defines.CNT_FRIEND
end

function CFriendCtrl:ExtendFriendCnt(iCnt)
    self:Dirty()
    self.m_iExtendCnt = self.m_iExtendCnt + iCnt
end

function CFriendCtrl:GetFriends()
    return self.m_mFriends
end

function CFriendCtrl:GetFriendOfflineChats()
    return self.m_mChats
end

function CFriendCtrl:HasFriend(iPid)
    local sPid = db_key(iPid)
    if self.m_mFriends[sPid] then
        return true
    end
    return false
end

function CFriendCtrl:FriendCount()
    return table_count(self.m_mFriends)
end

function CFriendCtrl:DelFriend(iPid)
    self:Dirty()
    local oWorldMgr = global.oWorldMgr
    local oFriendMgr = global.oFriendMgr

    local sPid = db_key(iPid)
    self.m_mFriends[sPid] = nil

    local oMaster = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oMaster then
        oFriendMgr:UnFocusFriend(oMaster, iPid)
        
        -- 数据中心log
        self:LogAnalyInfo(iPid, 2)
    end

    local mLogData = self:LogFriendData()
    mLogData["fid"] = iPid
    record.log_db("friend", "del_friend", mLogData)
end

function CFriendCtrl:AddFriend(iPid, mExtra)
    if not iPid or iPid == 0 then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oFriendMgr = global.oFriendMgr

    self:Dirty()
    local sPid = db_key(iPid)
    mExtra = mExtra or {}
    if not self.m_mFriends[sPid] then
        self.m_mFriends[sPid] = {}
    end
    self.m_mFriends[sPid].friend_degree = mExtra.friend_degree or 0

    local oMaster = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oMaster then
        oFriendMgr:FocusFriend(oMaster, iPid)

        -- 数据中心log
        self:LogAnalyInfo(iPid, 1)
        oMaster:MarkGrow(2)
    end
    local mLogData = self:LogFriendData()
    mLogData["fid"] = iPid
    mLogData["degree"] = self.m_mFriends[sPid].friend_degree
    record.log_db("friend", "add_friend", mLogData)
end

function CFriendCtrl:SetBothFriend(iPid)
    local sPid = db_key(iPid)
    if not self.m_mFriends[sPid] then
        return
    end
    self:Dirty()
    self.m_mFriends[sPid].both_friend = true
end

function CFriendCtrl:ClearBothFriend(iPid)
    local sPid = db_key(iPid)
    if not self.m_mFriends[sPid] then
        return
    end
    self:Dirty()
    self.m_mFriends[sPid].both_friend = nil
end

function CFriendCtrl:IsBothFriend(iPid)
    local sPid = db_key(iPid)
    if not self.m_mFriends[sPid] then
        return false
    end
    return self.m_mFriends[sPid].both_friend
end

function CFriendCtrl:GetBothFriends()
    local lBothFriend = {}
    for sPid, mInfo in pairs(self.m_mFriends) do
        if mInfo.both_friend then
            table.insert(lBothFriend, tonumber(sPid))
        end
    end
    return lBothFriend
end

function CFriendCtrl:ClearFriendDegree(iPid)
    local sPid = db_key(iPid)
    if not self.m_mFriends[sPid] then
        return
    end
    self:Dirty()
    local iOldDegree = self.m_mFriends[sPid].friend_degree or 0
    self.m_mFriends[sPid].friend_degree = 0

    local mLogData = self:LogFriendData()
    mLogData["fid"] = iPid
    mLogData["degree_old"] = iOldDegree
    mLogData["degree_add"] = -iOldDegree
    mLogData["degree_now"] = 0
    record.log_db("friend", "degree", mLogData)
   
    return iOldDegree
end

function CFriendCtrl:AddFriendDegree(iPid, iDegree)
    local sPid = db_key(iPid)
    if not self.m_mFriends[sPid] then
        return
    end
    if self.m_mFriends[sPid].friend_degree >= defines.DEGREE_MAX then
        return
    end
    self:Dirty()
    local iOldDegree = self.m_mFriends[sPid].friend_degree or 0
    self.m_mFriends[sPid].friend_degree = math.min(iOldDegree+iDegree, defines.DEGREE_MAX)

    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oMaster then
        global.oMentoring:SetStepResult(self:GetPid(), iPid, 9, self.m_mFriends[sPid].friend_degree)
    end
    
    local mLogData = self:LogFriendData()
    mLogData["fid"] = iPid
    mLogData["degree_old"] = iOldDegree
    mLogData["degree_add"] = iDegree
    mLogData["degree_now"] = self.m_mFriends[sPid].friend_degree
    record.log_db("friend", "degree", mLogData)
end

function CFriendCtrl:GetFriendDegree(iPid)
    local sPid = db_key(iPid)
    if not self.m_mFriends[sPid] then
        return 0
    end
    return self.m_mFriends[sPid].friend_degree or 0
end

function CFriendCtrl:GetBlackList()
    return self.m_mBlackList
end

function CFriendCtrl:IsShield(iPid)
    local sPid = db_key(iPid)
    return self.m_mBlackList[sPid]
end

function CFriendCtrl:Shield(iPid)
    if not iPid or iPid == 0 then
        return
    end
    self:Dirty()
    local sPid = db_key(iPid)
    self.m_mBlackList[sPid] = true

    local mLogData = self:LogFriendData()
    mLogData["fid"] = iPid
    mLogData["op"] = "shield"
    record.log_db("friend", "shield", mLogData)

    -- 数据中心log
    self:LogAnalyInfo(iPid, 3)
end

function CFriendCtrl:Unshield(iPid)
    self:Dirty()
    local sPid = db_key(iPid)
    self.m_mBlackList[sPid] = nil

    local mLogData = self:LogFriendData()
    mLogData["fid"] = iPid
    mLogData["op"] = "unshield"
    record.log_db("friend", "shield", mLogData)

    -- 数据中心log
    self:LogAnalyInfo(iPid, 4)
end

function CFriendCtrl:HasChat(iPid, sMessageId)
    local sPid = db_key(iPid)
    if not self.m_mChats[sPid] then
        return false
    end
    for _, v in ipairs(self.m_mChats[sPid]) do
        if v.message_id == sMessageId then
            return true
        end
    end
    return false
end

function CFriendCtrl:GetChat(iPid, sMessageId)
    local sPid = db_key(iPid)
    if not self.m_mChats[sPid] then
        return
    end
    local iIndex
    for k, v in ipairs(self.m_mChats[sPid]) do
        if v.message_id == sMessageId then
            iIndex = k
            return iIndex, v
        end
    end
    return
end

function CFriendCtrl:AddChat(iPid, sMessageId, sMsg)
    if not iPid or iPid == 0 then
        return false
    end
    if self:HasChat(iPid, sMessageId) then
        return false
    end
    self:Dirty()
    local sPid = db_key(iPid)
    if not self.m_mChats[sPid] then
        self.m_mChats[sPid] = {}
    end
    if #self.m_mChats[sPid] >= 50 then
        table.remove(self.m_mChats[sPid], 1)
    end
    table.insert(self.m_mChats[sPid], {message_id = sMessageId, msg = sMsg})
    return true
end

function CFriendCtrl:DelChat(iPid, sMessageId)
    local iIndex = self:GetChat(iPid, sMessageId)
    if not iIndex then
        return false
    end
    self:Dirty()
    local sPid = db_key(iPid)
    table.remove(self.m_mChats[sPid], iIndex)
    if #self.m_mChats[sPid] <= 0 then
        self.m_mChats[sPid] = nil
    end
    return true
end

function CFriendCtrl:EraseChat(iPid, sMessageId)
    local iIndex = self:GetChat(iPid, sMessageId)
    if not iIndex then
        return false
    end
    self:Dirty()
    local sPid = db_key(iPid)
    local l = {}
    for i = iIndex + 1, #self.m_mChats[sPid] do
        table.insert(l, self.m_mChats[sPid][i])
    end
    if #l <= 0 then
        self.m_mChats[sPid] = nil
    else
        self.m_mChats[sPid] = l
    end
    return true
end

function CFriendCtrl:GetFriendsOnlineStatusInfo()
    local mOnlineStatusInfoTbl = {}
    for k,_ in pairs(self.m_mFriends) do
        local iFriendId = tonumber(k)
        local iOnlineStatus = self:GetFriendOnlineStatusById(iFriendId) and 1 or 0
        table.insert(mOnlineStatusInfoTbl,{pid = iFriendId,onlinestatus = iOnlineStatus})
    end
    return mOnlineStatusInfoTbl
end

function CFriendCtrl:GetFriendOnlineStatusById(iFriendId)
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:IsOnline(iFriendId)
end

function CFriendCtrl:SendMailByDegree(iDegree, sMail, mMail)
    local oMailMgr = global.oMailMgr
    local iPid = self:GetPid()
    for sPid, mInfo in pairs(self.m_mFriends) do
        if mInfo.both_friend and mInfo.friend_degree > iDegree then
            oMailMgr:SendMail(iPid, sMail, tonumber(sPid), mMail, 0)
        end
    end
end

function CFriendCtrl:LogFriendData()
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetPid()
    local oMaster = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oMaster then
        return oMaster:LogData()
    else
        return {pid=iPid, show_id=iPid, name="", grade=0, channel=""}
    end
end

function CFriendCtrl:LogAnalyInfo(iFid, iOperation)
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetPid()
    local oMaster = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oMaster then return end

    local mAnalyLog = oMaster:BaseAnalyInfo()
    oWorldMgr:LoadProfile(iFid, function (oFriend)
        if not oFriend then return end

        -- 数据中心log
        mAnalyLog["operation"] = iOperation
        mAnalyLog["friend_role_id"] = iFid
        mAnalyLog["friend_role_name"] = oFriend:GetName()
        mAnalyLog["friend_role_level"] = oFriend:GetGrade()
        mAnalyLog["friend_profession"] = oFriend:GetSchool()
        mAnalyLog["friend_address"] = oFriend:GetPosition()
        analy.log_data("friend", mAnalyLog)
    end)
end

function CFriendCtrl:ChangePushConfig(iChatPush)
    if self.m_iChatPush ~= iChatPush then
        self:Dirty()
        self.m_iChatPush = iChatPush
    end
end

function CFriendCtrl:ValidChatPush()
    return false
    --return self.m_iChatPush == 0
end

function CFriendCtrl:ChangeFriendSysConfig(iRefuseToggle, iVerifyToggle, iStrangerMsgToggle)
    self:Dirty()
    self.m_iRefuseToggle = iRefuseToggle or 0
    self.m_iVerifyToggle = iVerifyToggle or 1
    self.m_iStrangerMsgToggle = iStrangerMsgToggle or 1
end

function CFriendCtrl:IsRefuseToggle()
    return self.m_iRefuseToggle == 1
end

function CFriendCtrl:IsVerifyToggle()
    return self.m_iVerifyToggle == 1
end

function CFriendCtrl:IsStrangerMsgToggle()
    return self.m_iStrangerMsgToggle == 1
end

function CFriendCtrl:AddVerifyApply(iPid, sName, sMsg)
    if not iPid or iPid == 0 or self.m_mVerifyApply[iPid] then
        return false
    end

    self:Dirty()

    local mApplyMsg = {
        pid = iPid,
        name = sName,
        msg = sMsg,
    }
    self.m_mVerifyApply[iPid] = mApplyMsg
end

function CFriendCtrl:HasVerifyApply(iPid)
    return self.m_mVerifyApply[iPid] ~= nil
end

function CFriendCtrl:DelVerifyApply(iPid)
    if not iPid or iPid == 0 then
        return false
    end

    self:Dirty()
    
    if self.m_mVerifyApply[iPid] then
        self.m_mVerifyApply[iPid] = nil
    end
end

function CFriendCtrl:GetVerifyApply()
    return self.m_mVerifyApply or {}
end

function CFriendCtrl:SetVerifyRefused(iFlag)
    if self.m_iVerifyRefused ~= iFlag then
        self:Dirty()
        self.m_iVerifyRefused = iFlag
    end
end

function CFriendCtrl:GetVerifyRefused()
    return self.m_iVerifyRefused
end

function CFriendCtrl:GetApprentice()
    return self:GetRelation(defines.RELATION_APPRENTICE)
end

function CFriendCtrl:GetMentor()
    return self:GetRelation(defines.RELATION_MASTER)
end

function CFriendCtrl:GetMentoringCD()
    return self.m_iMentoringCD or 0
end

function CFriendCtrl:SetMentoringCD(iTime)
    self.m_iMentoringCD = iTime
    self:Dirty()
end

