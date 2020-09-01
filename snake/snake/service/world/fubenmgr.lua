local global = require "global"
local res = require "base.res"

local fuben = import(service_path("fuben.fubenbase"))
local defines = import(service_path("fuben.defines"))
local extend = import(lualib_path("base.extend"))

mEnterFunc = {}
mEnterFunc[defines.CONDITION_ENTER_NOTEAM] = function(oPlayer)
    if oPlayer:HasTeam() then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), "组队状态下不能开始副本")
        return false
    end
    return true
end

mEnterFunc[defines.CONDITION_ENTER_SINGLE] = function(oPlayer)
    if not oPlayer:IsSingle() then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), "多人状态下不能开始副本")
        return false
    end
    return true
end

mEnterFunc[defines.CONDITION_ENTER_TEAM] = function(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam or (oTeam:MemberSize() + oPlayer:Query("testman", 0)) < 3 then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), "队伍人数小于3人不能开始副本")
        return false
    end
    return true
end

mEnterFunc[defines.CONDITION_ENTER_OTHER] = function(oPlayer)
    return true
end



function NewFubenMgr(...)
    return CFubenMgr:New(...)
end


CFubenMgr = {}
CFubenMgr.__index = CFubenMgr
inherit(CFubenMgr, logic_base_cls())

function CFubenMgr:New()
    local o = super(CFubenMgr).New(self)
    o.m_iFuben = 0
    o.m_mFuben = {}
    return o
end

function CFubenMgr:GenFubenId()
    self.m_iFuben = self.m_iFuben + 1
    return self.m_iFuben
end

function CFubenMgr:Release()
    for iFuben, oFuben in pairs(self.m_mFuben) do
        baseobj_safe_release(oFuben)
    end
    self.m_mFuben = {}
    super(CFubenMgr).Release(self)
end

function CFubenMgr:GetFuben(id)
    return self.m_mFuben[id]
end

function CFubenMgr:DelFuben(id)
    if not self.m_mFuben[id] then
        return
    end
    local oFuben = self.m_mFuben[id]
    self.m_mFuben[id] = nil
    oFuben:BeforeRelease()
    baseobj_safe_release(oFuben)
end

function CFubenMgr:GetFubenPath(iFuben)
    local mData = self:GetFubenConfig(iFuben)
    assert(mData, "wrong fuben id ".. iFuben)
    
    local sPath = "fuben/fubenbase"
    return sPath
end

function CFubenMgr:NewFuben(iFuben)
    local sPath = self:GetFubenPath(iFuben)
    local sModule = import(service_path(sPath))
    local id = self:GenFubenId()
    self.m_mFuben[id] = sModule.NewFuben(id, iFuben)
    return self.m_mFuben[id]
end

function CFubenMgr:TryStartFuben(oPlayer, iFuben)
    local iRet, lResult = self:OpenCondition(oPlayer, iFuben)
    if not iRet then
        return
    end
    if not self:EnterCondition(oPlayer, iFuben) then
        return
    end
    if not self:CheckEnterSure(oPlayer, iFuben, 1) then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene:ValidLeave(oPlayer) then
        return
    end
    local oOldTask = self:CheckFubenTask(oPlayer, iFuben)
    if not oOldTask then
        local oProgress = oPlayer:GetFubenMgr()
        local iStep = oProgress:GetFubenStep(iFuben)
        if iStep == 0 then 
            global.oNotifyMgr:Notify(oPlayer:GetPid(),"此副本你已经完成")
            return
        end
        local oFuben = self:NewFuben(iFuben)
        oFuben:GameStart(oPlayer, iStep)
        local oTeam = oPlayer:HasTeam()
        oTeam:SetFuben(oFuben:GetId())
    end
end

function CFubenMgr:CheckFubenTask(oPlayer, iFuben)
    local oTeam = oPlayer:HasTeam()
    local mConfig = self:GetFubenConfig(iFuben)
    for _, iGroup in pairs(mConfig.group_list) do
        local tasklist = res["daobiao"]["fuben"]["taskgroup"][iGroup]["task_list"]
        for _,iTask in ipairs(tasklist) do
            if oTeam:GetTask(iTask) then
                return oTeam:GetTask(iTask)
            end
        end
    end
end

function CFubenMgr:OpenCondition(oPlayer, iFuben)
    local mConfig = self:GetFubenConfig(iFuben)
    local mOpen = res["daobiao"]["open"][mConfig.open_name]
    local oToolMgr = global.oToolMgr
    local iGrade  = mOpen.p_level
    local oTeam = oPlayer:HasTeam()
    if not global.oToolMgr:IsSysOpen(mConfig.open_name,oPlayer) then
        return false, nil
    end
    if oTeam then
        local function FilterConnotJionMember(oMember)
            local iPid = oMember.m_ID
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer and not global.oToolMgr:IsSysOpen(mConfig.open_name,oPlayer,true) then
                return oPlayer:GetName()
            end
        end

        local lName = oTeam:FilterTeamMember(FilterConnotJionMember)
        if next(lName) then
            local mReplace = {role=table.concat(lName, "、"),grade = iGrade}
            self:Notify(oPlayer:GetPid(), 1001, mReplace)
            return false, lName
        end
    end
    return true, nil
end

function CFubenMgr:EnterCondition(oPlayer, iFuben)
    local mConfig = self:GetFubenConfig(iFuben)
    local iEnter = mConfig.condition_enter
    return mEnterFunc[iEnter](oPlayer)
end

function CFubenMgr:CheckEnterSure(oPlayer, iFuben, iConfirm)
    local mConfig = self:GetFubenConfig(iFuben)
    if mConfig.sure_type == defines.FUBEN_ENTER_NO_SURE then
        return true
    elseif mConfig.sure_type == defines.FUBEN_ENTER_TEAM_SURE then
        local oTeam = oPlayer:HasTeam()
        if not oTeam then return false end

        oTeam.m_oFubenSure:AutoEnterSure(iFuben)
        return oTeam.m_oFubenSure:CheckEnterSure(iFuben, iConfirm)
    end
end

function CFubenMgr:GetFubenConfig(iFuben)
    return res["daobiao"]["fuben"]["fuben_config"][iFuben]
end

function CFubenMgr:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(iPid, sMsg)
end

function CFubenMgr:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"fuben"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

