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
local yishiobj = import(service_path("huodong.jiebai.yishiobj"))

-- 红点枚举
KICK_MEMBER = 1

function NewJieBai(iJBID,iOwner)
    return CJieBai:New(iJBID,iOwner)
end

function NewYiShi(iJBID)
    return yishiobj.NewYiShi(iJBID)
end

local JIEBAI_STATE = {1,2,3} -- 1.结拜仪式前,2.结拜仪式期间 3.结拜仪式完成
local INVITE_STATE = {0,1} -- 0.待确认 1.确认
local VOTE_STATE = {0,1} ---0.待确认 1.同意

CJieBai = {}
CJieBai.__index = CJieBai
inherit(CJieBai, datactrl.CDataCtrl)

function CJieBai:New(iJBID,iOwner)
    local o = super(CJieBai).New(self)
    o.m_ID = iJBID
    o.m_iOwner = iOwner
    o.m_mInviter = {}
    o.m_mMember = {}
    o.m_iState = JIEBAI_STATE[1]
    o.m_iCreateTime = 0
    o.m_iInviteLimit = 0
    o.m_oYiShi = nil
    o.m_iCreateYSTime = 0
    o.m_sTitle = nil
    o.m_sEnounce = nil
    o.m_mVote = {}
    o.m_iJieYi = 0
    o.m_mKickInfo = nil
    o.m_bFreeChangeTitle = false
    return o
end

function CJieBai:ID()
    return self.m_ID
end

function CJieBai:Save()
    local mData = {}
    mData.id = self.m_ID
    mData.member = self.m_mMember
    mData.inviter = self.m_mInviter
    mData.state = self.m_iState
    mData.owner = self.m_iOwner
    mData.createtime = self.m_iCreateTime
    mData.invitelimit = self.m_iInviteLimit
    mData.createystime = self.m_iCreateYSTime
    mData.title = self.m_sTitle
    mData.enounce = self.m_sEnounce
    mData.vote = self.m_mVote
    mData.jieyi = self.m_iJieYi
    mData.kickinfo = self.m_mKickInfo
    mData.freechangetitle = self.m_bFreeChangeTitle
    return mData
end

function CJieBai:Load(mData)
    mData = mData or {}
    self.m_ID = mData.id or 0
    self.m_mMember = mData.member or {}
    self.m_mInviter = mData.inviter or{}
    self.m_iState = mData.state or JIEBAI_STATE[1]
    self.m_iOwner = mData.owner or 0
    self.m_iCreateTime = mData.createtime or 0
    self.m_iInviteLimit = mData.invitelimit or 0
    self.m_iCreateYSTime = mData.createystime or 0
    self.m_sTitle = mData.title
    self.m_sEnounce = mData.enounce
    self.m_mVote = mData.vote or {}
    self.m_iJieYi = mData.jieyi or 0
    self.m_mKickInfo = mData.kickinfo
    self.m_bFreeChangeTitle = freechangetitle or false
end

function CJieBai:AfterLoad()
    self:CreateInviterTimer()
    self:CreateKickOutTimer()
end

function CJieBai:ValidRelease() --是否解散结拜
    if self.m_iState == JIEBAI_STATE[1] then
        return true 
    end
    if  self.m_iState == JIEBAI_STATE[2] then
        return false
    end
    if table_count(self.m_mMember) + table_count(self.m_mInviter) >1 then
        return false
    end 
    return true
end

function CJieBai:TrueRelease() --解散结拜
    self:Dirty()
    local oHD = self:GetHD()
    for pid,_ in pairs(self.m_mInviter) do
        oHD:ClearJieBaiByPid(pid)
        if global.oWorldMgr:GetOnlinePlayerByPid(pid) then
            self:GS2CRemoveJieBai(pid)
        end
    end 
    for pid,_ in pairs(self.m_mMember) do
        oHD:ClearJieBaiByPid(pid)
        self:RemoveMemberTitle(pid)
        if global.oWorldMgr:GetOnlinePlayerByPid(pid) then
            self:GS2CRemoveJieBai(pid)
        end
    end
end

function CJieBai:Release()
    self:ClearTimer()
    local ysobj = self.m_oYiShi
    self.m_oYiShi = nil 
    if ysobj then
        baseobj_safe_release(ysobj)
    end
    super(CJieBai).Release(self)
end

