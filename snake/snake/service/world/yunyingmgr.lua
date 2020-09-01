local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"
local router = require "base.router"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))


function NewYunYingMgr(...)
    return CYunYingMgr:New(...)
end

local START_NOTIFY = {
    ["collect"] = true,
    ["caishen"] = true,
    ["dayexpense"] = true,
    ["activepoint"] = true,
}

CYunYingMgr = {}
CYunYingMgr.__index = CYunYingMgr
CYunYingMgr.m_sTableName = "yunyinginfo"
inherit(CYunYingMgr, datactrl.CDataCtrl)

function CYunYingMgr:New()
    local o = super(CYunYingMgr).New(self)
    o:Init()
    return o
end

function CYunYingMgr:Init()
    self.m_mHuoDong = {}
    self.m_mNotify = {}
    self.m_mHuoDongTagInfo = {}
end

function CYunYingMgr:Save()
    return {
        huodong = self.m_mHuoDong,
        notify = self.m_mNotify,
    }
end

function CYunYingMgr:Load(mData)
    if not mData then return end

    self.m_mHuoDong = mData.huodong or {}
    self.m_mNotify = mData.notify or {}
end

function CYunYingMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        local oYunYingMgr = global.oYunYingMgr
        oYunYingMgr:_CheckSaveDb()
    end)
end

function CYunYingMgr:_CheckSaveDb()
    assert(not is_release(self), "_CheckSaveDb fail")
    assert(self:IsLoaded(), "yunyingmgr save fail: is loading")
    if not self:IsDirty() then return end
    
    self:SaveDb()
end

function CYunYingMgr:SaveDb()
    local mInfo = {
        module = "globaldb",
        cmd = "SaveGlobal",
        cond = {name = self.m_sTableName},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("yunying", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CYunYingMgr:LoadDb()
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.m_sTableName},
    }
    gamedb.LoadDb("yunying", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        self:Load(mData.data)
        self:OnLoaded()
        self:ResertHDNotiy()
        self:CheckHDInfo(true)
    end)
end

function CYunYingMgr:NewHour(mNow)
    self:CheckHDInfo(false, mNow)
end

function CYunYingMgr:NewDay()
end

function CYunYingMgr:ResertHDNotiy()
    for _, m in pairs(self.m_mHuoDong) do
        if START_NOTIFY[m.hd_type] then
            self.m_mNotify[m.hd_id] = nil    
        end
    end
end

function CYunYingMgr:IsNeedNotify(m, bStart)
    if not self.m_mNotify[m.hd_id] then return true end

    if bStart and START_NOTIFY[m.hd_type] then return true end

    return false
end

function CYunYingMgr:CheckHDInfo(bStart, mNow)
    local lNotiy = {}
    local iNowTime = mNow and mNow.time or get_time()
    for id, m in pairs(self.m_mHuoDong) do
        if m.start_time <= iNowTime and iNowTime < m.end_time and self:IsNeedNotify(m, bStart) then
            self:NotifyHD(id)
        elseif iNowTime >= m.end_time + 20 then
            -- 延迟点删
            self:RemoveHD(id)
        end
    end
end

function CYunYingMgr:CheckTime(iStartTime, iEndTime, sType)
    if not iStartTime or not iEndTime then return false end

    local mConfig = res["daobiao"]["hdcontrol"][sType]
    if not mConfig then
        return false, "no config" 
    end

    local iNowTime = get_time()
    if iStartTime >= iEndTime or iNowTime >= iEndTime then
        return false, string.format("time error now:%s,start:%s,end:%s", iNowTime, iStartTime, iEndTime)
    end

    local iLimitType = mConfig["limit_type"]
    if iLimitType == 2 then
        -- 固定天
        local iSDayNo = get_morningdayno(iStartTime)
        local iEDayNo1 = get_morningdayno(iEndTime)
        local iEDayNo2 = get_morningdayno(iEndTime + 1)
        if iEDayNo1 == iEDayNo2 then
            return false, "endtime error1"      
        end
        if (iEDayNo2 - iSDayNo) ~= mConfig["limit_day"] then
            return false, "endtime error2"      
        end
    elseif iLimitType == 3 then
        -- 5点刷天
        local iEDayNo1 = get_morningdayno(iEndTime)
        local iEDayNo2 = get_morningdayno(iEndTime + 1)
        if iEDayNo1 == iEDayNo2 then
            return false, "endtime error1"      
        end
    end
    return true
end

