--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))

function NewFmtObj(iPid, iFmt, ...)
    local o = CFormat:New(iPid, iFmt, ...)
    return o
end


CFormat = {}
CFormat.__index = CFormat
inherit(CFormat, datactrl.CDataCtrl)

function CFormat:New(iPid, iFmt, ...)
    assert(iFmt>0 and iFmt<10, string.format("illegal fmt_id %d", iFmt))

    local o = super(CFormat).New(self)
    o:SetInfo("pid", iPid)
    o:SetInfo("fmt_id", iFmt)
    o:Init()
    return o
end

function CFormat:Init()
    self:SetData("grade", 1)
    self:SetData("exp", 0)
end

function CFormat:Save()
    local mData = {}
    mData.data = self.m_mData
    return mData
end

function CFormat:Load(m)
    self.m_mData = m.data
end

function CFormat:GetOwner()
    return self:GetInfo("pid")
end

function CFormat:GetId()
    return self:GetInfo("fmt_id")
end

function CFormat:GetGrade()
    return self:GetData("grade", 1)
end

function CFormat:GetName()
    local mBaseInfo = self:GetBaseInfo()
    local iFmt = self:GetInfo("fmt_id")
    return mBaseInfo[iFmt]["name"]
end

function CFormat:GetExp()
    return self:GetData("exp", 0)
end

function CFormat:GetNextExp()
    local iLevel = self:GetGrade()
    local iFmt = self:GetInfo("fmt_id")
    local mBaseInfo = self:GetBaseInfo()
    return mBaseInfo[iFmt]["exp"][iLevel]
end

function CFormat:GetFullGradeExpNeed()
    local iGrade = self:GetGrade()
    local iFmt = self:GetInfo("fmt_id")
    local mBaseInfo = self:GetBaseInfo()
    local lExpList = mBaseInfo[iFmt]["exp"]
    local iTotal = 0
    for iLevel = iGrade, (#lExpList - 1) do
        iTotal = iTotal + lExpList[iLevel]
    end
    return iTotal - self:GetExp()
end

function CFormat:AddExp(iAdd)
    local iFmt = self:GetInfo("fmt_id")
    local mBaseInfo = self:GetBaseInfo()
    local lExpList = mBaseInfo[iFmt]["exp"]

    local iGrade = self:GetGrade()
    if iGrade >= #lExpList then
        return false
    end
    local iNextExp = self:GetNextExp()
    if not iNextExp or iNextExp<=0 then
        return false
    end

    local iExp = self:GetData("exp", 0)
    self:SetData("exp", iExp+iAdd)
    self:CheckUpgrade()
    self:RefreshOneFmtInfo()
    self:Dirty()
    self:Notify(self:GetOwner(), 1004, {name=self:GetName(), num=iAdd})


    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData["fmt_id"] = self:GetId()
        mLogData["exp_old"] = iExp
        mLogData["exp_add"] = iAdd
        mLogData["exp_now"] = self:GetExp()
        mLogData["grade_old"] = iGrade
        mLogData["grade_now"] = self:GetGrade()
        record.log_db("formation", "fmt_exp", mLogData)
    end
    return true
end

function CFormat:CheckUpgrade()
    local bUpgrade = false
    for i = 1, 20 do
        local iExp = self:GetData("exp", 0)
        local iNextExp = self:GetNextExp()
        if not iNextExp or iNextExp <= 0 then
            break
        end

        if iExp >= iNextExp then
            self:DoUpgrade()
            bUpgrade = true
        end
    end
    if bUpgrade then
        self:OnUpgrade()
    end
end

function CFormat:DoUpgrade()
    local iLevel = self:GetGrade()
    if iLevel < 10 then
        local iExp = self:GetExp()
        local iNextExp = self:GetNextExp()
        self:SetData("grade", iLevel+1)
        self:SetData("exp", iExp - iNextExp)
        self:Dirty()
    end
end

function CFormat:OnUpgrade()
    local iPid = self:GetOwner()
    global.oScoreCache:Dirty(iPid, "fmt")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:PropChange("score")
    end
    local oFmtMgr = self:GetOwnerMgr()
    if oFmtMgr:GetCurrFmt() == self:GetId() then
        oFmtMgr:BroadCastFmt2Team()
    end
end

function CFormat:GetOwnerMgr()
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetOwner()
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        return oPlayer:GetFormationMgr()
    end
end

function CFormat:RefreshOneFmtInfo()
    local oFmtMgr = self:GetOwnerMgr()
    if oFmtMgr then
        oFmtMgr:RefreshOneFmtInfo(self:GetId())
    end
end

function CFormat:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(iPid, sMsg)
end

function CFormat:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"formation"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function CFormat:GetBaseInfo()
    return res["daobiao"]["formation"]["base_info"]
end

function CFormat:GetAttrInfo()
    return res["daobiao"]["formation"]["attr_info"]
end