function CJieBai:IsValid()  --创建结拜是否过期
    local iTime = self:GetInviteTime()
    if self.m_iState == JIEBAI_STATE[1] and self.m_iCreateTime + iTime <= get_time() then
        return false
    end
    return true
end

function CJieBai:GetInviteTime()
        local mConfig = self:GetConfigData()
        local iTime = mConfig.invite_time
        assert(iTime>0,"")
        return iTime
end

function CJieBai:Create(mData)
    self:Dirty()
    local mConfig  = self:GetConfigData()
    self.m_mMember[self.m_iOwner] = mData
    self.m_iCreateTime = get_time()
    local mInviteData = self:GetInviteData()
    self.m_iInviteLimit = mInviteData[0]["limit"]
    self:CreateInviterTimer()
end

function CJieBai:GetConfigData()
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    local mConfig = oHD:GetConfigData()
    return mConfig
end

function CJieBai:GetInviteData()
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    local mData = oHD:GetInviteData()
    return mData
end

function CJieBai:GetHD()
    return global.oHuodongMgr:GetHuodong("jiebai")
end

function CJieBai:NotifyAll(iText,mReplace)
    local oHD = self:GetHD()
    local sText = oHD:GetTextData(iText,mReplace)
    for pid,_ in pairs(self.m_mInviter) do
        global.oNotifyMgr:Notify(pid,sText)
    end
    for pid,_ in pairs(self.m_mMember) do
        global.oNotifyMgr:Notify(pid,sText)
    end
end

function CJieBai:Owner()
    return self.m_iOwner
end

function CJieBai:State()
    return self.m_iState
end

function CJieBai:SetState(iState)
    self:Dirty()
    self.m_iState = iState
end

function CJieBai:GetInviteLimit()   --邀请数量上限
    return self.m_iInviteLimit
end

function CJieBai:ValidInvite()  --邀请数量判断
    if table_count(self.m_mMember) + table_count(self.m_mInviter) >=self:GetInviteLimit() then
        return false
    end 
    return true
end

function CJieBai:HasMember(pid)
    return self.m_mMember[pid]
end

function CJieBai:AllMember()
    return self.m_mMember
end

function CJieBai:AllInviter()
    return self.m_mInviter
end

function CJieBai:HasInviter(pid)
    return self.m_mInviter[pid]
end

function CJieBai:AddInviter(mData)
    local oHD = self:GetHD()
    oHD:SetJieBaiByPid(mData.pid,self.m_ID)
    self:Dirty()
    self.m_mInviter[mData.pid]  = mData
    self:GS2CAddInviter(mData.pid)
    self:GS2CBecomeInviter(mData.pid)
end

function CJieBai:ClearValidInvite()
    local lDel = {}
    for pid,mData in pairs(self.m_mInviter) do
        if mData.invitestate == INVITE_STATE[1] then
            table.insert(lDel,pid)
        end
    end
    for _,pid in ipairs(lDel) do
        self:RemoveInviter(pid)
    end
end

function CJieBai:AddMember(pid, sMingHao, bFirstMhFree)
    local oHD = self:GetHD()
    oHD:SetJieBaiByPid(pid,self.m_ID)
    self:Dirty()
    local mMemData = {}
    mMemData.pid = pid
    mMemData.memtime = get_time()
    mMemData.minghao = sMingHao
    mMemData.free_minghao = bFirstMhFree
    self.m_mMember[pid]  = mMemData
    if not sMingHao then
        self:GS2CAddMember(pid)
        self:GS2CBecomeMember(pid)
    end
end

function CJieBai:RemoveInviter(pid)
    local oHD = self:GetHD()
    oHD:ClearJieBaiByPid(pid)
    self:Dirty()
    self.m_mInviter[pid]  = nil
    self:GS2CRemoveInviter(pid)
    self:GS2CRemoveJieBai(pid)
end

function CJieBai:RemoveMember(pid)
    local oHD = self:GetHD()
    oHD:ClearJieBaiByPid(pid)
    self:Dirty()
    self:RemoveMemberTitle(pid)
    self.m_mMember[pid] = nil
    if self.m_mKickInfo then
        if self.m_mKickInfo.owner == pid then
            self:RemoveKickInfo()
        elseif self.m_mKickInfo.pid == pid then
            self:RemoveKickInfo()
        elseif extend.Array.find(self.m_mKickInfo.agreelist,pid) then
            extend.Array.remove(self.m_mKickInfo.agreelist,pid)
            self:TryKickMemSuccess()
            self:TryKickMemFail()
        elseif extend.Array.find(self.m_mKickInfo.disagreelist,pid) then
            extend.Array.remove(self.m_mKickInfo.disagreelist,pid)
            self:TryKickMemSuccess()
            self:TryKickMemFail()
        end
    end
    self:GS2CRemoveMember(pid)
    self:GS2CRemoveJieBai(pid)
