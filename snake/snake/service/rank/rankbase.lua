--import module
local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local interactive = require "base.interactive"
local record = require "public.record"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

function NewRankObj(...)
    return CRankBase:New(...)
end


CRankBase = {}
CRankBase.__index = CRankBase
inherit(CRankBase, datactrl.CDataCtrl)

function CRankBase:New(idx, sName)
    local o = super(CRankBase).New(self)
    o:Init(idx, sName)
    return o
end

function CRankBase:Init(idx, sName)
    self.m_iShowLimit = 100
    self.m_iSaveLimit = 160
    self.m_mRankData = {}
    self.m_lSortList = {}
    self.m_mShowData = {}
    self.m_mShowRank = {}
    self.m_mTop3Data = {}
    self.m_lTitleList  = {}
    self.m_iRankIndex = idx
    self.m_sShowName = sName
    self.m_sRankName = sName
    self.m_iStubShow = 0
    self.m_iShowPage = 20
    self.m_lSortDesc = {true}  --true 降序, false 升序
    self.m_iFirstStub = 1      --第一次生成排行榜
end

function CRankBase:PushDataToRank(mData)
    local sKey, mUnit = self:GenRankUnit(mData)

    if self.m_mRankData[sKey] then
        if self:NeedReplaceRankData(sKey, mUnit) then
            self:Dirty()
            self.m_mRankData[sKey] = nil
            extend.Array.remove(self.m_lSortList, sKey)
            self:InsertToOrderRank(sKey, mUnit)
        end
    else
        self:InsertToOrderRank(sKey, mUnit)
    end
end

function CRankBase:SortFunction(mCompare1, mCompare2)
    local bSortDesc = self.m_lSortDesc[1]
    if not mCompare1 then return not bSortDesc end
    if not mCompare2 then return bSortDesc end

    for idx, bSortDesc in ipairs(self.m_lSortDesc) do
        if mCompare1[idx] > mCompare2[idx] then
            return bSortDesc
        elseif mCompare1[idx] < mCompare2[idx] then
            return not bSortDesc
        end
    end

    return bSortDesc
end

function CRankBase:GenRankUnit(mData)
    return db_key(mData.key), {mData.value}
end

function CRankBase:GenCompareUnit(sKey, mData)
    if mData then return mData end

    return self.m_mRankData[sKey]
end

function CRankBase:BinarySearch(sKey, mUnit)
    local iLen = #self.m_lSortList
    if iLen <= 0 then return 1 end

    local mCompare1 = nil
    local mCompare2 = self:GenCompareUnit(sKey, mUnit)

    if iLen >= self.m_iSaveLimit then
        mCompare1 = self:GenCompareUnit(self.m_lSortList[iLen])
        if self:SortFunction(mCompare1, mCompare2) then
            return
        else
            local sDel = self.m_lSortList[iLen]
            self.m_mRankData[sDel] = nil
            table.remove(self.m_lSortList, iLen)
            self:Dirty()
        end
    end

    local iStart, iEnd = 1, #self.m_lSortList
    while iStart <= iEnd do
        local iMiddle = (iStart + iEnd) // 2
        mCompare1 = self:GenCompareUnit(self.m_lSortList[iMiddle])
        if self:SortFunction(mCompare1, mCompare2) then
            iStart = iMiddle + 1
        else
            iEnd = iMiddle - 1
        end
    end
    return iStart 
end

function CRankBase:InsertToOrderRank(sKey, mUnit)
    local iIdx = self:BinarySearch(sKey, mUnit)
    if iIdx and iIdx >= 1 and iIdx <= self.m_iSaveLimit then
        table.insert(self.m_lSortList, iIdx, sKey)
        self.m_mRankData[sKey] = mUnit
        self:Dirty()
        return true
    end
    return false
end

function CRankBase:RemoveItemByKey(sKey)
    if self.m_mRankData[sKey] then
        self:Dirty()
        self.m_mRankData[sKey] = nil
        extend.Array.remove(self.m_lSortList, sKey)
    end
end

function CRankBase:NeedReplaceRankData(sKey, mNewData)
    local mOldCompare = self:GenCompareUnit(sKey)
    local mNewCompare = self:GenCompareUnit(sKey, mNewData)
    
    if not self:SortFunction(mOldCompare, mNewCompare) then
        return true
    end

    return false
end

function CRankBase:NewHour(iDay,iHour)
    if self.m_iStubShow ~= 5 then return end

    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRankBase:NewDay(iDay)
    if self.m_iStubShow ~= 0 then return end

    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRankBase:GetIndex()
