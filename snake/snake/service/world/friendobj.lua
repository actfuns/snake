--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local extend = require "base.extend"
local res = require "base.res"
local net = require "base.net"
local router = require "base.router"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local defines = import(service_path("offline.defines"))
local gamedb = import(lualib_path("public.gamedb"))

TYPE_RECOMMEND_TWODEGREE = 1
TYPE_RECOMMEND_ORG = 2
TYPE_RECOMMEND_CITY = 3
TYPE_RECOMMEND_SCHOOL = 4
TYPE_RECOMMEND_ONLINE = 5

CNT_RECOMMEND_TOTAL = 40
CNT_RECOMMEND_PERTYPE = 20
CNT_RECOMMEND_LIMIT = 10

function NewFriendMgr(...)
    local o = CFriendMgr:New(...)
    return o
end

CFriendMgr = {}
CFriendMgr.__index = CFriendMgr
inherit(CFriendMgr, logic_base_cls())

function CFriendMgr:New()
    local o = super(CFriendMgr).New(self)
    o.m_mRecommendInfo = {}
    return o
end

function CFriendMgr:OnDisconnected(oPlayer)
    self:UnFocusAllFriends(oPlayer)
end

function CFriendMgr:OnLogout(oPlayer)
    self:UnFocusAllFriends(oPlayer)
    self:NotifyLogoutToFriends(oPlayer)
end

function CFriendMgr:OnLogin(oPlayer, bReenter)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local oFriend = oPlayer:GetFriend()
    local mBlacks = oFriend:GetBlackList()
    local mFriendOfflineChats = oFriend:GetFriendOfflineChats()

    self:FocusAllFriends(oPlayer)

    local l1 = {}
    local l2 = {}
    local l3 = oFriend:GetFriendsOnlineStatusInfo()
    
    for k, _ in pairs(mBlacks) do
        table.insert(l2, tonumber(k))
    end
    for k, v in pairs(mFriendOfflineChats) do
        if #v > 0 then
            local m = {}
            m.pid = tonumber(k)
            m.chat_list = {}
            for _, v2 in ipairs(v) do
                table.insert(m.chat_list, {
                    message_id = v2.message_id,
                    msg = v2.msg,
                })
            end
            table.insert(l1, m)
        end
    end

    oPlayer:Send("GS2CLoginFriend", {
        friend_chat_list = l1,
        black_list = l2,
        friend_onlinestatus_list = l3,
    })

    self:StartRecommend(oPlayer)
    self:NotifyLoginToFriends(oPlayer)
    self:SendFriendVerifyApply(oPlayer)
end

function CFriendMgr:FocusFriend(oPlayer, iPid)
    local mBroadcastRole = {
        pid = oPlayer:GetPid(),
    }
    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE, iPid, true},
        },
        info = mBroadcastRole,
    })
end

function CFriendMgr:UnFocusFriend(oPlayer, iPid)
    local mBroadcastRole = {
        pid = oPlayer:GetPid(),
    }
    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE, iPid, false},
        },
        info = mBroadcastRole,
    })
end

function CFriendMgr:FocusAllFriends(oPlayer)
    local oFriend = oPlayer:GetFriend()
    local mFriends = oFriend:GetFriends()

    local mBroadcastRole = {
        pid = oPlayer:GetPid(), 
    }
    local lChannel = {}
    for k, _ in pairs(mFriends) do
        table.insert(lChannel, {gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE, tonumber(k), true})
    end
    if #lChannel > 0 then
        interactive.Send(".broadcast", "channel", "SetupChannel", {
            pid = oPlayer:GetPid(),
            channel_list = lChannel,
            info = mBroadcastRole,
        })
    end
end

function CFriendMgr:UnFocusAllFriends(oPlayer)
    local oFriend = oPlayer:GetFriend()
    if not oFriend then
        -- 登录不成功及登录中socket断掉
        return
    end
    local mFriends = oFriend:GetFriends()

    local mBroadcastRole = {
        pid = oPlayer:GetPid(), 
    }
    local lChannel = {}
    for k, _ in pairs(mFriends) do
        table.insert(lChannel, {gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE, tonumber(k), false})
    end
    if #lChannel > 0 then
        interactive.Send(".broadcast", "channel", "SetupChannel", {
            pid = oPlayer:GetPid(),
            channel_list = lChannel,
            info = mBroadcastRole,
        })
    end
end