end

function CJieBai:SetTitle(sTitle)
    self:Dirty()
    
    local sOldTitle = self.m_sTitle
    local oHD = self:GetHD()
    oHD:RecordTitle(self:ID(), sTitle, sOldTitle)

    self.m_sTitle = sTitle
end

function CJieBai:GetTitle()
    return self.m_sTitle
end

function CJieBai:GetMingHao(iPid)
    local mMember = self.m_mMember[iPid]
    if mMember then 
        return mMember.minghao 
    end
end

function CJieBai:CheckSameMingHao(sMingHao)
    local bSame = false
    local sName = ""
    for pid,mData in pairs(self.m_mInviter) do 
        if mData.minghao == sMingHao then
            bSame = true
            local oProfile = global.oWorldMgr:GetProfile(pid)
            if oProfile then sName = oProfile:GetName() end
            break
        end
    end 
    for pid,mData in pairs(self.m_mMember) do 
        if mData.minghao == sMingHao then
            bSame = true
            local oProfile = global.oWorldMgr:GetProfile(pid)
            if oProfile then sName = oProfile:GetName() end
            break
        end
    end
    return bSame, sName
end

function CJieBai:SetMingHao(pid,sMingHao)
    self:Dirty()
    local mData = self.m_mInviter[pid]
    if mData then
        mData.minghao = sMingHao
    end
    mData = self.m_mMember[pid]
    if mData then
        mData.minghao = sMingHao
    end
end

function CJieBai:SetRedPoint(iPid, iType)
    local mMember = self.m_mMember[iPid]
    if not mMember then return end

    local iRedPoint = mMember.red_point or 0
    mMember.red_point = iRedPoint | 2 ^ (iType - 1)
    self:Dirty()
end

function CJieBai:ResetRedPoint(iPid, iType)
    local mMember = self.m_mMember[iPid]
    if not mMember then return end
    
    local iRedPoint = mMember.red_point or 0
    mMember.red_point = iRedPoint & ~ (2 ^ (iType - 1))
    self:Dirty()
end

function CJieBai:GetRedPoint(iPid)
    local mMember = self.m_mMember[iPid]
    if not mMember then return end
    
    return mMember.red_point
end

