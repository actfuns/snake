
--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"
local datactrl = import(lualib_path("public.datactrl"))

--精气控制模块

function NewVigorCtrl(...)
    return CVigorCtrl:New(...)
end

CVigorCtrl = {}
CVigorCtrl.__index = CVigorCtrl
inherit(CVigorCtrl, datactrl.CDataCtrl)

function CVigorCtrl:New(iPid)
    local o = super(CVigorCtrl).New(self)
    o.m_iPid = iPid
    o.m_mList = {}
    o:Init()
    return o
end

function CVigorCtrl:Init()
    local mConfig = self:GetConfig()
    for iType, mInfo in pairs(mConfig) do
        self.m_mList[iType] = NewVigorItem(self.m_iPid, iType)
    end
end

function CVigorCtrl:Release()
    for iType, oVigorItem in pairs(self.m_mList) do
        baseobj_safe_release(oVigorItem)
    end
    self.m_mList = {}
    super(CVigorCtrl).Release(self)
end

function CVigorCtrl:Save()
    local mData = {}
    for iType, oVigorItem in pairs(self.m_mList) do
        mData[db_key(iType)] = oVigorItem:Save()
    end
    return mData
end

function CVigorCtrl:Load(m)
    for sType, mInfo in pairs(m or {}) do
        self.m_mList[tonumber(sType)]:Load(mInfo)
    end
end

function CVigorCtrl:TryOpenVigorUI(oPlayer)
    if not global.oToolMgr:IsSysOpen("VIGOR", oPlayer) then
        return
    end
    local lVigorList = {}
    for iType, oVigorItem in pairs(self.m_mList) do
        table.insert(lVigorList, oVigorItem:PackVigorInfo())
    end
    local mNet = {
        list_info = lVigorList,
    }
    oPlayer:Send("GS2CVigorChangeInfo", mNet)
end

function CVigorCtrl:TryStartTransform(oPlayer, iType)
    local oVigorItem = self.m_mList[iType]
    if not oVigorItem then return end

    local iRet = oVigorItem:ValidStartTransform(oPlayer)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet)
        return
    end

    oVigorItem:StartTransform(oPlayer, true)
end

function CVigorCtrl:SetTranfromAllByType(oPlayer, iType, iSet)
    local oVigorItem = self.m_mList[iType]
    if not oVigorItem then return end

    oVigorItem:SetTransformAll(oPlayer, iSet)
    local mNet = {
        change_type = iType,
        is_change_all = oVigorItem.m_iTransfromAll,
    }
    oPlayer:Send("GS2CVigorChangeItemStatus", mNet)
end

function CVigorCtrl:TryTransformAll(oPlayer)
    local mConfig = self:GetConfig()[1]
    if oPlayer:GetVigor() < mConfig.cost then
        self:Notify(oPlayer:GetPid(), 1003)
        return
    end

    for iType, oVigorItem in pairs(self.m_mList) do
        oVigorItem:TransformAll(oPlayer)
    end
    self:TryOpenVigorUI(oPlayer)
end

function CVigorCtrl:GetRewardByType(oPlayer, iType)
    local oVigorItem = self.m_mList[iType]
    if not oVigorItem then return end

    oVigorItem:GetRewardByPos(oPlayer, 1)
end

function CVigorCtrl:GetAllReward(oPlayer)
    local bReward = false
    local iErrorText = nil
    for iType, oVigorItem in pairs(self.m_mList) do
        local bRet,iRetText = oVigorItem:GetAllReward(oPlayer)
        bReward = bReward or bRet
        iErrorText = iErrorText or iRetText
    end
    if bReward then
        self:TryOpenVigorUI(oPlayer)
    elseif  iErrorText == 1014 then
        self:Notify(oPlayer:GetPid(),1014)
    elseif iErrorText == 1010 then
        local mNet = self:GetTextData(1010)
        global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
            if mData.answer == 1 then
                oPlayer:Send("GS2COpenCultivateUI", {})
            end
        end)
    else
        self:Notify(oPlayer:GetPid(), 1005)
    end
end

function CVigorCtrl:OpenGridLimitByType(oPlayer, iType)
    local oVigorItem = self.m_mList[iType]
    if not oVigorItem then return end

    oVigorItem:OpenGridLimit(oPlayer)
