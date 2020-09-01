local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Helpers.setrelation = {
    "设置好友关系",
    "setrelation 玩家ID1 玩家ID2 关系(1.夫妻，2.结拜，3.师徒)",
    "setrelation 1 2 1",
}
function Commands.setrelation(oMaster, iPid1, iPid2, iRelation)
    local oFriendMgr = global.oFriendMgr
    local oNotifyMgr = global.oNotifyMgr
    oFriendMgr:SetRelation(iPid1, iPid2, iRelation)
    oNotifyMgr:Notify(oMaster:GetPid(), "设置成功")
end

Helpers.clearrelation = {
    "解除好友关系",
    "clearrelation 玩家ID1 玩家ID2 关系(1.夫妻，2.结拜，3.师徒)",
    "clearrelation 1 2 1",
}
function Commands.clearrelation(oMaster, iPid1, iPid2, iRelation)
    local oNotifyMgr = global.oNotifyMgr
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:ResetRelation(iPid1, iPid2, iRelation)
    oNotifyMgr:Notify(oMaster:GetPid(), "解除成功")
end

Helpers.addfrienddegree = {
    "增加好友度",
    "addfrienddegree 玩家ID1 玩家ID2 增加好友度",
    "addfrienddegree 1 2 100",
}
function Commands.addfrienddegree(oMaster, iPid1, iPid2, iDegree)
    local oFriendMgr = global.oFriendMgr
    local oNotifyMgr = global.oNotifyMgr
    oFriendMgr:AddFriendDegree(iPid1, iPid2, iDegree)
    oNotifyMgr:Notify(oMaster:GetPid(), "增加好友度成功")
end

function Commands.recommend_clear(oMaster)
    interactive.Send(".recommend","friend","ClearAllCache", {})
end

Helpers.dissolveengage = {
    "解除订婚",
    "dissolveengage",
    "dissolveengage",
}
function Commands.dissolveengage(oMaster)
    global.oEngageMgr:DissolveEngage(oMaster, true)
    global.oNotifyMgr:Notify(oMaster:GetPid(), "解除订婚")
end

Helpers.cancelengage = {
    "取消订婚",
    "cancelengage",
    "cancelengage",
}
function Commands.cancelengage(oMaster)
    local oEngage = global.oEngageMgr:GetEngageByPid(oMaster:GetPid())
    if oEngage then
        global.oEngageMgr:RemoveEngage(oEngage)    
    end
    global.oNotifyMgr:Notify(oMaster:GetPid(), "取消订婚")
end

Helpers.mentoring = {
    "取消订婚",
    "mentoring 编号, 参数",
    "mentoring 100, {}",
}
function Commands.mentoring(oMaster, iFlag, mArgs)
    global.oMentoring:TestOp(oMaster, iFlag, mArgs)
end