function CJieBai:GS2CJBRedPoint(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CJBRedPoint",{red_point = self:GetRedPoint(iPid)})
    end
end

function CJieBai:UpdateAllRedPoint(iType, mExclude, bResert)
    mExclude = mExclude or {}
    for iPid,_ in pairs(self.m_mMember) do
        if not mExclude[iPid] then
            if bResert then
                self:ResetRedPoint(iPid, iType)
            else
                self:SetRedPoint(iPid, iType)
            end
            self:GS2CJBRedPoint(iPid)
        end
    end
end

--有效期控制
function CJieBai:ClearTimer()
    self:DelTimeCb("InviterTimer")
    self:DelTimeCb("FinishYiShi")
    self:DelTimeCb("CheckKickOut")
end

function CJieBai:CreateInviterTimer( )
    if self.m_iState ~=  JIEBAI_STATE[1] then
        return 
    end
    local sFlag = "InviterTimer"
    self:DelTimeCb(sFlag)
    local iTime = self:GetInviteTime()
    assert(iTime>0,string.format("%s %s %s CreateInviterTimer",self.m_ID,self.m_iOwner,iTime))
    local iExistTime = get_time() - self.m_iCreateTime
    if iExistTime<0 then
        record.warning(string.format("%s %s jiebai time error1 ",iExistTime,self.m_iCreateTime))
        return 
    end
    if iExistTime>=iTime then
        record.warning(string.format("%s %s jiebai time error2 ",iExistTime,iTime))
        return 
    end
    iTime = iTime - iExistTime
    self:AddTimeCb(sFlag,iTime*1000,function ()
        _CheckJBEnd(self.m_ID,sFlag)
    end)
end

function CJieBai:CheckJBEnd(sFlag)
    self:DelTimeCb(sFlag)
    if self.m_iState ~=  JIEBAI_STATE[1] then
        return 
    end
    local iTime = self:GetInviteTime()
    if get_time()>=self.m_iCreateTime + iTime then
        local oHD = self:GetHD()
        oHD:BackInviteConsume(self)
        oHD:RemoveJieBai(self)
    end
end

--邀请相关
function CJieBai:ArgeeInvite(oPlayer)
    self:Dirty()
    local pid = oPlayer:GetPid()
    if self:State() == JIEBAI_STATE[1] then
        local mInviteData = self:HasInviter(pid)
        mInviteData.invitestate = INVITE_STATE[2]
        self.m_mInviter[pid] = mInviteData
        self:RefreshInviter(pid)
        self:RefreshJieBai(pid)
    elseif self:State() == JIEBAI_STATE[3] then
        local mInviteData = self:HasInviter(pid)
        if mInviteData then
            self:RemoveInviter(pid)
        end
        local mExclude = self:GetUseMingHao()
        self:AddMember(pid, self:RandomMingHao(pid, mExclude), true)
        self:AddMemberTitle(pid)
        self:RefreshJieBai()
        self:SendAllMemberMail(2070, {role = oPlayer:GetName()})
    end
end

function CJieBai:SendAllMemberMail(iMail, mFormat)
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHD then return end
    for iPid, _ in pairs(self.m_mMember) do
        oHD:SendMail(iPid, iMail, {}, mFormat)
    end
end

function CJieBai:DisargeeInvite(pid)
    self:RemoveInviter(pid)
end

function CJieBai:KickInvite(pid)
    self:RemoveInviter(pid)
end

    --仪式相关--
function CJieBai:GetYiShi()
    return self.m_oYiShi
end

function CJieBai:FailYiShi()
    self:Dirty()
    self.m_iCreateYSTime = get_time()
    self.m_iState = JIEBAI_STATE[1]
    local ysobj = self.m_oYiShi
    if ysobj then
        baseobj_safe_release(ysobj)
    end
    self.m_oYiShi = nil 
    self:ClearYSInfo()
    self:RefreshJieBai()
end

function CJieBai:ClearYSInfo()
    for pid , mData in pairs(self.m_mInviter) do
        mData.minghao = nil 
        mData.hejiu  = nil 
    end
    for pid , mData in pairs(self.m_mMember) do
        mData.minghao = nil 
        mData.hejiu  = nil 
    end
    self.m_sTitle = nil 
end

--预开启仪式
function CJieBai:ValidPreStartYiShi()
    local mConfig = self:GetConfigData()
    if table_count(self.m_mMember) + table_count(self.m_mInviter) <=1 then
        return false,1014
    end 
    for pid,mInviteData in pairs(self.m_mInviter) do
        if mInviteData.invitestate == INVITE_STATE[1] then
            return false,1015
        end
        if not global.oWorldMgr:GetOnlinePlayerByPid(pid) then
            return  false, 1016
        end
    end
    if self.m_iCreateYSTime>0 and self.m_iCreateYSTime + mConfig.yishi_cd > get_time() then
        return false,1021
    end
    local ysobj = self:GetYiShi() 
    if ysobj then
        return   false,1064
    end
    return true,0
end

function CJieBai:PreStartYiShi()
    self:Dirty()
    local ysobj = NewYiShi(self.m_ID)
    assert(ysobj,"")
    self.m_oYiShi = ysobj
    self.m_iState = JIEBAI_STATE[2]
    ysobj:PreStart(self.m_iOwner)
end

--设置称谓
function CJieBai:TryFinishSetTitle(sTitle, bYiShi)
    self:SetTitle(sTitle)
    if bYiShi then
        local ysobj = self.m_oYiShi
        ysobj:SetMingHao()
    end
end

--随机称号, 默认随机两个名号拼接起来组成称号
function CJieBai:AutoSetTitle()
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    local mConfig = oHD:GetMingHaoConfig()
    local lKeys = table_key_list(mConfig)
    local iMaxCnt = #lKeys

    local mExcludeFirst = {}
    for i=1, iMaxCnt do
        local sFirstMH = self:RandomMingHao(iOwner, mExcludeFirst)
        local mExcludeSec = {}
        for j=1, iMaxCnt do
            local sSecondMH = self:RandomMingHao(iOwner, mExcludeSec)
            local sRandomTitle = string.format("%s%s", sFirstMH, sSecondMH)
            if oHD:CheckSameTitle(sRandomTitle) then
                self:SetTitle(sRandomTitle)
                return
            else
                mExcludeSec[sSecondMH] = true
            end
        end
        mExcludeFirst[sFirstMH] = true
    end

    --以防万一, 按理不需要走到这里就已随机到了
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:Owner())
    local sName = oPlayer:GetName()
    self:SetTitle(sName)
