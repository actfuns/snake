--import module

local global = require "global"
local record = require "public.record"
local skillobj = import(service_path("skill/skillobj"))

function NewSkill(iSk)
    local o = CFuZhuanSkill:New(iSk)
    return o
end

CFuZhuanSkill = {}
CFuZhuanSkill.__index = CFuZhuanSkill
CFuZhuanSkill.m_sType = "fuzhuan"
inherit(CFuZhuanSkill,skillobj.CSkill)

function CFuZhuanSkill:New(iSk)
    local o = super(CFuZhuanSkill).New(self,iSk)
    return o
end

function CFuZhuanSkill:LearnCost()
    local sFormula = self:GetSkillData()["learnpoint"]
    local iPoint = formula_string(sFormula,{lv=self:Level()})
    iPoint = math.floor(iPoint)
    return iPoint
end

function CFuZhuanSkill:ProductItem()
    local itemsid = self:GetSkillData()["shape"]
    return itemsid
end

function CFuZhuanSkill:GetApplyAttr()
    local sAttr = self:GetSkillData()["attr"]
    return sAttr
end

function CFuZhuanSkill:GetApplyAttrValue()
    local sFormula = self:GetSkillData()["attr_value"]
    local iAttrValue = formula_string(sFormula,{lv=self:Level()})
    iAttrValue = math.floor(iAttrValue)
    return iAttrValue
end

function CFuZhuanSkill:ResetCost()
    local sFormula = self:GetSkillData()["reset"]
    local iResetCost = formula_string(sFormula,{lv=self:Level()})
    iResetCost = math.floor(iResetCost)
    return iResetCost
end

function CFuZhuanSkill:ResetStoryPoint()
    local sFormula = self:GetSkillData()["learnpoint"]
    local iLevel = self:Level()-1
    iLevel = math.max(0,iLevel)
    local iPoint = formula_string(sFormula,{lv=iLevel})
    iPoint = math.floor(iPoint)
    return iPoint
end

function CFuZhuanSkill:ProductCost()
    local sFormula = self:GetSkillData()["huoli"]
    local iHuoli = formula_string(sFormula,{lv=self:Level()})
    iHuoli = math.floor(iHuoli)
    return iHuoli
end

function CFuZhuanSkill:LimitLevel(oPlayer)
    local sTopLimit = self:GetSkillData()["limit_level"]
    local iLevel = tonumber(sTopLimit)
    if iLevel then
        return iLevel
    end
    local mEnv = {
        grade = oPlayer:GetGrade(),
    }
    local iLevel = formula_string(sTopLimit,mEnv)
    return math.floor(iLevel)
end

function CFuZhuanSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    return mNet
end

function CFuZhuanSkill:ValidLearn(oPlayer)
    local pid = oPlayer:GetPid()
    local iLimitGrade = self:LimitLevel(oPlayer)
    local iLevel = self:Level()
    local oNotifyMgr = global.oNotifyMgr
    if iLevel>=iLimitGrade then
        local sText = self:GetText(1001,{skill = self:Name()})
        oNotifyMgr:Notify(pid,sText)
        return false
    end
    local iStoryPoint = self:LearnCost()
    assert(iStoryPoint>0,string.format("fuzhuan learn storypoint %s",iStoryPoint))
    if not oPlayer.m_oActiveCtrl:ValidStoryPoint(iStoryPoint) then
        -- local sText = self:GetText(1002)
        -- oNotifyMgr:Notify(pid,sText)
        return false
    end
    local iLimitGrade = self:LimitLevel(oPlayer)
    if iLevel>= iLimitGrade then
        local sText = self:GetText(1003,{grade = oPlayer:GetGrade(),amount=iLimitGrade})
        oNotifyMgr:Notify(pid,sText)
    end 
    return true
end

