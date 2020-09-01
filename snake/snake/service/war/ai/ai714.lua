--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local aibase = import(service_path("ai/ai101"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

-- AI: 被封印情况每回合有50%几率使用特技，命中后随机抽取一个特技使用
-- 若未抽中轮回技能，则再按照权重抽取其他技能

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)


function CAI:Command(oAction)
    local oWar = oAction:GetWar()
    local iType = gamedefines.BUFF_TYPE.CLASS_ABNORMAL
    if oAction.m_oBuffMgr:GetBuffByClass(iType, "封印") then
        self:SealedCmd(oAction)
        return
    end

    local mCmd = self:ReviveCmd(oAction)
    if mCmd then return end

    super(CAI).Command(self, oAction)
end

function CAI:SealedCmd(oAction)
    local oWar = oAction:GetWar()
    local mCmd = {cmd = "command_disable"}
    local iPerform, iTarget
    local iRatio = math.random(100)
    if iRatio <= 50 then
        iPerform = extend.Random.random_choice({9024, 9018, 9026})
        local oPerform = oAction:GetPerform(iPerform)
        if oPerform then
            iTarget = oPerform:ChooseAITarget(oAction)
        end
    end
    if iPerform and iTarget then
        mCmd = {
            cmd = "skill",
            data = {
                action_wlist = {oAction.m_iWid},
                select_wlist = {iTarget},
                skill_id = iPerform,
            }
        }
    end
    oWar:AddBoutCmd(oAction.m_iWid, mCmd)
end

function CAI:ReviveCmd(oAction)
    local oWar = oAction:GetWar()
    if math.random(100) > 50 then return end

    -- 轮回技能
    local iPerform, iTarget = 1205
    local oPerform = oAction:GetPerform(iPerform)
    if oPerform then
        iTarget = oPerform:ChooseAITarget(oAction)
    end

    if iTarget then
        local mCmd = {
            cmd = "skill",
            data = {
                action_wlist = {oAction.m_iWid},
                select_wlist = {iTarget},
                skill_id = iPerform,
            }
        }
        oWar:AddBoutCmd(oAction.m_iWid, mCmd)
        return mCmd
    end
end

