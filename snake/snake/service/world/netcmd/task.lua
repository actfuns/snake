local global = require "global"
local geometry = require "base.geometry"
local taskdefines = import(service_path("task/taskdefines"))

local max = math.max
local min = math.min

function C2GSClickTask(oPlayer,mData)
    local taskid = mData["taskid"]
    global.oTaskHandler:DoClickTask(oPlayer, taskid)
end

function C2GSTaskEvent(oPlayer,mData)
    local taskid = mData["taskid"]
    local npcid = mData["npcid"]
    global.oTaskHandler:DoClickTaskNpc(oPlayer, npcid, taskid)
end

function C2GSStepTask(oPlayer, mData)
    -- 一些特殊任务的步进
    local taskid = mData["taskid"]
    local iRestStep = mData["rest_step"]
    global.oTaskHandler:DoStepTask(oPlayer, taskid, iRestStep)
end

function C2GSCommitTask(oPlayer,mData)
    local taskid = mData["taskid"]
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
    if not oTask then
        return
    end
    oTask:Commit()
end

function C2GSAbandonTask(oPlayer,mData)
    local taskid = mData["taskid"]
    global.oTaskHandler:AbandonTask(oPlayer, taskid)
end

function C2GSAcceptTask(oPlayer, mData)
    local taskid = mData["taskid"]
    local npcid = mData["npcid"]
    global.oTaskHandler:CallAcceptTask(oPlayer, npcid, taskid)
end

function C2GSExtendTaskUIClick(oPlayer, mData)
    local taskid = mData["taskid"]
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
    if not oTask then
        return
    end
    oTask:OnExtendTaskUICallback(oPlayer, mData)
end

----- yibao ------
-- function C2GSYibaoRewardMain(oPlayer, mData)
--     global.oYibaoMgr:RewardYibaoMain(oPlayer)
-- end

function C2GSYibaoSeekHelp(oPlayer, mData)
    local taskid = mData.taskid
    global.oYibaoMgr:SeekHelpYibao(oPlayer, taskid)
end

function C2GSYibaoGiveHelp(oPlayer, mData)
    local iTarget = mData.target
    local taskid = mData.taskid
    local iCreateDay = mData.create_day
    global.oYibaoMgr:GiveHelpYibao(oPlayer, iTarget, taskid, iCreateDay)
end

function C2GSYibaoHelpSubmit(oPlayer, mData)
    local iTarget = mData.target
    local taskid = mData.taskid
    local iCreateDay = mData.create_day
    global.oYibaoMgr:HelpSubmitYibao(oPlayer, iTarget, taskid, iCreateDay)
end

function C2GSYibaoAccept(oPlayer)
    global.oYibaoMgr:NewTasks(oPlayer)
end

------------------

function C2GSRewardStoryChapter(oPlayer, mData)
    local iChapter = mData.chapter
    oPlayer.m_oTaskCtrl:RewardStoryChapter(oPlayer, iChapter)
end

function C2GSAnimeQteEnd(oPlayer, mData)
    local iAnimeId = mData.anime_id
    local iQteId = mData.qte_id
    local bSucc = mData.succ == 1
    oPlayer.m_oTaskCtrl:OnStoryAnimeQteEnd(oPlayer, iAnimeId, iQteId, bSucc)
end

----------------------
function C2GSRewardEverydayTask(oPlayer, mData)
    oPlayer.m_oTaskCtrl.m_oEverydayCtrl:RewardTask(oPlayer, mData.taskid)
end

--灵犀------------
function C2GSLingxiUseSeed(oPlayer, mData)
    local oTeamTask = global.oTaskMgr:GetUserTask(oPlayer, mData.taskid)
    if oTeamTask and oTeamTask:Type() == taskdefines.TASK_KIND.LINGXI then
        local iX = geometry.Recover(mData.put_x)
        local iY = geometry.Recover(mData.put_y)
        oTeamTask:OnUseSeed(oPlayer, iX, iY)
    end
end

