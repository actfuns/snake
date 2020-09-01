local global = require "global"
local res = require "base.res"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.rewardgold = true
Helpers.rewardgold = {
    "奖励金币",
    "rewardgold 金币数量",
    "rewardgold 200",
}
function Commands._gettarget(oMaster, iTarget)
    local oTarget
    if not iTarget or iTarget == 0 then
        oTarget = oMaster
    else
        oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    end
    if not oTarget then
        global.oNotifyMgr:Notify(oMaster:GetPid(), "该玩家不在线")
        return
    end
    return oTarget
end

function Commands.rewardgold(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardGold(iVal,"gm")
end

Opens.rewardsilver = true
Helpers.rewardsilver = {
    "奖励银币",
    "rewardsilver 银币数量",
    "rewardsilver 200",
}
function Commands.rewardsilver(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardSilver(iVal,"gm")
end

Opens.rewardexp = true
Helpers.rewardexp = {
    "奖励经验",
    "rewardexp 经验数量",
    "rewardexp 200",
}
function Commands.rewardexp(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardExp(iVal,"gm", {bEffect = false})
end

Opens.addgoldcoin = true
Helpers.addgoldcoin={
    "增加元宝",
    "addgoldcoin 数目",
    "addgoldcoin 1000"
}
function Commands.addgoldcoin(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oProfile = oTarget:GetProfile()
    oProfile:AddRplGoldCoin(iVal,"gm")
end

Helpers.cleangoldcoin = {
    "清空元宝",
    "cleangoldcoin",
    "cleangoldcoin"
}
function Commands.cleangoldcoin(oMaster, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oProfile = oTarget:GetProfile()
    local iVal = oProfile:GoldCoin()
    if iVal>0 then
        oProfile:ResumeGoldCoin(iVal,"gm")
        global.oNotifyMgr:Notify(oMaster:GetPid(), "清空完毕")
    else
        global.oNotifyMgr:Notify(oMaster:GetPid(), string.format("该玩家元宝已经为%s",iVal))
    end
end

Helpers.cleangoldcoinowe = {
    "清空负债元宝",
    "cleangoldcoinowe",
    "cleangoldcoinowe"
}
function Commands.cleangoldcoinowe(oMaster, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oProfile = oTarget:GetProfile()
    oProfile:CleanGoldCoinOwe()
    oProfile:CleanTrueGoldCoinOwe()
    global.oNotifyMgr:Notify(oMaster:GetPid(), "清空完毕")
end

Helpers.resumegoldcoin = {
    "消耗通用元宝",
    "resumegoldcoin 数量 目标",
    "resumegoldcoin 100 10001"
}
function Commands.resumegoldcoin(oMaster, iGoldCoin, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:ResumeGoldCoin(iGoldCoin,"gm")
    global.oNotifyMgr:Notify(oMaster:GetPid(), "消耗元宝成功")
end

Helpers.resumetruegoldcoin = {
    "消耗非绑定元宝",
    "resumetruegoldcoin 数量 目标",
    "resumetruegoldcoin 100 10001"
}
function Commands.resumetruegoldcoin(oMaster, iTrueGoldCoin, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oProfile = oTarget:GetProfile()
    oProfile:ResumeTrueGoldCoin(iTrueGoldCoin,"gm")
    global.oNotifyMgr:Notify(oMaster:GetPid(), "消耗非绑定元宝成功")
end

Opens.addgold = true
Helpers.addgold={
    "增加金币",
    "addgold 数目",
    "addgold 1000"
}
function Commands.addgold(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardGold(iVal,"gm")
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster.m_iPid,string.format("%s当前金币为%s",oTarget:GetPid(),oMaster.m_oActiveCtrl:GetData("gold",0)))
end

Helpers.cleangold = {
    "清空金币",
    "cleangold",
    "cleangold"
}
function Commands.cleangold(oMaster, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local iGold = oTarget.m_oActiveCtrl:GetData("gold",0)
    if iGold>0 then
        oTarget:ResumeGold(iGold,"gm")
        global.oNotifyMgr:Notify(oMaster:GetPid(), "清空完毕")
    else
        global.oNotifyMgr:Notify(oMaster:GetPid(), string.format("该玩家金币已经为%s",iGold))
    end
end

Helpers.cleangoldowe = {
    "清空金币负债",
    "cleangoldowe",
    "cleangoldowe"
}
function Commands.cleangoldowe(oMaster, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget.m_oActiveCtrl:SetData("gold_owe",0)
    global.oNotifyMgr:Notify(oMaster:GetPid(), "清空完毕")
end

Helpers.resumegold = {
    "消耗金币",
    "resumegold 数量 目标",
    "resumegold 100 10001"
}
function Commands.resumegold(oMaster, iGold, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:ResumeGold(iGold,"gm")
    global.oNotifyMgr:Notify(oMaster:GetPid(), "消耗金币成功")
end

Opens.addsilver = true
Helpers.addsilver = {
    "增加银币",
    "addsilver 数目",
    "addsilver 1000"
}
function Commands.addsilver(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardSilver(iVal,"gm")
end

Helpers.cleansilver = {
    "清空银币",
    "cleansilver",
    "cleansilver"
}
function Commands.cleansilver(oMaster, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local iSilver = oTarget.m_oActiveCtrl:GetData("silver",0)
    if iSilver >0 then
        oTarget:ResumeSilver(iSilver,"gm")
        global.oNotifyMgr:Notify(oMaster:GetPid(), "清空完毕")
    else
        global.oNotifyMgr:Notify(oMaster:GetPid(), string.format("该玩家银币已经为%s",iSilver))
    end
end

Helpers.cleansilverowe = {
    "清空银币负债",
    "cleansilverowe",
    "cleansilverowe"
}
function Commands.cleansilverowe(oMaster, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget.m_oActiveCtrl:SetData("silver_owe",0)
    global.oNotifyMgr:Notify(oMaster:GetPid(), "清空完毕")
end

Helpers.resumesilver = {
    "消耗银币",
    "resumesilver 数量 目标",
    "resumesilver 100 10001"
}
function Commands.resumesilver(oMaster, iSilver, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:ResumeSilver(iSilver,"gm")
    global.oNotifyMgr:Notify(oMaster:GetPid(), "消耗银币成功")
end

Opens.addpoint = true
Helpers.addpoint = {
    "增加潜力点",
    "addpoint 数目",
    "addpoint 1000",
}
function Commands.addpoint(oMaster, iPoint, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local iPoint = tonumber(iPoint)
    if iPoint > 0 then
        oTarget.m_oBaseCtrl:AddPoint(iPoint)
    end
end

Opens.setenergy = true
Helpers.setenergy = {
    "设置活力值",
    "setenergy 数量",
    "setenergy 1000",
}
function Commands.setenergy(oMaster, iEnergy, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local iEnergy = tonumber(iEnergy)
    if iEnergy > 0 then
        oTarget:AddEnergy(iEnergy, "gm")
    end
    oTarget:PropChange("energy")
end

Helpers.adddoublepoint = {
    "设置双倍点数",
    "adddoublepoint 点数",
    "adddoublepoint 10",
}
function Commands.adddoublepoint(oMaster, val, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oNotifyMgr = global.oNotifyMgr
    oTarget.m_oBaseCtrl:AddDoublePoint(val)
    oTarget.m_oBaseCtrl:RefreshDoublePoint()
    local sMsg = string.format("设置玩家%s双倍点数为%d", oTarget:GetPid(), val)
    oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
end

Helpers.adddoublepointlimit = {
    "设置双倍点数可领取值",
    "adddoublepointlimit 点数",
    "adddoublepointlimit 10",
}
function Commands.adddoublepointlimit(oMaster, val, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oNotifyMgr = global.oNotifyMgr
    oTarget.m_oBaseCtrl:AddDoublePointLimit(val)
    oTarget.m_oBaseCtrl:RefreshDoublePoint()
    local sMsg = string.format("设置玩家%s双倍点数可领取值为%d", oTarget:GetPid(), val)
    oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
end

Helpers.reward = {
    "奖励表发奖",
    "reward sGroupName iRewardId mEnvArgs",
    "reward test 2001 {ring=1}",
}
function Commands.reward(oMaster, sGroupName, iRewardId, mEnvArgs)
    if mEnvArgs then
        local iMailId = mEnvArgs.mail_id
        if iMailId and iMailId > 0 then
            global.oMailMgr:SendMailReward(oMaster, iMailId, iRewardId, sGroupName, {argenv = mEnvArgs, reason = "gm"})
            return
        end
    end
    global.oRewardMgr:RewardByGroup(oMaster, sGroupName, iRewardId, {argenv = mEnvArgs, reason = "gm"})
end

Opens.rewardwuxun = true
Helpers.rewardwuxun = {
    "奖励武勋",
    "rewardwuxun 武勋数量",
    "rewardwuxun 200",
}
function Commands.rewardwuxun(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardWuXun(iVal,"gm")
end

Opens.rewardjjcpoint = true
Helpers.rewardjjcpoint = {
    "奖励竞技场积分",
    "rewardjjcpoint 竞技场积分",
    "rewardjjcpoint 200",
}
function Commands.rewardjjcpoint(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardJJCPoint(iVal,"gm")
end

Opens.rewardleaderpoint = true
Helpers.rewardleaderpoint = {
    "增加队长积分越过每日最大限制",
    "rewardleaderpoint 增加队长积分",
    "rewardleaderpoint 200",
}

function Commands.rewardleaderpoint(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oActiveCtrl = oTarget.m_oActiveCtrl
    if oActiveCtrl then
        local mLogData = oTarget:LogData()
        mLogData["leaderpoint_old"] =  oActiveCtrl:GetData("leaderpoint", 0)
        mLogData["leaderpoint_add"] = iVal
        mLogData["reason"] = "GM指令越过每日上限"
        local iSetVal = math.max( oActiveCtrl:GetData("leaderpoint",0)+iVal,0)
        oActiveCtrl:SetData("leaderpoint",iSetVal)
        oTarget:PropChange("leaderpoint")
        oActiveCtrl:Dirty()
    end
end

Opens.rewardxiayipoint = true
Helpers.rewardxiayipoint = {
    "增加侠义值越过每日最大限制",
    "rewardxiayipoint 增加侠义值",
    "rewardxiayipoint 200",
}

function Commands.rewardxiayipoint(oMaster,iVal,iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oActiveCtrl = oTarget.m_oActiveCtrl
    if oActiveCtrl then
        local mLogData = oTarget:LogData()
        mLogData["xiayipoint_old"] =  oActiveCtrl:GetData("xiayipoint", 0)
        mLogData["xiayipoint_add"] = iVal
        mLogData["reason"] = "GM指令增加侠义值超过每日上限"
        local iSetVal = math.max( oActiveCtrl:GetData("xiayipoint",0)+iVal,0)
        oActiveCtrl:SetData("xiayipoint",iSetVal)
        oTarget:PropChange("xiayipoint")
        oActiveCtrl:Dirty()
    end
end

function Commands.checkrewardformula(oMaster)
    local res = require "base.res"
    local record = require "public.record"
    local lError = {}
    oMaster:Set("ignore_reward_monitor", 1)
    for sTask, lTask in pairs(res["daobiao"]["task"]) do
        if sTask ~= "fuben" and sTask ~= "test" then
            for iTask, mTask in pairs(lTask["task"]) do
                local oTask = global.oTaskLoader:CreateTask(iTask)
                if not oTask then goto continue end
    
                oTask:SetOwner(oMaster:GetPid())
                local lCmd = mTask["submitRewardStr"]
                if not lCmd or not next(lCmd) then
                    goto continue
                end
                
                local mEnv = oTask:GetRewardEnv(oMaster)
                for _, ss in ipairs(lCmd) do
                    local sCmd = string.match(ss, "^([$%a]+)")
                    local sIdx = string.sub(ss, #sCmd + 1, -1)
                    if sCmd == "R" or sCmd == "TR" then
                        local bOk, rMsg = safe_call(oTask.Reward, oTask, oMaster:GetPid(), sIdx, {})
                        if not bOk then
                            table.insert(lError, sTask..":"..iTask.."-"..sCmd..sIdx)
                            record.info(sTask, iTask, sCmd, sIdx)
                        end
                    end
                end
                ::continue::
            end
        end
    end
    
    for iFuben, mFuben in pairs(res["daobiao"]["fuben"]["fuben_config"]) do
        local oFuben = global.oFubenMgr:NewFuben(iFuben)
        if not oFuben then goto continue end

        for _, iGroup in ipairs(mFuben.group_list) do
            local lTask = res["daobiao"]["fuben"]["taskgroup"][iGroup]["task_list"]
            for _, iTask in pairs(lTask) do
                local mTask = res["daobiao"]["task"]["fuben"]["task"][iTask]
                if mTask then
                    local oTask = global.oTaskLoader:CreateTask(iTask)
                    oTask:SetOwner(oMaster:GetPid())
                    oTask.GetFubenObj = function(self)
                        return oFuben
                    end

                    local lCmd = mTask["submitRewardStr"]
                    if not lCmd or not next(lCmd) then
                        goto continue
                    end
                    
                    local mEnv = oTask:GetRewardEnv(oMaster)
                    for _, ss in ipairs(lCmd) do
                        local sCmd = string.match(ss, "^([$%a]+)")
                        local sIdx = string.sub(ss, #sCmd + 1, -1)
                        if sCmd == "R" or sCmd == "TR" then
                            local bOk, rMsg = safe_call(oTask.Reward, oTask, oMaster:GetPid(), sIdx, {})
                            if not bOk then
                                table.insert(lError, mFuben.fuben_name..":"..iTask.."-"..sCmd..sIdx)
                                record.info(mFuben.fuben_name, iTask, sCmd, sIdx)
                            end
                       end
                    end
                end
            end
        end
        ::continue::
    end

    oMaster:Set("ignore_reward_monitor", nil)
    record.info("================")
    record.info(table.concat(lError, "\n"))
    oMaster:Send("GS2CGMMessage", {msg = table.concat(lError, "\n")})
end

Opens.rewardsummonpoint = true
Opens.rewardsummonpoint = {
    "增加合宠积分",
    "rewardsummonpoint 合宠积分",
    "rewardsummonpoint 1000",
}

function Commands.rewardsummonpoint(oMaster, iVal, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    oTarget:RewardSummonPoint(iVal, "GM指令")
end

Opens.rewardchumopoint = true
Opens.rewardchumopoint = {
    "增加除魔值--绕过每日上限",
    "rewardchumopoint 除魔值 pid(不填是执行者自己)",
    "rewardchumopoint 1000 pid",
}

function Commands.rewardchumopoint(oMaster, iVal, iTarget)
    local oTarget = Commands._gettarget(oMaster, iTarget)
    if not oTarget then return end

    local oActiveCtrl = oTarget.m_oActiveCtrl
    if oActiveCtrl then
        local mLogData = oTarget:LogData()
        mLogData["chumopoint_old"] = oActiveCtrl:GetData("chomopoint", 0)
        mLogData["chumopoint_add"] = iVal
        mLogData["reason"] = "GM指令超越每日上限"
        local iSetVal = math.max(oActiveCtrl:GetData("chumopoint", 0) + iVal, 0)
        oActiveCtrl:SetData("chumopoint", iSetVal)
        oTarget:PropChange("chumopoint")
        oActiveCtrl:Dirty()
    end
end