function CYunYingMgr:ValidHDInfo(mInfo)
    if not mInfo then return false, "no data" end

    local iHDID = mInfo["hd_id"]
    local sHDType = mInfo["hd_type"]
    local sHDKey = mInfo["hd_key"]
    local iStartTime = mInfo["start_time"]
    local iEndTime = mInfo["end_time"]
    local sDesc = mInfo["desc"]

    local oHuodong = global.oHuodongMgr:GetHuodong(sHDType)
    if not oHuodong then
        record.warning('yunyingmgr ValidHDInfo error no huodong obj %s, %s', iHDID, sHDType)
        return false, "no huodong" 
    end

    local bRet, sMsg = self:CheckTime(iStartTime, iEndTime, sHDType)
    if not bRet then
        record.warning('yunyingmgr ValidHDInfo CheckTime error %s, %s, %s', iHDID, sHDType, sMsg)
        return false, sMsg 
    end
    return true
end

function CYunYingMgr:FormatHDInfo(mData)
    if not mData then return end

    local mInfo = {}
    mInfo["hd_id"] = mData["hd_id"]
    mInfo["hd_type"] = mData["hd_type"]
    mInfo["hd_key"] = mData["hd_key"]
    mInfo["start_time"] = mData["start_time"]
    mInfo["end_time"] = mData["end_time"]
    mInfo["desc"] = mData["desc"]
    return mInfo
end

function CYunYingMgr:RegisterHD(mData)
    local mInfo = self:FormatHDInfo(mData)
    if not mInfo then return false, "no data" end

    --世界杯会有额外推送数据
    if mData.hd_type == "worldcup" then
        mInfo = mData
    end

    local bCheck, sMsg = self:ValidHDInfo(mInfo)
    if not bCheck then
        return false, sMsg
    end
    self.m_mNotify[mInfo.hd_id] = nil
    self:AddHD(mInfo)
    if mInfo.start_time <= get_time() then
        self:NotifyHD(mInfo.hd_id)
    end
    return true
end

function CYunYingMgr:UnRegisterHD(ids)
    for _, id in pairs(ids) do
        local mInfo = self.m_mHuoDong[id]
        if mInfo then
            self:NotifyHD(id, true)
            self:RemoveHD(id)     
        end
    end
end

function CYunYingMgr:AddHD(mInfo)
    self:Dirty()
    self.m_mHuoDong[mInfo.hd_id] = mInfo
    record.user("huodonginfo", "hd_control_add", {info=self:PackLogInfo(mInfo)})
end

function CYunYingMgr:RemoveHD(id)
    local mInfo = self.m_mHuoDong[id]
    if not mInfo then return end

    self:Dirty()
    self.m_mHuoDong[id] = nil
    self.m_mNotify[id] = nil
    record.user("huodonginfo", "hd_control_del", {info=self:PackLogInfo(mInfo)}) 
end

function CYunYingMgr:PackLogInfo(mInfo)
    local mRecord = table_copy(mInfo)
    mRecord.stime = get_format_time(mInfo.start_time)
    mRecord.etime = get_format_time(mInfo.end_time)
    return mRecord
end

------------------------
-- 活动实现　RegisterHD
-- 存在重复 RegisterHD 的可能如果活动在进行中需处理结束时间
-- bClose　后台可能的取消活动

function CYunYingMgr:NotifyHD(id, bClose)
    local mInfo = self.m_mHuoDong[id]
    if not mInfo then return end

    local sHDType = mInfo["hd_type"]
    local oHuodong = global.oHuodongMgr:GetHuodong(sHDType)
    if oHuodong then
        local bSucc, bRet, sError = safe_call(oHuodong.RegisterHD, oHuodong, mInfo, bClose)
        if bSucc and bRet then
            self.m_mNotify[id] = true
            self:Dirty()
        else
            record.warning("yunyingmgr NotifyHD error %s, %s, ERROR: %s", sHDType, bRet, sError)    
        end
        record.user("huodonginfo", "hd_control_notify", {info=self:PackLogInfo(mInfo), success=(bRet and 1 or 0)}) 
    else
        record.warning("yunyingmgr not find huodong error %s", sHDType)
    end
end

function CYunYingMgr:SyncHuoDongTagInfo(mData)
    self.m_mHuoDongTagInfo = mData or {}
    record.user("huodonginfo", "hd_taginfo", {info=self.m_mHuoDongTagInfo}) 
end

function CYunYingMgr:GetHuoDongTagInfo()
    -- TODO 改成cs获取
    -- router.Request("cs", ".backendinfo", "common", "GetHuoDongTagInfo", {}, function (mRecord, mData)
    --     self:SyncHuoDongTagInfo(mData.data)
    -- end)
end

function CYunYingMgr:MergeFrom(mFromData)
    -- 不需要合
    return true
end



