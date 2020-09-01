local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local netwar = import(service_path("netcmd/war"))
local gamedefines = import(lualib_path("public.gamedefines"))


Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Opens.fight = false
Helpers.fight = {
    "进入fight导表战斗",
    "fight 导表类型 战斗id",
    "fight moneytree 1001",
}
function Commands.fight(oMaster, sType, iFight)
    global.oTestMgr:TryDoFightByIdx(oMaster, sType, tonumber(iFight))
end

Opens.warend = false
Helpers.warend = {
    "战斗结束",
    "warend 结束标记, 结束为空表示赢，为-1表示输",
    "warend, warend -1",
}
function Commands.warend(oMaster, iFlag)
    local oWar = oMaster.m_oActiveCtrl:GetNowWar()
    if oWar then
        if iFlag and iFlag < 0 then
            oWar:TestCmd("warfail",oMaster:GetPid(),{})
        else
            oWar:TestCmd("warend",oMaster:GetPid(),{})
        end
    end
end

Opens.addaura = false
Helpers.addaura = {
    "战斗中增加灵气",
    "addaura",
    "addaura",
}
function Commands.addaura(oMaster)
    local oWar = oMaster.m_oActiveCtrl:GetNowWar()
    if oWar then
        oWar:TestCmd("addaura", oMaster:GetPid(), {})
        oMaster:NotifyMessage("添加灵气成功")
    end 
end

Opens.addbuff = false
Helpers.addbuff = {
    "战斗中增加buff",
    "addbuff buff_id 回合数 目标玩家",
    "addbuff 196 3 或者addbuff 196 3 10001",
}
function Commands.addbuff(oMaster, iBuff, iBout, iPid)
    iPid = iPid or oMaster:GetPid()
    local oWar = oMaster.m_oActiveCtrl:GetNowWar()
    if oWar then
        oWar:TestCmd("addbuff", iPid, {buff_id=iBuff, bout=iBout})
    end
end

Opens.addzhenqi = false
Helpers.addzhenqi = {
    "战斗中增加zhenqi",
    "addzhenqi 真气值",
    "addzhenqi 196",
}
function Commands.addzhenqi(oMaster, iVal)
    local iPid = oMaster:GetPid()
    local oWar = oMaster.m_oActiveCtrl:GetNowWar()
    if oWar then
        oWar:TestCmd("addzhenqi", iPid, {val=iVal})
    end
end


Opens.setperform = false
Helpers.setperform = {
    "添加招式",
    "setperform 招式id 等级",
    "setperform 1201 5 或者 setperform 1201",
}
function Commands.setperform(oMaster,pfid,iLevel)
    local pid = oMaster.m_iPid
    local oNotifyMgr = global.oNotifyMgr

    if not res["daobiao"]["perform"][pfid] then
        oNotifyMgr:Notify(pid, string.format("没有招式%s", pfid))
        return
    end

    local mTestPerform = oMaster.m_oActiveCtrl:GetInfo("TestPerform",{})
    mTestPerform[pfid] = iLevel
    oMaster.m_oActiveCtrl:SetInfo("TestPerform",mTestPerform)
    oNotifyMgr:Notify(pid,"招式设置成功")
end

Opens.testwar = false
Helpers.testwar = {
    "测试多人PVP",
    "testwar {玩家ID1,玩家ID2,...}",
    "testwar {999, 234,}",
}
function Commands.testwar(oMaster, lTargets)
    local oWarMgr = global.oWarMgr
    local oWorldMgr = global.oWorldMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_NONE,
        {})

    if #lTargets <= 0 then
        return
    end

    local lRes = {}
    for _, v in ipairs(lTargets) do
        local o = oWorldMgr:GetOnlinePlayerByPid(v)
        if o then
            table.insert(lRes, o)
        end
    end
    local iMiddle = math.floor(#lRes/2 + 1)

    oWarMgr:EnterWar(oMaster, oWar:GetWarId(), {camp_id = 1}, true)
    for i = 1, iMiddle do
        local o = lRes[i]
        oWarMgr:EnterWar(o, oWar:GetWarId(), {camp_id = 2}, true)
    end
    for i = iMiddle + 1, #lRes do
        local o = lRes[i]
        oWarMgr:EnterWar(o, oWar:GetWarId(), {camp_id = 1}, true)
    end

    oWarMgr:StartWar(oWar:GetWarId())
end

Opens.wartimeover = false
Helpers.wartimeover = {
    "结束战斗本轮操作阶段",
    "wartimeover",
    "wartimeover",
}
function Commands.wartimeover(oMaster)
    local oWar = oMaster.m_oActiveCtrl:GetNowWar()
    if oWar then
        oWar:TestCmd("wartimeover", oMaster:GetPid(), {})
    end
end

Opens.setwarattr = false
Helpers.setwarattr = {
    "设置战斗属性",
    "setwarattr attr val",
    "setwarattr max_hp 100000",
}
function Commands.setwarattr(oMaster, attr, val)
    if not oMaster.m_mTestWarAttr then
        oMaster.m_mTestWarAttr = {}
    end
    oMaster.m_mTestWarAttr[attr] = val
    local oWar = oMaster.m_oActiveCtrl:GetNowWar()
    if oWar then
        oWar:TestCmd("setwarattr", oMaster:GetPid(), {attr=attr, val=val})
    end
end

Opens.openwardebug = true
Helpers.openwardebug = {
    "开启战斗debug",
    "openwardebug",
    "openwardebug",
}
function Commands.openwardebug(oMaster)
    Commands.setwarattr(oMaster, "wardebug", true)
end

Opens.closewardebug = true
Helpers.closewardebug = {
    "关闭战斗debug",
    "closewardebug",
    "closewardebug",
}
function Commands.closewardebug(oMaster)
    Commands.setwarattr(oMaster, "wardebug", nil)
end

Opens.perform = false
function Commands.perform(oMaster,iCmd,...)
    local args = {...}
    if iCmd == 100 then
        local oWar = oMaster.m_oActiveCtrl:GetNowWar()
        local iAction,iVictim,skill_id = table.unpack(args)
        local mData = {
            war_id = oWar:GetWarId(),
            action_wlist = {iAction,},
            select_wlist = {iVictim,},
            skill_id = skill_id,
        }
        netwar.C2GSWarSkill(oMaster,mData)
    elseif iCmd == 101 then
        local oWar = oMaster.m_oActiveCtrl:GetNowWar()
        local iAction,sum_id = table.unpack(args)
        local mData = {
            war_id = oWar:GetWarId(),
            action_wid = iAction,
            sum_id = sum_id,
        }
        netwar.C2GSWarSummon(oMaster,mData)
    elseif iCmd == 102 then
        oMaster:NewHour5(get_wdaytime({wday=1}))
    end
end

Opens.startvideo = false
Helpers.startvideo = {
    "播放录像",
    "startvideo iVideo, iCamp",
    "startvideo 1 1",
}
function Commands.startvideo(oMaster, iVideo, iCamp)
    global.oVideoMgr:StartVideo(oMaster, iVideo, iCamp)
end

Opens.savevideo = false
Helpers.savevideo = {
    "存储录像",
    "savevideo",
    "savevideo",
}
function Commands.savevideo(oMaster)
    global.oVideoMgr:_CheckSave()
end

function Commands.clearwarcmd(oMaster)
    oMaster.m_oBaseCtrl:SetData("war_command",{{},{}})
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oMaster:GetPid(), "指令执行成功")
end


