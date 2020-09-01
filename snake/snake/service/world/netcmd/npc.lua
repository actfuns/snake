--import module
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"

local handlenpc = import(service_path("npc/handlenpc"))

-- npc为场景npc时，点击任务会上行此协议，没有执行任务事件流程，！前端会自己在回调中拼接一些按钮
function C2GSClickNpc(oPlayer,mData)
    local npcid = mData["npcid"]
    local oNpcMgr = global.oNpcMgr
    local oNpc = oNpcMgr:GetObject(npcid)
    if not oNpc then
        --record.warning("C2GSClickNpc none npc, pid:%d,npcid:%d", oPlayer:GetPid(), npcid)
        return
    end
    oNpcMgr:OnClickNpc(oPlayer, oNpc)
end

function C2GSNpcRespond(oPlayer,mData)
    local npcid = mData["npcid"]
    local iAnswer = mData["answer"]
    local oNpcMgr = global.oNpcMgr
    local oNpc = oNpcMgr:GetObject(npcid)
    if not oNpc then
        --record.warning("C2GSNpcRespond none npc(check [client lost]/[dupl proto]), pid:%d,npcid:%d", oPlayer:GetPid(), npcid)
        return
    end
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    handlenpc.Respond(oPlayer.m_iPid,npcid,iAnswer)
end

function C2GSFindPathToNpc(oPlayer, mData)
    local iNpcType = mData.npctype
    global.oNpcMgr:FindPathToNpc(oPlayer, iNpcType)
end
