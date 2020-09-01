--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))

function NewBaseMgr(...)
    return COrgBaseMgr:New(...)
end

COrgBaseMgr = {}
COrgBaseMgr.__index = COrgBaseMgr
inherit(COrgBaseMgr, datactrl.CDataCtrl)

function COrgBaseMgr:New(orgid)
    local o = super(COrgBaseMgr).New(self, {orgid = orgid})
    return o
end

function COrgBaseMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgBaseMgr:Create(sAim)
    self:SetData("level", 1)
    self:SetData("aim", sAim)
    self:SetData("boom", 500)
    self:SetData("cash", 0)
    self:SetData("hw_days", 0)
    self:SetData("daymorning", get_morningdayno())
    self:SetData("weekmorning", get_morningweekno())
    self:SetData("weekhuoyue", 0)
    self:SetData("lastweekhuoyue", 0)
    self:SetData("auto_join", 1)
    self:SetData("prestige", 0)
    self:SetWeekMorning()
    self:SetDayMorning()
end

function COrgBaseMgr:Load(mData)
    mData = mData or {}
    self:SetData("level", mData.level)
    self:SetData("aim", mData.aim)
    self:SetData("cash", mData.cash)
    self:SetData("boom", mData.boom)
    self:SetData("hw_days", mData.hw_days or 0)
    self:SetData("daymorning", mData.daymorning)
    self:SetData("weekmorning", mData.weekmorning)
    self:SetData("weekhuoyue", mData.weekhuoyue or 0)
    self:SetData("lastweekhuoyue", mData.lastweekhuoyue or 0)
    self:SetData("auto_join", mData.auto_join or 0)
    self:SetData("prestige", mData.prestige)
    self:SetData("aim_time", mData.aim_time or 0)
    self:SetData("mail_time", mData.mail_time or 0)
end

function COrgBaseMgr:Save()
    local mData = {}
    mData.level = self:GetData("level")
    mData.aim = self:GetData("aim")
    mData.cash = self:GetData("cash")
    mData.boom = self:GetData("boom")
    mData.hw_days = self:GetData("hw_days")
    mData.daymorning = self:GetData("daymorning")
    mData.weekmorning = self:GetData("SetWeekMorning")
    mData.weekhuoyue = self:GetData("weekhuoyue")
    mData.lastweekhuoyue = self:GetData("lastweekhuoyue")
    mData.auto_join = self:GetData("auto_join")
    mData.prestige = self:GetData("prestige")
    mData.aim_time = self:GetData("aim_time")
    mData.mail_time = self:GetData("mail_time")
    return mData
end

function COrgBaseMgr:GetAim()
    return self:GetData("aim")
end

function COrgBaseMgr:SetAim(aim)
    self:SetData("aim", aim)
end

function COrgBaseMgr:GetLevel()
    return self:GetData("level", 1)
end

function COrgBaseMgr:GetBoomMax()
    return 1000
end

function COrgBaseMgr:GetBoom()
    return self:GetData("boom")
end

function COrgBaseMgr:AddBoom(iAdd)
    local iBoom = self:GetData("boom", 0)
    local iBoom = math.max(iBoom + iAdd, 0)
    local iBoom = math.min(iBoom, self:GetBoomMax())
    return self:SetData("boom", iBoom)
end

function COrgBaseMgr:GetCash()
    return self:GetData("cash", 0)
end

function COrgBaseMgr:AddCash(iAdd)
    local iCash = self:GetData("cash")
    local iCash = math.max(iCash + iAdd, 0)
    return self:SetData("cash", iCash)
end

function COrgBaseMgr:SetDayMorning()
    self:SetData("daymorning", get_morningdayno())
end

function COrgBaseMgr:GetDayMorning()
    return self:GetData("daymorning", 0)
end

function COrgBaseMgr:SetWeekMorning()
    self:SetData("weekmorning", get_morningweekno())
end

function COrgBaseMgr:GetWeekMorning()
    return self:GetData("weekmorning", 0)
end

function COrgBaseMgr:AddHuoYue(iVal)
    if iVal <= 0 then return end
    self:SetData("weekhuoyue", self:GetData("weekhuoyue") + iVal)
end

function COrgBaseMgr:GetWeekHuoYue()
    return self:GetData("weekhuoyue") or 0
end

function COrgBaseMgr:GetLastWeekHuoYue()
    return self:GetData("lastweekhuoyue") or 0
end

function COrgBaseMgr:WeekMaintain()
    self:SetWeekMorning()
    self:SetData("lastweekhuoyue", self:GetWeekHuoYue())
    self:SetData("weekhuoyue", 0)
end

function COrgBaseMgr:AddHwDay(iVal)
    self:SetData("hw_days", self:GetHwDay() + iVal)
end

function COrgBaseMgr:ClearHwDay()
    self:SetData("hw_days", 0)
end

function COrgBaseMgr:GetHwDay()
    return self:GetData("hw_days", 0)
end

function COrgBaseMgr:GetPrestige()
    return self:GetData("prestige", 0)
end

function COrgBaseMgr:AddPrestige(iVal)
    self:SetData("prestige", math.max(self:GetPrestige() + iVal, 0))
end

function COrgBaseMgr:SetAimTime()
    self:SetData("aim_time", get_time())
end

function COrgBaseMgr:GetAimTime()
    return self:GetData("aim_time", 0)
end

function COrgBaseMgr:SetMailTime()
    self:SetData("mail_time", get_time())
end

function COrgBaseMgr:GetMailTime()
    return self:GetData("mail_time", 0)
end
