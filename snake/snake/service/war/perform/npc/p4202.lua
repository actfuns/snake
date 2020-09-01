--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--李广意志

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oAction, mCmd)
        ChangeCmd(oAction, mCmd)
    end
    oPerformMgr:AddFunction("ChangeCmd", self.m_ID, func)
end

function ChangeCmd(oAction, mCmd)
    local iPerform = 3002       --射虎之弓

    if not oAction:GetPerform(iPerform) then return end

    local lTarget = oAction:GetEnemyList()
    if #lTarget <= 0 then return end

    local iTarget = lTarget[math.random(#lTarget)]:GetWid()

    local mNewCmd = {}
    mNewCmd.cmd = "skill"
    mNewCmd.data = {
        action_wlist = {oAction:GetWid()},
        select_wlist = {iTarget},
        skill_id = iPerform,
    }
    return mNewCmd
end