end

--设置名号
function CJieBai:TryFinishSetMingHao(pid,sMingHao)
    self:Dirty()
    local mData = self.m_mInviter[pid]
    if mData then
        mData.minghao = sMingHao
    end
    local mData = self.m_mMember[pid]
    if mData then
        mData.minghao = sMingHao
    end
    local bHeJiu = true
    for pid,mData in pairs(self.m_mMember) do
        if not mData.minghao then
            bHeJiu = false 
            break
        end
    end
    for pid,mData in pairs(self.m_mInviter) do
        if not mData.minghao then
            bHeJiu = false  
            break
        end
    end
    local ysobj = self:GetYiShi()
    if bHeJiu then
        ysobj:SetHejiu()
    else
        self:RefreshJieBai()
    end
end

function CJieBai:RandomMingHao(iPid, mExclude)
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    local mConfig = oHD:GetMingHaoConfig()
    local lKeys = table_key_list(mConfig)
    local iMaxCnt = #lKeys
    
    local sRandom
    local iRandom = math.random(1, iMaxCnt)
    for i= 1, iMaxCnt do
        local m = mConfig[iRandom]
        if not mExclude[m.minghao] then
            sRandom = m.minghao
            break
        end
        if iRandom >= iMaxCnt then
            iRandom = 1
        else
            iRandom = iRandom + 1
        end
    end
    if not sRandom then
        record.warning(string.format("jiebai RandomMingHao nil PID:%s ",iPid))
        return
    end
    return sRandom
end

function CJieBai:GetUseMingHao()
    local mMingHao = {}
    for _,m in pairs(self.m_mInviter) do
        if m.minghao then
            mMingHao[m.minghao] = true
        end
    end
    for _,m in pairs(self.m_mMember) do
        if m.minghao then
            mMingHao[m.minghao] = true
        end
    end
    return mMingHao
end

function CJieBai:AutoSetMingHao()
    self:Dirty()

    local mExclude = self:GetUseMingHao()
    for iPid,mData in pairs(self.m_mInviter) do
        if not mData.minghao then
            local sMingHao = self:RandomMingHao(iPid, mExclude)
            mData.minghao = sMingHao
            mExclude[sMingHao] = true
        end
    end
    for iPid,mData in pairs(self.m_mMember) do
        if not mData.minghao then
            local sMingHao = self:RandomMingHao(iPid, mExclude)
            mData.minghao = sMingHao
            mExclude[sMingHao] = true
        end
    end
end

--喝酒
function CJieBai:ValidHejiu(pid)
    local mData = self.m_mInviter[pid]
    if mData and not mData.hejiu  then
        return true 
    end
    mData = self.m_mMember[pid] 
    if mData and not mData.hejiu  then
        return true 
    end
    return false
end

function CJieBai:TryFinishHejiu(pid)
    self:Dirty()
    local mData = self.m_mInviter[pid]
    if mData then
        mData.hejiu = true
    end
    mData = self.m_mMember[pid] 
    if mData then
        mData.hejiu = true
    end
    local bHejiu = true
    for pid,mData in pairs(self.m_mInviter) do
        if not mData.hejiu then
            bHejiu = false
            break
        end
    end
    for pid,mData in pairs(self.m_mMember) do
        if not mData.hejiu then
            bHejiu = false
            break
        end
    end
    if bHejiu then
        self:TrueHejiu()
    end
end

function CJieBai:AutoFinishHejiu()
    self:Dirty()
    for pid,mData in pairs(self.m_mInviter) do
        if not mData.hejiu then
            mData.hejiu = true
        end
    end
    for pid,mData in pairs(self.m_mMember) do
        if not mData.hejiu then
            mData.hejiu = true
        end
    end
    self:TrueHejiu()
end

function CJieBai:TrueHejiu()
    local ysobj = self.m_oYiShi 
    if ysobj then
        ysobj:DelTimeCb("CheckSetHejiu")
    end
    self:BroadCast("GS2CJBHejiu",{})
    local mConfig = self:GetConfigData()
    local iJBID = self.m_ID
    self:AddTimeCb("FinishYiShi",mConfig.hejiu_time*1000,function ()
        _FinishYiShi(iJBID)
    end)
