local global = require "global"
local extend = require "base.extend"

local BASE_AI_ID = 401
local gamedefines = import(lualib_path("public.gamedefines"))
local aibase = import(service_path("ai/ai" .. BASE_AI_ID))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

-- AI: 第一回合使用固定技能

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)

-- function CAI:GetPerformAIId()
--     return BASE_AI_ID
-- end

function CAI:Command(oAction)
    local oWar = oAction:GetWar()
    if oWar:CurBout() == 1 then
        local mCmd = self:ReviveCmd(oAction)
        if mCmd then return end
    end

    super(CAI).Command(self, oAction)
end

function CAI:ReviveCmd(oAction)
    local oWar = oAction:GetWar()

    -- 1607技能
    local iPerform, iTarget = 1607
    local oPerform = oAction:GetPerform(iPerform)
    if oPerform then
        iTarget = oPerform:ChooseAITarget(oAction)
    end

    if iTarget then
        local iWid = oAction:GetWid()
        local mCmd = {
            cmd = "skill",
            data = {
                action_wlist = {iWid},
                select_wlist = {iTarget},
                skill_id = iPerform,
            }
        }
        oWar:AddBoutCmd(iWid, mCmd)
        return mCmd
    end
end
