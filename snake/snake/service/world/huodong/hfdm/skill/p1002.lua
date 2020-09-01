-- 活动技能-无影脚
local global = require "global"
local res = require "base.res"
local hfdmskill = import(service_path("huodong.hfdm.skill"))
local hfdmdefines = import(service_path("huodong.hfdm.defines"))

function GetHuodong()
    return global.oHuodongMgr:GetHuodong("hfdm")
end

function GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"huodong", "hfdm"})
end

function NewSkill(iPid, iSkillId)
    return CHuodongSkill:New(iPid, iSkillId)
end

CHuodongSkill = {}
CHuodongSkill.__index = CHuodongSkill
inherit(CHuodongSkill, hfdmskill.CHuodongSkillBase)

function CHuodongSkill:New(iPid, iSkillId)
    local o = super(CHuodongSkill).New(self, iPid, iSkillId)
    return o
end

function CHuodongSkill:CanUse(iTarget)
    local bSucc, iErr, bResync = super(CHuodongSkill).CanUse(self, iTarget)
    if not bSucc then
        return bSucc, iErr, bResync
    end
    local iPid = self.m_iOwner
    if iTarget == iPid then
        return false, hfdmdefines.ERR_USE_SKILL.TARGET_FAIL, false
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        return false, hfdmdefines.ERR_USE_SKILL.TARGET_OFFLINE, false
    end
    local oHuodong = GetHuodong()
    -- 等待期间可以用
    if not oHuodong:IsStateQuesTime() then
        return false, hfdmdefines.ERR_USE_SKILL.TIME_ERR, false
    end
    local iMyPosAnswer = oHuodong:GetPosAnswer(iPid)
    -- 允许未答题玩家使用技能
    -- if not iMyPosAnswer then
    --     return false, hfdmdefines.ERR_USE_SKILL.GIVE_UP, false
    -- end
    local iTPosAnswer = oHuodong:GetPosAnswer(iTarget)
    if iMyPosAnswer and iTPosAnswer and iTPosAnswer ~= iMyPosAnswer then
        return false, hfdmdefines.ERR_USE_SKILL.TARGET_FAIL, false
    end
    return true, 0, true
end

function CHuodongSkill:IsInShield(oTarget)
    local oHuodong = GetHuodong()
    return oHuodong.m_oSkillMgr:IsInShield(oTarget)
end

function CHuodongSkill:GetTargetFromToNewAnswer(iPid, iTarget)
    local oHuodong = GetHuodong()
    local iMyPosAnswer = oHuodong:GetPosFakeSelect(iPid)
    local iNewAnswer
    if iMyPosAnswer then
        iNewAnswer =  oHuodong:GetTheOtherAnswer(iPid)
    end
    iNewAnswer = oHuodong:GetRandomAnswer()
    return iMyPosAnswer, iNewAnswer
end

-- 可以通过state来实现，写新的stateobj，注意要开启心跳主动超时，要注册到aoistate里，前端根据aoi展示护盾特效
function CHuodongSkill:DoUse(iTarget)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iOwner)
    if not oPlayer then return end
    super(CHuodongSkill).DoUse(self, iTarget)

    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        return
    end
    if self:IsInShield(oTarget) then
        local sTName = oTarget:GetName()
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(2001), {role = sTName}))
        return
    end
    local oHuodong = GetHuodong()
    local iPid = oPlayer:GetPid()
    local iMyPosAnswer, iNewAnswer = self:GetTargetFromToNewAnswer(iPid, iTarget)
    local rX, rY = oHuodong:RandomAnswerPos(iNewAnswer)
    local mPos = {x = rX, y = rY}
    global.oSceneMgr:DoTransfer(oTarget, oNowScene:GetSceneId(), mPos)
    -- 此处做答案重刷，因为后端不做坐标校验，所以帮前端处理设置
    local iQuesId = oHuodong:GetCurQuesId()
    oHuodong:SelectAnswer(oTarget, iQuesId, iNewAnswer)
    if not iMyPosAnswer or iMyPosAnswer == 0 then
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(3014), {role = oTarget:GetName(), answerpos = oHuodong:GetAnswerPosName(iNewAnswer)}))
    else
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(3011), {role = oTarget:GetName()}))
    end
    oTarget:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(3012), {role = oPlayer:GetName()}))
end

function CHuodongSkill:NotifySkillErr(oPlayer, iErr)
    super(CHuodongSkill).NotifySkillErr(self, oPlayer, iErr)
end
