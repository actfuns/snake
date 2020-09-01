--import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local touxianobj = import(service_path("touxian.touxianobj"))
local analylog = import(lualib_path("public.analylog"))

CTouxianCtrl = {}
CTouxianCtrl.__index = CTouxianCtrl
inherit(CTouxianCtrl, datactrl.CDataCtrl)

local DEFAULT_LEVEL = 0

function CTouxianCtrl:New(iPid)
    local o = super(CTouxianCtrl).New(self,{pid = iPid})
    o.m_iLevel = DEFAULT_LEVEL
    o.m_oTouxian = nil
    return o
end

function CTouxianCtrl:Release()
    if self.m_oTouxian then
        baseobj_safe_release(self.m_oTouxian)
    end
    super(CTouxianCtrl).Release(self)
end

function CTouxianCtrl:GetPid()
    return self:GetInfo("pid")
end

function CTouxianCtrl:GetTouxianID()
    if self.m_oTouxian then
        return self.m_oTouxian:GetTouxianID()
    end
    return 0
end

function CTouxianCtrl:PreLogin(oPlayer, bReEnter)
    if not bReEnter then
        local iSchool = oPlayer:GetSchool()
        local iMaxLevel  = self:GetTouxianMaxLevel(iSchool)
        if not self.m_oTouxian and self.m_iLevel > DEFAULT_LEVEL and self.m_iLevel < (1+ iMaxLevel) and self:IsValidSchool(iSchool) then
            if global.oToolMgr:IsSysOpen("BADGE",oPlayer,true) then
                self.m_oTouxian = self:_CreateTouxian(self.m_iLevel,oPlayer:GetSchool())
                global.oScoreCache:Dirty(oPlayer:GetPid(), "touxian")
            end
        end
        self:SynclSumData(oPlayer)
    end
end

function CTouxianCtrl:OnLogin(oPlayer, bReEnter)
    local LIMIT_GRADE = res["daobiao"]["open"]["BADGE"]["p_level"]
    if LIMIT_GRADE <=oPlayer:GetGrade() then
        self:GS2CUpgradeTouxianInfo(oPlayer)
    end
    if self.m_oTouxian then
        local iTouxianID = self.m_oTouxian:GetTouxianID()
        oPlayer:SyncSceneInfo({touxian_tag=iTouxianID})
    else
        oPlayer:SyncSceneInfo({touxian_tag=0})
    end
end

function CTouxianCtrl:Save()
    local mData = {}
    mData["level"] = self.m_iLevel
    return mData
end

function CTouxianCtrl:Load(mData)
    if not mData then return end
    self.m_iLevel = mData["level"] or DEFAULT_LEVEL
end

function CTouxianCtrl:OnUpGrade(oPlayer)
    if not global.oToolMgr:IsSysOpen("BADGE",oPlayer,true) then
        return
    end
    local LIMIT_GRADE = res["daobiao"]["open"]["BADGE"]["p_level"]
    if LIMIT_GRADE <=oPlayer:GetGrade() and self.m_iLevel == DEFAULT_LEVEL  and not self.m_oTouxian then
        self:Dirty()
        self.m_iLevel = 1
        self.m_oTouxian = self:_CreateTouxian(self.m_iLevel,oPlayer:GetSchool())
        global.oScoreCache:Dirty(oPlayer:GetPid(), "touxian")
        self:GS2CUpgradeTouxianInfo(oPlayer)
        oPlayer:SyncSceneInfo({touxian_tag=self.m_oTouxian:GetTouxianID()})
        self:SynclSumData(oPlayer)
        analylog.LogSystemInfo(oPlayer, "upgrade_touxian", self.m_iLevel, {})
    end
end