end

function CVigorCtrl:ExchangeGoldcoinToVigor(oPlayer)
    if not global.oToolMgr:IsSysOpen("VIGOR", oPlayer) then
        return
    end

    local mConfig = res["daobiao"]["vigo"]["other"][1]
    local iCost = mConfig.cost
    local iVal = mConfig.value
    if oPlayer:GetGoldCoin() < iCost then
        self:Notify(oPlayer:GetPid(), 1006)
        return
    end
    local iVigor = oPlayer:GetVigor()
    if iVigor >= mConfig.vigor_maxLimit then
        self:Notify(oPlayer:GetPid(), 1009)
        return
    end
    oPlayer:ResumeGoldCoin(iCost, "元宝转精气")
    oPlayer:AddVigor(iVal, "元宝转精气")
    self:Notify(oPlayer:GetPid(), 1011, {val=iVal})
end

function CVigorCtrl:ChangeItemToVigor(oPlayer, lItemList)
    if not global.oToolMgr:IsSysOpen("VIGOR", oPlayer) then
        return
    end

    local iTotal = 0
    local iVigor = oPlayer:GetVigor()
    local mConfig = res["daobiao"]["vigo"]["other"][1]

    for _, mItem in ipairs(lItemList) do
--        if iTotal + iVigor > mConfig.vigor_maxLimit then
--            break
--        end
        local iAmount = mItem.change_amount
        if iAmount <= 0 then goto continue end

        local iItem = mItem.item_id
        local oItem = oPlayer:HasItem(iItem)
        if not oItem then goto continue end

        local iChange = oItem:Change2VigorVal()
        if iChange <= 0 then goto continue end

        if oItem:IsBind() then
            iChange = math.ceil( iChange * mConfig["bind_item"])
        end

        local iUseAmount = math.min(iAmount, oItem:GetAmount())
        self:PreItemToVigor(oPlayer,oItem,iUseAmount)
        oPlayer:RemoveOneItemAmount(oItem, iUseAmount, "精气炼化")

        iTotal = iTotal + iUseAmount*iChange
        ::continue::
    end

    if iTotal > 0 then
        oPlayer:AddVigor(iTotal, "道具转精气")
        self:Notify(oPlayer:GetPid(), 1011, {val=iTotal})
    end
end

function CVigorCtrl:PreItemToVigor(oPlayer,oItem,iAmount)
    if oItem:ItemType() == "equip" and table_count(oItem:GetHunShi())>0 then
        local mAllInfo = oItem:GetHunShi()
        for pos ,mInfo in pairs(mAllInfo) do
            global.oItemHandler:BackHunShi(oPlayer,mInfo,"vigor")
        end
    end
end

function CVigorCtrl:CheckSelf(oPlayer)
    local iPid = oPlayer:GetPid()
    local iTime = get_time()
    local iCheckTime = 0xffff
    for iType, oItemVigor in pairs(self.m_mList) do
        for iPos, mGrid in pairs(oItemVigor.m_lAllGrid) do
            local iDelta = mGrid.timeout - iTime
            if iDelta < 300 and iDelta < iCheckTime then
                iCheckTime = math.max(1, iDelta)
            end
        end
    end
    if iCheckTime ~= 0xffff then
        self:DelTimeCb("RedPointNotify")
        self:AddTimeCb("RedPointNotify", (iCheckTime+1)*1000, function()
            RedPointNotify(iPid)
        end)
    end
end

function CVigorCtrl:RedPointNotify(oPlayer)
    local iTime = get_time()
    for iType, oItemVigor in pairs(self.m_mList) do
        for iPos, mGrid in pairs(oItemVigor.m_lAllGrid) do
            local iDelta = mGrid.timeout - iTime
            if iDelta <= 0 and (iType~=3 or oPlayer.m_oSkillCtrl:CanAnyCulSkillAddExp(mGrid.val)) then
                oPlayer:Send("GS2CVigorRedPoint", {})
                break
            end
        end
    end
end

function CVigorCtrl:Notify(iPid, iChat, mReplace)
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oNotifyMgr:Notify(iPid, sMsg)
end

