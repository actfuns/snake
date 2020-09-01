--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local playernet = import(service_path("netcmd/player"))
local fmtmgr = import(service_path("formation.fmtmgr"))
local bianshenobj = import(service_path("player/bianshenobj"))
local fubenmgr = import(service_path("fuben.progress"))
local sysconfigmgr = import(service_path("player.sysconfigmgr"))
local gamepushmgr = import(service_path("player.gamepushmgr"))
local waiguan = import(service_path("playerctrl.baseobj.waiguan"))
local grow = import(service_path("playerctrl.baseobj.grow"))
local testctrl = import(service_path("playerctrl.sub.testctrl"))
local zhenmoctrl = import(service_path("task.zhenmo.zhenmoctrl"))
local analylog = import(lualib_path("public.analylog"))
local max = math.max
local min = math.min

local lPropName = {"agility", "strength", "magic", "endurance", "physique"}

CPlayerBaseCtrl = {}
CPlayerBaseCtrl.__index = CPlayerBaseCtrl
inherit(CPlayerBaseCtrl, datactrl.CDataCtrl)

function CPlayerBaseCtrl:New(pid)
    local o = super(CPlayerBaseCtrl).New(self, {pid = pid})
    o.m_oFmtMgr = fmtmgr.NewFmtMgr(pid)
    o.m_oBianShenMgr = bianshenobj.NewBianShenMgr(pid)
    o.m_oFubenMgr = fubenmgr.NewProgress(pid)
    o.m_oSysConfigMgr = sysconfigmgr.NewSysConfigMgr(pid)
    o.m_oGamePushMgr = gamepushmgr.NewGamePushMgr(pid)
    o.m_oWaiGuan = waiguan.NewWaiGuan(pid)
    o.m_oGrow = grow.NewGrow(pid)
    o.m_oTestCtrl = testctrl.CTestCtrl:New()
    o.m_oZhenmoCtrl = zhenmoctrl.NewZhenmoCtrl(pid)
    return o
end

function CPlayerBaseCtrl:Release()
    baseobj_safe_release(self.m_oFmtMgr)
    self.m_oFmtMgr = nil
    baseobj_safe_release(self.m_oBianShenMgr)
    self.m_oBianShenMgr = nil
    baseobj_safe_release(self.m_oFubenMgr)
    self.m_oFubenMgr = nil
    baseobj_safe_release(self.m_oSysConfigMgr)
    self.m_oSysConfigMgr = nil
    baseobj_safe_release(self.m_oGamePushMgr)
    self.m_oGamePushMgr = nil
    baseobj_safe_release(self.m_oWaiGuan)
    self.m_oWaiGuan = nil
    baseobj_safe_release(self.m_oGrow)
    self.m_oGrow = nil
    baseobj_safe_release(self.m_oTestCtrl)
    self.m_oTestCtrl = nil
    baseobj_safe_release(self.m_oZhenmoCtrl)
    self.m_oZhenmoCtrl = nil
    super(CPlayerBaseCtrl).Release(self)
end

function CPlayerBaseCtrl:GetPid()
    return self:GetInfo("pid")
end

function CPlayerBaseCtrl:Load(mData)
    local mData = mData or {}
    local mRoleInitProp = res["daobiao"]["roleprop"][1]

    self:SetData("grade", mData.grade or mRoleInitProp.grade)
    self:SetData("sex", mData.sex or 1)
    self:SetData("icon", mData.icon or mData.model_info.shape)
    self:SetData("role_type", mData.role_type)
    self:SetData("point", mData.point or mRoleInitProp.point)
    self:SetData("critical_multiple", mData.critical_multiple or mRoleInitProp.critical_multiple)
    self:SetData("phy_critical_ratio", mData.phy_critical_ratio or mRoleInitProp.phy_critical_ratio)
    self:SetData("res_phy_critical_ratio", mData.res_phy_critical_ratio or mRoleInitProp.res_phy_critical_ratio)
    self:SetData("mag_critical_ratio", mData.mag_critical_ratio or mRoleInitProp.mag_critical_ratio)
    self:SetData("res_mag_critical_ratio", mData.res_mag_critical_ratio or mRoleInitProp.res_mag_critical_ratio)
    self:SetData("seal_ratio", mData.seal_ratio or mRoleInitProp.seal_ratio)
    self:SetData("res_seal_ratio", mData.res_seal_ratio or mRoleInitProp.res_seal_ratio)