function CFuZhuanSkill:Learn(oPlayer)
    if not self:ValidLearn(oPlayer) then
        return
    end
    local mLogData = oPlayer:LogData()
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local iLevel = self:Level()
    local iAddLevel = 1
    local iStoryPoint = self:LearnCost()
    local sReason = "剧情技能学习"
    oPlayer.m_oActiveCtrl:ResumeStoryPoint(iStoryPoint, sReason) 
    iLevel = iLevel +iAddLevel
    mLogData.add_level = iAddLevel
    mLogData.cur_level = iLevel
    mLogData.storypoint = iStoryPoint
    mLogData.skill = self:Name()
    record.log_db("playerskill", "fuzhuan_skill_add", mLogData)
    self:SetLevel(iLevel)
    self:Refresh(oPlayer)
    local sText = self:GetText(1004,{skill = self:Name(),amount=iLevel})
    oNotifyMgr:Notify(pid,sText)
end

function CFuZhuanSkill:ValidReset(oPlayer)
    local pid = oPlayer:GetPid()
    local iLevel = self:Level()
    local oNotifyMgr = global.oNotifyMgr
    if iLevel <=0 then
        local sText = self:GetText(1009,{skill=self:Name()})
        oNotifyMgr:Notify(pid,sText)
        return false 
    end
    local iCost = self:ResetCost()
    assert(iCost>0,string.format("fuzhuan reset silver %s",iCost))
    if not oPlayer:ValidSilver(iCost) then
        return false
    end
    return true
end

function CFuZhuanSkill:Reset(oPlayer)
    if not self:ValidReset(oPlayer) then
        return
    end
    local pid = oPlayer:GetPid()
    local iCost = self:ResetCost()
    local sReason = "剧情技能重置"
    oPlayer:ResumeSilver(iCost,sReason)
    local iStoryPoint = self:ResetStoryPoint()
    local iSubLevel = 1
    local iLevel = self:Level()
    iLevel = iLevel - iSubLevel

    local mLogData = oPlayer:LogData()
    mLogData.sub_level = iSubLevel
    mLogData.cur_level = iLevel
    mLogData.storypoint = iStoryPoint
    mLogData.skill = self:Name()
    record.log_db("playerskill", "fuzhuan_skill_reset", mLogData)

    oPlayer.m_oActiveCtrl:RewardStoryPoint(iStoryPoint,sReason) 
    self:SetLevel(iLevel)
    self:Refresh(oPlayer)
    global.oNotifyMgr:Notify(pid,self:GetText(1011,{skill=self:Name(),amount = self:Level()}))
end

function CFuZhuanSkill:ValidProduct(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<1 then
        oNotifyMgr:Notify(pid,self:GetText(1005))
        return false
    end
    local iHuoLi = self:ProductCost()
    assert(iHuoLi>0,string.format("fuzhuan product huoli %s",iHuoLi))
    if not oPlayer.m_oActiveCtrl:ValidEnergy(iHuoLi,{cancel_tip=true}) then
        oNotifyMgr:Notify(pid,self:GetText(1006))
        return false
    end
    return true
end

function CFuZhuanSkill:Product(oPlayer)
    if not self:ValidProduct(oPlayer) then
        return
    end
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local iHuoLi = self:ProductCost()
    local sShape = self:ProductItem()
    local iAmount = 1
    local sReason = "fuzhuan_product"
    local oItem = global.oItemLoader:ExtCreate(sShape,{skill_level=self:Level()})
    oPlayer.m_oActiveCtrl:ResumeEnergy(iHuoLi,sReason)
    oItem:SetAmount(iAmount)
    oPlayer:RewardItem(oItem,sReason)
    local sText = self:GetText(1007,{item=oItem:Name()})
    oNotifyMgr:Notify(pid,sText)
end

function CFuZhuanSkill:GetText(iText,mReplace)
    mReplace = mReplace or {}
    local sText =  global.oToolMgr:GetTextData(iText,{"skill"})
    sText = global.oToolMgr:FormatColorString(sText,mReplace)
    return sText
end

function CFuZhuanSkill:Refresh(oPlayer)
    local mNet = {}
    mNet.sk = self:ID()
    mNet.level = self:Level()
    oPlayer:Send("GS2CRefreshFuZhuanSkill",mNet)
end