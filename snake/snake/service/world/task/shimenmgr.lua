local global = require "global"
local net = require "base.net"
local record = require "public.record"

local taskdefines = import(service_path("task/taskdefines"))

CShimenMgr = {}
CShimenMgr.__index = CShimenMgr
inherit(CShimenMgr, logic_base_cls())

function NewShimenMgr()
    local o = CShimenMgr:New()
    return o
end

function CShimenMgr:SyncInfo(oPlayer)
    local iDoneDaily = self:GetShimenTodayDoneRing(oPlayer)
    local mNet = {
        done_daily = iDoneDaily,
        done_weekly = oPlayer.m_oWeekMorning:Query("shimen_done", 0),
        daily_full = iDoneDaily >= taskdefines.SHIMEN_INFO.LIMIT_RINGS and 1 or 0,
    }
    oPlayer:Send("GS2CShimenInfo", mNet)
end

function CShimenMgr:GetShimenTodayDoneRing(oPlayer)
    if oPlayer.m_oTodayMorning:Query("perfect_shimen") then
        return taskdefines.SHIMEN_INFO.LIMIT_RINGS
    end
    return oPlayer.m_oTodayMorning:Query("shimen_done", 0)
end

-- TODO 以后再考虑将符合部分条件的player缓存的处理
function CShimenMgr:GetShimenOnlineFightMirrorPlayer(oPlayer)
    local iSchool = oPlayer:GetSchool()
    local iPid = oPlayer:GetPid()
    -- 这个函数是filter，不是callback
    local fCheck = function(pid, oUser)
        if pid == iPid then
            return
        end
        -- 不同门派
        if oUser:GetSchool() == iSchool then
            return
        end
        -- lv >= serverLv-5
        local iGrade = oUser:GetGrade()
        local iServerGrade = oPlayer:GetServerGrade()
        if iGrade < iServerGrade - 5 then
            return
        end
        return oUser
    end

    local oTargetPlayer
    -- 优先本org
    local iOrgId = oPlayer:GetOrgID()
    if iOrgId and iOrgId ~= 0 then
        oTargetPlayer = global.oToolMgr:SelectOrgOnlinePlayer(iOrgId, fCheck)
        if oTargetPlayer then
            return oTargetPlayer
        end
    end

    local fCheckElseOrg = function(pid, oUser)
        if pid == iPid then
            return
        end
        if iOrgId and oUser:GetOrgID() == iOrgId then
            return
        end
        return fCheck(pid, oUser)
    end
    oTargetPlayer = global.oToolMgr:SelectWorldOnlinePlayer(fCheckElseOrg)
    if oTargetPlayer then
        return oTargetPlayer
    end
end

function CShimenMgr:RecordShimenWeekDoneInc(oPlayer, oDoneTask)
    oPlayer.m_oWeekMorning:Add("shimen_done", 1)
    local iDoneWeekly = oPlayer.m_oWeekMorning:Query("shimen_done")
    if iDoneWeekly == taskdefines.SHIMEN_INFO.WEEKLY_REWARD_RING then
        -- 发固定奖励表
        local mLogData = oPlayer:LogData()
        mLogData.rewardid = taskdefines.SHIMEN_INFO.WEEKLY_REWARD_TBL
        record.user("task", "shimen_weekly_reward_done", mLogData)

        global.oNotifyMgr:Notify(pid, string.format("本周完成门派修行%d环", iDoneWeekly))
        oDoneTask:Reward(pid, taskdefines.SHIMEN_INFO.WEEKLY_REWARD_TBL, {limit_type = "week"})
        global.oNotifyMgr:Notify(pid, "门派修行周奖励已放入邮箱")
    end
end

-- 设置 m_oTodayMorning为今日完成的环数，CTask."Ring"为显示用的进行中环数
function CShimenMgr:RecordShimenTodayDoneRing(oPlayer, iDoneRing)
    if oPlayer.m_oTodayMorning:Query("perfect_shimen") then
        return
    end

    oPlayer.m_oTodayMorning:Set("shimen_done", iDoneRing)

    -- 师门日程加活跃
    oPlayer.m_oScheduleCtrl:AddByName("shimen")
    oPlayer.m_oScheduleCtrl:HandleRetrieve(1001, 1)

    if iDoneRing >= taskdefines.SHIMEN_INFO.LIMIT_RINGS then
        -- 完成到上限
        oPlayer.m_oTodayMorning:Add("perfect_shimen", 1)
    end
end