--    self:SetData("hit_ratio", mData.hit_ratio or mRoleInitProp.hit_ratio)
--    self:SetData("hit_res_ratio", mData.hit_res_ratio or mRoleInitProp.hit_res_ratio)
    self:SetData("phy_hit_ratio", mData.phy_hit_ratio or mRoleInitProp.phy_hit_ratio)
    self:SetData("phy_hit_res_ratio", mData.phy_hit_res_ratio or mRoleInitProp.phy_hit_res_ratio)
    self:SetData("mag_hit_ratio", mData.mag_hit_ratio or mRoleInitProp.mag_hit_ratio)
    self:SetData("mag_hit_res_ratio", mData.mag_hit_res_ratio or mRoleInitProp.mag_hit_res_ratio)
    self:SetData("physique", mData.physique or mRoleInitProp.physique)
    self:SetData("strength", mData.strength or mRoleInitProp.strength)
    self:SetData("magic", mData.magic or mRoleInitProp.magic)
    self:SetData("endurance", mData.endurance or mRoleInitProp.endurance)
    self:SetData("agility", mData.agility or mRoleInitProp.agility)
    self:SetData("model_info", mData.model_info)
    self:SetData("school", mData.school)
    self:SetData("point_plan", mData.point_plan or {})
    self:SetData("selected_point_plan", mData.selected_point_plan or 1)
    self:SetData("init_newrole",mData.init_newrole)
    self:SetData("cure_power", mData.cure_power or mRoleInitProp.cure_power)
    self:SetData("position", mData.position or "未知")
    self:SetData("agree", mData.agree or {})
    self:SetData("position_hide", mData.position_hide or 1)
    self:SetData("rename", mData.rename or 0)   --0-没改过名，1-改过名
    self:SetData("double_point", mData.double_point)
    self:SetData("other_info", mData.other_info or {})
    self.m_oFmtMgr:Load(mData.fmt_data or {})
    self.m_oBianShenMgr:Load(mData.bianshen or {})
    self.m_oFubenMgr:Load(mData.fuben or {})
    self.m_oSysConfigMgr:Load(mData.sys_config or {})
    self.m_oGamePushMgr:Load(mData.gamepush or {})
    self.m_oWaiGuan:Load(mData.waiguan or {})
    self.m_oGrow:Load(mData.growinfo or {})
    self.m_oTestCtrl:Load(mData.testctrl)
    self.m_oZhenmoCtrl:Load(mData.zhenmo or {})
    self:SetData("war_command",mData.warcommand or {{},{}})
end

function CPlayerBaseCtrl:Save()
    local mData = {}

    mData.grade = self:GetData("grade")
    mData.sex = self:GetData("sex")
    mData.role_type = self:GetData("role_type")
    mData.point = self:GetData("point")
    mData.critical_multiple = self:GetData("critical_multiple")
    mData.phy_critical_ratio = self:GetData("phy_critical_ratio")
    mData.res_phy_critical_ratio = self:GetData("res_phy_critical_ratio")
    mData.mag_critical_ratio = self:GetData("mag_critical_ratio")
    mData.res_mag_critical_ratio = self:GetData("res_mag_critical_ratio")
    mData.seal_ratio = self:GetData("seal_ratio")
    mData.res_seal_ratio = self:GetData("res_seal_ratio")
