local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"
local net = require "base.net"
local util = import(lualib_path("public.util"))


local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--摇钱树召唤

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAction, oVictim, iRatio)
    local oWar = oAction:GetWar()
    if not oWar then return end
    local iNewbieCnt = GetNewbieCnt(oWar, oAction)
    local mEnv = {newbie = iNewbieCnt}
    local mMonsterRadio, mNumRadio = GetMonsterCntTbl(mEnv, oAction:GetTypeSid())

    local iTotal, iLoop = 1, 1
    local iMaxMonsterNum = 10
    local iPos = 1
    local mHasUsed = {}
    for i=1,iMaxMonsterNum do
        if iTotal >= iMaxMonsterNum then break end
        local iMonster = table_choose_key(mMonsterRadio)
        local lMonsterNumRadio = mNumRadio[iMonster] or {}
        local iAmount = table_choose_key(lMonsterNumRadio) or 0
        iAmount = math.min(iMaxMonsterNum-iTotal, iAmount)    
        if iAmount and iAmount > 0 then
            iTotal = iTotal + iAmount
            for i=1, iAmount do
                iPos = iPos + 1
                if iPos == 11 then
                    iPos = 12
                end
                AddNpcWarrior(oAction, iMonster, iPos)
            end
        end
        mMonsterRadio[iMonster] = 0 --确保下次随机不到
    end
end

function GetNewbieCnt(oWar, oAction)
    if oAction.m_iNewbieCnt then
        return oAction.m_iNewbieCnt
    end

    local lWarrior = oWar:GetPlayerWarriorList()

    local iMaxGrade = 0
    for _, oWarrior in pairs(lWarrior) do
        if oWarrior:GetGrade() > iMaxGrade then
            iMaxGrade = oWarrior:GetGrade()
        end
    end

    local iLimit = iMaxGrade - 10
    local iNewbie = 0
    for _, oWarrior in pairs(lWarrior) do
        if oWarrior:GetGrade() < iLimit then
            iNewbie = iNewbie + 1
        end
    end
    oAction.m_iNewbieCnt = iNewbie

    return iNewbie
end

function GetMonsterCntTbl(mEnv, iTypeId)
    local sCntName = "monster_cnt_ruyi"
    if iTypeId == 10020 then
        sCntName = "monster_cnt_jixiang"
    end
    local mInfo = res["daobiao"]["huodong"]["moneytree"][sCntName]
    local mMonsterRadio = {}
    local mNumRadio = {}
    for iMonster, mAmount in pairs(mInfo) do
        local mTmp = {}
        for iAmount, sRatio in pairs(mAmount.num_radio) do
            if tonumber(sRatio) then
                mTmp[iAmount] = tonumber(sRatio)
            else
                mTmp[iAmount] = formula_string(sRatio, mEnv)
            end
        end
        mNumRadio[iMonster] = mTmp
        mMonsterRadio[iMonster] = mAmount.monster_radio
    end
    return mMonsterRadio, mNumRadio
end

function AddNpcWarrior(oAction, iMonster, iPos)
    local oWar = oAction:GetWar()
    local mAllMonsterInfo = oAction:GetData("all_monster", {})
    local mMonster = table_deep_copy(mAllMonsterInfo[iMonster])
    if not mMonster then return end


    local oWarrior = oWar:AddNpcWarrior(2, mMonster, iPos, 0, true)

    local func = function(oAction, mCmd)
        return {cmd="defense", data={action_wid=oAction:GetWid()}}
    end
    oWarrior:AddFunction("ChangeCmd", 100001, func)

    local func = function(oAction, oAttack)
        OnDeadCommon(oAction, oAttack)
    end
    oWarrior:AddFunction("OnDead", 100001, func)
end

function OnDeadCommon(oAction, oAttack)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local iNpcIdx = oAction:GetData("type", 0)
    local mMsg = res["daobiao"]["huodong"]["moneytree"]["text"][iNpcIdx]
    if mMsg and mMsg.content then
        local sText = util.FormatColorString(mMsg.content, {role = oAttack:GetName()})
        NotifyAll(oWar, sText)
    end

    --治疗
    if iNpcIdx == 10013 or iNpcIdx == 20013 then
        for _, oWarrior in pairs(oAttack:GetFriendList(true)) do
            if oWarrior and oWarrior:IsAlive() then
                local iHp = math.floor(oWarrior:GetMaxHp()*30/100)
                if iHp > 0 then
                    global.oActionMgr:DoAddHp(oWarrior, iHp)
                end
            end
        end
    end
end

function NotifyAll(oWar, sMsg)
    local lWarrior = oWar:GetPlayerWarriorList()
    local iType = gamedefines.CHANNEL_TYPE.MSG_TYPE
    for _, oWarrior in pairs(lWarrior) do
        oWarrior:Notify(sMsg, 0x1|0x2, 1)
    end
end
