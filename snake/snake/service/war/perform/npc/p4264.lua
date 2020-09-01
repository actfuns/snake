--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--复制

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
    --print("4264-1")
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
    if oWar.m_iBout ~= 2 then
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
    local mMonster = table_deep_copy(mAllMonsterInfo[10125]) 
    if mMonster then
        --print("4264-2")
        oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
    end
end