function C2GSLingxiCloseToGrowPos(oPlayer, mData)
    local oTeamTask = global.oTaskMgr:GetUserTask(oPlayer, mData.taskid)
    if oTeamTask and oTeamTask:Type() == taskdefines.TASK_KIND.LINGXI then
        oTeamTask:OnCloseToGrowPos(oPlayer)
    end
end

function C2GSLingxiCloseToFlower(oPlayer, mData)
    local oTeamTask = global.oTaskMgr:GetUserTask(oPlayer, mData.taskid)
    if oTeamTask and oTeamTask:Type() == taskdefines.TASK_KIND.LINGXI then
        oTeamTask:OnCloseToFlower(oPlayer)
    end
end

function C2GSLingxiAwayFromFlower(oPlayer, mData)
    local oTeamTask = global.oTaskMgr:GetUserTask(oPlayer, mData.taskid)
    if oTeamTask and oTeamTask:Type() == taskdefines.TASK_KIND.LINGXI then
        oTeamTask:OnAwayFromFlower(oPlayer)
    end
end

function C2GSLingxiQuestionAnswer(oPlayer, mData)
    local oTeamTask = global.oTaskMgr:GetUserTask(oPlayer, mData.taskid)
    if oTeamTask and oTeamTask:Type() == taskdefines.TASK_KIND.LINGXI then
        oTeamTask:QuestionAnswer(oPlayer, mData)
    end
end
----------------------

function C2GSAcceptBaotuTask(oPlayer, mData)
    global.oTaskHandler:TryAcceptBaotuTask(oPlayer, true)
end

-- 跑环---------------
function C2GSRunringGiveHelp(oPlayer, mData)
    local iTarget = mData.target
    local iCreateWeekNo = mData.create_week
    local iRing = mData.ring
    local iTaskId = mData.taskid
    global.oRunRingMgr:HelpGiveSubmitTask(oPlayer, iTarget, iTaskId, iCreateWeekNo, iRing)
end

----------------------

--悬赏 start-----------

function C2GSOpenXuanShangView(oPlayer, mData)
    local oXuanShangCtrl = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl
    if oXuanShangCtrl then
        oXuanShangCtrl:C2GSOpenXuanShangView(oPlayer)
    end
end

function C2GSAcceptXuanShangTask(oPlayer, mData)
    local iTaskId = mData.taskid
    local oXuanShangCtrl = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl
    if oXuanShangCtrl then
        oXuanShangCtrl:C2GSAcceptXuanShangTask(oPlayer, iTaskId)
    end
end

function C2GSRefreshXuanShang(oPlayer, mData) 
    local oXuanShangCtrl = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl
    if oXuanShangCtrl then
        local iFastBuy = mData.fastbuy_flag
        oXuanShangCtrl:C2GSRefreshXuanShang(oPlayer, iFastBuy)
    end
end

function C2GSXuanShangStarTip(oPlayer, mData)
    local oXuanShangCtrl = oPlayer.m_oTaskCtrl.m_oXuanShangCtrl
    if oXuanShangCtrl then
        local iConfirm = mData.confirm
        local iTip = mData.tip
        local iFastBuy = mData.fastbuy_flag
        oXuanShangCtrl:C2GSXuanShangStarTip(oPlayer, iConfirm, iTip, iFastBuy)
    end
end

--悬赏 end-------------

--镇魔塔 start-----------

function C2GSZhenmoEnterLayer(oPlayer, mData)
    local iLayer = mData.layer
    oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:C2GSZhenmoEnterLayer(iLayer)
end

function C2GSZhenmoSpecialReward(oPlayer, mData)
    oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:C2GSZhenmoSpecialReward()
end

function C2GSZhenmoPlayAnim(oPlayer, mData)
    local iAnim = mData.anim
    oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:C2GSZhenmoPlayAnim(iAnim)
end

function C2GSZhenmoOpenView(oPlayer, mData)
    oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:C2GSZhenmoOpenView()
end


--镇魔塔 end-------------