end

function CRankBase:OnUpdateName(iPid, sName)
    local sKey = db_key(iPid)
    local iPidPos, iNamePos = self:GetIndex()
    if not iPidPos or not iNamePos then
        return
    end

    if self.m_mRankData[sKey] then
        self.m_mRankData[sKey][iNamePos] = sName
    end

    local iRank = self.m_mShowRank[sKey]
    if not iRank then return end

    for iPage, mData in pairs(self.m_mShowData) do
        for idx, lInfo in ipairs(mData) do
            if lInfo[iPidPos] == iPid then
                lInfo[iNamePos] = sName
            end
        end
    end

    for iRank, mInfo in pairs(self.m_mTop3Data) do
        if mInfo.pid == iPid then
            mInfo.name = sName
        end
    end
    self:Dirty()
end

function CRankBase:GetOrgInfo()
end

function CRankBase:OnUpdateOrgName(iOrgId, sName)
    local iOrgPos, iNamePos, sIdKey, sNameKey, bOrgKey = self:GetOrgInfo()
    if not iOrgPos or not iNamePos or not sIdKey or not sNameKey then
        return
    end

    for sKey, lInfo in pairs(self.m_mRankData) do
        if lInfo[iOrgPos] == iOrgId then
            lInfo[iNamePos] = sName
        end
    end

    if bOrgKey then
        local iRank = self.m_mShowRank[db_key(iOrgId)]
        if not iRank then return end
    end

    for iPage, mData in pairs(self.m_mShowData) do
        for idx, lInfo in ipairs(mData) do
            if lInfo[iOrgPos] == iOrgId then
                lInfo[iNamePos] = sName
            end
        end
    end

    for iRank, mInfo in pairs(self.m_mTop3Data) do
        if mInfo[sIdKey] == iPid then
            mInfo[sNameKey] = sName
        end
    end
    self:Dirty()
end

function CRankBase:OnLogin(iPid)
end

function CRankBase:OnLogout(iPid)
end

function CRankBase:GetRankShift(sKey, iCurrRank)
    if not self.m_mShowRank[sKey] then
        return iCurrRank + self.m_iShowLimit
    end
    return iCurrRank - self.m_mShowRank[sKey]
end

function CRankBase:DoStubShowData() 
    if table_count(self.m_mShowData) > 0 then
        self.m_iFirstStub = 0
    end

    local iCount, iPage = 0, 1 
    local lPageList = {}
    local mShowData = {}
    local mShowRank = {}
    
    for idx, sKey in ipairs(self.m_lSortList) do
        if self.m_mRankData[sKey] then
            local mTmpData = table_deep_copy(self.m_mRankData[sKey])
            local iRankShift = self:GetRankShift(sKey, idx)
            table.insert(mTmpData, iRankShift)
            table.insert(lPageList, mTmpData)
            iCount  = iCount + 1
            mShowRank[sKey] = idx
        end
        if iCount >= self.m_iShowPage then
            mShowData[iPage] = lPageList
            iCount = 0
            iPage = iPage + 1
            lPageList = {}
        end
    end
    if #lPageList > 0 then
        mShowData[iPage] = lPageList
    end
    self.m_mShowData = mShowData
    self.m_mShowRank = mShowRank

    self:Dirty()
end

function CRankBase:GetShowRankData(iPage)
    if iPage < 1 or iPage > self.m_iShowLimit/self.m_iShowPage then
        return {}
    end
    return self.m_mShowData[iPage] or {}
end

function CRankBase:GetRankShowDataByLimit(iLimit)
    local iPage, iRet = iLimit // self.m_iShowPage, iLimit % self.m_iShowPage
    local lResult = {}
    for i = 1, iPage do
        for _, mInfo in pairs(self.m_mShowData[i] or {}) do
            table.insert(lResult, mInfo)
        end
    end
    if iRet > 0 then
        for idx, mInfo in pairs(self.m_mShowData[iPage+1] or {}) do
            if idx > iRet then break end
            table.insert(lResult, mInfo)
        end
    end
    return lResult
end

function CRankBase:PackShowRankData(iPid, iPage)
    --local lPageList = self.m_mShowData[iPage] or {}
    return {}
end

function CRankBase:PackTop3RankData()
    return {}
end

function CRankBase:GetCondition(mData)
    --
end