function CFriendMgr:NotifyLoginToFriends(oPlayer)
    local mData = {
        message = "GS2COnline",
        type = gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE,
        id = oPlayer:GetPid(),
        data = {
            pid = oPlayer:GetPid()
        },
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CFriendMgr:NotifyLogoutToFriends(oPlayer)
    local mData = {
        message = "GS2COffline",
        type = gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE,
        id = oPlayer:GetPid(),
        data = {
            pid = oPlayer:GetPid()
        },
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CFriendMgr:SendFriendVerifyApply(oPlayer)
    local oFriend = oPlayer:GetFriend()
    local iErrorCode = oFriend:GetVerifyRefused()
    if iErrorCode ~= 0 then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(iErrorCode))
        oFriend:SetVerifyRefused(0)
    end

    local mVerifyApply = oFriend:GetVerifyApply()
    local lVerifyApply = table_value_list(mVerifyApply)
    if #lVerifyApply > 0 then
        oPlayer:Send("GS2CVerifyFriendConfirm", {
            verify_list = lVerifyApply
        })
    end
end

function CFriendMgr:GetTextData(idx, mReplace)
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:GetTextData(idx, {"friend"})
    if mReplace then
        sText = oToolMgr:FormatColorString(sText, mReplace)
    end
    return sText
end

function CFriendMgr:StartRecommend(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    interactive.Request(".recommend","friend","DigTwoDegreeFriends", {pid=iPid}, function (mRecord,mData)
        if mData.success then
            local mData = mData.data
            self:_Recommend(iPid, mData)
        end
    end)
end

function CFriendMgr:_Recommend(iPid, mData)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end

    local mFriends = {}
    for k, _ in pairs(mData) do
        mFriends[k] = {type = TYPE_RECOMMEND_TWODEGREE}
    end

    --两度好友限制10个
    mFriends = extend.Random.sample_table(mFriends, CNT_RECOMMEND_LIMIT)
    self:GetOtherRecommend(oPlayer, mFriends)
end

function CFriendMgr:_Recommend1(iPid, mFriends)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oMyFriend = oPlayer:GetFriend()
    local mMyFriends = oMyFriend:GetFriends()
    for k, v in pairs(mMyFriends) do
        mFriends[tonumber(k)] = nil
    end
    mFriends[iPid] = nil
    -- mFriends = extend.Random.sample_table(mFriends, CNT_RECOMMEND_PERTYPE)
    local iRequestCount = table_count(mFriends)
    local mHandle = {
        count = iRequestCount,
        list = {},
        is_sent = false,
    }

    for k, v in pairs(mFriends) do
        local o = oWorldMgr:GetOnlinePlayerByPid(k)
        if o then
            self:PackRecommendData(iPid, o, v.type, mHandle)
        else
            oWorldMgr:LoadProfile(k, function (o)
                if not o then
                    mHandle.count = mHandle.count - 1
                    self:JudgeSendRecommendFriends(iPid, mHandle)
                else
                    self:PackRecommendData(iPid, o, v.type, mHandle)
                end
            end)
        end
    end
end

function CFriendMgr:PackRecommendData(iPid, o, iType, mHandle)
    mHandle.count = mHandle.count - 1
    local info = {
        pid = o:GetPid(),
        name = o:GetName(),
        shape = o:GetModelInfo().shape,
        type = iType,
        grade = o:GetGrade(),
        school = o:GetSchool(),
        icon = o:GetIcon(),
    }
    table.insert(mHandle.list, info)
    self:JudgeSendRecommendFriends(iPid, mHandle)
end

function CFriendMgr:JudgeSendRecommendFriends(iPid, mHandle)
    if mHandle.count <= 0 and not mHandle.is_sent then
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send("GS2CRecommendFriends", {
                recommend_friend_list = table_value_list(mHandle.list),
            })
        end
        mHandle.is_sent = true
    end
end

function CFriendMgr:GetOtherRecommend(oPlayer, mFriends)
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    local oOrg = oPlayer:GetOrg()
    if oOrg then
        local mRecommend = oOrg:GetRecommendFriend(iPid, oPlayer:GetGrade(), CNT_RECOMMEND_LIMIT, mFriends)
        for k, _ in pairs(mRecommend) do
            mFriends[k] = {type = TYPE_RECOMMEND_ORG}
        end
    end

    local mCondition = {school=oPlayer:GetSchool()}
    interactive.Request(".rank", "rank", "GetScoreSchoolRank", mCondition,
    function(mRecord, mData)
        self:GetOtherRecommend1(iPid, mFriends, mData)
    end)
end

function CFriendMgr:GetOtherRecommend1(iPid, mFriends, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local lSortList = mData.sort_list or {}
    local iCnt = 0
    for _, sPid in ipairs(lSortList) do
        if iCnt >= CNT_RECOMMEND_LIMIT then break end
        local pid = tonumber(sPid)
        if iPid ~= pid and not mFriends[pid] then
            mFriends[pid] = {type = TYPE_RECOMMEND_SCHOOL}
            iCnt = iCnt + 1
        end
    end

    --以上三种都没玩家推荐时，选择推荐在线玩家
    if table_count(mFriends) == 0 then
        iCnt = 0
        local lOnlinePlayers = global.oWorldMgr:GetOnlinePlayerList()
        for pid, _ in pairs(lOnlinePlayers) do
            if iCnt >= CNT_RECOMMEND_LIMIT then break end
            if iPid ~= pid then
                mFriends[pid] = {type = TYPE_RECOMMEND_ONLINE}
                iCnt = iCnt + 1
            end
        end
    end
    self:_Recommend1(iPid, mFriends)
end

function CFriendMgr:AddFriend(oPlayer, iTargetPid, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    if is_ks_server() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1052))
        return
    end
    if iTargetPid == iPid then
        oNotifyMgr:Notify(iPid, self:GetTextData(1021))
        return
    end

    local oFriend = oPlayer:GetFriend()
    if oFriend:HasFriend(iTargetPid) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1004))
        return
    end
    if oFriend:IsShield(iTargetPid) then
        local oCbMgr = global.oCbMgr
        local sText = self:GetTextData(1001)
        local mData = oCbMgr:PackConfirmData(nil, {["sContent"]=sText})
        local func = function (oPlayer, mData)
            local iAnswer = mData["answer"]
            if iAnswer == 1 then
                oFriend:Unshield(iTargetPid)
                oPlayer:Send("GS2CFriendUnshield", {
                    pid_list = {iTargetPid,},
                })
                self:_AddFriend1(oPlayer, iTargetPid, mArgs)
                return
            end
        end
        oCbMgr:SetCallBack(iPid,"GS2CConfirmUI",mData,nil,func)
        return 
    end
    self:_AddFriend1(oPlayer, iTargetPid, mArgs)
end

