--import module
local skynet = require "skynet"
local global = require "global"

local datactrl = import(lualib_path("public.datactrl"))

function NewMemberInfo(...)
    return CMemberInfo:New(...)
end

CMemberInfo = {}
CMemberInfo.__index = CMemberInfo
inherit(CMemberInfo, datactrl.CDataCtrl)

function CMemberInfo:New()
    local o = super(CMemberInfo).New(self)
    return o
end

function CMemberInfo:Create(pid, name, grade, school, offer, logout_time)
    self:SetData("pid", pid)
    self:SetData("name", name)
    self:SetData("grade", grade)
    self:SetData("school", school)
    self:SetData("offer", offer)
    self:SetData("apply_type", 0)
    self:SetData("logout_time", logout_time or get_time())
    self:SetData("create_time", get_time())
end

function CMemberInfo:CreateNew(mArgs)
    self:SetData("pid", mArgs.pid)
    self:SetData("name", mArgs.name)
    self:SetData("grade", mArgs.grade)
    self:SetData("school", mArgs.school)
    self:SetData("offer", mArgs.offer)
    self:SetData("apply_type", mArgs.apply_type)
    self:SetData("logout_time", mArgs.logout_time or get_time())
    self:SetData("touxian", mArgs.touxian)
    self:SetData("create_time", get_time())
end

function CMemberInfo:Load(mData)
    if not mData then
        return
    end
    self:SetData("pid", mData.pid)
    self:SetData("name", mData.name)
    self:SetData("grade", mData.grade)
    self:SetData("school", mData.school)
    self:SetData("offer", mData.offer)
    self:SetData("apply_type", mData.apply_type or 0)
    self:SetData("logout_time", mData.logout_time or get_time())
    self:SetData("create_time", mData.create_time or get_time())
end

function CMemberInfo:Save()
    local mData = {}
    mData.pid = self:GetData("pid")
    mData.name = self:GetData("name")
    mData.grade = self:GetData("grade")
    mData.school = self:GetData("school")
    mData.offer = self:GetData("offer")
    mData.apply_type = self:GetData("apply_type")
    mData.logout_time = self:GetData("logout_time")
    mData.create_time = self:GetData("create_time")
    return mData
end

function CMemberInfo:SetApplyType(iType)
    self:SetData("apply_type", iType)
end

function CMemberInfo:GetName()
    return self:GetData("name")
end

function CMemberInfo:GetSchool()
    return self:GetData("school")
end

function CMemberInfo:GetGrade()
    return self:GetData("grade")
end

function CMemberInfo:GetPid()
    return self:GetData("pid")
end

function CMemberInfo:GetCreateTime()
    return self:GetData("create_time")
end

function CMemberInfo:PackOrgApplyInfo()
    local mNet = {}
    mNet.pid = self:GetData("pid")
    mNet.name = self:GetData("name")
    mNet.grade = self:GetData("grade")
    mNet.school = self:GetData("school")
    mNet.apply_type = self:GetData("apply_type")
    mNet.touxian = self:GetData("touxian")
    return mNet
end

function CMemberInfo:SyncData(mData)
    for k,v in pairs(mData) do
        if self:GetData(k) then
            self:SetData(k, v)
        end
    end
end

function CMemberInfo:VaildApplyTime()
    local iTime = global.oOrgMgr:GetOtherConfig("apply_valid_time")
    local iLeftTime = self:GetCreateTime() + iTime - get_time()
    if iLeftTime <= 0 then
        return false
    end
    return true
end
