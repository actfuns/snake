--import module

local global = require "global"
local extend = require "base.extend"

local action = import(service_path("action/actionbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, action.CWarAction)

local ORDER_NAME = {"南","无","阿","弥","陀","佛"}

function CWarAction:New(...)
    local o = super(CWarAction).New(self, ...)
    return o
end

function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    local mSpeekData = mInfo.speek or {}
    mInfo.speek_enable = false

    local iCamp = 1
    local lMonster = oWar:GetWarriorList(iCamp)
    for _,oWarrior in ipairs(lMonster) do
        local iType = oWarrior:GetData("type")
        if iType == 20018 then
            oWarrior:AddFunction("ChangeCmd", 1005, function (oWarrior,mCmd)
                local cmd = OnBeforeAct4(oWarrior,mCmd)
                if cmd then
                    return cmd 
                end
            end)
        end
    end

    local iCamp = 2
    local sFaHaiContent = ""
    local lMonster = oWar:GetWarriorList(iCamp)
    for _,oWarrior in ipairs(lMonster) do
        local iType = oWarrior:GetData("type")
        for _,mInfo in ipairs(mSpeekData) do
            if mInfo.actor_id == iType then
                local sContent = mInfo.content
                local sName = oWarrior:GetName()
                if oWarrior:GetName() == "绿嘟嘟" then
                    oWarrior:AddFunction("ChangeCmd", 1005, function (oWarrior,mCmd)
                            local cmd = ChangeCmd(oWarrior,mCmd,sContent)
                            return cmd
                        end)
                elseif oWarrior:GetName() == "妖仙子" then
                    oWarrior:AddFunction("OnBeforeAct", 1005, function (oWarrior)
                        OnBeforeAct2(oWarrior, sContent)
                        end)
                elseif oWarrior:GetName() == "青藤妖" then
                    oWarrior:AddFunction("OnBeforeAct", 1005, function (oWarrior)
                        OnBeforeAct3(oWarrior, sContent)
                        end)
                elseif oWarrior:GetName() == "法海" then
                    sFaHaiContent = sContent
                end
            end
        end
    end

    local iCamp = 2
    local lMonster = oWar:GetWarriorList(iCamp)
    for _,oWarrior in ipairs(lMonster) do
        local sName = oWarrior:GetName()
        if extend.Array.find({"四大皆空","无欲无求","破六欲","斩七情","遁空门"},sName) then
            oWarrior:AddFunction("OnDead", 1005, function (oVictim, oAttack)
                CheckXuXian(oVictim, oAttack)
            end)
        elseif sName == "法海" then
            oWarrior:AddFunction("ChangeCmd", 1005, function (oWarrior,mCmd)
                    local cmd = ChangeCmdFaHai(oWarrior,mCmd)
                    return cmd
                end)
            oWarrior:AddFunction("OnNewBout",1005,function (oAction)
                CheckOrder(oAction, sFaHaiContent)
            end)
            oWarrior:AddFunction("OnImmuneDamage",1005,function (oVictim,oAttack, oPerform,iDamage)
                OnOrderDamaged(oVictim,oAttack, oPerform,iDamage)
            end)
        end
    end

end

function DoSpeek(oWarrior, sContent)
    if oWarrior:IsDead() then
        return
    end
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local mCmd = {
        war_id = oWarrior:GetWarId(),
        wid = oWarrior:GetWid(),
        content = sContent,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end

function ChangeCmd(oAction,mCmd,sContent)
    local cmd = {}
    cmd.cmd = "skill"
    cmd.data = {}
    cmd.data.action_wlist = mCmd.data.action_wlist
    local lPerform = oAction:GetPerformList()
    local mEnemy = oAction:GetEnemyList()
    local iMinHP = 0
    local iSelectWid
    local iPerform1 = 1606
    local iPerform2 = 1607
    local iPerform3 = 1107
    for _,oEnemy in pairs(mEnemy) do
        local iHP = oEnemy:GetHp()
        local iTempHP = math.floor(oEnemy:GetMaxHp()*30/100)
        if iHP<=iTempHP then
            if iMinHP == 0 then
                iMinHP = iHP
                iSelectWid = oEnemy:GetWid()
            elseif iMinHP>iHP then
                iMinHP = iHP
                iSelectWid = oEnemy:GetWid()               
            end
        end
    end
    if iSelectWid and extend.Array.find(lPerform,iPerform2) then
        cmd.data.skill_id = iPerform2
        cmd.data.select_wlist = {}
        table.insert(cmd.data.select_wlist,iSelectWid)
        
        if not oAction:QueryBoutArgs("speek_1005") then
            DoSpeek(oAction,sContent)
            oAction:SetBoutArgs("speek_1005",true)
        end
        return cmd
    end
    local iHP = oAction:GetHp()
    local iMaxHP = oAction:GetMaxHp()

    if iHP>math.floor(iMaxHP/2) and  extend.Array.find(lPerform,iPerform1) then
        local oPerform = oAction:GetPerform(iPerform1)
        cmd.data.skill_id = iPerform1
        cmd.data.select_wlist={}
        table.insert(cmd.data.select_wlist,oPerform:ChooseAITarget(oAction))
        if not oAction:QueryBoutArgs("speek_1005") then
            DoSpeek(oAction,sContent)
            oAction:SetBoutArgs("speek_1005",true)
        end
        return cmd
    elseif iHP<=math.floor(iMaxHP/2) and  extend.Array.find(lPerform,iPerform3) then
        local oPerform = oAction:GetPerform(iPerform3)
        cmd.data.skill_id = iPerform3
        cmd.data.select_wlist={}
        table.insert(cmd.data.select_wlist,oPerform:ChooseAITarget(oAction))
        DoSpeek(oAction,sContent)
        if not oAction:QueryBoutArgs("speek_1005") then
            DoSpeek(oAction,sContent)
            oAction:SetBoutArgs("speek_1005",true)
        end
        return cmd
    end
end

function OnBeforeAct2(oWarrior, sContent)
    local mFriend = oWarrior:GetFriendList()
    for _,obj in ipairs(mFriend) do
        if obj:GetName() == "绿嘟嘟" then
            DoSpeek(oWarrior, sContent)
            return
        end
    end
end

function OnBeforeAct3(oWarrior, sContent)
    local mFriend = oWarrior:GetFriendList()
    for _,obj in ipairs(mFriend) do
        if obj:GetName() == "绿嘟嘟" then
            DoSpeek(oWarrior, sContent)
            return
        end
    end
end

--白素贞
function OnBeforeAct4(oWarrior,mCmd)
    if mCmd.cmd ~= "skill" then return end
    if mCmd.data.skill_id ~= 3012 then return end
    local mEnemy = oWarrior:GetEnemyList()
    for _,oEnemy in pairs(mEnemy) do
        if oEnemy:GetName()=="许仙" then
            mCmd.data.select_wlist = {oEnemy:GetWid()}
            return mCmd
        end
    end
    local cmd = {}
    cmd.cmd = "normal_attack"
    cmd.data = {}
    return cmd
end

--四大皆空
function OnBeforeAct5(oWarrior,mCmd)
    if mCmd.cmd ~= "skill" then return end
    if mCmd.data.skill_id ~= 3005 then return end
    local mFriend = oWarrior:GetFriendList()
    for _,oFriend in pairs(mFriend) do
        if oFriend:GetName()=="许仙" then
            mCmd.data.select_wlist = {oFriend:GetWid()}
            return mCmd
        end
    end
    local cmd = {}
    cmd.cmd = "normal_attack"
    cmd.data = {}
    return cmd
end

function CheckXuXian(oVictim, oAttack)
    local mFriend = oVictim:GetFriendList()
    if #mFriend == 1 and mFriend[1]:GetName() == "许仙" then
        local oWar=oVictim:GetWar()
        oWar.m_iWarResult = 1
        oWar:WarEnd()
    end
end


function ChangeCmdFaHai(oAction,cmd)
    local mActivePerform = {3006}
    local iPerform2 = 3007
    local iPerform3 = 3008
    local mFriend = oAction:GetFriendList(true)
    local lPerform = oAction:GetPerformList()
    local bDead = false
    local bSmallHP = false
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:IsDead() then
            bDead = true
        else
            local iHP = oWarrior:GetHp()
            if iHP<math.floor(oWarrior:GetMaxHp()*5/10) then
                bSmallHP = true
            end
        end
    end
    if bDead and math.random(100)<50 and extend.Array.find(lPerform,iPerform2) then
        local oPerform = oAction:GetPerform(iPerform2)
        cmd.data.skill_id = iPerform2
        cmd.data.select_wlist={}
        table.insert(cmd.data.select_wlist,oPerform:ChooseAITarget(oAction))
        return cmd
    end
    if bSmallHP and extend.Array.find(lPerform,iPerform3) then
        local oPerform = oAction:GetPerform(iPerform3)
        cmd.data.skill_id = iPerform3
        cmd.data.select_wlist={}
        table.insert(cmd.data.select_wlist,oPerform:ChooseAITarget(oAction))
        return cmd
    end
    local iPerform = extend.Random.random_choice(mActivePerform)
    local oPerform = oAction:GetPerform(iPerform)
    cmd.data.skill_id = iPerform
    cmd.data.select_wlist={}
    local iTarget = oPerform:ChooseAITarget(oAction)
    if iTarget then
        if type(iTarget) == "number" then
            table.insert(cmd.data.select_wlist,iTarget)
        else
            print("cg_debug action 1005",iTarget,iPerform)
        end
    end
    return cmd
end

function CheckOrder(oAction, sContent)
    local oWar = oAction:GetWar()
    if not oWar then return end

    if oWar:CurBout() % 2 == 1 then
        DoSpeek(oAction, sContent)
    end
    
    local mFriend = oAction:GetFriendList(true)
    local lReLife1 = {}
    local lReLife2 =  {}
    for _,sName in ipairs(ORDER_NAME) do
        for _,oFriend in ipairs(mFriend) do
            if oFriend:GetName() == sName then
                table.insert(lReLife1,oFriend)
            end
        end
    end
    local bOrder = false
    for _, oWarrior in ipairs(lReLife1) do
        if not oWarrior:IsDead() and not bOrder then
            bOrder = true
        end
        if bOrder and oWarrior:IsDead() then 
            table.insert(lReLife2,oWarrior)
        end
    end

    for _,oWarrior in ipairs(lReLife2) do
        if oWarrior:IsDead() then
            oWarrior:AddHp(oWarrior:GetMaxHp(),oAction)
        end
    end
end

function OnOrderDamaged(oVictim,oAttack, oPerform,iDamage)
    local mFriend = oVictim:GetFriendList()
    for _,oWarrior in ipairs(mFriend) do
        if oWarrior ~= oVictim then 
            oVictim:SetBoutArgs("immune_damage", true)
        end
    end
    return iDamage
end