function CFriendMgr:_AddFriend1(oPlayer, iTargetPid, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()

    oWorldMgr:LoadProfile(iTargetPid, function (o)
        if not o then
            oNotifyMgr:Notify(iPid, "不存在该玩家")
        else
            if not is_release(self) then
                self:_AddFriend2(iPid, iTargetPid, o, mArgs)
            end
        end
    end)
end

function CFriendMgr:_AddFriend2(iPid, iTargetPid, oTargetProfile, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    oWorldMgr:LoadFriend(iTargetPid, function (oTargetFriend)
        if not oTargetFriend then
            oNotifyMgr:Notify(iPid, "不存在该玩家")
        else
            if not is_release(self) then
                self:_AddFriend3(iPid, oTargetFriend, oTargetProfile, mArgs)
            end
        end
    end)
end

function CFriendMgr:_AddFriend3(iPid, oTargetFriend, oTargetProfile, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end

    if oTargetFriend:IsRefuseToggle() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1041))
        return 
    end

    mArgs = mArgs or {}
    if oTargetFriend:IsVerifyToggle() and not mArgs.ignore_verify then

        if oTargetFriend:IsShield(iPid) then
            oNotifyMgr:Notify(iPid, self:GetTextData(1041))
            return
        end

        local pMsg = {
            pid = oTargetProfile:GetPid(),
            name = oTargetProfile:GetName()
        }
        oPlayer:Send("GS2CVerifyFriend", pMsg)
    else
        local mData = self:PackAddFriend(oPlayer, oTargetProfile)
        self:_AddFriend4(iPid, oTargetFriend, mData)
    end
end

function CFriendMgr:_AddFriend4(iPid, oTargetFriend, mData, bIsBoth)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end

    local iTargetPid = oTargetFriend:GetPid()
    local oFriend = oPlayer:GetFriend()
    if oFriend:FriendCount() < oFriend:FriendsMaxCnt() then
        local bIsTargetNotBoth = oTargetFriend:HasFriend(iPid) and not oTargetFriend:IsBothFriend(iPid)

        if oFriend:IsShield(iTargetPid) then
            oFriend:Unshield(iTargetPid)
            oPlayer:Send("GS2CFriendUnshield", {
                pid_list = {iTargetPid,},
            })
        end
        oFriend:AddFriend(iTargetPid)
        oPlayer.m_bCanChatOne = true
        if oTargetFriend:HasFriend(iPid) then
            oFriend:SetBothFriend(iTargetPid)
            oTargetFriend:SetBothFriend(iPid)
            local iSub = oTargetFriend:GetFriendDegree(iPid) - oFriend:GetFriendDegree(iTargetPid)
            oFriend:AddFriendDegree(iTargetPid, 1)
            oTargetFriend:AddFriendDegree(iPid, (iSub > 0 and 0 or 1))
            mData.friend_degree = oFriend:GetFriendDegree(iTargetPid)
            mData.both = oFriend:IsBothFriend(iTargetPid) and 1 or 0
        end

        if bIsBoth then
            mData.both = oFriend:IsBothFriend(iTargetPid) and 1 or 0
        end
        oNotifyMgr:Notify(iPid, self:GetTextData(1003))
        oPlayer:Send("GS2CAddFriend", {profile_list = {mData}})
        local iFriendOnlineStatus = oFriend:GetFriendOnlineStatusById(iTargetPid) 
        if iFriendOnlineStatus then
            oPlayer:Send("GS2COnline",{pid = iTargetPid})
        else
            oPlayer:Send("GS2COffline",{pid = iTargetPid})
        end

        if iFriendOnlineStatus and bIsTargetNotBoth then
            local iBoth = oTargetFriend:IsBothFriend(iPid) and 1 or 0
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
            if oTarget then
                local mData = {
                    pid = iPid,
                    both = 1
                }
                oTarget:Send("GS2CRefreshFriendProfileBoth", mData)
            end
        end
        global.oMentoring:UpdateRecommendData(oPlayer)
    else
        local mReplace = {item=global.oItemLoader:GetItem(11144):TipsName()}
        oNotifyMgr:Notify(iPid, self:GetTextData(1002, mReplace))
    end
end

function CFriendMgr:_AddFriend5(iSourcePid, iTargetPid, oSourceProfile, oTarget, oSourceFriend, oTargetFriend)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    self:_AddFriend4(iTargetPid, oSourceFriend, self:PackAddFriend(oTarget, oSourceProfile), true)
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iSourcePid)
    if oPlayer then
        self:_AddFriend4(iSourcePid, oTargetFriend, self:PackAddFriend(oPlayer, oTarget), true)
    else
        --添加方不在线了
        if oSourceFriend:IsShield(iTargetPid) then
            oSourceFriend:Unshield(iTargetPid)
        end
        oSourceFriend:AddFriend(iTargetPid)

        if oTargetFriend:HasFriend(iSourcePid) then
            oSourceFriend:SetBothFriend(iTargetPid)
            oTargetFriend:SetBothFriend(iSourcePid)
            local iSub = oTargetFriend:GetFriendDegree(iSourcePid) - oSourceFriend:GetFriendDegree(iTargetPid)
            oSourceFriend:AddFriendDegree(iTargetPid, 1)
            oTargetFriend:AddFriendDegree(iSourcePid, (iSub > 0 and 0 or 1))
        end
    end
end

function CFriendMgr:VerifyFriend(oPlayer, iTargetPid, sVerifyMsg)
    if is_ks_server() then return end

    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    oWorldMgr:LoadFriend(iTargetPid, function(oTargetFriend)
        if not oTargetFriend then
            oNotifyMgr:Notify(iPid, "不存在该玩家")
        else
            if not is_release(self) then
                self:_VerifyFriend(oPlayer, iTargetPid, sVerifyMsg, oTargetFriend)
            end
        end
    end)
end

function CFriendMgr:_VerifyFriend(oPlayer, iTargetPid, sVerifyMsg, oTargetFriend)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    local oFriend = oPlayer:GetFriend()
    if oFriend:FriendCount() >= oFriend:FriendsMaxCnt() then
        local mReplace = {item=global.oItemLoader:GetItem(11144):TipsName()}
        oNotifyMgr:Notify(iPid, self:GetTextData(1002, mReplace))
        return
    end

    oNotifyMgr:Notify(iPid, self:GetTextData(1044))
    if oTargetFriend:HasVerifyApply(iPid) then
        return
    end

    --对方在自己的黑名单，添加对方，验证信息确认时取消
    if oFriend:IsShield(iTargetPid) then
        oFriend:Unshield(iTargetPid)
        oPlayer:Send("GS2CFriendUnshield", {
            pid_list = {iTargetPid,},
        })
    end

    local sName = oPlayer:GetName()
    oTargetFriend:AddVerifyApply(iPid, sName, sVerifyMsg)
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    if oTarget then
        oTarget:Send("GS2CVerifyFriendConfirm", {
            verify_list = { { pid = iPid, name = sName, msg = sVerifyMsg } },
        })
    end
end

function CFriendMgr:VerifyFriendConfirm(oPlayer, iResult, iSourcePid)
    if is_ks_server() then return end

    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local oFriend = oPlayer:GetFriend()
    oFriend:DelVerifyApply(iSourcePid)

    oWorldMgr:LoadFriend(iSourcePid, function(oSourceFriend)
        if not oSourceFriend then
            oNotifyMgr:Notify(oPlayer:GetPid(), "不存在该玩家")
        else
            if not is_release(self) then
                self:_VerifyFriendConfirm1(oPlayer, iResult, iSourcePid, oSourceFriend)
            end
        end
    end)
end

function CFriendMgr:_VerifyFriendConfirm1(oTarget, iResult, iSourcePid, oSourceFriend)
    
    if iResult ~= 1 then
        self:VerifyRefused(iSourcePid, oSourceFriend, 1041)
        return
    end

    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iTargetPid = oTarget:GetPid()
    local oTargetFriend = oTarget:GetFriend()
    if oTargetFriend:FriendCount() < oTargetFriend:FriendsMaxCnt() then
        oWorldMgr:LoadProfile(iSourcePid, function (oSourceProfile)
            if not oSourceProfile then
                oNotifyMgr:Notify(iTargetPid, "不存在该玩家")
            else
                if not is_release(self) then
                    self:_VerifyFriendConfirm2(iSourcePid, iTargetPid, oSourceProfile, oTarget, oSourceFriend, oTargetFriend)
                end
            end
        end)
    else
        oNotifyMgr:Notify(iTargetPid, self:GetTextData(1042))
        self:VerifyRefused(iSourcePid, oSourceFriend, 1045)
    end
