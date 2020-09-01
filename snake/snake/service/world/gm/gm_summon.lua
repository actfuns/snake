local global = require "global"
local extend = require "base.extend"
local res = require "base.res"

local loadsummon = import(service_path("summon.loadsummon"))
local summondefines = import(service_path("summon.summondefines"))


Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.summonop = true
Helpers.summonop = {
    "玩家测试指令",
    "summonop iFlag mArgs",
    "summonop 101 ",
}
function Commands.summonop(oMaster,iFlag,mArgs)
    local summontest = import(service_path("summon/test"))
    summontest.TestOP(oMaster,iFlag,mArgs)
end

Opens.givesummon = true
Helpers.givesummon = {
    "给一只宠物",
    "givesummon 造型 等级 野生",
    "givesummon 1001 10 1",
}
function Commands.givesummon(oMaster, sid, grade, iWild)
    local oSummon
    if iWild == 1 then
        oSummon = loadsummon.CreateSummon(sid, grade, iWild)
    else
        oSummon = loadsummon.CreateSummon(sid, grade)
    end
    assert(oSummon, string.format("gm givesummon sid err:%d %d", sid, grade))
    if not oMaster.m_oSummonCtrl:AddSummon(oSummon, "gm_give") then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oMaster:GetPid(), "携带的宠物数量已经达到上限了")
    end
end

Opens.addsummonexp = true
Helpers.addsummonexp = {
    "给当前参战宠物加经验",
    "addsummonexp 经验值",
    "addsummonexp 100",
}
function Commands.addsummonexp(oMaster, iExp)
    local oSummon = oMaster.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        oSummon:RewardExp(iExp, "gm")
    end
end

Opens.setsummonbind = true
Helpers.setsummonbind = {
    "设置宠物绑定",
    "setsummonbind summId",
    "setsummonbind 1",
}
function Commands.setsummonbind(oMaster, sid)
    local oSummon = oMaster.m_oSummonCtrl:GetSummon(sid)
    if not oSummon then
        oMaster:NotifyMessage("没有指定的宠物")        
        return
    end
    oSummon:Bind(oMaster:GetPid())
    oMaster:NotifyMessage("绑定成功")
end

Opens.dropallsummon = false
Helpers.dropallsummon = {
    "清空宠物",
    "dropallsummon",
    "dropallsummon",
}
function Commands.dropallsummon(oMaster)
    local mSummons = extend.Table.values(oMaster.m_oSummonCtrl:SummonList())
    for _, oSummon in ipairs(mSummons) do
        oMaster.m_oSummonCtrl:RemoveSummon(oSummon)
    end
end

Opens.clearsumskill = false
Helpers.clearsumskill = {
    "清空当前参战宠技能",
    "clearsumskill",
    "clearsumskill",
}
function Commands.clearsumskill(oMaster)
    local oSummon = oMaster.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        local skids = oSummon:GetSKillList()
        for _, skid in ipairs(skids) do
            oSummon:RemoveSkill(skid)
        end
    end
end

Opens.addsumskill = true
Helpers.addsumskill = {
    "增加当前参战宠物技能",
    "addsumskill 技能编号 技能等级",
    "addsumskill 5101 2",
}
function Commands.addsumskill(oMaster, skid, lv)
    local oSummon = oMaster.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        local oSkill = oSummon:GetSKill(skid)
        if oSkill then
            oSkill:SkillUnEffect(oSummon)
        end
        oSummon:AddSkill(skid, lv)
    end
end

Opens.countcombinesummon = false
Helpers.countcombinesummon = {
    "测试统计合成宠物",
    "countcombinesummon 合成宠物1sid 合成宠物2sid 合成次数",
    "countcombinesummon 1009 1000 1000",
    -- C2GSGMCmd {cmd="countcombinesummon 1009 1001 1000"}
}
function Commands.countcombinesummon(oMaster, sid1, sid2, cnt)
    local oSummonMgr = global.oSummonMgr
    local  mSummons = res["daobiao"]["summon"]["info"]
    if not mSummons[sid1] then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oMaster:GetPid(), "找不到对应的合成宠物1")
        return
    end
    if not mSummons[sid2] then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oMaster:GetPid(), "找不到对应的合成宠物2")
        return
    end
    local oSummon1 = loadsummon.CreateSummon(sid1)
    local oSummon2 = loadsummon.CreateSummon(sid2)
    local iResultSID
    local mRet = {}
    for i=1, cnt do
        iResultSID = oSummonMgr:RandomCombineSID_new(oSummon1, oSummon2)
        if not mRet[iResultSID] then
            mRet[iResultSID] = 1
        else
            mRet[iResultSID] = mRet[iResultSID]  + 1
        end
    end
    local sMsg = string.format("宠物合成 sid1:%d sid2:%d count:%d", sid1, sid2, cnt)
    global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    local infolist, bynum, xynum  = {}, 0, 0
    for i, n in pairs(mRet)  do
        local mInfo = mSummons[i]
        sMsg = string.format("合成 sid:%d 名字:%s 次数:%d %2f", i, mInfo["name"], n, n/cnt)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end

Opens.addsummonlife = true
Helpers.addsummonlife = {
    "给当前参战宠物加寿命",
    "addsummonlife 值",
    "addsummonlife 100",
}
function Commands.addsummonlife(oMaster, iLife)
    local oSummon = oMaster.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        oSummon:AddLife(iLife)
    end
end

Opens.getzhenpininfo = true
Helpers.getzhenpininfo = {
    "获取珍品信息",
    "getzhenpininfo",
    "getzhenpininfo",
}
function Commands.getzhenpininfo(oMaster)
    local oSummon = oMaster.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        local mConfig = global.oSummonMgr:GetSummonConfig()
        local iCur, iMax = 0, oSummon:GetZpMaxAptitude()
        local mCurAptitude = oSummon:CurAptitude()
        for _, iVal in pairs(mCurAptitude) do
            iCur = iCur + iVal
        end

        local iRate = 100
        for _,m in pairs(mConfig["zp_aptitude_rate"] or {}) do
            if m.grade > oSummon:CarryGrade() then break end
           
            iRate = m.ratio
        end
        local sMsg = string.format("当前资质:%d 最大资质:%d 计算比率:%d 当前成长:%d 最大成长:%d 计算比率:%d", 
            iCur, iMax, iRate, oSummon:Grow(), oSummon:BaseGrow(), mConfig["zp_grow"])
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)

    end
end

Opens.washsepsummon = true
Helpers.washsepsummon = {
    "洗练珍品",
    "washsepsummon 造型",
    "washsepsummon 1001",
}
function Commands.washsepsummon(oMaster, sid)
    local oSummon = loadsummon.CreateSepWashSummon(sid)
    assert(oSummon, string.format("gm givesummon sid err:%d", sid))
    if not oMaster.m_oSummonCtrl:AddSummon(oSummon, "gm_give") then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oMaster:GetPid(), "携带的宠物数量已经达到上限了")
    end
end

Opens.setsumhp = true
Helpers.setsumhp = {
    "增加当前参战宠物hp",
    "setsumhp hp",
    "setsumhp 10",
}
function Commands.setsumhp(oMaster, hp)
    local oSummon = oMaster.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        oSummon:SetData("hp", hp)
        oSummon:PropChange("hp")
    end
end

