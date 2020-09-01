local global = require "global"
local npcobj = import(service_path("npc/npcobj"))
local handleteam = import(service_path("team/handleteam"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self,npctype)
    return o
end

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

local AUTO_TEAM_GHOST = 1400

function CNpc:do_look(oPlayer)
    if oPlayer.m_bTestGhostRun then
        self:OnClickNpcOptions(oPlayer, {answer = 1})
        return
    end
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:GetTextData(1007, {"task_ext"})
    local sMenu4 = self:GetMenu4Text(oPlayer)
    if sMenu4 then
        sText = string.format("%s&Q%s", sText,sMenu4)
    end

    local npcid = self:ID()
    self:SayRespond(oPlayer:GetPid(), sText, nil, function(oPlayer, mData)
        local oNpc = global.oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:OnClickNpcOptions(oPlayer, mData)
        end
    end)
end

function CNpc:GetMenu4Text(oPlayer)
    local bWhite = global.oServerMgr:IsWhiteListAccount(oPlayer:GetAccount(), oPlayer:GetChannel())
    if not bWhite and not global.oToolMgr:IsSysOpen("KS_SYS", oPlayer, true) then
        return
    end

    if is_ks_server() then
        return "退出跨服"
    end
    return "进入跨服"
end

function CNpc:OnClickNpcOptions(oPlayer, mData)
    local iAnswer = mData.answer
    if iAnswer == 1 then
        self:GiveTask(oPlayer:GetPid())
    elseif iAnswer == 2 then
        --oPlayer.m_oActiveCtrl:QuickTeamup(oPlayer, AUTO_TEAM_GHOST)
        self:AutoTeamUp(oPlayer, AUTO_TEAM_GHOST)
    elseif iAnswer == 3 then
        local sMsg = global.oToolMgr:GetTextData(1014,{"task_ext"})
        local iBaseTime = oPlayer.m_oTodayMorning:Query("ghost_base",0)
        if iBaseTime - 60 >= 0 then
            iBaseTime = 0
        else
            iBaseTime = 60 - iBaseTime
        end
        local iPoint,iPointLimit = oPlayer.m_oBaseCtrl:GetDoublePoint()
        local iTotalTime = oPlayer.m_oTodayMorning:Query("ghost_total",0)
        sMsg = global.oToolMgr:FormatColorString(sMsg,{base_time = iBaseTime, double_point = iPoint + iPointLimit , total_time = iTotalTime})
        local npcid = self:ID()
        self:SayRespond(oPlayer:GetPid(),sMsg,nil, function(oPlayer, mData)
            local oNpc = global.oNpcMgr:GetObject(npcid)
            if oNpc then
                oNpc:OnClickNpcOptions(oPlayer, mData)
            end
        end)
    elseif iAnswer == 4 then
        if is_ks_server() then
            global.oWorldMgr:TryBackGS(oPlayer)
        else
            local sKsServer = global.oKuaFuMgr:GetKuaFuServer("fuben_ks")
            global.oKuaFuMgr:TryEnterKS(oPlayer, sKsServer, {})
        end
    end
end

function CNpc:ValidGiveTask(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return false
    end
    return global.oGhostHandler:ValidAccpetTask(oPlayer, true)
end


function CNpc:GiveTask(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if not global.oToolMgr:IsSysOpen("ZHUAGUI", oPlayer) then
        return
    end

    if not oPlayer:HasTeam() then
        self:AutoTeamUp(oPlayer, AUTO_TEAM_GHOST)
        return
    else
        if oPlayer:IsTeamLeader() then
            local iNeedSize = 3
            local oTeam = oPlayer:HasTeam()
            local iMemberSize = oTeam:MemberSize()
            local iTeamSize = oTeam:TeamSize()
            if iMemberSize < 3 then
                if iTeamSize < 3 then
                    local oCbMgr = global.oCbMgr
                    local mData = {
                        sContent = "降魔至少需要3人，是否加入便捷组队？",
                        sConfirm = "确定",
                        sCancle = "取消",
                        time = 10,
                        extend_close = 3,
                    }
                    local mData = oCbMgr:PackConfirmData(nil, mData)
                    local func = function(oPlayer, mData)
                        if mData.answer == 1 then
                            self:AutoTeamUp(oPlayer, AUTO_TEAM_GHOST)
                        end
                    end
                    oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
                    return
                end
            end
        end
    end

    if not self:ValidGiveTask(iPid) then
        return
    end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local iTaskid = 62000
    local oTask = global.oTaskLoader:CreateTask(iTaskid)
    oTask:SetData("ring",1)
    handleteam.AddTask(iPid,oTask)
    global.oNotifyMgr:Notify(iPid, "任务领取成功")
    oTask:Click(iPid)
    oPlayer:Set("accept_ghost", oPlayer:Query("accept_ghost", 0) + 1)
    self:CheckDoublePoint(oPlayer, oTask)
end

function CNpc:CheckDoublePoint(oPlayer, oTask)
   local oTeam = oPlayer:HasTeam()
   if not oTeam then return end

   local lMember = oTeam:GetTeamMember()
    for _,iPid in pairs(lMember or {}) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oTask:CheckDoublePoint(oPlayer)
        end
    end 
end

function CNpc:AutoTeamUp(oPlayer, iTarget)
    if not global.oToolMgr:IsSysOpen("ZHUAGUI", oPlayer) then
        return
    end

    if not oPlayer:HasTeam() then
        handleteam.PlayerAutoMatch(oPlayer, iTarget)
        oPlayer:NotifyMessage("已开始自动匹配，请稍候")
    else
        local oTeam = oPlayer:HasTeam()
        if oTeam:TeamSize() >= 5 then return end

        if oPlayer:IsTeamLeader() and oTeam:MemberSize() < 5 then
            local mData = {
                auto_target = iTarget,
                max_grade = global.oWorldMgr:GetServerGradeLimit(),
                min_grade = global.oToolMgr:GetSysOpenPlayerGrade("ZHUAGUI"),
                team_match = 1,
            }
            handleteam.TeamAutoMatch(oPlayer, mData)
        else
            local sMsg = global.oToolMgr:GetTextData(1021)
            global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
        end
    end
end