end

function CFriendMgr:_VerifyFriendConfirm2(iSourcePid, iTargetPid, oSourceProfile, oTarget, oSourceFriend, oTargetFriend)
    if oSourceFriend:FriendCount() < oSourceFriend:FriendsMaxCnt() then
        self:_AddFriend5(iSourcePid, iTargetPid, oSourceProfile, oTarget, oSourceFriend, oTargetFriend)
    else
        local mData = self:PackAddFriend(oTarget, oSourceProfile)
        self:_AddFriend4(iTargetPid, oSourceFriend, mData)
    end
end

function CFriendMgr:VerifyRefused(iPid, oFriend, iErrorCode)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oNotifyMgr:Notify(iPid, self:GetTextData(iErrorCode))
    else
        oFriend:SetVerifyRefused(iErrorCode)
    end
end

function CFriendMgr:DelFriend(oPlayer, iTargetPid, endfunc)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    local oFriend = oPlayer:GetFriend()
    if is_ks_server() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1053))
        return
    end
    if not oFriend:HasFriend(iTargetPid) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1009))
        return
    end
    if global.oEngageMgr:GetEngageByPid(iPid) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1049))
        return
    end
    if oFriend:HasRelation(iTargetPid, defines.RELATION_COUPLE) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1018))
        return
    elseif oFriend:HasRelation(iTargetPid, defines.RELATION_BROTHER) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1019))
        return
    elseif oFriend:HasRelation(iTargetPid, defines.RELATION_MASTER) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1020))
        return
    elseif oFriend:HasRelation(iTargetPid, defines.RELATION_APPRENTICE) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1020))
        return
    elseif oFriend:HasRelation(iTargetPid, defines.RELATION_ENGAGE) then
        oNotifyMgr:Notify(iPid, self:GetTextData(1048))
        return
    elseif oFriend:GetFriendRelation(iTargetPid) ~= 0 then
        return
    end
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    if oHD and oHD:IsJBRelation(iPid,iTargetPid) then
        oNotifyMgr:Notify(iPid,self:GetTextData(1050))
        return 
    end
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    oWorldMgr:LoadFriend(iTargetPid, function (oTargetFriend)
        if not oTargetFriend then
            oNotifyMgr:Notify(iPid, "不存在该玩家")
        else
            if not is_release(self) then
                self:_DelFriend1(iPid, oTargetFriend, endfunc)
            end
        end
    end)
end

function CFriendMgr:_DelFriend1(iPid, oTargetFriend, endfunc)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oFriend = oPlayer:GetFriend()
    local iTargetPid = oTargetFriend:GetPid()
    oFriend:DelFriend(iTargetPid)
    oTargetFriend:ClearBothFriend(iPid)
    oNotifyMgr:Notify(iPid, self:GetTextData(1010))
    oPlayer:Send("GS2CDelFriend", {
        pid_list = {iTargetPid,},
    })
    if oTargetFriend:HasFriend(iPid) then
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
        if oTarget then
            local mData = {
                pid = iPid,
                both = 0
            }
            oTarget:Send("GS2CRefreshFriendProfileBoth", mData)
        end
    end
    if endfunc then
        endfunc()
    end
    global.oMentoring:UpdateRecommendData(oPlayer)
end

function CFriendMgr:QueryFriendProfile(oPlayer, lList)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    local oFriend = oPlayer:GetFriend()
    local lPidList = {}
    local lStrangerList = {}
    for _, v in ipairs(lList) do
        if oFriend:HasFriend(v) then
            table.insert(lPidList, v)
        else
            table.insert(lStrangerList, v)
        end
    end

    self:BatchQueryProfile(iPid, lPidList, self.SendAddFriend)
    self:BatchQueryProfile(iPid, lStrangerList, self.SendStrangerProfile)
end

function CFriendMgr:QueryPlayerProfile(oPlayer, lList,flag)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    self:BatchQueryProfile(iPid, lList, function (oFriendMgr,oPlayer,mResult)
        oFriendMgr:SendQueryPlayerProfile(oPlayer,mResult,flag)
    end)
end

function CFriendMgr:BatchQueryProfile(iPid, lPidList, sendfunc)
    local oWorldMgr = global.oWorldMgr
    local iRequestCount = #lPidList
    local mHandle = {
        count = iRequestCount,
        list = {},
        is_sent = false,
    }

    for _, k in ipairs(lPidList) do
        local o = oWorldMgr:GetOnlinePlayerByPid(k)
        if o then
            self:_HandleQueryProfile(iPid, o, mHandle, sendfunc)
        else
            oWorldMgr:LoadProfile(k, function (o)
                if not o then
                    mHandle.count = mHandle.count - 1
                    self:_JudgeSend(iPid, mHandle, sendfunc)
                else
                    self:_HandleQueryProfile(iPid, o, mHandle, sendfunc)
                end
            end)
        end
    end
end

function CFriendMgr:PackAddFriend(oPlayer, o)
    local pid = o:GetPid()
    local oFriend = oPlayer:GetFriend()
    local iFriendShip = oFriend:GetFriendDegree(pid)
    local iRelation = oFriend:GetFriendRelation(pid)
    local iBoth = oFriend:IsBothFriend(pid) and 1 or 0

    local m = {}
    m.pid = pid
    m.name = o:GetName()
    m.icon = o:GetIcon()
    m.grade = o:GetGrade()
    m.school = o:GetSchool()
    m.orgid = o:GetOrgID()
    m.orgname = o:GetOrgName()
    m.friend_degree = iFriendShip
    m.relation = iRelation
    m.both = iBoth
    return net.Mask("base.FriendProfile", m)
end

function CFriendMgr:_HandleQueryProfile(iPid, o, mHandle, sendfunc)
    mHandle.count = mHandle.count - 1
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        table.insert(mHandle.list, self:PackAddFriend(oPlayer, o))
    end
    self:_JudgeSend(iPid, mHandle, sendfunc)
end

function CFriendMgr:_JudgeSend(iPid, mHandle, sendfunc)
    if mHandle.count <= 0 and not mHandle.is_sent then
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            sendfunc(self, oPlayer, mHandle.list)
        end
        mHandle.is_sent = true
    end
end

