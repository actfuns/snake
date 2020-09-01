-- import module
--人物修炼丹

local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

local DAYUSELIMIT = 10
-- 服务器等级 与玩家等级之差  小于此变量限制时 玩家每日使用数目受限
local GRADESUBLIMIT = 10
CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who,target)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local pid = who:GetPid()
    local iGrade = who:GetGrade()
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("XIU_LIAN_SYS")
    if iGrade < iOpenGrade then
        local sMsg = oToolMgr:FormatColorString("人物达到#G#open#n级开启#G修炼技能#n后才可使用",{open = iOpenGrade})
        oNotifyMgr:Notify(pid, sMsg)
        return
    end
    local oSk = who.m_oSkillCtrl:GetSkill(target)
    if not oSk then
        -- oSk = who.m_oSkillCtrl:GetRoleCultivateSkill()
        oNotifyMgr:Notify(pid, string.format("找不到对应的技能"))
        return
    end
    assert(oSk, string.format("cultivate select skill not exist! item sid:%d", self.m_SID))
    if oSk:IsMaxLevel(who) then
        local sContent = string.format("您当前设置的#R%s#n已达上限，无法使用", oSk:Name())
        self:ConfirmCultivateSkillUI(who, sContent)
    else
        local sName = self:Name()
        local iTodayUsed = who.m_oToday:Query(sName, 0)
        if self:GradeSubLimit(who) then
            if iTodayUsed >= DAYUSELIMIT then
                oNotifyMgr:Notify(pid, string.format("你今天已使用#R%d#n个#G%s#n，无法继续使用", DAYUSELIMIT, sName ))
                return
            else
                self:_Use(who)
                -- iTodayUsed = iTodayUsed + 1
                -- oNotifyMgr:Notify(pid, string.format("今天还能使用#R%d#n个#G%s#n", DAYUSELIMIT - iTodayUsed, sName ))
            end
        else
            self:_Use(who)
        end
        who.m_oToday:Add(sName, 1)
        oSk:AddExp(who, 300)
        who.m_oSkillCtrl:FireLearnCultivateSkill(oSk)
    end
    return true
end

function CItem:ConfirmCultivateSkillUI(who, sContent)
    local oCbMgr = global.oCbMgr
    local oUIMgr = global.oUIMgr
    local mData = {
        sContent = sContent,
        sConfirm = "修改类型",
        sCancle = "取消",
    }
    local mData = oCbMgr:PackConfirmData(nil, mData)
    local func = function (oPlayer,mData)
        local iAnswer = mData["answer"]
        if iAnswer == 1 then
            oUIMgr:GS2COpenCultivateUI(oPlayer)
        end
    end
    oCbMgr:SetCallBack(who:GetPid(), "GS2CConfirmUI",mData,nil,func)
end

function CItem:_Use(who)
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(who)
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
end

function CItem:GradeSubLimit(who)
    local iGrade = who:GetGrade()
    local iServerGrade = who:GetServerGrade()
    if iGrade > iServerGrade - GRADESUBLIMIT then
        return true
    else
        return false
    end
end

function CItem:DayUseLimit(who)
    if self:GradeSubLimit(who) then
        local sName = self:Name()
        local iTodayUsed = who.m_oToday:Query(sName, 0)
        return 1, math.max(DAYUSELIMIT - iTodayUsed, 0)
    else
        return 0, nil
    end
end