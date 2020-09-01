--import module
local global = require "global"
local interactive = require "base.interactive"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local orgmeminfo = import(service_path("org.orgmeminfo"))
local orgdefines = import(service_path("org.orgdefines"))
local gamedb = import(lualib_path("public.gamedb"))

function NewReadyOrg(...)
    return CReadyOrg:New(...)
end

function DoReadyOrgFail(iOrgId)
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetReadyOrg(iOrgId)
    if not oOrg then return end

    oOrg:_RespondFail()    
end

CReadyOrg = {}
CReadyOrg.__index = CReadyOrg
inherit(CReadyOrg, datactrl.CDataCtrl)

function CReadyOrg:New(orgid)
    local o = super(CReadyOrg).New(self)
    o.m_iID = orgid
    o.m_mRespondInfo = {}
    return o
end

function CReadyOrg:Create(oOwner, iShowId, sName, sAim)
    self:SetData("name", sName)
    self:SetData("aim", sAim)
    self:SetData("showid", iShowId)
    self:SetData("leader", oOwner:GetPid())
    self:SetData("createtime", get_time())
    self:SetData("spreadtime", 0)
    self:AddRespond(oOwner)
end

function CReadyOrg:Release()
    for _, oMem in pairs(self.m_mRespondInfo) do
        baseobj_safe_release(oMem)
    end
    self.m_mRespondInfo = {}
    super(CReadyOrg).Release(self)
end

function CReadyOrg:AfterLoad()
    self:_CheckRespond()
end

function CReadyOrg:ConfigSaveFunc()
    local id = self:OrgID()
    self:ApplySave(function ()
        local oOrgMgr = global.oOrgMgr
        local obj = oOrgMgr:GetReadyOrg(id)
        if obj then
            obj:_CheckSaveDb()
        else
            record.user("org", "ready_org_save", {
                org_id = id,
                reason = "readyorg save err: no obj",
            })
        end
    end)
end

function CReadyOrg:_CheckSaveDb()
    assert(not is_release(self), string.format("readyorg %d save err: has release", self:OrgID()))
    self:SaveDb()
end