--    mData.hit_ratio = self:GetData("hit_ratio")
--    mData.hit_res_ratio = self:GetData("hit_res_ratio")
    mData.phy_hit_ratio = self:GetData("phy_hit_ratio")
    mData.phy_hit_res_ratio = self:GetData("phy_hit_res_ratio")
    mData.mag_hit_ratio = self:GetData("mag_hit_ratio")
    mData.mag_hit_res_ratio = self:GetData("mag_hit_res_ratio")
    mData.physique = self:GetData("physique")
    mData.strength = self:GetData("strength")
    mData.magic = self:GetData("magic")
    mData.endurance = self:GetData("endurance")
    mData.agility = self:GetData("agility")
    mData.model_info = self:GetData("model_info")
    mData.school = self:GetData("school")
    mData.point_plan = self:GetData("point_plan")
    mData.selected_point_plan = self:GetData("selected_point_plan")
    mData.init_newrole = self:GetData("init_newrole")
    mData.agree = self:GetData("agree")
    mData.position = self:GetData("position")
    mData.position_hide = self:GetData("position_hide")
    mData.rename = self:GetData("rename")
    mData.double_point = self:GetData("double_point")
    mData.other_info = self:GetData("other_info")
    mData.fmt_data = self.m_oFmtMgr:Save()
    mData.bianshen = self.m_oBianShenMgr:Save()
    mData.fuben = self.m_oFubenMgr:Save()
    mData.sys_config = self.m_oSysConfigMgr:Save()
    mData.gamepush = self.m_oGamePushMgr:Save()
    mData.warcommand = self:GetData("war_command")
    mData.waiguan = self.m_oWaiGuan:Save()
    mData.growinfo = self.m_oGrow:Save()
    mData.testctrl = self.m_oTestCtrl:Save()
    mData.zhenmo = self.m_oZhenmoCtrl:Save()
    return mData
end

function CPlayerBaseCtrl:IsDirty()
    if super(CPlayerBaseCtrl).IsDirty(self) then
        return true
    end
    if self.m_oFmtMgr:IsDirty() then
        return true
    end
    if self.m_oFubenMgr:IsDirty() then
        return true
    end
    if self.m_oBianShenMgr:IsDirty() then
        return true
    end
    if self.m_oSysConfigMgr:IsDirty() then
        return true
    end
    if self.m_oWaiGuan:IsDirty() then
        return true
    end
    if self.m_oGrow:IsDirty() then
        return true
    end
    if self.m_oTestCtrl:IsDirty() then
        return true
    end
    if self.m_oZhenmoCtrl:IsDirty() then
        return true
    end
    return false
end

function CPlayerBaseCtrl:NewHour(mNow)
    self.m_oWaiGuan:NewHour(mNow)
end

function CPlayerBaseCtrl:NewHour5(mNow)
    self.m_oFubenMgr:NewHour5(mNow)
    self.m_oZhenmoCtrl:NewHour5(mNow)
end

function CPlayerBaseCtrl:UnDirty()
    super(CPlayerBaseCtrl).UnDirty(self)
    self.m_oFmtMgr:UnDirty()
    self.m_oFubenMgr:UnDirty()
    self.m_oBianShenMgr:UnDirty()
    self.m_oSysConfigMgr:UnDirty()
    self.m_oWaiGuan:UnDirty()
    self.m_oGrow:UnDirty()
    self.m_oTestCtrl:UnDirty()
    self.m_oZhenmoCtrl:UnDirty()
end

function CPlayerBaseCtrl:PreLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:SynclSumData(oPlayer)
    end
end

function CPlayerBaseCtrl:OnLogin(oPlayer, bReEnter)
    self.m_oSysConfigMgr:OnLogin(oPlayer, bReEnter)
    self.m_oGamePushMgr:OnLogin(oPlayer, bReEnter)
    self.m_oBianShenMgr:OnLogin(oPlayer, bReEnter)
    self:GS2CPointPlanInfoList()
    self:GS2CWarCommand()
    self.m_oTestCtrl:OnLogin(oPlayer, bReEnter)
    self.m_oGrow:OnLogin(oPlayer,bReEnter)
    self.m_oFubenMgr:OnLogin(oPlayer, bReEnter)
    self.m_oZhenmoCtrl:OnLogin(oPlayer, bReEnter)
    self.m_oWaiGuan:OnLogin(oPlayer, bReEnter)
end

function CPlayerBaseCtrl:GetRoleType()
    return self:GetData("role_type")
end

