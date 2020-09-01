--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local geometry = require "base.geometry"
local interactive = require "base.interactive"

local huodongbase = import(service_path("huodong.huodongbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local loaditem = import(service_path("item.loaditem"))
local handleteam = import(service_path("team.handleteam"))
local datactrl = import(lualib_path("public.datactrl"))
local jiebaiobj = import(service_path("huodong.jiebai.jiebaiobj"))

local JIEBAI_STATE = {1,2,3} -- 1.结拜仪式前,2.结拜仪式期间 3.结拜仪式完成
local INVITE_STATE = {0,1} -- 0.待确认 1.确认
local YISHI_STATE = {0,1,2,3,4} -- 0.预开启 1.收集box 2.取称谓 3.取名号 4.喝酒

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

function NewJieBai(iJBID,iOwner)
    return jiebaiobj.NewJieBai(iJBID,iOwner)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "结拜系统"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iDispatch = 0
    o.m_mJieBai = {}
    o.m_mJieBaiPid ={}
    o.m_mJieBaiTitle = {}
    return o
end

function CHuodong:NewHour(mNow)
end

function CHuodong:NewDay(mNow)
    for _,oJbObj in pairs(self.m_mJieBai) do
        oJbObj:ClearValidInvite()
        oJbObj:RefreshJieBai()
    end
end

function CHuodong:OnLogin(oPlayer,reenter)
    local oToolMgr = global.oToolMgr
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("JIEBAI")
    if oToolMgr:IsSysOpen("JIEBAI", nil , true) and oPlayer:GetGrade() < iOpenGrade then
        self:AddUpgradeEvent(oPlayer)
        return
    end

    local iPid = oPlayer:GetPid()
    local oJbObj = self:GetJieBaiByPid(iPid)
    if not oJbObj then return end

    if oJbObj:HasMember(iPid) then
        oJbObj:GS2CMemberOnLogin(iPid)
        oJbObj:GS2CJBRedPoint(iPid)
    elseif oJbObj:HasInviter(iPid) then
        oJbObj:GS2CInviterOnLogin(iPid)
    end
end

function CHuodong:ClickRedPoint(oPlayer, lPoint)
    if #lPoint <= 0 then return end

    local iPid = oPlayer:GetPid()
    local oJieBai = self:GetJieBaiByPid(iPid)
    if not oJieBai then return end

    for _,iType in pairs(lPoint) do
        oJieBai:ResetRedPoint(iPid, iType)
    end
    oJieBai:GS2CJBRedPoint(iPid)
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade, iGrade)
    local oToolMgr = global.oToolMgr
    local iLimitGrade = oToolMgr:GetSysOpenPlayerGrade("JIEBAI")
    if oToolMgr:IsSysOpen("JIEBAI", nil , true) and iLimitGrade+1 == iGrade then
        local mData = {
            sContent = self:GetTextData(1003),
            sConfirm = "前往了解",
            sCancle = "暂时不用",
        }
        global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI",mData,nil,function (oPlayer,mData)
            local iAnswer = mData["answer"]
            if iAnswer == 1 then
                self:FindPathToNpc(oPlayer)
            end
        end)
    end
end

function CHuodong:FindPathToNpc(oPlayer)
    local oNpcMgr = global.oNpcMgr
    local oGlobalNpc = oNpcMgr:GetGlobalNpc(5295)
    if oGlobalNpc then
        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oGlobalNpc)
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.jiebaipid = self.m_mJieBaiPid
    local mJbData = {}
    for iJbId, oJbObj in pairs(self.m_mJieBai) do
        mJbData[iJbId] = oJbObj:Save()
    end
    mData.jiebai = mJbData
    mData.dispatch = self.m_iDispatch
    mData.jiebaititle = self.m_mJieBaiTitle
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_mJieBaiPid  = mData.jiebaipid or {}
    self.m_mJieBaiTitle = mData.jiebaititle or {}
    self.m_iDispatch = mData.dispatch or 0
    for iJBID ,mJBData in pairs(mData.jiebai or {}) do
        local jbobj = NewJieBai(iJBID,nil)
        jbobj:Load(mJBData)
        self.m_mJieBai[iJBID] = jbobj
    end
end

function CHuodong:AfterLoad()
    local lValid = {}
    local lNoValid = {}
    for iJBID,jbobj in pairs(self.m_mJieBai) do
        if jbobj:IsValid() then
            table.insert(lValid,iJBID)
        else
            table.insert(lNoValid,iJBID)
        end
    end
    for _,iJBID in ipairs(lValid) do
        local jbobj = self.m_mJieBai[iJBID]
        jbobj:AfterLoad()
    end
    for _,iJBID in ipairs(lNoValid) do
        local jbobj = self.m_mJieBai[iJBID]
        self:RemoveJieBai(jbobj)
    end
end