end

function CJieBai:CheckFinishYiShi()
    self:DelTimeCb("FinishYiShi")
    if not self.m_oYiShi then
        return 
    end
    self:FinishYiShi()
end

--仪式完成
function CJieBai:FinishYiShi()
    local ysobj = self.m_oYiShi
    self:Dirty()
    self.m_oYiShi = nil
    self.m_iState = JIEBAI_STATE[3]
    if ysobj then
        baseobj_safe_release(ysobj)
    end
    local mAllInviteData = self.m_mInviter 
    self.m_mInviter = {}
    for pid,mInviteData in pairs(mAllInviteData) do
        self:AddMember(pid,mInviteData.minghao)
    end
    self:RefreshJieBai()
    for iPid, _ in pairs(self.m_mMember) do
        self:AddMemberTitle(iPid)
    end
    self:NotifyAll(1039)
end

function CJieBai:AddMemberTitle(iPid)
    if not self.m_sTitle then return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    local mData = self.m_mMember[iPid]
    if not mData then return end

    local sMingHao = mData.minghao
    if sMingHao then
        local iTitle = 1050
        local sNewTitle = string.format("%s.%s", self.m_sTitle, sMingHao)
        global.oTitleMgr:AddTitle(iPid, iTitle, sNewTitle)
        global.oTitleMgr:UseTitle(oPlayer, iTitle)

        oPlayer:MarkGrow(52) --成长
    end
end

function CJieBai:RemoveMemberTitle(iPid)
    local iTitle = 1050
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        global.oTitleMgr:RemoveOneTitle(iPid, iTitle)
    end
end

function CJieBai:RefreshMemberTitle(iPid)
    if iPid then
        self:RefreshOneTitle(iPid)
        return
    end 

    for iPid,_ in pairs(self.m_mMember) do
        self:RefreshOneTitle(iPid)
    end
end

