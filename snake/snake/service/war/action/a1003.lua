--import module

local global = require "global"

local action = import(service_path("action/actionbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, action.CWarAction)


function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    local iCamp = 2
    local lMonster = oWar:GetWarriorList(2)
    for _,oWarrior in ipairs(lMonster) do
        self:DoActionConfig2(oWarrior)
    end
    
    local lMonster = oWar:GetWarriorList(1)
    for _,oWarrior in ipairs(lMonster) do
        self:DoActionConfig1(oWarrior)
    end
end

function CWarAction:DoActionConfig1(oWarrior)
    local iType = oWarrior:GetData("type")
    --if oWarrior:GetName() == "李广" and oWarrior:GetCampId() == 1 then
    if iType == 10008 then
        local func = function(oAttack, mCmd)
            return OnChangeCmdLiguang(oAttack, mCmd)
        end
        oWarrior:AddFunction("ChangeCmd", 1003, func)
    end
end

function CWarAction:DoActionConfig2(oWarrior)
    local iType = oWarrior:GetData("type")
    --if oWarrior:GetName() == "霍去病" then
    if iType == 10013 then
        local func1 = function(oVictim, oAttack)
            OnDeadHuoqubing(oVictim, oAttack)
        end
        oWarrior:AddFunction("OnDead", 1003, func1)
        local func2 = function(oVictim, oAttack, oPerform, iDamage)
            OnReceiveDamageHuoqubing(oVictim, oAttack, oPerform, iDamage)
        end
        oWarrior:AddFunction("OnReceiveDamage", 1003, func2)
        local func3 = function (oAttack, mCmd)
            return OnChangeCmdHuoQuBing(oAttack, mCmd)
        end
        oWarrior:AddFunction("ChangeCmd", 1003, func3)
    end
    --if oWarrior:GetName() == "妖鬼" then
    if iType == 10001 then
        local func1 = function(oWarrior)
            OnWarStartYaogui(oWarrior)
        end
        oWarrior:AddFunction("OnWarStart", 1003, func1)
        local func2 = function(oAttack, oVictim, oPerform, iDamage, mArgs)
            OnAttackYaogui(oAttack, oVictim, oPerform, iDamage, mArgs)
        end
        oWarrior:AddFunction("OnAttack", 1003, func2)
    end
    --if oWarrior:GetName() == "情妖" then
    if iType == 10009 then
        local func = function(oVictim, oAttack)
            OnDeadQingyao(oVictim, oAttack)
        end
        oWarrior:AddFunction("OnDead", 1003, func)
    end
    --if oWarrior:GetName() == "贴身侍卫" then
    if iType == 10019 then
        local func = function(oWarrior)
            OnBeforeActShiwei(oWarrior)
        end
        oWarrior:AddFunction("OnBeforeAct", 1003, func)
    end
    --if oWarrior:GetName() == "XX喽啰" then
    if iType == 10021 then
        local func = function(oWarrior)
            OnNewBoutLouluo(oWarrior)
        end
        oWarrior:AddFunction("OnNewBout", 1003, func)
    end
end

function OnDeadHuoqubing(oVictim, oAttack)
    local oWar = oVictim:GetWar()
    if not oWar then return end

    local lFriend = oVictim:GetFriendList()
    local iPerform, mPerform = 4208, {lv = 1}
    local lSpeek = {}

    for _, oWarrior in pairs(lFriend) do
        if oWarrior:GetWid() ~= oVictim:GetWid() then
            local mTmp = {
                wid = oWarrior:GetWid(),
                content = "将军，让我们替你复仇",
            }
            table.insert(lSpeek, mTmp)
            if not oWarrior:GetPerform(iPerform) then
                oWarrior:SetPerform(iPerform, mPerform)
            end
        end
    end

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = lSpeek,
        block_ms = 100,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end

function OnReceiveDamageHuoqubing(oVictim, oAttack, oPerform, iDamage)
    if not oVictim or oVictim:IsDead() then return end

    local oWar = oVictim:GetWar()
    if not oWar then return end

    if oVictim:GetHp() > math.floor(oVictim:GetMaxHp() * 0.3) then 
        return 
    end
    if not oVictim.m_DamageSpeek then
        return
    end
    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {{wid=oVictim:GetWid(), content="享受狂暴之血吧!",},},
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)

    local iPerform, mPerform = 4208, {lv = 1}
    if oVictim:GetPerform(iPerform) then return end
    oVictim:SetPerform(iPerform, mPerform)
end

function OnChangeCmdHuoQuBing(oAttack,mCmd)
    if oAttack:GetHp() > math.floor(oAttack:GetMaxHp() * 0.3) then 
        oAttack.m_DamageSpeek = true
    else
        oAttack.m_DamageSpeek = false
    end
    return mCmd
end

function OnWarStartYaogui(oWarrior)
    local oWar = oWarrior:GetWar()
    if not oWar then return end

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {{wid=oWarrior:GetWid(), content="嘿嘿, 又来了几个送死的！",},},
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end

function OnAttackYaogui(oAttack, oVictim, oPerform, iDamage, mArgs)
    local oWar = oAttack:GetWar()
    if not oWar or iDamage<=0 then return end

    if not oVictim or oVictim:IsAlive() then return end

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {{wid=oAttack:GetWid(), content="给你们点颜色瞧瞧！",},},
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end

function OnChangeCmdLiguang(oAttack, mCmd)
    if oAttack:IsDead() then return end

    local oWar = oAttack:GetWar()
    if not oWar then return end

    if oWar:CurBout() % 2 == 0 then
        return {cmd="defense", data={action_wid=oAttack:GetWid()}}
    end
end

function OnDeadQingyao(oVictim, oAttack)
    local lFriend = oVictim:GetFriendList(true)
    for _, oWarrior in pairs(lFriend) do
        if oWarrior:GetPerform(4204) then
            local oPerform = oWarrior:GetPerform(4204)
            oPerform:AddCallBackFunc(oWarrior)
        end
        if oWarrior:GetPerform(4205) then
            local oPerform = oWarrior:GetPerform(4205)
            oPerform:AddCallBackFunc(oWarrior)
        end
    end
end

function OnBeforeActShiwei(oWarrior)
    if not oWarrior or oWarrior:IsDead() then return end

    local oWar = oWarrior:GetWar()
    if not oWar then return end

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {{wid=oWarrior:GetWid(), content = "一刀要你命！",},},
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end

function OnNewBoutLouluo(oWarrior)
    if not oWarrior or oWarrior:IsDead() then return end

    local oWar = oWarrior:GetWar()
    if not oWar then return end

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {{wid=oWarrior:GetWid(), content="自幼体质不好，所以苦练一身金刚不坏，刀剑难伤的功夫。",},},
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end