function CHuodong:OnServerStartEnd()
    local jblist = table_key_list(self.m_mJieBai)
    for _,iJBID in pairs(jblist) do
        local jbobj  = self.m_mJieBai[iJBID]
        if jbobj then
            if jbobj:State() == JIEBAI_STATE[2] or jbobj:GetYiShi() then
                jbobj:FailYiShi()
            end
        end
    end
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong jiebai without data"
    end
    self:Dirty()
    for iPid, iJbId in pairs(mFromData.jiebaipid or {}) do
        self.m_mJieBaiPid[iPid] = iJbId
    end
    for iJbId, mJBData in pairs(mFromData.jiebai or {}) do
        local oJbObj = NewJieBai(iJbId, nil)
        oJbObj:Load(mJBData)
        self.m_mJieBai[iJbId] = oJbObj
    end

    for sTitle, iJbId in pairs(mFromData.jiebaititle or {}) do
        if self.m_mJieBaiTitle[sTitle] then
            if self.m_mJieBai[iJbId] then
                local iLeader = self.m_mJieBai[iJbId]:Owner()
                if iLeader then
                    local oItem = global.oItemLoader:ExtCreate(10198)
                    local mData, name = global.oMailMgr:GetMailInfo(9012)
                    global.oMailMgr:SendMail(0, name, iLeader, mData, 0, {oItem})
                end
                local sNewTitle = sTitle.."*".. iJbId
                self.m_mJieBai[iJbId]:SetTitle(sNewTitle)
                self.m_mJieBaiTitle[sNewTitle] = iJbId
            end
        else
            self.m_mJieBaiTitle[sTitle] = iJbId
        end
    end
    return true
end

function CHuodong:IsDirty()
    if super(CHuodong).IsDirty(self) then
        return true
    end
    for iJBID,jbobj in pairs(self.m_mJieBai) do
        if jbobj:IsDirty() then
            return true 
        end
    end
    return false
end

function CHuodong:UnDirty()
    super(CHuodong).UnDirty(self)
    for iJBID,jbobj in pairs(self.m_mJieBai) do
        jbobj:UnDirty()
    end
end

function CHuodong:ValidEnterTeam(oPlayer,oLeader,iApply)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    oNotifyMgr:Notify(pid,self:GetTextData(1031))
    return false
end

function CHuodong:DispatchID()
    local iServerID = get_server_id()
    local iMode = math.fmod(iServerID,10000)
    local iLimitID = 1000000
    self.m_iDispatch = self.m_iDispatch + 1
    assert(self.m_iDispatch<iLimitID,string.format("%s dispatch error %s",self.m_sName,self.m_iDispatch))
    local id = iMode*iLimitID + self.m_iDispatch 
    return id
end

function CHuodong:GetConfigData()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GetInviteData()
    return res["daobiao"]["huodong"][self.m_sName]["invite_cnt"]
end

function CHuodong:GetVoteData()
    return res["daobiao"]["huodong"][self.m_sName]["vote"]
end

function CHuodong:GetMingHaoConfig()
    return res["daobiao"]["huodong"][self.m_sName]["minghao"]
end

function CHuodong:ClearJieBaiByPid(iPid)
    self:Dirty()
    self.m_mJieBaiPid[iPid] = nil
end

function CHuodong:SetJieBaiByPid(iPid, iJbId)
    self:Dirty()
    self.m_mJieBaiPid[iPid] = iJbId
end

function CHuodong:GetJieBaiByPid(iPid)
    local iJbId = self.m_mJieBaiPid[iPid]
    if not iJbId then return end
    local oJbObj  = self.m_mJieBai[iJbId]
    return oJbObj
end

function CHuodong:GetYiShiByPid(iPid)
    local iJbId = self.m_mJieBaiPid[iPid]
    if not iJbId then return end
    local oJbObj  = self.m_mJieBai[iJbId]
    if not oJbObj then return end
    return oJbObj:GetYiShi()
end

function CHuodong:RemoveJieBai(jbobj)
    self:Dirty()
    local sTitle = jbobj:GetTitle()
    jbobj:TrueRelease()
    self.m_mJieBai[jbobj:ID()] = nil
    if sTitle then
        self.m_mJieBaiTitle[sTitle] = nil
    end
    baseobj_safe_release(jbobj)
end

function CHuodong:GetJieBai(iJBID)
    return self.m_mJieBai[iJBID]
end

function CHuodong:GetTextData(iText,mReplace)
    local sText = super(CHuodong).GetTextData(self, iText)
    sText = global.oToolMgr:FormatColorString(sText,mReplace)
    return sText
end

