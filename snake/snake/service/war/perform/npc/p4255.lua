local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

-- 被封印数量＞2时不占用回合数立即使用玉清诀解除全体封印
function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAc)
        OnWarStart(iWid, iPerform, oAc)
    end
    oPerformMgr:AddFunction("OnWarStart",self.m_ID, func)
end

function OnWarStart(iWid, iPerform, oAction)
    local iWid = oAction:GetWid()
    local func = function (oAttack, oVictim, oUsePerform)
        OnSealed(iWid, iPerform, oAttack, oVictim, oUsePerform)
    end

    local lFriend = oAction:GetFriendList()
    for _, oFriend in pairs(lFriend) do
        oFriend:AddFunction("OnSealed", iPerform, func)
    end
end

function OnSealed(iWid, iPerform, oAttack, oVictim, oUsePerform)
    if not oVictim then return end
    local oAction = oVictim:GetWarrior(iWid)
    if not oAction then return end

    local lSealWid, lSelect = {}, {}
    local iType = gamedefines.BUFF_TYPE.CLASS_ABNORMAL 
    for _, oWid in pairs(oVictim:GetFriendList()) do
        if oWid.m_oBuffMgr:GetBuffByClass(iType, "封印") then
            table.insert(lSealWid, oWid)
            table.insert(lSelect, oWid:GetWid())
        end
    end
    if #lSealWid <= 2 then return end

    oAction:SendAll("GS2CWarSkill", {
        war_id = oAction:GetWarId(),
        action_wlist = {oAction:GetWid(),},
        select_wlist = lSelect,
        skill_id = iPerform,
        magic_id = 1,
    })
    -- oVictim:GS2CTriggerPassiveSkill(4255)
    for _, oWid in pairs(lSealWid) do
        oWid.m_oBuffMgr:RemoveClassBuffInclude(iType, {["封印"]=1})        
    end
end
