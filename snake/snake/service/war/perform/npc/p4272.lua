--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

local ACTION_ID = 100007

--因果循环
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnBoutEnd(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end

function OnBoutEnd(iPerform, oAttack)
    --print("4272-1")
    if not oAttack or oAttack:IsDead() then 
        return 
    end
    local oWar  = oAttack:GetWar()
    if not oWar then 
        return 
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then 
        return 
    end
    local mAllMonsterInfo = oAttack:GetData("all_monster", {})
    if not next(mAllMonsterInfo) then
        return
    end
    local mFriend = oAttack:GetFriendList()
    if next(mFriend) then
        for _,oWarrior in pairs(mFriend) do
            local iType = oWarrior:GetData("type",0)
            if iType == 10088 then
                OnBoutEnd10088(oWarrior)
            elseif  iType == 10089 then
                OnBoutEnd10089(oWarrior)
            end
        end
    end
    local lVictim = {oAttack}
    oAttack:SendAll("GS2CWarSkill", {
        war_id = oAttack:GetWarId(),
        action_wlist = {oAttack:GetWid(),},
        select_wlist = list_generate(lVictim, function (v)
            return v:GetWid()
        end),
        skill_id = oPerform.m_ID,
        magic_id = 1,
    })
    local mTime = oPerform:PerformMagicTime(oAttack)
    oWar:AddAnimationTime(mTime[1])
    oWar:AddDebugMsg(string.format("#B%s#n使用#B%s#n", oAttack:GetName(), oPerform:Name() ))
    local mMonster = table_deep_copy(mAllMonsterInfo[10088]) 
    if mMonster then
        --print("4272-1")
        local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
        if oWarrior then
            oWarrior:AddFunction("OnAttacked",ACTION_ID,function (oAction,oAttack,oPerform,iDamage,mArgs)
                OnAttacked10088(oAction,oAttack,oPerform,iDamage,mArgs)
            end)
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10088(oAction)
            end)
            oWarrior:AddFunction("OnDead", ACTION_ID, function (oVictim, oAttack)
                OnDead10088(oVictim, oAttack)
            end)
        end
    end
    mMonster = table_deep_copy(mAllMonsterInfo[10089]) 
    if mMonster then
        --print("4272-2")
        local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
        if oWarrior then
            oWarrior:AddFunction("OnAttacked",ACTION_ID,function (oAction,oAttack,oPerform,iDamage,mArgs)
                OnAttacked10089(oAction,oAttack,oPerform,iDamage,mArgs)
            end)
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10089(oAction)
            end)
        end
    end
end

function OnAttacked10088(oAction,oAttack,oPerform,iDamage,mArgs)
    if iDamage<=0 then return end
    DoSpeek(oAction,"前世受你恩惠，今生偿还",1)
    local oActionMgr = global.oActionMgr
    local mEnemy = oAction:GetEnemyList()
    for _,oWarrior in pairs(mEnemy) do
        local iHP = math.floor(oWarrior:GetMaxHp()/20)
        if iHP > 0 then
            oActionMgr:DoAddHp(oWarrior,iHP)
        end
    end
end

function OnDead10088(oAction, oAttack)
    if not oAction:IsDead() then
        return
    end
    DoSpeek(oAction,"前世受你恩惠，今生偿还",1)
    local oActionMgr = global.oActionMgr
    local mEnemy = oAction:GetEnemyList()
    for _,oWarrior in pairs(mEnemy) do
        local iHP = math.floor(oWarrior:GetMaxHp()/20)
        if iHP > 0 then
            oActionMgr:DoAddHp(oWarrior,iHP)
        end
    end
end

function OnBoutEnd10088(oAction)
    --print("OnBoutEnd10088")
    oAction:SetExtData("escape_ratio",100)
    global.oActionMgr:WarEscape(oAction)
end

function OnAttacked10089(oAction,oAttack,oPerform,iDamage,mArgs)
    if iDamage<=0 then return end
    --print("OnAttacked10089")
    DoSpeek(oAction,"因果循环，今生偿还",1)
end

function OnBoutEnd10089(oAction)
    --print("OnBoutEnd10089")
    oAction:SetExtData("escape_ratio",100)
    global.oActionMgr:WarEscape(oAction)
end

function DoSpeek(oWarrior, sContent,iFlag)
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
        flag = iFlag,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end