--业务接口
function CHuodong:ValidCreateJieBai(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local oJbObj = self:GetJieBaiByPid(pid)
    if oJbObj then
        if oJbObj:HasMember(pid) then
            oNotifyMgr:Notify(pid, self:GetTextData(1048))
            return false
        end
        if oJbObj:HasInviter(pid) then
            oNotifyMgr:Notify(pid,self:GetTextData(1013))
            return false
        end
        return false
    end
    local mConfig = self:GetConfigData()
    local iNeedSilver = mConfig.create_resume
    assert(iNeedSilver>0,string.format("%s TryCreateJieBai %s error ",pid,iNeedSilver))
    if not oPlayer:ValidSilver(iNeedSilver) then return end
    if not global.oToolMgr:IsSysOpen("JIEBAI",oPlayer) then return  end
    return true
end

--创建结拜
function CHuodong:TryCreateJieBai(oPlayer)
    if not self:ValidCreateJieBai(oPlayer) then return end

    local mConfig = self:GetConfigData()
    local iNeedSilver = mConfig.create_resume
    oPlayer:ResumeSilver(iNeedSilver,"发起结拜")

    self:CreateJieBai(oPlayer)
end

function CHuodong:CreateJieBai(oPlayer)
    local iPid = oPlayer:GetPid()
    local iJbId = self:DispatchID()
    local jbobj = NewJieBai(iJbId, iPid)
    jbobj:Create({pid = iPid})
    self:SetJieBaiByPid(iPid, iJbId)
    self.m_mJieBai[iJbId] = jbobj
    local mNet = jbobj:PackData()
    oPlayer:Send("GS2CJiaBaiCreate",{jiebai_info=mNet})
end

function CHuodong:ValidInviteMember(oPlayer,iTarget)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local mConfig = self:GetConfigData()
    local iJBID = self.m_mJieBaiPid[pid]
    if not iJBID then
        oNotifyMgr:Notify(pid,self:GetTextData(1049))
        return false
    end
    local jbobj = self.m_mJieBai[iJBID] 
    if not jbobj then
        oNotifyMgr:Notify(pid,self:GetTextData(1050))
        return false
    end
    if self.m_mJieBaiPid[iTarget] then
        oNotifyMgr:Notify(pid,self:GetTextData(1056))
        return 
    end
    if not jbobj:ValidInvite() then
        oNotifyMgr:Notify(pid,self:GetTextData(1051))
        return false
    end
    if jbobj:State() == JIEBAI_STATE[2] then
        oNotifyMgr:Notify(pid,self:GetTextData(1055))
        return false
    end
    if jbobj:State() == JIEBAI_STATE[3] then
        local mInviteData = jbobj:AllInviter()
        if next(mInviteData) then
            oNotifyMgr:Notify(pid,self:GetTextData(1084))
            return 
        end
    end
    local oFriendCtrl = oPlayer:GetFriend()
    if not oFriendCtrl:HasFriend(iTarget)  then
        oNotifyMgr:Notify(pid,self:GetTextData(1052))
        return false
    end
    if not oFriendCtrl:IsBothFriend(iTarget) then
        oNotifyMgr:Notify(pid,self:GetTextData(1053))
        return false
    end
    if oFriendCtrl:GetFriendDegree(iTarget) <mConfig.friend_degree then
        oNotifyMgr:Notify(pid,self:GetTextData(1054))
        return false
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget) 
    if not oTarget then
        oNotifyMgr:Notify(pid,self:GetTextData(1092))
        return false
    end
    local oTargetFriendCtrl = oTarget:GetFriend()
    local mAllInviter = jbobj:AllInviter()
    local mAllMember = jbobj:AllMember()
    for iPid , mInfo in pairs(mAllInviter) do
        if mInfo.invitestate~=INVITE_STATE[2] then
            goto continue
        end
        local oProfile = global.oWorldMgr:GetProfile(iPid)
        local sName =string.format("玩家%s",iPid)
        if oProfile then
            sName = oProfile:GetName()
        end
        if not oTargetFriendCtrl:HasFriend(iPid)  then
            oNotifyMgr:Notify(pid,self:GetTextData(1066,{role=sName}))
            return false
        end
        if not oTargetFriendCtrl:IsBothFriend(iPid) then
            oNotifyMgr:Notify(pid,self:GetTextData(1067,{role=sName}))
            return false
        end
        if oTargetFriendCtrl:GetFriendDegree(iPid) <mConfig.friend_degree then
            oNotifyMgr:Notify(pid,self:GetTextData(1068,{role=sName}))
            return false
        end
        ::continue::
    end
    for iPid , mInfo in pairs(mAllMember) do
        local oProfile = global.oWorldMgr:GetProfile(iPid)
        local sName =string.format("玩家%s",iPid)
        if oProfile then
            sName = oProfile:GetName()
        end
        if not oTargetFriendCtrl:HasFriend(iPid)  then
            oNotifyMgr:Notify(pid,self:GetTextData(1066,{role=sName}))
            return false
        end
        if not oTargetFriendCtrl:IsBothFriend(iPid) then
            oNotifyMgr:Notify(pid,self:GetTextData(1067,{role=sName}))
            return false
        end
        if oTargetFriendCtrl:GetFriendDegree(iPid) <mConfig.friend_degree then
            oNotifyMgr:Notify(pid,self:GetTextData(1068,{role=sName}))
            return false
        end
    end
    return true
end

function CHuodong:TryInviteMember(oPlayer,iTarget)
    if not self:ValidInviteMember(oPlayer,iTarget) then
        return 
    end
    local pid = oPlayer:GetPid()
    local iJBID = self.m_mJieBaiPid[pid]
    local jbobj = self.m_mJieBai[iJBID]
    local mData = self:PackInvite(iTarget,pid)
    jbobj:AddInviter(mData)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    local sName = "对方"
    if oTarget then
        sName = oTarget:GetName()
    end
    global.oNotifyMgr:Notify(pid,self:GetTextData(1005,{role=sName}))
end

function CHuodong:PackInvite(iTarget,pid)
    local mData = {}
    mData.pid = iTarget
    mData.invitetime = get_time()
    mData.invitestate = INVITE_STATE[1]
    mData.owner = pid
    return mData
end