function CFriendMgr:SendAddFriend(oPlayer, mResult)
    oPlayer:Send("GS2CAddFriend", {
        profile_list = mResult,
    })
end

function CFriendMgr:SendStrangerProfile(oPlayer, mResult)
    oPlayer:Send("GS2CStrangerProfile", {
        profile_list = mResult,
    })
end

function CFriendMgr:SendQueryPlayerProfile(oPlayer, mResult,flag)
    oPlayer:Send("GS2CPlayerProfile", {
        profile_list = mResult,
        flag = flag,
    })
end

function CFriendMgr:ChatToFriend(oPlayer, iTargetPid, sMessageId, sMsg, iForbid)
    sMsg = trim(sMsg)
    if string.len(sMsg) <= 0 then
        return
    end
    if is_ks_server() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(1054))
        return
    end

    local iBanTime = oPlayer.m_oActiveCtrl:GetBanChatTime()
    local oToolMgr = global.oToolMgr
    if iBanTime > 0 then
        local sHour, sMin, sSec = oToolMgr:FormatTime2BanChat(iBanTime)
        local sMsg = oToolMgr:FormatColorString("禁言中(#HH:#MM:#SS)", {HH=sHour, MM=sMin, SS=sSec})
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local iPid = oPlayer:GetPid()
    global.oChatMgr:RequestCheckChat(iPid, gamedefines.CHANNEL_TYPE.BASE_TYPE, sMsg, iForbid, function (mData)
        if mData.code == 1 then return end
        
        self:ChatToFriend1(iTargetPid, iPid, sMessageId, sMsg)
    end)
end

function CFriendMgr:ChatToFriend1(iTargetPid, iPid, sMessageId, sMsg)
    global.oWorldMgr:LoadFriend(iTargetPid, function (o)
        self:ChatToFriend2(iPid, sMessageId, sMsg, o)
    end)
end

function CFriendMgr:ChatToFriend2(iPid, sMessageId, sMsg, oFriend)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    if not oFriend then
        oNotifyMgr:Notify(iPid, "不存在该玩家")
    else
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer and oFriend:IsStrangerMsgToggle() and not oFriend:HasFriend(iPid) then
            oPlayer:Send("GS2CNotifyRefuseStrangerMsg", { pid = oFriend:GetPid() })
            return
        end

        if oPlayer and not oPlayer.m_bCanChatOne and oPlayer:GetGrade() <= 25 then
            return
        end

        oFriend:AddChat(iPid, sMessageId, sMsg)
        if oPlayer then
            oPlayer.m_bCanChatOne = nil
            oPlayer:Send("GS2CAckChatTo", {
                pid = oFriend:GetPid(),
                message_id = sMessageId,
            })
        end
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(oFriend:GetPid())
        if oTarget then
            oTarget:Send("GS2CChatFrom", {
                pid = iPid,
                message_id = sMessageId,
                msg = sMsg,
            })
        else
            if oFriend:ValidChatPush() then
                global.oGamePushMgr:Push(oFriend:GetPid(), "好友消息", sMsg)
            end
        end
        global.oChatMgr:LogAnalyInfo(oPlayer, gamedefines.CHANNEL_TYPE.BASE_TYPE, sMsg, oFriend:GetPid())
        -- global.oChatMgr:PushChatMsg(oPlayer, gamedefines.CHANNEL_TYPE.BASE_TYPE, sMsg)
    end
end

function CFriendMgr:AckChatFrom(oPlayer, iSourcePid, sMessageId)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local oFriend = oPlayer:GetFriend()
    oFriend:EraseChat(iSourcePid, sMessageId)
end

function CFriendMgr:FindFriendByPid(oPlayer, iTargetShowId)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    local iShowId = oPlayer:GetShowId()
    if iShowId == iTargetShowId then
        oNotifyMgr:Notify(iPid, self:GetTextData(1008))
        return
    end

    router.Request("cs", ".idsupply", "common", "GetPidByShowId", {
        show_id = iTargetShowId
    }, function (mRecord, mData)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        self:FindFriendByPid1(oPlayer, iTargetShowId, mData)
    end)
end

function CFriendMgr:FindFriendByPid1(oPlayer, iTargetPid, mData)
    iTargetPid = mData.pid or iTargetPid
    if not iTargetPid then return end

    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    if oTarget then
        self:SendNameCardInfo2(iPid, oTarget)
    else
        if is_ks_server() then
            oNotifyMgr:Notify(iPid, self:GetTextData(1051))
            return
        end
        oWorldMgr:LoadProfile(iTargetPid, function (o)
            if not o then
                oNotifyMgr:Notify(iPid, self:GetTextData(1006))
            else
                if not is_release(self) then
                    self:SendNameCardInfo2(iPid, o)
                end
            end
        end)
    end
end

function CFriendMgr:FindFriendByName(oPlayer, sName)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()

    if is_ks_server() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1051))
        return
    end
    if sName == oPlayer:GetName() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1008))
        return
    end
    if not string.match(sName, "[^%c]+") then
        oNotifyMgr:Notify(iPid, self:GetTextData(1006))
        return
    end

    local mInfo = {
        module = "playerdb",
        cmd = "GetPlayerByName",
        cond = {name=sName},
    }
    gamedb.LoadDb(iPid, "common", "DbOperate", mInfo, function (mRecord,mData)
        if not is_release(self) then
            self:FindFriendByName1(iPid, mData)
        end
    end)
end