function CPlayerBaseCtrl:ChangeShape(iShape)
    local m = self:GetData("model_info")
    m.shape = iShape
    self:SetData("model_info", m)

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    oPlayer:PropChange("model_info")
end

function CPlayerBaseCtrl:WashPoint(sProp, iFlag)
    local iPlan = self:GetData("selected_point_plan")
    local lPointPlan = self:GetData("point_plan")
    if not next(lPointPlan) then
        return
    end
    local mPlan = lPointPlan[iPlan]
    local iPid = self:GetInfo("pid")
    if mPlan then
        local oNotifyMgr = global.oNotifyMgr
        local iCanWashPoint = mPlan[sProp]
        if iCanWashPoint > 0 then
            local oWorldMgr = global.oWorldMgr
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
            local iItemId = 10004
            local iHaveAmount = oPlayer:GetItemAmount(iItemId)
            local sReason
            local mLogCost = {}
            if iFlag and iFlag > 0 then
                sReason = string.format("fast_wash_point_%s",sProp)
                local mNeedCost = {}
                mNeedCost["item"] = {}
                mNeedCost["item"][iItemId] = 1
                local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
                if not bSucc then return end
                if mTrueCost["goldcoin"] then
                    mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
                end
                for iSid, iUseAmount in pairs(mTrueCost["item"]) do
                    mLogCost[iSid] = iUseAmount
                end
            else
                if iHaveAmount <= 0 then
                    oNotifyMgr:Notify(iPid, "洗点丹不足！")
                    return
                else
                    sReason = string.format("wash_point_%s", sProp)
                    oPlayer:RemoveItemAmount(iItemId, 1, sReason)
                    mLogCost[iItemId] = 1
                end
            end
            local mLogData = oPlayer:LogData()
            mLogData["point_old"] = mPlan["remain_point"] or 0

            local iSubPoint = math.min(iCanWashPoint, 2)
            mPlan[sProp] = iCanWashPoint - iSubPoint
            mPlan["remain_point"] = mPlan["remain_point"] + iSubPoint
            oPlayer:SubPrimaryProp({[sProp] = iSubPoint})
            local mNet = {}
            mNet["remain_wash_point"] = mPlan[sProp]
            mNet["prop_name"] = sProp
            mNet["remain_point"] = mPlan["remain_point"]
            oPlayer:Send("GS2CWashPoint", mNet)
            oPlayer:PropChange(sProp)
            oPlayer:SecondLevelPropChange()

            mLogData["prop"] = {sProp}
            mLogData["point_wash"] = iSubPoint
            mLogData["point_now"] = mPlan["remain_point"]
            mLogData["point_all"] = mPlan[sProp]
            record.log_db("player", "wash_point", mLogData)

            analylog.LogSystemInfo(oPlayer, "player_wash_point", nil, mLogCost)
        else
            oNotifyMgr:Notify(iPid, "可洗点不足！")
        end
    end
end

function CPlayerBaseCtrl:WashAllPoint()
    local iPlan = self:GetData("selected_point_plan")
    local lPointPlan = self:GetData("point_plan")
    if not next(lPointPlan) then
        return
    end
    local mPlan = lPointPlan[iPlan]
    if mPlan then
        local iPid = self:GetInfo("pid")
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        local iItemId = 10005
        local iHaveAmount = oPlayer:GetItemAmount(iItemId)
        if iHaveAmount > 0 then
            local mLogData = oPlayer:LogData()
            mLogData["point_old"] = mPlan["remain_point"] or 0

            oPlayer:RemoveItemAmount(iItemId, 1, "wash_all_point")
            oPlayer:SubPrimaryProp(mPlan)
            local iSumWashPoint = 0
            for _, sProp in pairs(lPropName) do
                iSumWashPoint = iSumWashPoint + mPlan[sProp]
                mPlan[sProp] = 0
            end
            mPlan["remain_point"] = mPlan["remain_point"] + iSumWashPoint
            local mNet = {}
            mNet["wash_info"] = mPlan
            oPlayer:Send("GS2CPointPlanInfo", mNet)
            oPlayer:PropChange(table.unpack(lPropName))
            self:SetData("point_plan", lPointPlan)
            oPlayer:SecondLevelPropChange()
            
            mLogData["point_now"] = mPlan["remain_point"]
            mLogData["point_all"] = 0
            mLogData["point_wash"] = iSumWashPoint
            mLogData["prop"] = lPropName
            record.log_db("player", "wash_point", mLogData)
            
            analylog.LogSystemInfo(oPlayer, "player_all_wash", nil, {[iItemId]=1})
        else
            local oNotifyMgr = global.oNotifyMgr
            oNotifyMgr:Notify(iPid, "人参果不足！")
        end
    end