function CHuodong:GetValidInviteList(oPlayer)
    local pid = oPlayer:GetPid()

    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local plist = {}
    local mConfig = self:GetConfigData()
    local oFriendCtrl = oPlayer:GetFriend()
    local mFriends = oFriendCtrl:GetFriends()
    local mAllMember = jbobj:AllMember()
    local mAllInviter = jbobj:AllInviter()
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("JIEBAI")
    for k,v in pairs(mFriends) do
        local iTarget = tonumber(k)
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if not oTarget or oTarget:GetGrade() < iOpenGrade then
            goto continue
        end
        if self:GetJieBaiByPid(iTarget) then
            goto continue
        end

        local oTargetFriendCtrl = oTarget:GetFriend()
        for iPid,_ in pairs(mAllMember) do 
            if not oTargetFriendCtrl:HasFriend(iPid) then
                goto continue
            end
            if not oTargetFriendCtrl:IsBothFriend(iPid) then
                goto continue
            end
            if oTargetFriendCtrl:GetFriendDegree(iPid) < mConfig.friend_degree then
                goto continue
            end
        end        
        for iPid,_ in pairs(mAllInviter) do 
            if not oTargetFriendCtrl:HasFriend(iPid) then
                goto continue
            end
            if not oTargetFriendCtrl:IsBothFriend(iPid) then
                goto continue
            end
            if oTargetFriendCtrl:GetFriendDegree(iPid) <mConfig.friend_degree then
                goto continue
            end
        end      
        table.insert(plist,iTarget)
        ::continue::
    end
    oPlayer:Send("GS2CJBValidInviter",{plist=plist})
end

--同意邀请
function CHuodong:ArgeeInvite(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr

    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    if jbobj:State() == JIEBAI_STATE[2] then
        oNotifyMgr:Notify(pid,self:GetTextData(1058))
        return 
    end
    local mInviteData = jbobj:HasInviter(pid) 
    if not mInviteData then
        return 
    end
    local mConfig = self:GetConfigData()
    local iNeedSilver = mConfig.agree_invite
    if not oPlayer:ValidSilver(iNeedSilver) then
        return 
    end
    local iOwener = mInviteData.owner
    oPlayer:ResumeSilver(iNeedSilver,"接受结拜邀请")
    jbobj:ArgeeInvite(oPlayer)
    local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwener)
    if oOwner then
        oNotifyMgr:Notify(iOwener,self:GetTextData(1006, {role=oPlayer:GetName()}))
    end
end

--拒绝邀请
function CHuodong:DisargeeInvite(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local mInviteData = jbobj:HasInviter(pid) 
    if not mInviteData then
        return 
    end
    if jbobj:State() == JIEBAI_STATE[2] then
        oNotifyMgr:Notify(pid,self:GetTextData(1058))
        return 
    end
    local iOwener = mInviteData.owner
    jbobj:DisargeeInvite(pid)
    local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwener)
    if oOwner then
        oNotifyMgr:Notify(iOwener,self:GetTextData(1007, {role=oPlayer:GetName()}))
    end
end

--剔除邀请
function CHuodong:KickInvite(oPlayer,iTarget)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local mInviteData = jbobj:HasInviter(iTarget) 
    if not mInviteData then
        return 
    end

    if jbobj:State() == JIEBAI_STATE[2] then
        oNotifyMgr:Notify(pid,self:GetTextData(1059))
        return 
    end
    if jbobj:State() == JIEBAI_STATE[1] and jbobj:Owner() ~= pid then
        return 
    end
    if jbobj:State() == JIEBAI_STATE[3] and mInviteData.owner ~= pid then
        return 
    end

    if mInviteData.invitestate == INVITE_STATE[2] then
        local mConfig = self:GetConfigData()
        local iNeedSilver = mConfig.agree_invite
        local iMailID = mConfig.mail_id
        self:SendMail(iTarget,iMailID,{silver = iNeedSilver})
    end

    jbobj:KickInvite(iTarget)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        oNotifyMgr:Notify(iTarget,self:GetTextData(1009, {role=oPlayer:GetName()}))
    end
end

function CHuodong:KickMember(oPlayer,iTarget)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    if iTarget == pid then return end

    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end
    
    if iTarget == jbobj:Owner() then
        oNotifyMgr:Notify(pid,self:GetTextData(1078))
        return 
    end
    local mMemData = jbobj:HasMember(iTarget) 
    if not mMemData then
        return 
    end
    if jbobj:State() ~= JIEBAI_STATE[3] then
        return 
    end
    if jbobj:GetKickInfo() then
        oNotifyMgr:Notify(pid,self:GetTextData(1079))
        return 
    end
    local mAllMember = jbobj:AllMember()
    local mConfig = self:GetConfigData()
    if table_count(mAllMember) < mConfig.kickmem_limit then
        oNotifyMgr:Notify(pid,self:GetTextData(1077,{count = mConfig.kickmem_limit}))
        return 
    end
    local mKickInfo = {}
    mKickInfo.owner = pid
    mKickInfo.pid=iTarget
    mKickInfo.time =get_time()
    mKickInfo.agreelist={pid}
    mKickInfo.disagreelist={}
    jbobj:SetKickInfo(mKickInfo)
    jbobj:RefreshJieBai()
    jbobj:UpdateAllRedPoint(jiebaiobj.KICK_MEMBER, {[pid]=true})
end