function CFriendMgr:FindFriendByName1(iPid, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    if not mData.data then
        oNotifyMgr:Notify(iPid, self:GetTextData(1006))
        if mData.err then
            record.error("FindFriendByName err pid:%d name:%s", iPid, mData.name)
        end
        return
    else
        local iTargetPid = mData.pid
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
        if oTarget then
            self:SendNameCardInfo2(iPid, oTarget)
        else
            oWorldMgr:LoadProfile(iTargetPid, function (o)
                if not o then
                    oNotifyMgr:Notify(iPid, self:GetTextData(1006))
                else
                    if not is_release(self) then
                        self:SendNameCardInfo2(iPid, o)
                    end
                end
            end)
        end
    end
end

function CFriendMgr:SendNameCardInfo(oPlayer, iTargetPid)
    local oWorldMgr = global.oWorldMgr
    local pid = oPlayer:GetPid()
    local oOther = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    if oOther then
        self:SendNameCardInfo2(pid, oOther)
    else
        if is_ks_server() then return end

        local func = function (oProfile)
            if oProfile then
                self:SendNameCardInfo2(pid, oProfile)
            end
        end
        oWorldMgr:LoadProfile(iTargetPid,func)
    end
end

function CFriendMgr:SendNameCardInfo2(pid, o)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oRankMgr = global.oRankMgr
    local mUpvote = o:GetUpvote()
    local mNet = {}
    mNet["pid"] = o:GetPid()
    mNet["show_id"] = o:GetShowId()
    mNet["name"] = o:GetName()
    mNet["title_info"] = o:PackTitleInfo()
    mNet["grade"] = o:GetGrade()
    mNet["score"] = o:GetScore()
    mNet["achieve"] = o:GetAchieve()
    mNet["school"] = o:GetSchool()
    mNet["position"] = o:GetPosition()
    mNet["position_hide"] = o:GetPositionHide()
    mNet["orgname"] = o:GetOrgName()
    mNet["upvote_amount"] = extend.Table.size(mUpvote)
    mNet["isupvote"] = (mUpvote[pid] and 1) or 0
    mNet["rank"] = oRankMgr:GetUpvoteShowRank(db_key(o:GetPid()))
    mNet["model_info"] = o:GetModelInfo()
    oPlayer:Send("GS2CNameCardInfo", mNet)
end

function CFriendMgr:Shield(oPlayer, iTargetPid)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    if iPid == iTargetPid then
        oNotifyMgr:Notify(iPid, "不能拉黑自己")
        return
    end
    if is_ks_server() then return end

    local oFriend = oPlayer:GetFriend()
    if oFriend:IsShield(iTargetPid) then
        return
    end
    oWorldMgr:LoadProfile(iTargetPid, function (o)
        if not o then
            oNotifyMgr:Notify(iPid, "玩家不存在")
            return
        else
            local sTargetName = o:GetName()
            self:_Shield2(iPid, iTargetPid, sTargetName)
        end
    end)
end

function CFriendMgr:_Shield2(iPid, iTargetPid, sTargetName)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local func
    func = function ()
        if not is_release(self) then
            self:_Shield3(iPid, iTargetPid, sTargetName)
        end
    end
    local oFriend = oPlayer:GetFriend()
    if oFriend:HasFriend(iTargetPid) then
        self:DelFriend(oPlayer, iTargetPid, func)
        return
    end
    func()
end

function CFriendMgr:_Shield3(iPid, iTargetPid, sTargetName)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oFriend = oPlayer:GetFriend()
    if oFriend:IsShield(iTargetPid) then
        return
    end
    oFriend:Shield(iTargetPid)
    oPlayer:Send("GS2CFriendShield", {
        pid_list = {iTargetPid,},
    })
    local sText = self:GetTextData(1012)
    local oToolMgr = global.oToolMgr
    oNotifyMgr:Notify(iPid, oToolMgr:FormatColorString(sText, {role = sTargetName}))
end

function CFriendMgr:Unshield(oPlayer, iTargetPid)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    if iPid == iTargetPid then
        oNotifyMgr:Notify(iPid, "不用对自己移出黑名单")
        return
    end
    if is_ks_server() then return end

    local oFriend = oPlayer:GetFriend()
    if not oFriend:IsShield(iTargetPid) then
        return
    end
    oWorldMgr:LoadProfile(iTargetPid, function (o)
        if not o then
            oNotifyMgr:Notify(iPid, "玩家不存在")
            return
        else
            local sTargetName = o:GetName()
            self:_Unshield2(iPid, iTargetPid, sTargetName)
        end
    end)
end

function CFriendMgr:_Unshield2(iPid, iTargetPid, sTargetName)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oFriend = oPlayer:GetFriend()
    if not oFriend:IsShield(iTargetPid) then
        return
    end
    oFriend:Unshield(iTargetPid)
    oPlayer:Send("GS2CFriendUnshield", {
        pid_list = {iTargetPid,},
    })
    local sText = self:GetTextData(1017)
    local oToolMgr = global.oToolMgr
    oNotifyMgr:Notify(iPid, oToolMgr:FormatColorString(sText, {role = sTargetName}))
end

function CFriendMgr:BatchLoadFriend(lPid, endfunc, packfunc)
    local oWorldMgr = global.oWorldMgr
    local mHandle = {
        count = #lPid,
        data = {},
    }
    for _, k in ipairs(lPid) do
        oWorldMgr:LoadFriend(k, function (o)
            mHandle.count = mHandle.count - 1
            if o then
                if packfunc then
                    mHandle.data[k] = packfunc(o)
                else
                    mHandle.data[k] = true
                end
            end
            self:_BatchLoadFriend2(mHandle, endfunc)
        end)
    end
end

function CFriendMgr:_BatchLoadFriend2(mHandle, endfunc)
    if not mHandle or mHandle.count > 0 then
        return
    end
    endfunc(mHandle.data)
end

function CFriendMgr:AddFriendDegree(iPid1, iPid2, iDegree, bIsWar)
    local func
    func = function (data)
        if not is_release(self) then
            self:_AddFriendDegree2(iPid1, iPid2, iDegree, bIsWar)
            return
        end
    end
    self:BatchLoadFriend({iPid1, iPid2}, func)
end

function CFriendMgr:_AddFriendDegree2(iPid1, iPid2, iDegree, bIsWar)
    local oWorldMgr = global.oWorldMgr
    local oFriend1 = oWorldMgr:GetFriend(iPid1)
    local oFriend2 = oWorldMgr:GetFriend(iPid2)
    if not oFriend1 or not oFriend2 then
        return
    end
    if not oFriend1:HasFriend(iPid2) or not oFriend2:HasFriend(iPid1) then
        return
    end

    local iDegree12 = oFriend1:GetFriendDegree(iPid2)
    local iDegree21 = oFriend2:GetFriendDegree(iPid1)
    local iSub = iDegree12 - iDegree21
    -- local iSub = oFriend1:GetFriendDegree(iPid2) - oFriend2:GetFriendDegree(iPid1)
    if iSub > 0 then
        if bIsWar and iDegree21 >= 5000 then
            return
        end

        oFriend2:AddFriendDegree(iPid1, iDegree)
        if iDegree - iSub > 0 then
            oFriend1:AddFriendDegree(iPid2, iDegree - iSub)
        end
    else
        if bIsWar and iDegree12 >= 5000 then
            return
        end

        iSub = -iSub
        oFriend1:AddFriendDegree(iPid2,iDegree)
        if iDegree - iSub > 0 then
            oFriend2:AddFriendDegree(iPid1,iDegree - iSub)
        end
    end
    local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(iPid1)
    if oPlayer1 then
        self:GS2CRefreshDegree(oPlayer1, iPid2)
    end
    local oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if oPlayer2 then
        self:GS2CRefreshDegree(oPlayer2, iPid1)
    end
end

function CFriendMgr:SetRelation(iPid1, iPid2, iRelation1, iRelation2)
    local func
    func = function (data)
        if not is_release(self) then
            self:_SetRelation2(iPid1, iPid2, iRelation1, iRelation2)
            return
        end
    end
    self:BatchLoadFriend({iPid1, iPid2}, func)
end

function CFriendMgr:_SetRelation2(iPid1, iPid2, iRelation1, iRelation2)
    local oWorldMgr = global.oWorldMgr
    local oFriend1 = oWorldMgr:GetFriend(iPid1)
    local oFriend2 = oWorldMgr:GetFriend(iPid2)
    if not oFriend1 or not oFriend2 then
        return
    end
    local bAddFriend = false
    if not oFriend1:HasFriend(iPid2) then
        oFriend1:AddFriend(iPid2)
        bAddFriend = true
    end
    if not oFriend2:HasFriend(iPid1) then
        oFriend2:AddFriend(iPid1)
        bAddFriend = true
    end
    if bAddFriend then
        oFriend1:AddFriendDegree(iPid2, 1)
        oFriend2:AddFriendDegree(iPid1, 1)
    end
    iRelation2 = iRelation2 or iRelation1
    oFriend1:SetRelation(iPid2, iRelation2)
    oFriend2:SetRelation(iPid1, iRelation1)
    local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(iPid1)
    if oPlayer1 then
        self:GS2CRefreshRelation(oPlayer1, iPid2)
        global.oMentoring:UpdateRecommendData(oPlayer1)
    end
    local oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if oPlayer2 then
        self:GS2CRefreshRelation(oPlayer2, iPid1)
        global.oMentoring:UpdateRecommendData(oPlayer2)
    end
end

function CFriendMgr:ResetRelation(iPid1, iPid2, iRelation1, iRelation2)
    local func
    func = function (data)
        if not is_release(self) then
            self:_ResetRelation2(iPid1, iPid2, iRelation1, iRelation2)
            return
        end
    end
    self:BatchLoadFriend({iPid1, iPid2}, func)
end

function CFriendMgr:_ResetRelation2(iPid1, iPid2, iRelation1, iRelation2)
    local oWorldMgr = global.oWorldMgr
    local oFriend1 = oWorldMgr:GetFriend(iPid1)
    local oFriend2 = oWorldMgr:GetFriend(iPid2)
    if not oFriend1 or not oFriend2 then
        return
    end
    iRelation2 = iRelation2 or iRelation1
    oFriend1:ResetRelation(iPid2, iRelation2)
    oFriend2:ResetRelation(iPid1, iRelation1)
    local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(iPid1)
    if oPlayer1 then
        self:GS2CRefreshRelation(oPlayer1, iPid2)
    end
    local oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if oPlayer2 then
        self:GS2CRefreshRelation(oPlayer2, iPid1)
    end
end

function CFriendMgr:GS2CRefreshRelation(oPlayer, iTargetPid)
    if not oPlayer then
        return
    end
    local mData = {}
    mData.pid = iTargetPid
    mData.relation = oPlayer:GetFriend():GetFriendRelation(iTargetPid)
    mData = net.Mask("base.FriendProfile", mData)
    oPlayer:Send("GS2CAddFriend", {profile_list = {mData}})
end

function CFriendMgr:GS2CRefreshDegree(oPlayer, iTargetPid)
    if not oPlayer then
        return
    end
    local mData = {}
    mData.pid = iTargetPid
    mData.friend_degree = oPlayer:GetFriend():GetFriendDegree(iTargetPid)
    mData = net.Mask("base.FriendProfile", mData)
    oPlayer:Send("GS2CAddFriend", {profile_list = {mData}})
end

function CFriendMgr:RefreshFriendProfile(iPid, mData)
    local mNet = {
        message = "GS2CRefreshFriendProfile",
        type = gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE,
        id = iPid,
        data = {
            profile = net.Mask("base.FriendProfile", mData),
        }
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mNet)
end

function CFriendMgr:SendFlower(iPid1, iPid2, iFlower, iAmount, sText, iSysBless, bBuy)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if not oTarget then
        global.oNotifyMgr:Notify(iPid1, self:GetTextData(1035))
        return
    end
    if is_ks_server() then
        global.oNotifyMgr:Notify(iPid1, self:GetTextData(1055))
        return
    end
    local func = function (data)
        if not is_release(self) then
            self:_SendFlower2(iPid1, iPid2, iFlower, iAmount, sText, iSysBless, bBuy)
        end
    end
    self:BatchLoadFriend({iPid1, iPid2}, func)
end

function CFriendMgr:_SendFlower2(iPid1, iPid2, iFlower, iAmount, sText, iSysBless, bBuy)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid1)
    if not oPlayer then
        return
    end
    local oFriend1 = oWorldMgr:GetFriend(iPid1)
    local oFriend2 = oWorldMgr:GetFriend(iPid2)
    if not oFriend1 or not oFriend2 then
        return
    end
    if not oFriend1:HasFriend(iPid2) then
        oNotifyMgr:Notify(iPid1, self:GetTextData(1033))
        return
    end
    if not oFriend2:HasFriend(iPid1) then
        oNotifyMgr:Notify(iPid1, self:GetTextData(1036))
        return
    end
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if not oTarget then
        global.oNotifyMgr:Notify(iPid1, self:GetTextData(1035))
        return
    end
    local oFlower = global.oItemLoader:GetItem(iFlower)
    assert(oFlower, string.format("flower not defines %s", iFlower))
    if not oFlower:ValidSend(oPlayer, oTarget) then
        return
    end
    local iCnt = oPlayer:GetItemAmount(iFlower)
    local iRemove = iAmount
    if iCnt < iAmount then
        local iBuy = iAmount - iCnt
        local mItem = oFlower:GetItemData()
        local iCost = mItem["giftPrice"] * iBuy
        if bBuy then
            local iCostType = gamedefines.MONEY_TYPE.GOLDCOIN
            if not oPlayer:ValidMoneyByType(iCostType, iCost) then
                return
            end
            oPlayer:ResumeMoneyByType(iCostType, iCost, "鲜花赠送")
            iRemove = iCnt
        else
            local sMsg = self:GetTextData(1037)
            sMsg = global.oToolMgr:FormatColorString(sMsg, {item = oFlower:Name(), amount = iCost})
            
            local oCbMgr = global.oCbMgr
            local mData = {
                sContent = sMsg,
                sConfirm = "确定",
                sCancle = "取消",
            }
            mData = oCbMgr:PackConfirmData(nil, mData)
            local func = function (oPlayer, mData)
                global.oFriendMgr:OnBuyFlowerConfirm(oPlayer, iPid2, iFlower, iAmount, sText, iSysBless, mData)
            end
            oCbMgr:SetCallBack(iPid1, "GS2CConfirmUI", mData, nil, func)
            return
        end
    end
    if iRemove > 0 then
        oPlayer:RemoveItemAmount(iFlower, iRemove, "鲜花赠送")
    end
    local iPreAdd = oFlower:CalItemFormula(oPlayer, {})
    local iTotalAdd = iPreAdd * iAmount
    self:_AddFriendDegree2(iPid1, iPid2, iTotalAdd)
    self:PushDataToFlowerRank(oTarget, iTotalAdd)
    self:LogFlower(oPlayer, oTarget, iTotalAdd)
    oPlayer:Send("GS2CSendFlowerSuccess", {pid = iPid2, bless = sText})
    local oChatMgr = global.oChatMgr
    local oPlayer1 = oWorldMgr:GetOnlinePlayerByPid(iPid1)
    local oPlayer2 = oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if oPlayer1 then
        local sMsg = self:GetTextData(1039,{name = oPlayer2:GetName(),amount = iAmount,item = oFlower:Name()})
        oNotifyMgr:Notify(iPid1,sMsg)
        sMsg = self:GetTextData(1038,{ role = oPlayer2:GetName(),amount = iTotalAdd})
        oChatMgr:HandleMsgChat(oPlayer1,sMsg)
    end
    if oPlayer2 then
        local sMsg = self:GetTextData(1040,{name = oPlayer1:GetName(),amount = iAmount,item = oFlower:Name()})
        oNotifyMgr:Notify(iPid2,sMsg)
        sMsg = self:GetTextData(1038,{ role = oPlayer1:GetName() ,amount = iTotalAdd})
        oChatMgr:HandleMsgChat(oPlayer2,sMsg)

    end
    local iFlowerEffect, iVisible, iChuanwen = self:GetFlowerEffect(iFlower, iAmount)
    if iVisible ~= 0 and iFlowerEffect ~= 0 then
        oPlayer:Send("GS2CSceneEffect", {effect = iFlowerEffect})
        oTarget:Send("GS2CSceneEffect", {effect = iFlowerEffect})
        if iVisible == 2 then
            local oPlayerScene = oPlayer.m_oActiveCtrl:GetNowScene()
            if oPlayerScene then
                oPlayerScene:SceneAoiEffect(oPlayer, iFlowerEffect)
            end
            local oTargetScene = oTarget.m_oActiveCtrl:GetNowScene()
            if oTargetScene then
                oTargetScene:SceneAoiEffect(oTarget, iFlowerEffect)
            end
        end
    end
    
    if iChuanwen ~= 0 and sText then
        local sMsg
        local mChuanwen = res["daobiao"]["chuanwen"][1033]
        if iSysBless == 1 then
            sMsg = sText
        else
            sMsg = global.oToolMgr:FormatColorString(mChuanwen.content, {role={oPlayer:GetName(), oTarget:GetName()}, amount=iAmount, sid=oFlower:SID(), flowerbless=sText})
        end
        global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end

    global.oRankMgr:PushDataToEveryDayRank(oPlayer, "send_flower", {cnt=iAmount})
