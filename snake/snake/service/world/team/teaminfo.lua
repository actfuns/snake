local global = require "global"
local extend = require "base.extend"

local INVITE_OUTTIME = 2*60
local APPLY_OUTTIME = 2*60

function NewApplyInfoMgr(...)
    return CApplyInfoMgr:New(...)
end

local SortApplyFunc = function (oApply1,oApply2)
    if oApply1.m_iCreateTime ~= oApply2.m_iCreateTime then
        return oApply1.m_iCreateTime < oApply2.m_iCreateTime
    else
        return oApply1.m_ID < oApply2.m_ID
    end
end

local SortFunc = function (mData1,mData2)
    if mData1.createtime ~= mData2.createtime then
        return mData1.createtime < mData2.createtime
    else
        return mData1.teamid < mData2.teamid
    end
end

CApplyInfoMgr = {}
CApplyInfoMgr.__index = CApplyInfoMgr
inherit(CApplyInfoMgr,logic_base_cls())

function CApplyInfoMgr:New(iTeamID)
    local o = super(CApplyInfoMgr).New(self)
    o.m_List = {}
    o.m_iTeamID = iTeamID
    return o
end

function CApplyInfoMgr:Release()
    local mApply = table_copy(self.m_List) 
    for _,oApply in pairs(mApply) do
        baseobj_safe_release(oApply)
    end
    self.m_List = {}
    super(CApplyInfoMgr).Release(self)
end

function CApplyInfoMgr:GetApplyInfo()
    self:_CheckValidApply()
    local mData = {}
    local mApplyInfo = table_value_list(self.m_List)
    table.sort(mApplyInfo,SortApplyFunc)
    for _,oApplyInfo in ipairs(mApplyInfo) do
        if table_count(mData) < 20 then
           table.insert(mData,oApplyInfo:PackInfo())
       else
            break
        end
    end
    return mData
end

function CApplyInfoMgr:ValidApply()
    self:_CheckValidApply()
    if table_count(self.m_List) >= self:LimitSize() then
        return false
    end
    return true
end

function CApplyInfoMgr:HasApply(pid)
    return self.m_List[pid]
end

function CApplyInfoMgr:AddApply(pid,mArgs)
    if self:HasApply(pid) then
        self:RemoveApply(pid)
    end
    local oApplyInfo = CApplyInfo:New(pid)
    oApplyInfo:Init(mArgs)
    self.m_List[pid] = oApplyInfo
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(self.m_iTeamID)
    if oTeam then
        local mNet = {
            apply_info = oApplyInfo:PackInfo(),
        }
        local mOnlineMem = oTeam:OnlineMember()
        oTeam:BroadCast(mOnlineMem,"GS2CAddTeamApplyInfo",mNet)
    end
end

function CApplyInfoMgr:RemoveApply(pid,target)
    local oApply = self.m_List[pid]
    self.m_List[pid] = nil
    baseobj_delay_release(oApply)
    local mNet = {}
    mNet["pid"] = pid
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(self.m_iTeamID)
    if oTeam then
        local mOnlineMem = oTeam:OnlineMember()
        oTeam:BroadCast(mOnlineMem,"GS2CDelTeamApplyInfo",mNet)
    end
end

function CApplyInfoMgr:Size()
    return table_count(self.m_List)
end

function CApplyInfoMgr:LimitSize()
    return 20
end

function CApplyInfoMgr:ClearApply(pid)
    local mApply = table_copy(self.m_List) 
    for _,oApply in pairs(mApply) do
        baseobj_safe_release(oApply)
    end
    self.m_List = {}

    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(self.m_iTeamID)
    if oTeam then
        local mOnlineMem = oTeam:OnlineMember()
        oTeam:BroadCast(mOnlineMem,"GS2CTeamApplyInfo",{})
    end
end

function CApplyInfoMgr:_CheckValidApply()
    local plist = table_key_list(self.m_List)
    for _,pid in pairs(plist) do
        local oApplyInfo = self.m_List[pid]
        if oApplyInfo and not oApplyInfo:Validate() then
            self:RemoveApply(pid)
        end
    end
end

function CApplyInfoMgr:SendApplyInfo(oPlayer,bOpen)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local iOldCount  = table_count(self.m_List)
    local mApplyInfo = self:GetApplyInfo()
    local mNet = {
        apply_info = mApplyInfo
    }
    if bOpen then
        if #mApplyInfo <= 0 then
            if iOldCount<=0 then
                oNotifyMgr:Notify(pid,"暂无申请信息")
            else
                oNotifyMgr:Notify(pid,"申请信息已过期")
            end
        end
        mNet.open = 1
    end
    oPlayer:Send("GS2CTeamApplyInfo",mNet)
end

CApplyInfo = {}
CApplyInfo.__index = CApplyInfo
inherit(CApplyInfo,logic_base_cls())