function CHuodong:ArgeeKickMember(oPlayer)
    local pid = oPlayer:GetPid()
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    if jbobj:State() ~= JIEBAI_STATE[3] then
        return 
    end
    local mKickInfo = jbobj:GetKickInfo()
    if not mKickInfo then
        return 
    end
    if extend.Array.find(mKickInfo.agreelist,pid) then
        return 
    end
    if extend.Array.find(mKickInfo.disagreelist,pid) then
        return 
    end
    table.insert(mKickInfo.agreelist,pid)
    jbobj:UpdateKickInfo(mKickInfo)
    jbobj:TryKickMemSuccess()
    jbobj:RefreshJieBai()
end

function CHuodong:DisArgeeKickMember(oPlayer)
    local pid = oPlayer:GetPid()
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    if jbobj:State() ~= JIEBAI_STATE[3] then
        return 
    end
    local mKickInfo = jbobj:GetKickInfo()
    if not mKickInfo then
        return 
    end
    if extend.Array.find(mKickInfo.agreelist,pid) then
        return 
    end
    if extend.Array.find(mKickInfo.disagreelist,pid) then
        return 
    end
    table.insert(mKickInfo.disagreelist,pid)
    jbobj:UpdateKickInfo(mKickInfo)
    jbobj:TryKickMemFail()
    jbobj:RefreshJieBai()
end

--退出结拜,割袍断义
function CHuodong:QuitJieBai(oPlayer)
    local iPid = oPlayer:GetPid()
    local oJbObj = self:GetJieBaiByPid(iPid)
    if not oJbObj then return end

    if oJbObj:State() == JIEBAI_STATE[2] then
        return 
    end
    if oJbObj:HasMember(iPid) then
        if oJbObj:Owner() == iPid then
            return 
        end
        oJbObj:RemoveMember(iPid)
        oJbObj:SubFriendDegree(iPid)
        oJbObj:SendAllMemberMail(2071, {role = oPlayer:GetName()})
    elseif oJbObj:HasInviter(iPid) then
        local mInviteData = oJbObj:HasInviter(iPid)
        oJbObj:RemoveInviter(iPid)
    end
end

--解散结拜
function CHuodong:ReleaseJieBai(oPlayer)
    local iPid = oPlayer:GetPid()
    local oJbObj = self:GetJieBaiByPid(iPid)
    if not oJbObj then return end

    if oJbObj:Owner() ~= iPid then return end
    if not oJbObj:ValidRelease() then return end
    self:BackInviteConsume(oJbObj, oPlayer:GetName())
    self:RemoveJieBai(oJbObj)
end

function CHuodong:BackInviteConsume(oJbObj, sName)
    if not oJbObj or oJbObj:State() ~= JIEBAI_STATE[1] then return end

    local mAllInviter = oJbObj:AllInviter()
    for iPid, mInviteData in pairs(mAllInviter) do
        if sName then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                global.oNotifyMgr:Notify(iPid, self:GetTextData(1091, {role = sName}))
            end
        end

        if mInviteData.invitestate == INVITE_STATE[2] then
            local mConfig = self:GetConfigData()
            local iNeedSilver = mConfig.agree_invite
            local iMailID = mConfig.mail_id
            self:SendMail(iPid, iMailID, {silver = iNeedSilver})
        end
    end
end