function CTouxianCtrl:CheckUpGrade()
    local LIMIT_GRADE = res["daobiao"]["open"]["BADGE"]["p_level"]
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())

    if oPlayer:GetSchool() <=0 then
        oNotifyMgr:Notify(self:GetPid(),"你还没有职业")
        return
    end  

    local iNextLevel = self.m_iLevel + 1
    if iNextLevel > self:GetTouxianMaxLevel(oPlayer:GetSchool()) then 
        oNotifyMgr:Notify(self:GetPid(),"您的头衔已经到顶级了")
        return 
    end
    if LIMIT_GRADE > oPlayer:GetGrade() then 
        local sMsg = string.format("角色等级%s可以提升",LIMIT_GRADE)
        oNotifyMgr:Notify(self:GetPid(),sMsg)
        return 
    end

    local oNextTouxian  = self:_CreateTouxian(iNextLevel,oPlayer:GetSchool())
    if oNextTouxian then
        if oNextTouxian:GetScore() > oPlayer:GetScore() then
            oNotifyMgr:Notify(self:GetPid(),"人物评分不足，请先提升人物评分")
            return
        end
        
        local mCost = oNextTouxian:GetCost()
        local sid, iCostAmount = mCost.itemid,  mCost.amount
        local iHaveAmount = oPlayer.m_oItemCtrl:GetItemAmount(sid)
        if iHaveAmount < iCostAmount then
            local oItem = global.oItemLoader:Create(sid)
            oNotifyMgr:Notify(self:GetPid(),string.format("%s不足",oItem:TipsName()))
            return
        end

        if oPlayer:GetGrade() < oNextTouxian:GetLevel() then
            local sMsg = string.format("角色等级#G%s#n可以提升",oNextTouxian:GetLevel())
            oNotifyMgr:Notify(self:GetPid(),sMsg)
            return
        end

        if false == oPlayer:RemoveItemAmount(sid,iCostAmount, "头衔升级") then
            return
        end
        self:Dirty()
        self.m_iLevel = iNextLevel
        local oPreTouXian = self.m_oTouxian
        baseobj_delay_release(oPreTouXian)
        self.m_oTouxian = self:_CreateTouxian(self.m_iLevel,oPlayer:GetSchool())
        global.oScoreCache:Dirty(oPlayer:GetPid(), "touxian")
        oPlayer:SyncSceneInfo({touxian_tag=self.m_oTouxian:GetTouxianID()})
        oNotifyMgr:Notify(self:GetPid(),string.format("恭喜头衔升级到#G%s#n级",self.m_iLevel))
        self:GS2CUpgradeTouxianInfo(oPlayer)
        oPlayer:SecondLevelPropChange()
        oPlayer:SyncTosOrg({touxian=self.m_oTouxian:GetTouxianID()})
        oPlayer:MarkGrow(29)
        self:SynclSumData(oPlayer)
        local oHD = global.oHuodongMgr:GetHuodong("kaifudianli")
        oHD:TouxianUpGrade(oPlayer,self.m_iLevel)
        self:TriggerEvent(gamedefines.EVENT.PLAYER_TOUXIAN_UPGRADE, {level = self.m_iLevel})

        analylog.LogSystemInfo(oPlayer, "upgrade_touxian", self.m_iLevel, {[sid]=iCostAmount})
    end
end

function CTouxianCtrl:GS2CUpgradeTouxianInfo(oPlayer)
    if self.m_oTouxian then
        oPlayer:Send("GS2CUpgradeTouxianInfo", {infos = self.m_oTouxian:PackNetInfo()})
    else
        oPlayer:Send("GS2CUpgradeTouxianInfo", {infos = {tid = 0}})
    end
end

function CTouxianCtrl:_CreateTouxian(iLevel,iSchool)
    local oTouxian = touxianobj.NewTouxian(iLevel, self:GetPid(),iSchool)
    return oTouxian
end

function CTouxianCtrl:GetTouxianMaxLevel(iSchool)
    local mData = res["daobiao"]["touxian"]["touxian"]
    local iMaxLevel = 0
    for tid, mInfo in pairs(mData) do
        if iMaxLevel <= mInfo.level  and mInfo.school == iSchool then
            iMaxLevel = mInfo.level 
        end
    end
    return iMaxLevel
end

function CTouxianCtrl:IsValidSchool(iSchool)
    if iSchool ==0 then
        return false
    end
    local mData = res["daobiao"]["touxian"]["touxian"]
    for tid, mInfo in pairs(mData) do
        if mInfo.school == iSchool then
            return true
        end
    end
    return false
end

function CTouxianCtrl:GetScore()
    if self.m_oTouxian then
        return self.m_oTouxian:GetPower()
    end
    return 0
end

function CTouxianCtrl:GetCultivateLevel(iSkill)
    local iLevel = 0
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then
        return iLevel
    end
    if not global.oToolMgr:IsSysOpen("BADGE",oPlayer,true) then
        return iLevel
    end
    if self.m_oTouxian then
        iLevel = self.m_oTouxian:GetCultivateLevel(iSkill)
    end
    return iLevel
end

function CTouxianCtrl:GetApply(sAttr)
    local iValue = 0
    if self.m_oTouxian then
        iValue =  self.m_oTouxian:GetApplyAttr(sAttr)
    end
    return iValue
end

function CTouxianCtrl:GetAllApplys()
    if self.m_oTouxian then
        return self.m_oTouxian:GetAllApplys()
    else
        return {}
    end
end

function CTouxianCtrl:SynclSumData(oPlayer)
    oPlayer:ClearlSum(gamedefines.SUM_DEFINE.MO_TOUXIAN)
    for sAttr, iVal in pairs(self:GetAllApplys()) do
        oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_TOUXIAN, sAttr, iVal)
    end
end