function CReadyOrg:SaveDb()
    if self:IsDirty() then
        local mInfo = {
            module = "orgreadydb",
            cmd = "SaveReadyOrg",
            cond = {orgid = self:OrgID()},
            data = self:Save(),
        }
        gamedb.SaveDb(self:OrgID(), "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CReadyOrg:_CheckRespond()
    self:DelTimeCb("_CheckRespond")
    local iLeftTime = self:GetLeftTime()
    iLeftTime = math.max(1, iLeftTime)

    local iOrgId = self:OrgID()
    local f = function ()
        DoReadyOrgFail(iOrgId)
    end
    self:AddTimeCb("_CheckRespond", iLeftTime * 1000, f)
end

function CReadyOrg:_RespondFail()
    local oOrgMgr = global.oOrgMgr
    oOrgMgr:OnCreateOrgFail(self:OrgID())
end

function CReadyOrg:Load(mData)
    mData = mData or {}
    self:SetData("name", mData.name)
    self:LoadData(mData.data)
end

function CReadyOrg:LoadData(mData)
    self:SetData("showid", mData.showid)
    self:SetData("aim", mData.aim)
    self:SetData("leader", mData.leader)
    self:SetData("createtime", mData.createtime)
    self:SetData("spreadtime", mData.spreadtime)
    self:SetData("renamecard", mData.renamecard or 0)
    local mRespondInfo = {}
    for pid, data in pairs(mData.respond) do
        pid = tonumber(pid)
        local meminfo = orgmeminfo.NewMemberInfo()
        meminfo:Load(data)
        mRespondInfo[pid] = meminfo
    end
    self.m_mRespondInfo = mRespondInfo
end

function CReadyOrg:SaveData()
    local mData = {}
    mData.showid = self:ShowID()
    mData.aim = self:GetData("aim")
    mData.leader = self:GetData("leader")
    mData.createtime = self:GetData("createtime")
    mData.spreadtime = self:GetData("spreadtime")
    mData.renamecard = self:GetData("renamecard")
    local mRespondInfo = {}
    for pid, meminfo in pairs(self.m_mRespondInfo) do
        pid = db_key(pid)
        mRespondInfo[pid] = meminfo:Save()
    end
    mData.respond = mRespondInfo
    return mData
end

function CReadyOrg:Save()
    local mData = {}
    mData.name = self:GetData("name")
    mData.data = self:SaveData()
    return mData
end

function CReadyOrg:OrgID()
    return self.m_iID
end

function CReadyOrg:ShowID()
    return self:GetData("showid", self:OrgID())
end

function CReadyOrg:GetName()
    return self:GetData("name")
end

function CReadyOrg:GetAim()
    return self:GetData("aim")
end

function CReadyOrg:GetLeader()
    return self:GetData("leader")
end

function CReadyOrg:GetLeaderName()
    local oMem = self:GetRespond(self:GetLeader())
    if oMem then
        return oMem:GetName()
    end
    return nil
end

function CReadyOrg:GetLeaderSchool()
    local oMem = self:GetRespond(self:GetLeader())
    if oMem then
        return oMem:GetSchool()
    end
    return 0
end

function CReadyOrg:GetCreateTime()
    return self:GetData("createtime")
end

function CReadyOrg:AddRespond(oPlayer)
    self:Dirty()
    local iPid = oPlayer:GetPid()
    local mArgs = {
        pid = iPid,
        name = oPlayer:GetName(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        offer = oPlayer:GetOffer(),
        touxian = oPlayer.m_oTouxianCtrl:GetTouxianID()
    }
    local oMember = orgmeminfo.NewMemberInfo()
    -- oMember:Create(pid, name, grade, school)
    oMember:CreateNew(mArgs)
    self.m_mRespondInfo[iPid] = oMember
end

function CReadyOrg:GetRespond(pid)
    return self.m_mRespondInfo[pid]
end

function CReadyOrg:DelRespond(pid)
    self:Dirty()
    local oMem = self.m_mRespondInfo[pid]
    if oMem then
        baseobj_delay_release(oMem)
        self.m_mRespondInfo[pid] = nil
    end
end

function CReadyOrg:RespondCnt()
    return table_count(self.m_mRespondInfo)
end

function CReadyOrg:GetRespondInfo(pid)
    return self.m_mRespondInfo[pid]
end

function CReadyOrg:HasRespond(pid)
    if self:GetRespondInfo(pid) then
        return 1
    else
        return 0
    end
end

function CReadyOrg:PackReadyOrgInfo()
    local mNet = {}
    mNet.orgid = self:OrgID()
    mNet.aim = self:GetAim()
    mNet.left_time = self:GetLeftTime()
    mNet.spread_cd = self:GetSpreadLeftTime()
    return mNet
end

function CReadyOrg:PackReadyOrgListInfo()
    local mNet = {}
    mNet.orgid = self:OrgID()
    mNet.showid = self:ShowID()
    mNet.name = self:GetName()
    mNet.respondcnt = self:RespondCnt() 
    mNet.leaderid = self:GetLeader()
    mNet.leadername = self:GetLeaderName()
    mNet.createtime = self:GetCreateTime()
    mNet.school = self:GetLeaderSchool()
    return mNet
end

function CReadyOrg:GetLeftTime()
    local res = require "base.res"
    local iTime = res["daobiao"]["org"]["others"][1]["create_respond_time"]
    local iLeftTime = self:GetData("createtime", 0) + iTime - get_time()
    return iLeftTime
end

function CReadyOrg:GetSpreadLeftTime()
    local res = require "base.res"
    local iTime = res["daobiao"]["org"]["others"][1]["world_ad_rate"]    
    local  iLeftTime = self:GetData("spreadtime", 0) + iTime - get_time()
    iLeftTime = math.max(iLeftTime, 0)
    return iLeftTime
end

function  CReadyOrg:SetSpreadTime()
    self:SetData("spreadtime", get_time())
end

function CReadyOrg:SyncRespondData(iPid, mData)
    local oMem = self:GetRespond(iPid)
    if oMem then
        oMem:SyncData(mData)
        self:Dirty()
    end
end

function CReadyOrg:PackRespondInfo()
    local mNet = {}
    mNet.orgid = self:OrgID()
    mNet.respondcnt = self:RespondCnt()
    return mNet
end