end

function CPlayerBaseCtrl:StartPlanPoint(iNewPlan)
    local iOldPlan = self:GetData("selected_point_plan")
    if iNewPlan and iNewPlan == iOldPlan then
        return
    end
    local lPointPlan = self:GetData("point_plan")
    if not next(lPointPlan) then return end
    local mNewPlan, mOldPlan = lPointPlan[iNewPlan], lPointPlan[iOldPlan]
    if mNewPlan and mOldPlan then
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        oPlayer:SubPrimaryProp(mOldPlan)
        oPlayer:AddPrimaryProp(mNewPlan)
        self:SetData("selected_point_plan", iNewPlan)
        local mPlan = table_deep_copy(mNewPlan)
        local mNet = {}
        mNet["wash_info"] = mPlan
        oPlayer:Send("GS2CPointPlanInfo", mNet)
        oPlayer:PropChange(table.unpack(lPropName))
        oPlayer:SecondLevelPropChange()

        local mLogData = oPlayer:LogData()
        mLogData["old_plan"] = iOldPlan
        mLogData["new_plan"] = iNewPlan
        record.log_db("player", "change_plan", mLogData)
    end
end

function CPlayerBaseCtrl:AddPlanPoint(mData)
    local oNotifyMgr = global.oNotifyMgr
    local iPlan = mData["plan_id"]
    local iSelected = self:GetData("selected_point_plan")
    if iPlan and iSelected and iPlan == iSelected then
        local lPointPlan = self:GetData("point_plan")
        if not next(lPointPlan) then
            return
        end
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        local mPlan = lPointPlan[iSelected]
        local iAddSum =0
        local mLogData = oPlayer:LogData()
        mLogData["old_data"] = mPlan
        for _, name in pairs(lPropName) do
            local iProp = mData[name] or 0
            if iProp > 0 then
                iAddSum = iAddSum + iProp
            end
        end
        local iRemain = mPlan["remain_point"] - iAddSum
        if iRemain >= 0 then
            mPlan["remain_point"] = iRemain
            oPlayer:AddPrimaryProp(mData)
            for _, name in pairs(lPropName) do
                local iProp = mData[name] or 0
                if iProp > 0 then
                    mPlan[name] = mPlan[name] + iProp
                end
            end
            local mNet = {}
            mNet["wash_info"] = mPlan
            oPlayer:Send("GS2CPointPlanInfo", mNet)
            oPlayer:PropChange(table.unpack(lPropName))
            self:SetData("point_plan", lPointPlan)
            oPlayer:SecondLevelPropChange()

            mLogData["plan"] = iPlan
            mLogData["new_data"] = mPlan
            record.log_db("player", "add_point", mLogData)
        else
            oNotifyMgr:Notify(self:GetInfo("pid"), "潜力点不足！")
        end
    else
        oNotifyMgr:Notify(self:GetInfo("pid"), "只可加点已选方案！")
    end
end

function CPlayerBaseCtrl:AddPoint(iPoint)
    if iPoint > 0 then
        self:SetData("point", self:GetData("point") + iPoint)
        local lPointPlan = self:GetData("point_plan")
        for iPlan, mPlan in pairs(lPointPlan) do
            mPlan["remain_point"] = mPlan["remain_point"] + iPoint
        end
        if next(lPointPlan) then
            self:Dirty()
        end
    end
end

