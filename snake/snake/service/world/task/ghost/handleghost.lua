local global = require "global"
local res = require "base.res"

local taskdefines = import(service_path("task/taskdefines"))
local handleteam = import(service_path("team/handleteam"))

local iGhostTaskKind = taskdefines.TASK_KIND.GHOST

function GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"task_ext"})
end

function GetNeedGrade()
    local res = require "base.res"
    return table_get_depth(res, {"daobiao", "task_type", iGhostTaskKind, "grade_limit"})
end

function NewGhostHandler()
    return CGhostHandler:New()
end

CGhostHandler = {}
CGhostHandler.__index = CGhostHandler
inherit(CGhostHandler, logic_base_cls())

function CGhostHandler:GetAcceptCondi()
end

function CGhostHandler:GetNeedTeamSizeCondi()
    local res = require "base.res"
    return table_get_depth(res, {"daobiao", "task_type", iGhostTaskKind, "teamsize_condi"})
end

function CGhostHandler:ValidSeeTask(oPlayer, bTips)
    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(iGhostTaskKind)
    if oTask then
        if bTips then
            oNotifyMgr:Notify(oPlayer.m_iPid, "你已经有金刚伏魔了")
        end
        return false
    end
end

function CGhostHandler:ValidAccpetTask(oPlayer, bTips)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer.m_iPid
    local oTeam = oPlayer:HasTeam()
    -- 系统关闭提示临时处理
    if oTeam and oTeam:IsLeader(iPid) then
        if not global.oToolMgr:IsSysOpen("ZHUAGUI", nil, true) then
            global.oToolMgr:IsSysOpen("ZHUAGUI",oPlayer, false)
            return
        end
    end
    if not oTeam or not oTeam:IsLeader(iPid) then
        if bTips then
            local sMsg = GetTextData(1009)
            oNotifyMgr:Notify(iPid, sMsg)
        end
        return false
    end
    local iTeamsize
    if not oTeam then
        iTeamsize = 0
    else
        iTeamsize = oPlayer:GetMemberSize() + oPlayer:Query("testman", 0)
    end
    local sTeamSizeCondi = self:GetNeedTeamSizeCondi()
    if sTeamSizeCondi then
        if not formula_string(sTeamSizeCondi, {teamsize=iTeamsize}) then
            if bTips then
                local sMsg = GetTextData(1011)
                oNotifyMgr:Notify(iPid, sMsg)
            end
            return false
        end
    end

    local function FilterCannotGhostMember(oMember)
        local iPid = oMember.m_ID
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer and not global.oToolMgr:IsSysOpen("ZHUAGUI", oPlayer, true) then
            return oPlayer:GetName()
        end
    end
    local lName = oTeam:FilterTeamMember(FilterCannotGhostMember)
    local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade("ZHUAGUI")
    
    if next(lName) then
        if bTips then
            local sMsg = GetTextData(1010)
            local oToolMgr = global.oToolMgr
            sMsg = oToolMgr:FormatColorString(sMsg,{role=table.concat(lName, "、"), level = iOpenLevel})
            oNotifyMgr:Notify(iPid, sMsg)
        end
        return false
    end
    local oTask = oTeam:GetTaskByType(taskdefines.TASK_KIND.GHOST)
    if oTask then
        if bTips then
            oNotifyMgr:Notify(iPid, "你已经有金刚伏魔了")
        end
        return false
    end
    return true
end

function CGhostHandler:ToAddNewTask(iPid, iDoneRing)
    if not iDoneRing then
        iDoneRing = 0
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    local mTask = {62000,62001,62002,62003}
    local iTask = mTask[math.random(#mTask)]

    local oTask = global.oTaskLoader:CreateTask(iTask)
    if not oTask then
        return
    end
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return
    end
    local iLeader = oTeam:Leader()
    if  iDoneRing < 10 then
        oTask:SetData("ring", iDoneRing + 1)
        handleteam.AddTask(iLeader,oTask)
        oTask:Click(iLeader)
    else
        local oTeam = oPlayer:HasTeam() 
        local plist = {}
        if oTeam then
            for _,oMem in pairs(oTeam:GetMember()) do
                local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                if oTarget then
                    table.insert(plist,oTarget)
                end
            end
        else
            plist = {oPlayer}
        end
        for _,oTarget in pairs(plist) do
            oTarget:MarkGrow(11)
        end
        if oPlayer.m_bTestGhostRun then
            self:OnAcceptConfirm(oPlayer, {answer = 1})
            return
        end
--        if oPlayer:Query("accept_ghost", 0) < 3 then
        self:GiveNewTask(oPlayer)
        return
--        else
--            oPlayer:Set("accept_ghost", nil)
--        end
--        local oCbMgr = global.oCbMgr
--        local mData = {
--            sContent = "是否继续帮助判官擒拿恶鬼？",
--            sConfirm = "继续",
--            sCancle = "取消",
--            time = 60,
--            extend_close = 3,
--        }
--        local mData = oCbMgr:PackConfirmData(nil, mData)
--        local func = function (oPlayer,mData)
--            global.oGhostHandler:OnAcceptConfirm(oPlayer, mData)
--        end
--        -- 战斗结束时动画还在播，需要前端将GS2CConfirmUI都放到后面，如果有即时弹窗需求，加新协议处理
--        oCbMgr:SetCallBack(iLeader, "GS2CConfirmUI", mData, nil, func)
    end
end

function CGhostHandler:OnAcceptConfirm(oPlayer, mData)
    local iAnswer = mData["answer"]
    if iAnswer == 1 then
        local npctype = 5234
        local oNpc = global.oNpcMgr:GetGlobalNpc(npctype)
        if not oNpc then
            return
        end
        if not oPlayer or not oPlayer:IsTeamLeader() then
            return
        end
        local iMap = oNpc:MapId()
        local iX = oNpc.m_mPosInfo["x"]
        local iY = oNpc.m_mPosInfo["y"]
        local oSceneMgr = global.oSceneMgr
        oSceneMgr:SceneAutoFindPath(oPlayer:GetPid(), iMap, iX, iY, oNpc:ID())
    end
end

function CGhostHandler:GiveNewTask(oPlayer)
    local oNpc = global.oNpcMgr:GetGlobalNpc(5234)
    if oNpc then
        oNpc:GiveTask(oPlayer:GetPid())
    end
end

function CGhostHandler:OnCancelAutoMatch(oTeam)
    local iTarget = oTeam:GetTargetID()
    if iTarget ~= 1400 then return end

    if oTeam:HasTaskKind(taskdefines.TASK_KIND.GHOST) then
        return
    end

    if oTeam:TeamSize() < 5 then
        return
    end

    local oLeader = oTeam:GetLeaderObj()
    local oCbMgr = global.oCbMgr
    local mData = {
        sContent = "队伍已满5人，是否直接开始金刚伏魔？",
        time = 10,
        extend_close = 3,
    }
    local mData = oCbMgr:PackConfirmData(nil, mData)
    local func = function(oPlayer, mData)
        if mData.answer == 1 then
            self:CheckAutoGiveTask(oPlayer)
        end
    end
    oCbMgr:SetCallBack(oLeader:GetPid(), "GS2CConfirmUI", mData, nil, func)
end

function CGhostHandler:CheckAutoGiveTask(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    if not oPlayer:IsTeamLeader() then return end
    
    if oTeam:TeamSize() < 5 then return end
    
    local oNpc = global.oNpcMgr:GetGlobalNpc(5234)
    if oNpc then
        oNpc:GiveTask(oPlayer:GetPid())
    end
end

