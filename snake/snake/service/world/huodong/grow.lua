--import module
local global  = require "global"
local extend = require "base.extend"

local huodongbase = import(service_path("huodong.huodongbase"))
local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "成长"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:TestOp(iFlag, arg)
    local oNotifyMgr = global.oNotifyMgr
    local pid = arg[#arg]
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag ==101 then
        if global.oToolMgr:HasTrueItemByReward("grow",arg.reward) then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),"你的背包已满，请清理后再领取")
            return
        end
    end
    oNotifyMgr:Notify(oPlayer:GetPid(),"执行完毕")
end