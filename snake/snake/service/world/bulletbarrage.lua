local global = require "global"
local interactive = require "base.interactive"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

local TYPE_STORY_VIDEO = 999

function NewBulletBarrageMgr( ... )
    local o = CBulletBarrageMgr:New()
    o:Schedule()
    return o
end

CBulletBarrageMgr = {}
CBulletBarrageMgr.__index = CBulletBarrageMgr
inherit(CBulletBarrageMgr, logic_base_cls())

function CBulletBarrageMgr:New()
    local o = super(CBulletBarrageMgr).New(self)
    o.m_mList = {}
    return o
end

function CBulletBarrageMgr:Schedule()
    local f1
    f1 = function ()
        self:DelTimeCb("_CheckClean")
        self:AddTimeCb("_CheckClean", 5 * 60 * 1000, f1)
        self:_CheckClean()
    end
    f1()
end

function CBulletBarrageMgr:_CheckClean()
    local mClean = {}
    for sType, _ in pairs(self.m_mList) do
        local lBulletBarrage = table_get_set_depth(self.m_mList, {sType})
        for sBarrage, obj in pairs(lBulletBarrage) do
            if not is_release(obj) and not obj:IsActive() then
                table.insert(mClean, {sType, sBarrage})
            end
        end
    end
    for _, mData in pairs(mClean) do
        local sType, sBarrage = table.unpack(mData)
        local iType, iBarrage = tonumber(sType), tonumber(sBarrage)
        self:RemoveBulletBarrage(iType, iBarrage)
    end
end

function CBulletBarrageMgr:OnCloseGS()
    for sType, _ in pairs(self.m_mList) do
        local lBulletBarrage = table_get_set_depth(self.m_mList, {sType})
        for sBarrage, obj in pairs(lBulletBarrage) do
            if obj and obj:IsDirty() then
                obj:SaveDb()
            end
        end
    end
end

function CBulletBarrageMgr:AddBulletBarrage(iBarrage, iType, obj)
    local sBarrage, sType = tostring(iBarrage), tostring(iType)
    if not self.m_mList[sType] then
        self.m_mList[sType] = {}
    end
    self.m_mList[sType][sBarrage] = obj
end

function CBulletBarrageMgr:RemoveBulletBarrage(iBarrage, iType)
    local obj = self:GetBulletBarrage(iBarrage, iType)
    local sBarrage, sType = tostring(iBarrage), tostring(iType)
    if obj then
        self.m_mList[sType][sBarrage] = nil
        baseobj_delay_release(obj)
    end
end

function CBulletBarrageMgr:GetBulletBarrage(iBarrage, iType)
    local sBarrage, sType = tostring(iBarrage), tostring(iType)
    if self.m_mList[sType] then
        return self.m_mList[sType][sBarrage]
    else
        return nil
    end
end

function CBulletBarrageMgr:AddBulletBarrageObj(iBarrage, iType, mData)
    local obj = CBulletBarrage:New(iBarrage, iType, mData)
    obj:OnLoaded()
    obj:Dirty()
    obj:SaveDb()
    self:AddBulletBarrage(iBarrage, iType, obj)
    return obj
end

function CBulletBarrageMgr:NewBulletBarrageObj(iBarrage, iType)
    local obj = CBulletBarrage:New(iBarrage, iType)
    self:AddBulletBarrage(iBarrage, iType, obj)
    return obj
end

function CBulletBarrageMgr:LoadBulletBarrage(iBarrage, iType, fCallback)
    local o = self:GetBulletBarrage(iBarrage, iType)
    if o then
        o:WaitLoaded(fCallback)
    else
        o = self:NewBulletBarrageObj(iBarrage, iType)
        o:WaitLoaded(fCallback)
        local mInfo = {
            module = "bulletbarragedb",
            cmd = "LoadBulletBarrage",
            cond = {id = iBarrage, type = iType},
        }
        gamedb.LoadDb("bulletbarrage", "common", "DbOperate", mInfo, function (mRecord, mData)
            local o = self:GetBulletBarrage(iBarrage, iType)
            assert(o and not o:IsLoaded(), string.format("LoadBulletBarrage fail %s %s", iBarrage, iType))
            if not mData.success then
                if iType == TYPE_STORY_VIDEO then
                    o:OnLoaded()
                    o:Dirty()
                    o:SaveDb()
                else
                    o:OnLoadedFail()
                    self:RemoveBulletBarrage(iBarrage, iType)
                end
            else
                local m = mData.data
                o:Load(m)
                o:OnLoaded()
                self:AddBulletBarrage(iBarrage, iType, o)
            end
        end)
    end
end

function CBulletBarrageMgr:AddBulletBarrageContents(iBarrage, iType, mContents)
    self:LoadBulletBarrage(iBarrage, iType, function (oBulletBarrage)
        if not oBulletBarrage then return end
        oBulletBarrage:AddContents(mContents)
    end)
end

function CBulletBarrageMgr:GetBulletBarrageData(oPlayer, iBarrage, iType)
    local iPid = oPlayer:GetPid()
    local obj = self:GetBulletBarrage(iBarrage, iType)
    if obj then
        if not obj:IsLoaded() then
            local fCallback = function (o)
                self:PackBulletBarrage(iPid, o)
            end
            obj:WaitLoaded(fCallback)
        else
            obj:PackData(oPlayer)
        end
    else
        self:LoadBulletBarrage(iBarrage, iType, function (oBulletBarrage)
            if not oBulletBarrage then return end
            self:PackBulletBarrageData(iPid, oBulletBarrage)
        end)
    end