function CVigorCtrl:GetTextData(iChat)
    return global.oToolMgr:GetTextData(iChat, {"vigo"})
end

function CVigorCtrl:GetConfig()
    return res["daobiao"]["vigo"]["config"]
end


function NewVigorItem(...)
    return CVigorItem:New(...)
end

CVigorItem = {}
CVigorItem.__index = CVigorItem
inherit(CVigorItem, datactrl.CDataCtrl)

function CVigorItem:New(iPid, iType)
    local o = super(CVigorItem).New(self)
    o.m_iPid = iPid
    o.m_iType = iType
    o.m_lAllGrid = {}
    o.m_iSizeLimit = 2
    o.m_iTransfromAll = 1
    return o
end

function CVigorItem:Save()
    local mData = {}
    local lAllGrid = {}
    for iPos, mGrid in pairs(self.m_lAllGrid) do
        lAllGrid[db_key(iPos)] = mGrid
    end
    mData.grid_list = lAllGrid
    mData.size_limit = self.m_iSizeLimit
    mData.transform_all = self.m_iTransfromAll 
    return mData
end

function CVigorItem:Load(m)
    if not m then return end

    for sPos, mGrid in pairs(m.grid_list or {}) do
        self.m_lAllGrid[tonumber(sPos)] = mGrid
    end
    if m.size_limit then
        self.m_iSizeLimit = m.size_limit
    end
    if m.transform_all then
        self.m_iTransfromAll = m.transform_all
    end
end

function CVigorItem:GetName()
    local mConfig = self:GetConfig()
    return mConfig.name
end

function CVigorItem:OpenGridLimit(oPlayer)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    if self.m_iSizeLimit >= mConfig.grid_limit then
        self:Notify(iPid, 1007)
        return
    end
    local iSize = self.m_iSizeLimit + 1
    local iCost = mConfig.grid_cost[iSize]
    if oPlayer:GetGoldCoin() < iCost then
        self:Notify(iPid, 1006)
        return
    end
   
    self:Dirty()
    oPlayer:ResumeGoldCoin(iCost, "开启精气炼制格子"..iSize)
    self.m_iSizeLimit = iSize
    self:Notify(iPid, 1008, {name=self:GetName()})
    local mNet = {change_type = self.m_iType, grid_size=iSize}
    oPlayer:Send("GS2CVigorItemGetNewGrid", mNet)
end

function CVigorItem:StartTransform(oPlayer, bRefresh)
    local mConfig = self:GetConfig()
    oPlayer:AddVigor(-mConfig.cost, "精气炼制"..self.m_iType)

    local iStartTime = get_time()
    local iLen = #self.m_lAllGrid
    if iLen > 0 then
        local mPreGrid = self.m_lAllGrid[iLen]
        iStartTime = math.max(get_time(), mPreGrid.timeout)
    end

    local mEnv = {
        grade = oPlayer:GetGrade(),
        SLV = oPlayer:GetServerGrade(),
    }
    local iVal = math.floor(formula_string(mConfig.formula, mEnv))
    local iTime = mConfig.time*60 + iStartTime
    table.insert(self.m_lAllGrid, {val=iVal, timeout=iTime})
    self:Dirty()

    if bRefresh then
        local mNet = {item_info = self:PackVigorInfo()}
        oPlayer:Send("GS2CVigorItemGetProduct", mNet)
    end
end

function CVigorItem:ValidStartTransform(oPlayer)
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.grade_limit then
        return 1002
    end

    if self.m_iSizeLimit <= #self.m_lAllGrid then
        return 1001
    end

    if oPlayer:GetVigor() < mConfig.cost then
        return 1003
    end
    return 1
end

function CVigorItem:SetTransformAll(oPlayer, iSet)
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.grade_limit then
        return
    end
    self.m_iTransfromAll = iSet
    self:Dirty()
end

function CVigorItem:TransformAll(oPlayer)
    if self.m_iTransfromAll <= 0 then
        return
    end
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.grade_limit then
        return
    end
    local iStart = #self.m_lAllGrid + 1
    if iStart > self.m_iSizeLimit then return end

    for iPos = iStart, self.m_iSizeLimit do
        local iRet = self:ValidStartTransform(oPlayer)
        if iRet ~= 1 then break end

        self:StartTransform(oPlayer, false)
    end