function CPlayerBaseCtrl:GS2CPointPlanInfoList()
    local lPointPlan = self:GetData("point_plan")
    assert(type(lPointPlan) == "table", string.format("pid:%d, need table, but is :%s", self:GetInfo("pid"), lPointPlan))
    if next(lPointPlan) then
        local mNet = {}
        mNet["wash_info_list"] = lPointPlan
        mNet["selected_plan"] = self:GetData("selected_point_plan")
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        oPlayer:Send("GS2CLoginPointPlanInfoList", mNet)
    end
end

function CPlayerBaseCtrl:OnUpGrade(iFromGrade, iGrade)
    self:CheckPointPlan(iFromGrade, iGrade)
end

function CPlayerBaseCtrl:CheckPointPlanOpen()
    local iGrade = self:GetData("grade")
    self:CheckPointPlan(iGrade, iGrade)
end

function CPlayerBaseCtrl:CheckPointPlan(iFromGrade, iGrade)
    local mWashPoint = res["daobiao"]["washpoint"]
    local lPlanID = table_key_list(mWashPoint)
    table.sort(lPlanID)
    for _, iPlan in ipairs(lPlanID) do
        if iGrade >= mWashPoint[iPlan] .unlock_lev then
            self:UpdatePointPlan(iPlan, iFromGrade, iGrade)
        end
    end
    if iGrade >= mWashPoint[lPlanID[1]].unlock_lev  then
        self:GS2CPointPlanInfoList()
    end
end

function CPlayerBaseCtrl:UpdatePointPlan(iPlan, iFromGrade, iGrade)
    local iDiffGrade = iGrade - iFromGrade
    local lPointPlan = self:GetData("point_plan")
    local mSchool = res["daobiao"]["school"]
    local m = mSchool[self:GetData("school")]
    local mWashPoint = m.washpoints
    local mPlan = lPointPlan[iPlan]
    if mPlan and iDiffGrade > 0 then
        mPlan["agility"] =  mPlan["agility"] + mWashPoint["agility"] * iDiffGrade
        mPlan["strength"] = mPlan["strength"] + mWashPoint["strength"] * iDiffGrade
        mPlan["magic"] = mPlan["magic"] + mWashPoint["magic"]  * iDiffGrade
        mPlan["endurance"] = mPlan["endurance"] + mWashPoint["endurance"] * iDiffGrade
        mPlan["physique"] = mPlan["physique"] + mWashPoint["physique"] * iDiffGrade
    else
        lPointPlan[iPlan] = {}
        mPlan = lPointPlan[iPlan]
        local iGrade = self:GetData("grade")
        mPlan["agility"]  = mWashPoint["agility"] * iGrade
        mPlan["strength"] = mWashPoint["strength"] * iGrade
        mPlan["magic"] = mWashPoint["magic"] * iGrade
        mPlan["endurance"] = mWashPoint["endurance"] * iGrade
        mPlan["physique"] = mWashPoint["physique"] * iGrade
        mPlan["remain_point"] = self:GetData("point")
        mPlan["plan_id"] = iPlan
    end
    self:SetData("point_plan", lPointPlan)
end

function CPlayerBaseCtrl:InitDoublePoint()
    local mPointInfo = {}
    mPointInfo["day"] = get_morningdayno()
    mPointInfo["point"] = 0
    mPointInfo["point_limit"] = 60
    self:SetData("double_point", mPointInfo)
end

function CPlayerBaseCtrl:RefreshDoublePointByDay()
    local mPointInfo = self:GetData("double_point",nil)
    if mPointInfo then
        local iCurrDay = get_morningdayno()
        local iDayNo = mPointInfo["day"]
        local iDelta = iCurrDay - iDayNo

        if iDelta > 0 then
            self:AddDoublePointLimit(iDelta * 60)
            mPointInfo["day"] = iCurrDay
        end
        self:SetData("double_point",mPointInfo)
    end
end

function CPlayerBaseCtrl:RefreshDoublePoint()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end

    local iPoint, iPointLimit = self:GetDoublePoint()
    local mNet = {}
    mNet["db_point"] = iPoint
    mNet["db_point_limit"] = iPointLimit
    oPlayer:Send("GS2CRefreshDoublePoint", mNet)

    local oState = oPlayer.m_oStateCtrl:GetState(1004)
    if oState then
        oState:Refresh(self:GetInfo("pid"))
    end