end

function CBulletBarrageMgr:PackBulletBarrageData(pid, oBulletBarrage)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oBulletBarrage:PackData(oPlayer)
end



CBulletBarrage = {}
CBulletBarrage.__index = CBulletBarrage
inherit(CBulletBarrage, datactrl.CDataCtrl)

function CBulletBarrage:New(iBarrage, iType, mData)
    local o = super(CBulletBarrage).New(self)
    o.m_iID = iBarrage
    o.m_iType = iType
    o.m_mData = mData or {}
    o.m_iLastTime = get_time()
    o.m_lWaitFuncList = {}
    o.m_iPerSecMax = 15
    return o
end

function CBulletBarrage:ConfigSaveFunc()
    local bid, iType = self.m_iID, self.m_iType
    self:ApplySave(function ()
        local oBulletBarrageMgr = global.oBulletBarrageMgr
        local obj = oBulletBarrageMgr:GetBulletBarrage(bid, iType)
        if obj then 
            obj:SaveDb()
        else
            record.warning("bulletbarrage save err: %d %d no obj", bid, iType)
        end
    end)
end

function CBulletBarrage:AddContents(mContents)
    self:Dirty()
    if self.m_iType ~= TYPE_STORY_VIDEO then
        local iBout = mContents.bout
        local iSecs = mContents.secs
        local sBout = tostring(iBout)
        local sSecs = tostring(iSecs)
        local sName = mContents.name
        local sMsg = mContents.msg
        local lBout = table_get_set_depth(self.m_mData, {sBout, sSecs})
        table.insert(lBout, {sName, sMsg})
        local iCnt = table_count(lBout)
        if iCnt > self.m_iPerSecMax then
            self.m_mData[sBout][sSecs] = list_split(lBout, iCnt - self.m_iPreMax + 1, iCnt)
        end
    else
        local iSecs = mContents.secs
        local sSecs = tostring(iSecs)
        local sName = mContents.name
        local sMsg = mContents.msg
        local lContents = table_get_set_depth(self.m_mData, {sSecs})
        table.insert(lContents, {sName, sMsg})
        local iCnt = table_count(lContents)
        if iCnt > self.m_iPerSecMax then
            self.m_mData[sSecs] = list_split(lContents, iCnt - self.m_iPerSecMax + 1, iCnt)
        end
    end
end

function CBulletBarrage:Save()
    local mData = {}
    mData.id = self.m_iID
    mData.type = self.m_iType
    mData.data = table_deep_copy(self.m_mData or {}) 
    return mData
end

function CBulletBarrage:Load(mData)
    if not mData then return end
    self.m_iID = mData.id
    self.m_iType = mData.type
    self.m_mData = mData.data
end

function CBulletBarrage:SaveDb()
    if not self:IsLoaded() or not self:IsDirty() then
        return
    end
    local mInfo = {
        module = "bulletbarragedb",
        cmd = "SaveBulletBarrage",
        cond = {id = self.m_iID, type = self.m_iType},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("bulletbarrage", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CBulletBarrage:SetLastTime()
    self.m_iLastTime = get_time()
end

function CBulletBarrage:GetLastTime()
    return self.m_iLastTime
end

function CBulletBarrage:IsActive()
    local iNowTime = get_time()
    if iNowTime - self:GetLastTime() <= 5*60 then
        return true
    end
    return false
end

function CBulletBarrage:LoadedExec()
    super(CBulletBarrage).LoadedExec(self)
    self:SetLastTime()
end

function CBulletBarrage:WaitLoaded(func)
    super(CBulletBarrage).WaitLoaded(self, func)
    if self:IsLoaded() then
        self:SetLastTime()
    end
end

function CBulletBarrage:PackData(oPlayer)
    local mNet = {}
    if self.m_iType == TYPE_STORY_VIDEO then
        mNet.story_id = self.m_iID
        local mList = {}
        for sSecs, mContents in pairs(self.m_mData or {}) do
            local mBulletBarrage = {}
            local mBase = {}
            mBulletBarrage.sec = tonumber(sSecs)
            for _, mData in pairs(mContents) do
                local name, msg = table.unpack(mData)
                table.insert(mBase, {name = name, msg = msg})
            end
            mBulletBarrage.base = mBase
            table.insert(mList, mBulletBarrage)
        end
        mNet.lst = mList
        oPlayer:Send("GS2CStoryBulletBarrageData", mNet)
    else
        mNet.war_id = self.m_iID
        mNet.type = self.m_iType
        local mBarrage = {}
        for sBout, mBout in pairs(self.m_mData or {}) do
            local mList = {}
            for sSecs, mSecs in pairs(mBout) do
                local mBase = {}
                for _, mContents in pairs(mSecs) do
                    local mBarrage = {}
                    local name, msg = table.unpack(mContents)
                    mBarrage.name = name
                    mBarrage.msg = msg
                    table.insert(mBase, mBarrage)
                end
                table.insert(mList, {sec = tonumber(sSecs), base = mBase})
            end
            table.insert(mBarrage, {bout = tonumber(sBout), lst = mList})
        end
        mNet.barrage = mBarrage
        oPlayer:Send("GS2CWarBulletBarrageData", mNet)
    end
end