function CApplyInfo:New(pid)
    local o = super(CApplyInfo).New(self)
    o.m_ID =pid
    return o
end

function CApplyInfo:Init(mArgs)
    self.m_sName = mArgs.name
    self.m_iGrade = mArgs.grade
    self.m_iSchool =mArgs.school
    self.m_mModelInfo = mArgs.model_info
    self.m_iIcon = mArgs.icon
    self.m_iOrgID = mArgs.orgid
    self.m_iCreateTime = get_time()
end

function CApplyInfo:PackInfo()
    local mData = {
        pid  = self.m_ID,
        name  = self.m_sName,
        grade = self.m_iGrade,
        school = self.m_iSchool,
        icon = self.m_iIcon,
        model_info = self.m_mModelInfo,
        orgid = self.m_iOrgID,
    }
    return mData
end

function CApplyInfo:Validate()
    if get_time() - self.m_iCreateTime >= APPLY_OUTTIME then
        return false
    end
    return true
end

function CApplyInfo:IsOutTime()
    if not self:Validate() then
        return true
    end
    return false
end

CInviteInfoMgr = {}
CInviteInfoMgr.__index = CInviteInfoMgr
inherit(CInviteInfoMgr,logic_base_cls())

function CInviteInfoMgr:New(pid)
    local o = super(CInviteInfoMgr).New(self)
    o.m_ID =pid
    o.m_List = {}
    return o
end

function CInviteInfoMgr:ValidInvite()
    return true
end

function CInviteInfoMgr:AddInvitor(oTeam,oTarget)
    local iTeamID = oTeam:TeamID()
    if self:HasInvite(iTeamID) then
        self:RemoveInvite(iTeamID,self.m_ID)
    end
    local mData = {
        teamid = iTeamID,
        pid = oTarget:GetPid(),
        createtime = get_time(),
    }
    self.m_List[iTeamID] = mData
    local mNet = {
        teaminfo  = oTeam:PackTeamInfo()
    }
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if oPlayer then
        oPlayer:Send("GS2CAddInviteInfo",mNet)
    end
end

function CInviteInfoMgr:HasInvite(iTeamID)
    return self.m_List[iTeamID]
end

function CInviteInfoMgr:IsValidate(iTeamID)
    local oTeamMgr = global.oTeamMgr
    local mData = self.m_List[iTeamID]
    if not mData then
        return  false
    end
    local iCreateTime = mData.createtime
    if get_time() - iCreateTime >= INVITE_OUTTIME  then
        return false
    end
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if not oTeam then
        return false
    end
    return true
end

function CInviteInfoMgr:Size()
    return table_count(self.m_List)
end

function CInviteInfoMgr:LimitSize()
    return  20
end

function CInviteInfoMgr:IsOutTime(iTeamID)
    local mData = self.m_List[iTeamID]
    local iCreateTime = mData.createtime or 0
     if get_time() - iCreateTime >= INVITE_OUTTIME then
        return true
    end
    return false
end

function CInviteInfoMgr:SendInviteInfo(oPlayer,bLogin)
    local oTeamMgr = global.oTeamMgr
    local oNotifyMgr = global.oNotifyMgr
    local mInviteInfo = table_value_list(self.m_List)
    table.sort(mInviteInfo,SortFunc)
    local mData = {}
    for _,mTeamInfo in ipairs(mInviteInfo) do
        local iTeamID = mTeamInfo["teamid"]
        if #mData>=self:LimitSize() then
            self.m_List[iTeamID] = nil 
        else
            local oTeam = oTeamMgr:GetTeam(iTeamID)
            if oTeam then
                table.insert(mData,oTeam:PackTeamInfo())
            else
                self.m_List[iTeamID] = nil 
            end
        end
    end
    if table_count(mData) <=0 and not bLogin then
        oNotifyMgr:Notify(oPlayer:GetPid(),"暂时还没有人邀请你入队哦")
        return
    end
    local mNet = {}
    mNet["teaminfo"] = mData
    if bLogin then
        mNet.login = 1
    end
    oPlayer:Send("GS2CInviteInfo",mNet)
end

function CInviteInfoMgr:ClearInviteInfo()
    self.m_List = {}
    local mNet = {}
    mNet["teaminfo"] = {}
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if oPlayer then
        oPlayer:Send("GS2CInviteInfo",mNet)
    end
end

function CInviteInfoMgr:RemoveInvite(iTeamID,target)
    self.m_List[iTeamID] = nil
    local mNet = {}
    mNet["teamid"] = iTeamID
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(target)
    if oPlayer then
        oPlayer:Send("GS2CRemoveInvite",mNet)
    end
end

function NewInviteMgr(...)
    return CInviteInfoMgr:New(...)
end