end

function CFriendMgr:OnBuyFlowerConfirm(oPlayer, iPid2, iFlower, iAmount, sText, iSysBless, mData)
    local iAnswer = mData["answer"]
    if iAnswer == 1 then
        self:SendFlower(oPlayer:GetPid(), iPid2, iFlower, iAmount, sText, iSysBless, true)
    end
end

function CFriendMgr:PushDataToFlowerRank(oPlayer, iAmount)
    oPlayer.m_oThisWeek:Add("flower", iAmount)
    local iFriendDegree = oPlayer.m_oThisWeek:Query("flower", 0)
    local mData = {}
    mData.pid = oPlayer:GetPid()
    mData.name = oPlayer:GetName()
    mData.time = get_time()
    mData.degree = iFriendDegree
    mData.school = oPlayer:GetSchool()
    global.oRankMgr:PushDataToRank("flower", mData)
end

function CFriendMgr:LogFlower(oSource, oTarget, iAmount)
    local iFriendDegree = oTarget.m_oThisWeek:Query("flower", 0)
    local mLogData = oTarget:GetFriend():LogFriendData()
    mLogData["fid"] = oSource:GetPid()
    mLogData["flower_add"] = iAmount
    mLogData["flower_now"] = iFriendDegree
    record.log_db("friend", "flower", mLogData)