end

function CPlayerBaseCtrl:AddDoublePoint(iAdd)
    local mPointInfo = self:GetData("double_point")
    local iPoint = max(0, mPointInfo["point"] + iAdd)
    if iPoint > 120 then
        local iRemain = iPoint - 120
        self:AddDoublePointLimit(iRemain)
        mPointInfo["point"] = 120
    else
        mPointInfo["point"] = iPoint
    end
    self:SetData("double_point",mPointInfo)
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local mLogData = oPlayer:LogData()
    mLogData["double_point"] = mPointInfo["point"]
    mLogData["double_point_add"] = iAdd
    record.log_db("player", "double_point", mLogData)
end

function CPlayerBaseCtrl:AddDoublePointLimit(iAdd)
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    local mPointInfo = self:GetData("double_point")
    if not mPointInfo then
        self:InitDoublePoint()
    end

    mPointInfo = self:GetData("double_point")
    local iPointLimit = max(0, mPointInfo["point_limit"] + iAdd)
    if iPointLimit > 840 then
        mPointInfo["point_limit"] = 840
    else
        mPointInfo["point_limit"] = iPointLimit
    end
    self:SetData("double_point",mPointInfo)
    local mLogData = oPlayer:LogData()
    mLogData["double_point_limit_add"] = iAdd
    mLogData["double_point_limit"] = mPointInfo["point_limit"]
    record.log_db("player", "double_point_limit", mLogData)
end

function CPlayerBaseCtrl:GetDoublePoint()
    local mPointInfo = self:GetData("double_point")
    if not mPointInfo then
        self:InitDoublePoint()
    end
    self:RefreshDoublePointByDay()
    mPointInfo = self:GetData("double_point")
    return mPointInfo["point"], mPointInfo["point_limit"]
end

function CPlayerBaseCtrl:RewardDoublePoint()
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local iPoint, iPointLimit = self:GetDoublePoint()
    if iPointLimit <= 0 then
        oNotifyMgr:Notify(self:GetInfo("pid"), "当前无双倍点数可领取")
        return
    end

    if iPoint >= 120 then
        local oToolMgr = global.oToolMgr
        local sMsg = oToolMgr:GetTextData(1001, {"task_ext"})
        oNotifyMgr:Notify(self:GetInfo("pid"), sMsg)
        return
    end

    local iAddPoint = max(0, min(min(60, 120-iPoint), iPointLimit))
    if iAddPoint <= 0 then
        oNotifyMgr:Notify(self:GetInfo("pid"), "当前无双倍点数可领取")
        return
    end

    self:AddDoublePointLimit(-iAddPoint)
    self:AddDoublePoint(iAddPoint)
    self:RefreshDoublePoint()

    local sMsg = string.format("成功领取#G%d#n点双倍点数", iAddPoint)
    oNotifyMgr:Notify(self:GetInfo("pid"), sMsg)
end

function CPlayerBaseCtrl:GS2CWarCommand()
    local extend = require "base.extend"
    local oWorldMgr = global.oWorldMgr
    local mNet={}
    local mWarCommand = self:GetData("war_command",{})
    for iType,mInfo in pairs(mWarCommand) do
        table.insert(mNet,{type = tonumber(iType),cmds = mInfo})
    end
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    oPlayer:Send("GS2CRefreshWarCmd", {warcmds=mNet})
end

function CPlayerBaseCtrl:PackBackendInfo()
    local mRet = {}
    mRet["grade"] = self:GetData("grade")
    mRet["school"] = self:GetData("school")
    mRet["other_info"] = self:GetData("other_info")
    return mRet
end

function CPlayerBaseCtrl:SetData(sAttr, value)
    super(CPlayerBaseCtrl).SetData(self,sAttr,value)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_BASE,sAttr,value)
    end
end

function CPlayerBaseCtrl:SynclSumData(oPlayer)
    for sAttr,value in pairs(self.m_mData) do
        oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_BASE,sAttr,value)
    end
end