function CJieBai:RefreshOneTitle(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    global.oTitleMgr:RefreshTitle(iPid, 1050)
    oPlayer:SyncSceneInfo({title_info=oPlayer:PackTitleInfo()})
end

--结拜宣言
function CJieBai:SetEnounce(sEnounce)
    self:Dirty()
    self.m_sEnounce = sEnounce
    self:RefreshJieBai()
end

function CJieBai:GetEnounce()
    return self.m_sEnounce
end

--结义值
function CJieBai:AddJieYi(iValue)
    self:Dirty()
    self.m_iJieYi = self.m_iJieYi + iValue
    self.m_iJieYi = math.max(0,self.m_iJieYi)
    if iValue>0 then
        local mInviteData = self:GetInviteData()
        local iLimitCnt = self.m_iInviteLimit
        for k,v in pairs(mInviteData) do
            if self.m_iJieYi>=k and v["limit"]>iLimitCnt then
                iLimitCnt = v["limit"]
            end
        end
        if iLimitCnt > self.m_iInviteLimit then
            self.m_iInviteLimit = iLimitCnt
        end
    end
end

function CJieBai:GetJieYi()
    return self.m_iJieYi
end

--投票踢人
function CJieBai:GetKickInfo()
    return self.m_mKickInfo
end

function CJieBai:SetKickInfo(mInfo)
    self:Dirty()
    self.m_mKickInfo=mInfo
    self:CreateKickOutTimer()
end

function CJieBai:UpdateKickInfo(mInfo)
    self:Dirty()
    self.m_mKickInfo=mInfo
end

function CJieBai:RemoveKickInfo()
    self:Dirty()
    self.m_mKickInfo = nil 
    self:DelTimeCb("CheckKickOut")
end

function CJieBai:TryKickMemSuccess(bTimeOut)
    local mConfig = self:GetConfigData()
    local mKickInfo = self.m_mKickInfo
    if not mKickInfo then return end

    local iTotal = table_count(self:AllMember())
    if bTimeOut then
        iTotal = #mKickInfo.agreelist + #mKickInfo.disagreelist
    end
    if #mKickInfo.agreelist*100/iTotal <mConfig.vote_ratio then
        return 
    end
    local mKickInfo = self.m_mKickInfo
    self:RemoveKickInfo()
    if self:HasMember(mKickInfo.pid) then
        self:RemoveMember(mKickInfo.pid)
    end
    self:UpdateAllRedPoint(KICK_MEMBER, {}, true)
end

function CJieBai:TryKickMemFail(bTimeOut)
    local mConfig = self:GetConfigData()
    local mKickInfo = self.m_mKickInfo
    if not mKickInfo then return end

    local iTotal = table_count(self:AllMember())
    if bTimeOut then
        iTotal = #mKickInfo.agreelist + #mKickInfo.disagreelist
    end
    if #mKickInfo.disagreelist*100/iTotal < mConfig.vote_ratio then
        return
    end
    self:RemoveKickInfo()
    self:UpdateAllRedPoint(KICK_MEMBER, {}, true)
end

function CJieBai:CreateKickOutTimer()
    if self:State() ~= JIEBAI_STATE[3] then
        return 
    end
    if not self.m_mKickInfo then
        return 
    end
    local iCreateTime = self.m_mKickInfo.time 
    local iNowTime = get_time()
    local mConfig = self:GetConfigData()
    local iJBID  = self.m_ID
    local iVoteTime = mConfig.vote_time
    if iNowTime - iCreateTime >= iVoteTime then
        self:RemoveKickInfo()
    else
        local iLeftTime = iVoteTime-(iNowTime-iCreateTime) 
        self:AddTimeCb("CheckKickOut",iLeftTime*1000,function ()
            _CheckKickOut(iJBID)
        end)
    end
end

function CJieBai:CheckKickOut()
    self:DelTimeCb("CheckKickOut")
    if self.m_mKickInfo then
        self:TryKickMemSuccess(true)
        self:TryKickMemFail(true)
        self:RemoveKickInfo()
        self:RefreshJieBai()
    end
end

--割袍断义,与其他结拜成员好友度减半
function CJieBai:SubFriendDegree(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oFriendCtrl = oPlayer:GetFriend()
    for iTarget, _ in pairs(self.m_mMember) do
        local iDegree = oFriendCtrl:GetFriendDegree(iTarget)
        if iDegree > 0 then
            local iSub = math.floor(iDegree*0.5)
            oFriendCtrl:AddFriendDegree(iTarget, -iSub)
            global.oFriendMgr:GS2CRefreshDegree(oPlayer, iTarget)
        end
    end
end

    --协议相关--
function CJieBai:PackData()
    local mNet = {}
    mNet.id = self.m_ID
    mNet.owner = self.m_iOwner
    mNet.state = self.m_iState
    mNet.createtime = self.m_iCreateTime
    mNet.createystime = self.m_iCreateYSTime
    mNet.allinviter = {}
    mNet.allmember = {}
    for pid,mData in pairs(self.m_mInviter) do
        table.insert(mNet.allinviter,self:PackInviteData(pid))
    end
    for pid,mData in pairs(self.m_mMember) do
        table.insert(mNet.allmember,self:PackMemberData(pid))
    end
    if self.m_oYiShi then
        mNet.ysstate = self.m_oYiShi:State()
        mNet.ysstarttime = self.m_oYiShi:GetStateTime()
    end
    mNet.title = self.m_sTitle
    mNet.enounce = self.m_sEnounce
    mNet.jieyi = self.m_iJieYi
    if not self.m_mKickInfo then
        mNet.kickout = {}
    else
        mNet.kickout = self.m_mKickInfo
    end
    mNet.invite_limit = self.m_iInviteLimit
    return mNet
end

function CJieBai:PackInviteData(pid)
    local mData = self.m_mInviter[pid]
    local mNet = {}
    mNet.pid = pid
    mNet.invitetime = mData.invitetime
    mNet.invitestate = mData.invitestate
    mNet.minghao = mData.minghao
    mNet.owner = mData.owner
    return mNet
end

function CJieBai:PackFullInviteData(pid)
    local mNet  = {}
    local invite_info = self:PackInviteData(pid)
    mNet.id = self.m_ID
    mNet.owner = self.m_iOwner
    mNet.createtime = self.m_iCreateTime
    mNet.state = self:State()
    mNet.invite_info = invite_info
    return mNet
end

function CJieBai:PackMemberData(pid)
    local mData = self.m_mMember[pid]
    local mNet = {}
    mNet.pid = pid
    mNet.memtime = mData.memtime
    mNet.minghao = mData.minghao
    mNet.free_minghao = mData.free_minghao and 1 or 0
    return mNet
end

function CJieBai:GS2CAddInviter(pid)
    local mNet = self:PackInviteData(pid)
    self:BroadCast("GS2CJBAddInviter",{invite_info = mNet},pid)
end

function CJieBai:GS2CBecomeInviter(pid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oTarget then
        return 
    end
    local mNet = self:PackFullInviteData(pid)
    oTarget:Send("GS2CJBBecomeInviter",{fullinvite_info = mNet})
end

function CJieBai:GS2CInviterOnLogin(pid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oTarget then
        return 
    end
    local mInviteData = self:HasInviter(pid)
    if mInviteData.invitestate == INVITE_STATE[1] then --第一阶段待确认邀请的玩家
        local mNet = self:PackFullInviteData(pid)
        oTarget:Send("GS2CJBInviterOnLogin",{fullinvite_info = mNet})
    elseif mInviteData.invitestate == INVITE_STATE[2] then  --第一阶段同意邀请的玩家
        local mNet = self:PackData()
        oTarget:Send("GS2CJBInvitedOnLogin",{jiebai_info = mNet})
    end
end

function CJieBai:GS2CRemoveInviter(pid)
    local mNet = {}
    mNet.pid = pid
    self:BroadCast("GS2CJBRemoveInviter",mNet)
end

function CJieBai:RefreshInviter(pid)
    local mNet = self:PackInviteData(pid)
    self:BroadCast("GS2CJBRefreshInviter",{invite_info = mNet},pid)
end

function CJieBai:GS2CMemberOnLogin(pid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oTarget then
        return 
    end
    if self:HasMember(pid) then
        local mNet = self:PackData()
        oTarget:Send("GS2CJBMemberOnLogin",{jiebai_info = mNet})
    end
end

function CJieBai:GS2CAddMember(pid)
    local mNet = self:PackMemberData(pid)
    self:BroadCast("GS2CJBAddMember",{mem_info = mNet},pid)
end

function CJieBai:GS2CBecomeMember(pid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oTarget then
        return 
    end
    local mNet = self:PackData()
    oTarget:Send("GS2CJBBecomeMember",{jiebai_info = mNet})
end

function CJieBai:GS2CRemoveMember(pid)
    local mNet = {}
    mNet.pid = pid
    self:BroadCast("GS2CJBRemoveMember",mNet)
end

function CJieBai:RefreshMember(pid)
    local mNet = self:PackMemberData(pid)
    self:BroadCast("GS2CJBRefreshMember",{mem_info = mNet})
end

function CJieBai:GS2CRemoveJieBai(pid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oTarget then
        return 
    end
    oTarget:Send("GS2CJBRemoveJieBai",{})
end

function CJieBai:RefreshJieBai(pid)
    local mNet = self:PackData()
    if not pid then
        self:BroadCast("GS2CJBRefresh",{jiebai_info = mNet})
    else
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CJBRefresh",{jiebai_info = mNet})
        end
    end
end

function CJieBai:BroadCast(sMessage,mNet,iExclude)
    iExclude = iExclude or 0
    for pid,_ in pairs(self.m_mMember) do
        if pid == iExclude then
            goto continue
        end
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send(sMessage,mNet)
        end
        ::continue::
    end
    for pid,mData in pairs(self.m_mInviter) do
        if pid == iExclude then
            goto continue
        end
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer and mData.invitestate == INVITE_STATE[2] then
            oPlayer:Send(sMessage,mNet)
        end
        ::continue::
    end
end

function CJieBai:SetChangeTitleFree(bFlag)
    self:Dirty()
    self.m_bFreeChangeTitle = bFlag
end

function CJieBai:IsChangeTitleFree()
    return self.m_bFreeChangeTitle
end

function _GetJieBai(iJbId)
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHD then return end
    local oJbObj = oHD:GetJieBai(iJbId)
    return oJbObj
end

function _CheckJBEnd(iJbId, sFlag)
    local oJbObj = _GetJieBai(iJbId)
    if oJbObj then
        oJbObj:CheckJBEnd(sFlag)
    end
end

function _CheckKickOut(iJbId)
    local oJbObj = _GetJieBai(iJbId)
    if oJbObj then
        oJbObj:CheckKickOut()
    end
end

function _FinishYiShi(iJbId)
    local oJbObj = _GetJieBai(iJbId)
    if oJbObj then
        oJbObj:CheckFinishYiShi()
    end
end