function CRankBase:RemoteGetTop3Profile()
    local lPageData = self.m_mShowData[1] or {}
    local iSize = math.min(3, #lPageData)
    if iSize <= 0 then return end
   
    local mKeepInfo = {} 
    for i = 1, iSize do
        local mCondition = self:GetCondition(i, lPageData[i])
        if not mCondition then
            record.warning(string.format("RemoteGetTop3Profile error %s ",self.m_sRankName))
            return 
        end
        interactive.Request(".world", "rank", "GetProfile", mCondition,
        function(mRecord, mData)
            mKeepInfo[mData.rank] = mData
            if table_count(mKeepInfo) >= iSize then
                self:RemoteDone(mKeepInfo)
            end
        end)
    end
end

function CRankBase:RemoteDone(mKeepInfo)
    if not mKeepInfo then return end
    for iRank, mData in pairs(mKeepInfo) do
        mData.value = self.m_mShowData[1][iRank][1]
        self.m_mTop3Data[iRank] = mData
    end
    self:Dirty()
end

function CRankBase:Save()
    local mData = {}
    mData.rank_data = self.m_mRankData
    mData.sort_list = self.m_lSortList
    mData.show_data = self.m_mShowData
    mData.show_rank = self.m_mShowRank
    mData.top3_data = self.m_mTop3Data
    mData.first_stub = self.m_iFirstStub
    mData.titlelist = self.m_lTitleList or {}
    return mData
end

function CRankBase:Load(m)
    self.m_mRankData = m.rank_data or {}
    self.m_lSortList = m.sort_list or {}
    self.m_mShowData = m.show_data or {}
    self.m_mShowRank = m.show_rank or {}
    self.m_mTop3Data = m.top3_data or {}
    self.m_iFirstStub = m.first_stub or 1
    self.m_lTitleList = m.titlelist or {}
end

function CRankBase:MergeFrom(mFromData)
    return false, "merge function is not implemented"
end

function CRankBase:MergeFinish()
    
end

function CRankBase:SaveDb()
    if is_ks_server() then return end

    if not self:IsLoaded() then return end
    if not self:IsDirty() then return end
    assert(self.m_sRankName, "rankname can't be empty")
    
    local mInfo = {
        module = "rankdb",
        cmd = "SaveRankByName",
        cond = {rank_name = self.m_sRankName},
        data = {rank_data = self:Save()},
    }
    gamedb.SaveDb("rank", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CRankBase:LoadDb()
    local mInfo = {
        module = "rankdb",
        cmd = "LoadRankByName",
        cond = {rank_name = self.m_sRankName},
    }
    gamedb.LoadDb("rank", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        if not self:IsLoaded()  then
            self:Load(mData.rank_data)
            self:OnLoaded()
        end
    end)
end

function CRankBase:ConfigSaveFunc()
    local idx = self.m_iRankIndex
    self:ApplySave(function ()
        local oRankMgr = global.oRankMgr
        local obj = oRankMgr:GetRankObj(idx)
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("rank save err: %d no obj", idx)
        end
    end)
end

function CRankBase:_CheckSaveDb()
    assert(not is_release(self), string.format("rank %s is releasing, save fail", self.m_sRankName))
    assert(self:IsLoaded(), string.format("rank %s is loading, save fail", self.m_sRankName))
    self:SaveDb()
end

function CRankBase:ValidRefresh(iDay,iHour)
    local mRes = res["daobiao"]["rank"][self.m_iRankIndex]
    if not mRes then
        return false
    end
    if mRes.refreshtype ==1 then
        if extend.Array.find(mRes.refreshhour,iHour) then
            return true
        end
    elseif mRes.refreshtype == 2 then
        if iDay ==1 and extend.Array.find(mRes.refreshhour,iHour) then
            return true
        end
    else
        return true 
    end
    return false
end

function CRankBase:RecordTitlePlayer(lTitlelist)
    self:Dirty()
    self.m_lTitleList = lTitlelist or {}
end

function CRankBase:RemoveTitle()
    if self.m_lTitleList and #self.m_lTitleList>0 then
        local mData = {plist = self.m_lTitleList,rank = self.m_sRankName}
        interactive.Send(".world", "rank", "RemoveTitle", mData)
    end
end

function CRankBase:MergeTitleRecord(mFromData)
    if mFromData.titlelist and #mFromData.titlelist>0 then
        for _,mInfo in pairs(mFromData.titlelist) do
            table.insert(self.m_lTitleList,mInfo)
        end
    end
end

function CRankBase:GetAlias()
    local mRank = res["daobiao"]["rank"][self.m_iRankIndex]
    return mRank.alias
end