end

function CFriendMgr:OpenSendFlowerUI(oPlayer, iTarget)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        self:_OpenSendFlowerUI2(iPid, oTarget)
    else
        oWorldMgr:LoadProfile(iTarget, function (o)
            if o then
                self:_OpenSendFlowerUI2(iPid, o)
            end
        end)
    end
end

function CFriendMgr:_OpenSendFlowerUI2(iPid, oTarget)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local iTarget = oTarget:GetPid()
    local oFriend = oPlayer:GetFriend()
    local iFriendShip = oFriend:GetFriendDegree(iTarget)

    local mNet = {}
    mNet.pid = iTarget
    mNet.name = oTarget:GetName()
    mNet.icon = oTarget:GetIcon()
    mNet.grade = oTarget:GetGrade()
    mNet.friend_degree = iFriendShip
    mNet.role_type = oTarget:GetRoleType()
    oPlayer:Send("GS2COpenSendFlowerUI", mNet)
end

function CFriendMgr:GetFlowerEffect(iFlower, iAmount)
    local iEffect,iVisible,iChuanwen = 0,0,0
    local mFriend = res["daobiao"]["friend"]
    local mFlower = mFriend["flower"][iFlower] or {}
    for _, list in ipairs(mFlower.effect_list or {}) do
        if list.amount == iAmount then
            local mEffect = mFriend["effect"][list.effect] or {}
            iEffect = mEffect.effect or 0
            iChuanwen = mEffect.chuanwen or 0
            iVisible = mEffect.visible or 0
            break
        end
    end
    return iEffect,iVisible,iChuanwen
end
