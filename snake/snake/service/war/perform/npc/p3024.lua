--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end
local ACTION_ID = 100007
--召唤火鸦

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnBoutEnd10100(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end

function OnBoutEnd10100(iPerform, oAttack)
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
    OnBoutEnd10101(3025,oAttack)
    local mAllMonsterInfo = oAttack:GetData("all_monster", {})
    if not next(mAllMonsterInfo) then
        return
    end
    local oCamp = oWar:GetCampObj(oAttack:GetCampId())
    if not oCamp then
        return
    end
    if oCamp:GetLeftPosCnt()<=0 then
        return
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
    local iMonster = 10101
    for i = 1,5 do
        if oCamp:GetLeftPosCnt() <=0 then
            break
        end
        local mMonster = table_deep_copy(mAllMonsterInfo[iMonster]) 
        local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
    end
end

function OnBoutEnd10101(iPerform, oAttack)
    if not oAttack or oAttack:IsDead() then 
        return 
    end
    local oWar  = oAttack:GetWar()
    if not oWar then 
        return 
    end

    local mFriend = oAttack:GetFriendList()
    local lDelWarrior = {}
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetData("type") == 10101 then
            table.insert(lDelWarrior, oWarrior:GetWid())
        end
    end
    for _, iWid in pairs(lDelWarrior) do
        local oWarrior = oWar:GetWarrior(iWid)
        if not oWarrior or oWarrior:IsDead() then
            goto continue
        end
        local oPerform = oWarrior:GetPerform(iPerform)
        if not oPerform then
            goto continue
        end
        local mEnemy = oWarrior:GetEnemyList()
        if #mEnemy <= 0 then
            goto continue
        end
        global.oActionMgr:Perform(oWarrior,mEnemy[1],iPerform)
        oWar:KickOutWarrior(oWarrior)
        ::continue::
    end
end