--结拜仪式预开启
function CHuodong:JBPreStart(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    if oPlayer:HasTeam() then
        oNotifyMgr:Notify(pid,self:GetTextData(1019))
        return 
    end
    if pid ~= jbobj:Owner() then
        oNotifyMgr:Notify(pid,self:GetTextData(1026))
        return 
    end
    local bValid,iText = jbobj:ValidPreStartYiShi() 
    if not bValid then
        oNotifyMgr:Notify(pid,self:GetTextData(iText))
        return 
    end
    jbobj:PreStartYiShi()
    self:CuiCu(oPlayer)
end

--结拜仪式开启
function CHuodong:JBStart(oPlayer)
    local iPid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local jbobj = self:GetJieBaiByPid(iPid)
    if not jbobj then return end

    if iPid ~= jbobj:Owner() then
        oNotifyMgr:Notify(iPid,self:GetTextData(1026))
        return
    end
    local ysobj = jbobj:GetYiShi()
    if not ysobj then
        return 
    end
    local oYSScene = ysobj:GetScene()
    local oCurScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oYSScene:GetSceneId() ~= oCurScene:GetSceneId() then
        oNotifyMgr:Notify(iPid,self:GetTextData(1061))
        return 
    end
    local plist = oYSScene:GetAllPlayerIds()
    local mAllInviter = jbobj:AllInviter()
    local mAllMember = jbobj:AllMember()
    if table_count(plist) < table_count(mAllInviter) + table_count(mAllMember) then
        global.oNotifyMgr:Notify(iPid,self:GetTextData(1024))
        return 
    end
    ysobj:Start()
end

--催促参加结拜仪式
function CHuodong:CuiCu(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local ysobj = jbobj:GetYiShi()
    if not ysobj then
        oNotifyMgr:Notify(pid,self:GetTextData(1060))
        return 
    end
    local oYSScene = ysobj:GetScene()
    local oCurScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oYSScene:GetSceneId() ~= oCurScene:GetSceneId() then
        oNotifyMgr:Notify(pid,self:GetTextData(1061))
        return 
    end
    local plist = oYSScene:GetAllPlayerIds()
    local mAllMember = jbobj:AllMember()
    local mAllInviter = jbobj:AllInviter()
    for iTarget,_ in pairs(mAllInviter) do
        if not extend.Array.find(plist,iTarget) then
            local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
            if oTarget then
                oTarget:Send("GS2CJBYiShiChuiCu",{})
            end
        end
    end

    for iTarget, _ in pairs(mAllMember) do
        if not extend.Array.find(plist,iTarget) then
            local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
            if oTarget then
                oTarget:Send("GS2CJBYiShiChuiCu",{})
            end
        end
    end
end

--加入结拜仪式
function CHuodong:JoinYiShi(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr

    local ysobj = self:GetYiShiByPid(pid)
    if not ysobj then
        oNotifyMgr:Notify(pid,self:GetTextData(1060))
        return 
    end
    if oPlayer:HasTeam() then
        oNotifyMgr:Notify(pid,self:GetTextData(1019))
        return 
    end
    if oPlayer:InWar() then
        oNotifyMgr:Notify(pid,self:GetTextData(1096))
        return 
    end
    local oYSScene = ysobj:GetScene()
    local oCurScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oYSScene:GetSceneId() == oCurScene:GetSceneId() then
        return 
    end
    if not oCurScene:ValidLeave(oPlayer, oYSScene) then
        return
    end
    ysobj:JoinYiShi(pid)
end

function CHuodong:ChecKYiShiMember(jbobj)
    local iOwner = jbobj:Owner()
    local ysobj = jbobj:GetYiShi()
    local oYSScene = ysobj:GetScene()
    local plist = oYSScene:GetAllPlayerIds()
    local mAllInviter = jbobj:AllInviter()
    local mAllMember = jbobj:AllMember()
    if table_count(plist) == table_count(mAllInviter) + table_count(mAllMember) then
        global.oNotifyMgr:Notify(iOwner,self:GetTextData(1025))
        return 
    end
end

function CHuodong:do_look(oPlayer, npcobj)
    local pid = oPlayer:GetPid()
    local nid = npcobj.m_ID
    local npctype = npcobj:Type()
    if npctype == 1001 then
        local func = function (oPlayer,mData)
            self:Respond(oPlayer, nid, mData["answer"])
        end
        local sMsg = self:GetTextData(1001)
        local oYsObj = self:GetYiShiByPid(pid)
        if oYsObj and oYsObj:State() ~= YISHI_STATE[1] then
            sMsg = string.sub(sMsg, 1, string.find(sMsg, "&Q"))
        end
        self:SayText(pid, npcobj, sMsg, func)
    elseif npctype == 1002 then
        local ysobj = self:GetYiShiByPid(pid)
        if not ysobj or ysobj:State() ~= YISHI_STATE[2] then
            global.oNotifyMgr:Notify(pid, self:GetTextData(1098))
            return 
        end

        local func = function (oPlayer,mData)
            self:Respond(oPlayer, nid, mData["answer"])
        end
        local mConfig = self:GetConfigData() 
        local iAllCnt = mConfig.collect_box_cnt
        local iCollectSilver = mConfig.collectsilver 
        local iCollectBox = ysobj.m_iCollectBox
        local iNeedCnt = iAllCnt - iCollectBox
        local mFormat = {
            cnt = iCollectBox,
            allcnt = iAllCnt,
            amout =  iNeedCnt,
            money = iNeedCnt * iCollectSilver
        }
        local sText = self:GetTextData(1002, mFormat)
        self:SayText(pid,npcobj,sText,func)
    elseif npctype == 1003 then
        self:CollectBox(oPlayer,nid)
    end
end

function CHuodong:Respond(oPlayer, nid, iAnswer)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        return
    end
    local npctype = npcobj:Type()
    if npctype == 1001 then
        if iAnswer == 1 then
            self:JBStart(oPlayer)
        elseif iAnswer == 2 then
            self:CuiCu(oPlayer)
        elseif iAnswer == 3 then
            local mData = {
                sContent = self:GetTextData(1023),
                sConfirm = "确认",
                sCancle = "取消",
            }
            global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI",mData,nil,function (oPlayer,mData)
                local iAnswer = mData["answer"]
                if iAnswer == 1 then
                    self:LeaveYSScene(oPlayer)
                end
            end)
        end
    elseif npctype ==1002 then
        if iAnswer == 1 then
            self:FinishCollectBox(oPlayer)
        end
    end
end

--离开结拜场景
function CHuodong:LeaveYSScene(oPlayer)
    local pid = oPlayer:GetPid()
    local ysobj = self:GetYiShiByPid(pid)
    if not ysobj then return end

    local oCurScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local oYSScene = ysobj:GetScene()
    if oCurScene:GetSceneId() ~= oYSScene:GetSceneId() then
        return 
    end
    local iLeaveMapID = 101000
    local oScene = global.oSceneMgr:SelectDurableScene(iLeaveMapID)
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId())
end

--收集盒子
function CHuodong:CollectBox(oPlayer,nid)
    local pid = oPlayer:GetPid()
    local ysobj = self:GetYiShiByPid(pid)
    if not ysobj then return end

    if ysobj:State() ~= YISHI_STATE[2] then
        return 
    end
    ysobj:CollectBox(nid)
end

--快捷完成收集盒子阶段
function CHuodong:FinishCollectBox(oPlayer)
    local pid = oPlayer:GetPid()
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local ysobj = jbobj:GetYiShi()
    if not ysobj then
        return 
    end
    if ysobj:State() ~= YISHI_STATE[2] then
        return 
    end
    local mConfig = self:GetConfigData() 
    local iCollectSilver = mConfig.collectsilver 
    local iCollectBox = ysobj.m_iCollectBox
    local iNeedCnt = mConfig.collect_box_cnt - iCollectBox
    assert(iNeedCnt>0,"")
    local iNeedSilver = iNeedCnt*iCollectSilver
    if not oPlayer:ValidSilver(iNeedCnt*iCollectSilver) then
        return 
    end
    ysobj.m_iCollectBox = mConfig.collect_box_cnt
    oPlayer:ResumeSilver(iNeedSilver,string.format("%s_collect_box",self.m_sName))
    ysobj:SetTitle()
end

--选取称谓
function CHuodong:SetTitle(oPlayer,sTitle)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local mConfig = self:GetConfigData()
    if jbobj:State() == JIEBAI_STATE[2] then
        local ysobj = jbobj:GetYiShi()
        if not ysobj then return end

        if ysobj:State() ~= YISHI_STATE[3] then
            return 
        end
    elseif jbobj:State() == JIEBAI_STATE[3] then
        local oItem = oPlayer.m_oItemCtrl:GetItemObj(10198)
        if not oItem and jbobj:GetJieYi()<mConfig.title_jieyi then
            oNotifyMgr:Notify(pid,self:GetTextData(1041))
            return 
        end
    else
        return
    end

    if pid ~= jbobj:Owner() then
        oNotifyMgr:Notify(pid,self:GetTextData(1035))
        return 
    end
    if not sTitle then
        oNotifyMgr:Notify(pid,self:GetTextData(1032))
        return 
    end
    
    if not self:CheckSameTitle(sTitle) then
        oNotifyMgr:Notify(pid,self:GetTextData(1033))
        return 
    end

    --如果是改称谓,则需要结义值
    if jbobj:State() == JIEBAI_STATE[3] then
        local oItem = oPlayer.m_oItemCtrl:GetItemObj(10198)
        if oItem then
            oPlayer:RemoveOneItemAmount(oItem, 1, "jiebai")
        else
            jbobj:AddJieYi(-mConfig.title_jieyi)
        end
        jbobj:TryFinishSetTitle(sTitle)
        jbobj:RefreshMemberTitle()
        jbobj:RefreshJieBai()
    else
        jbobj:TryFinishSetTitle(sTitle, true)
    end
end

function CHuodong:RecordTitle(iJbId, sNewTitle, sOldTitle)
    if sOldTitle and self.m_mJieBaiTitle[sOldTitle] then
        self.m_mJieBaiTitle[sOldTitle] = nil
    end
    self.m_mJieBaiTitle[sNewTitle] = iJbId
end

function CHuodong:CheckSameTitle(sTitle)
    return not self.m_mJieBaiTitle[sTitle]
end

--选取名号
function CHuodong:SetMingHao(oPlayer,sMingHao)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    if not sMingHao then
        oNotifyMgr:Notify(pid,self:GetTextData(1032))
        return 
    end

    local bSame, sName = jbobj:CheckSameMingHao(sMingHao)
    if bSame then
        oNotifyMgr:Notify(pid, self:GetTextData(1037, {role = sName}))
        return 
    end

    local ysobj = jbobj:GetYiShi()
    if ysobj and ysobj:State() == YISHI_STATE[4] then 
        jbobj:TryFinishSetMingHao(pid,sMingHao)
    elseif jbobj:State() == JIEBAI_STATE[3] then
        local mMemData = jbobj:HasMember(pid)
        if not mMemData then
            return
        end
        if mMemData.free_minghao then
            mMemData.free_minghao = nil
        else
            local mConfig = self:GetConfigData()
            local iSilver = mConfig.minghao_silver
            if not oPlayer:ValidSilver(iSilver) then
                return 
            end
            oPlayer:ResumeSilver(iSilver,"改名号")
        end
        jbobj:SetMingHao(pid,sMingHao)
        jbobj:RefreshJieBai()
        jbobj:RefreshMemberTitle(pid)
    end
end

--喝酒
function CHuodong:JingJiu(oPlayer)
    local pid = oPlayer:GetPid()
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    local ysobj = jbobj:GetYiShi()
    if not ysobj then return end

    if ysobj:State() ~= YISHI_STATE[5] then
        return 
    end
    if not jbobj:ValidHejiu(pid) then
        return 
    end
    jbobj:TryFinishHejiu(pid)
end

--设置宣言
function CHuodong:SetEnounce(oPlayer,sEnounce)
    local pid = oPlayer:GetPid()
    local jbobj = self:GetJieBaiByPid(pid)
    if not jbobj then return end

    if jbobj:State() ~=JIEBAI_STATE[3] then
        return 
    end
    if jbobj:Owner() ~= pid then
        return 
    end
    jbobj:SetEnounce(sEnounce)
end

--是否有结拜关系
function CHuodong:IsJBRelation(pid1,pid2)
    if not self.m_mJieBaiPid[pid1] then return false end

    return self.m_mJieBaiPid[pid1] == self.m_mJieBaiPid[pid2]
end

function CHuodong:OnWarEnd(mArgs)
    local bOpen = global.oToolMgr:IsSysOpen("JIEBAI", nil , true)
    if not bOpen then return end

    for iSide=1, 2 do
        local lPlayer = mArgs.player[iSide] or {}
        local lDie = mArgs.die[iSide] or {}
        local iSidePlayer = table_combine(lPlayer, lDie)
        self:DealWarCampJieYiValue(iSidePlayer)
    end
end

function CHuodong:DealWarCampJieYiValue(lPlayer)
    if table_count(lPlayer) < 2 then return end
    local mJbPlayer = {}
    for _, iPid in ipairs(lPlayer) do
        if self.m_mJieBaiPid[iPid] then
            local iJbId = self.m_mJieBaiPid[iPid]
            if not mJbPlayer[iJbId] then 
                mJbPlayer[iJbId] = {}
            end
            table.insert(mJbPlayer[iJbId], iPid)
        end
    end

    for iJbId, lList in pairs(mJbPlayer) do
        local iJbValue = #lList
        if iJbValue > 1 then --两个玩家及以上才给结义值
            local oJbObj = self:GetJieBai(iJbId)
            if oJbObj and oJbObj:State() == JIEBAI_STATE[3] then
                oJbObj:AddJieYi(iJbValue)
                oJbObj:RefreshJieBai()
            end
        end
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 增加结义值\nhuodongop jiebai 101 {value=10}",
        "102 强制解散结拜\nhuodongop jiebai 102",
        "103 冷却时间n秒后结束\nhuodongop jiebai 103 {sec=5}",
        "104 仪式预开启阶段n秒后结束\nhuodongop jiebai 104 {sec=5}",
        "105 仪式称谓阶段n秒后结束\nhuodongop jiebai 105 {sec=5}",
        "106 仪式名号阶段n秒后结束\nhuodongop jiebai 106 {sec=5}",
        "107 解散所有结拜\nhuodongop jiebai 107",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag ==101 then
        local oJbObj = self:GetJieBaiByPid(pid)
        if oJbObj then
            oJbObj:AddJieYi(mArgs.value or 10)
            oJbObj:RefreshJieBai()
        end
    elseif iFlag == 102 then
        local oJbObj = self:GetJieBaiByPid(pid)
        if oJbObj then
            self:RemoveJieBai(oJbObj)
            oNotifyMgr:Notify(pid,"清除成功")
        end
    elseif iFlag == 103 then
        local oJbObj = self:GetJieBaiByPid(pid)
        if oJbObj then
            local iTime = mArgs.sec or 5
            oJbObj.m_iCreateYSTime = get_time() - 3600 + 5
            oJbObj:RefreshJieBai()
            local sMsg = string.format("%d秒后冷却结束", iTime)
            oNotifyMgr:Notify(pid, sMsg)
        else
            oNotifyMgr:Notify(pid,"没有结拜")
        end
    elseif iFlag == 104 then
        local oYsObj = self:GetYiShiByPid(pid)
        if oYsObj then
            if oYsObj:State() == YISHI_STATE[1] then
                local iTime = mArgs.sec or 5
                oYsObj.m_iStateTime = get_time()
                oYsObj:AddPreStartCb(iTime)
                oYsObj:GetJieBai():RefreshJieBai()
                local sMsg = string.format("%d秒后预开启阶段结束", iTime)
                oNotifyMgr:Notify(pid, sMsg)
            else
                oNotifyMgr:Notify(pid,"仪式不在预开启阶段")
            end
        else
            oNotifyMgr:Notify(pid,"没有仪式")
        end
    elseif iFlag == 105 then
        local oYsObj = self:GetYiShiByPid(pid)
        if oYsObj then
            if oYsObj:State() == YISHI_STATE[3] then
                local iTime = mArgs.sec or 5
                oYsObj.m_iStateTime = get_time()
                oYsObj:AddSetTitleCb(iTime)
                oYsObj:GetJieBai():RefreshJieBai()
                local sMsg = string.format("%d秒后称谓阶段结束", iTime)
                oNotifyMgr:Notify(pid, sMsg)
            else
                oNotifyMgr:Notify(pid,"仪式不在称谓阶段")
            end
        else
            oNotifyMgr:Notify(pid,"没有仪式")
        end
    elseif iFlag == 106 then
        local oYsObj = self:GetYiShiByPid(pid)
        if oYsObj then
            if oYsObj:State() == YISHI_STATE[4] then
                local iTime = mArgs.sec or 5
                oYsObj.m_iStateTime = get_time()
                oYsObj:AddSetMingHaoCb(iTime)
                oYsObj:GetJieBai():RefreshJieBai()
                local sMsg = string.format("%d秒后名号阶段结束", iTime)
                oNotifyMgr:Notify(pid, sMsg)
            else
                oNotifyMgr:Notify(pid,"仪式不在名号阶段")
            end
        else
            oNotifyMgr:Notify(pid,"没有仪式")
        end
    elseif iFlag == 107 then
        for iJbId, oJbObj in pairs(self.m_mJieBai) do
            self:RemoveJieBai(oJbObj)
        end
        self:Dirty()
        self.m_mJieBai = {}
        self.m_mJieBaiTitle = {}
        self.m_mJieBaiPid = {}
        oNotifyMgr:Notify(pid, "解散所有结拜")
    end
end