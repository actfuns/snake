--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

-- 凝魄
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local iWid = oAction:GetWid()
    local func1 = function (oAct)
        OnBoutStart(iType, oAct)
    end
    local func2 = function (oAct, oAttack)
        OnDeadAfterSubHp(iType, iWid, oAct, oAttack)
    end
    local func3 = function (oAct)
        OnNewBout(iType, iWid, oAct)
    end

    oPerformMgr:AddFunction("OnBoutStart",self.m_ID, func1)
    oPerformMgr:AddFunction("OnNewBout",self.m_ID, func3)
    local lFriend = oAction:GetFriendList(true)
    for _,oFriend in pairs(lFriend) do
        oFriend:AddFunction("OnDeadAfterSubHp", iWid*10000+self.m_ID, func2)
    end
end

function CPerform:GetExtArgs()
    local mEnv = {level=self:Level()}
    local mExtArgs = formula_string(self:ExtArg(), mEnv)
    return mExtArgs
end

function OnNewBout(iPerform, iWid, oAction)
    local func = function (oAct, oAttack)
        OnDeadAfterSubHp(iPerform, iWid, oAct, oAttack)
    end

    local lFriend = oAction:GetFriendList(true)
    for _,oFriend in pairs(lFriend) do
        oFriend:AddFunction("OnDeadAfterSubHp", iWid*10000+iPerform, func)
    end
end

function OnBoutStart(iPerform, oAction)
    if not oAction then return end

    if oAction:IsDead() then
        AddGhost(iPerform, oAction)    
    else
        oAction:Set("p5701_ghost", 0)
    end
end

function OnDeadAfterSubHp(iPerform, iSummWid, oAction, oAttack)
    if not oAction or not oAction:IsDead() or oAction:IsGhost() then return end

    local oSummon = oAction:GetWarrior(iSummWid)
    if not oSummon then return end
    
    AddGhost(iPerform, oSummon)    
end

function AddGhost(iPerform, oAction)
    if not oAction or not oAction:IsDead() or not oAction:IsGhost() then return end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local mExtArgs = oPerform:GetExtArgs()
    oAction:Add("p5701_ghost", 1)
    if oAction:Query("p5701_ghost", 0) >= mExtArgs.ghost_cnt then
        local iHp = math.floor(oAction:GetMaxHp() * mExtArgs.hp_ratio)
        oAction:Set("revive_disable", nil)
        global.oActionMgr:DoAddHp(oAction, iHp)
        oAction:Set("revive_bout", nil)
        oAction:Set("p5701_ghost", nil)
        oAction:Set("revive_disable", 1)
        local oBuff = oAction.m_oBuffMgr:HasBuff(192)
        if oBuff then
            oAction.m_oBuffMgr:RemoveBuff(oBuff)    
        end
    end
    oAction:GS2CTriggerPassiveSkill(iPerform, {{key="ghost", value=oAction:Query("p5701_ghost", 0)}})
end

-- 状态机制，等客户端实现
-- function AddGhost(iPerform, oAction)
--     if not oAction or not oAction:IsDead() or not oAction:IsGhost() then return end

--     local oPerform = oAction:GetPerform(iPerform)
--     if not oPerform then return end

--     local mExtArgs = oPerform:GetExtArgs()
--     local oStatus = oAction.m_oStatusBuffMgr:GetStatus(iPerform)
--     oAction:GS2CTriggerPassiveSkill(iPerform)

--     if not oStatus then
--         oAction.m_oStatusBuffMgr:AddStatus(iPerform, {ghost_cnt=1})
--         return        
--     end

--     local iGhostCnt = oStatus:GetAttr("ghost_cnt", 0) + 1
--     if iGhostCnt >= mExtArgs.ghost_cnt then
--         oAction.m_oStatusBuffMgr:RemoveStatus(iPerform)
--         local iHp = math.floor(oAction:GetMaxHp() * mExtArgs.hp_ratio)
--         oAction:Set("revive_disable", nil)
--         global.oActionMgr:DoAddHp(oAction, iHp)
--         oAction:Set("revive_bout", nil)
--         oAction:Set("p5701_ghost", nil)
--         oAction:Set("revive_disable", 1)
--         local oBuff = oAction.m_oBuffMgr:HasBuff(192)
--         if oBuff then
--             oAction.m_oBuffMgr:RemoveBuff(oBuff)    
--         end
--     else
--         oAction.m_oStatusBuffMgr:UpdateStatus(iPerform, {ghost_cnt=iGhostCnt})
--     end
-- end