end

function CVigorItem:ValidGetReward(oPlayer, mGrid)
    if not mGrid then return 1013 end
    
    if get_time() <= mGrid.timeout then
        return 1012
    end

    if self.m_iType==3 then
        local iVal = self:GetRewardValue(oPlayer)
        if not oPlayer.m_oSkillCtrl:CanAnyCulSkillAddExp(iVal) then
            return 1014
        end
        if not oPlayer.m_oSkillCtrl:CanAddCurrCulSkillExp(iVal) then
            return 1010
        end
    end

    return 1
end

function CVigorItem:GetRewardByPos(oPlayer, iPos)
    local mGrid = self.m_lAllGrid[iPos]
    
    local iRet = self:ValidGetReward(oPlayer, mGrid)
    if iRet ~= 1 then
        if iRet == 1010  then
            local mNet = self:GetTextData(1010)
            global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
                if mData.answer == 1 then
                    oPlayer:Send("GS2COpenCultivateUI", {})
                end
            end)
        else
            self:Notify(oPlayer:GetPid(), iRet)
        end
        return
    end

    table.remove(self.m_lAllGrid, iPos)
    self:Dirty()
    self:DoReward(oPlayer)

    local mNet = {item_info = self:PackVigorInfo()}
    oPlayer:Send("GS2CVigorItemGetProduct", mNet)
end

function CVigorItem:GetRewardValue(oPlayer)
    local mConfig = self:GetConfig()
    local mEnv = {
        grade = oPlayer:GetGrade(),
        SLV = oPlayer:GetServerGrade(),
    }
    local iVal = math.floor(formula_string(mConfig.formula, mEnv))
    return iVal
end

function CVigorItem:DoReward(oPlayer)
    local iVal = self:GetRewardValue(oPlayer)
    if self.m_iType == 1 then
        oPlayer:RewardSilver(iVal, "精气炼制")
    elseif self.m_iType == 2 then
        oPlayer:RewardExp(iVal, "精气炼制")
    elseif self.m_iType == 3 then
        oPlayer:RewardCultivateExp(iVal, "精气炼制")
    end
end

function CVigorItem:GetAllReward(oPlayer)
    local iCurrTime = get_time()
    local lRemove = {}
    local iRetText
    for iPos, mGrid in pairs(self.m_lAllGrid) do
        local iRet = self:ValidGetReward(oPlayer, mGrid)
        if iRet == 1 then
            self:DoReward(oPlayer)
            table.insert(lRemove, iPos)
        else
            if iRet == 1010 or iRet == 1014 then
                iRetText = iRet
            end
            break
        end
    end
    local iLen = #lRemove
    if iLen > 0 then
        for i = iLen, 1, -1 do
            table.remove(self.m_lAllGrid, lRemove[i])
        end
        self:Dirty()
        return true, iRetText
    end
    return false, iRetText
end

function CVigorItem:PackVigorInfo()
    local lGrid = {}
    for iPos, mGrid in pairs(self.m_lAllGrid) do
        table.insert(lGrid, self:PackGridInfo(iPos))
    end
    local mNet = {
        is_change_all = self.m_iTransfromAll,
        grid_size = self.m_iSizeLimit,
        change_type = self.m_iType,
        grid_info = lGrid,
    }
    return mNet
end

function CVigorItem:PackGridInfo(iPos)
    local mGrid = self.m_lAllGrid[iPos]
    if not mGrid then return end

    local mNet = {
        timeout = mGrid.timeout,
        value = mGrid.val,
    }
    return mNet
end

function CVigorItem:Dirty()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        oPlayer.m_oActiveCtrl.m_oVigorCtrl:Dirty()
    end
end

function CVigorItem:Notify(iPid, iChat, mReplace)
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oNotifyMgr:Notify(iPid, sMsg)
end

function CVigorItem:GetTextData(iChat)
    return global.oToolMgr:GetTextData(iChat, {"vigo"})
end

function CVigorItem:GetConfig()
    return res["daobiao"]["vigo"]["config"][self.m_iType]
end

function RedPointNotify(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    oPlayer.m_oActiveCtrl.m_oVigorCtrl:RedPointNotify(oPlayer)
end
