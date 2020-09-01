--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local res = require "base.res"
local gamedefines = import(lualib_path("public.gamedefines"))


function NewTargetMgr(...)
    local o = CTargetMgr:New(...)
    return o
end

CTargetMgr = {}
CTargetMgr.__index = CTargetMgr
inherit(CTargetMgr, logic_base_cls())

function CTargetMgr:New(...)
    local o = super(CTargetMgr).New(self)
    return o
end

function CTargetMgr:GetConfig()
    return res["daobiao"]["ai"]["target"]
end

function CTargetMgr:ChooseAITarget(iType, oAttack, lTarget, ...)
    local mConfig = self:GetConfig()
    local sFunc = mConfig[iType]["func"]
    local sArgs = mConfig[iType]["args"]

    assert(self[sFunc], "ai target doesn't exist func:" .. sFunc)

    return self[sFunc](self, oAttack, lTarget, sArgs, ...)
end

function CTargetMgr:Default(oAttack, lTarget, ...)
    return self:Random(oAttack, lTarget, ...)
end

function CTargetMgr:Random(oAttack, lTarget, ...)
    if next(lTarget) then
        local oTarget = lTarget[math.random(#lTarget)]
        return oTarget:GetWid()
    end
end

function CTargetMgr:HpMax(oAttack, lTarget, ...)
    if next(lTarget) then
        local iMaxHp, iTarget = 0, nil
        for _, oTarget in pairs(lTarget) do
            if iMaxHp < oTarget:GetHp() then
                iMaxHp = oTarget:GetHp()
                iTarget = oTarget:GetWid()
            end
        end
        return iTarget
    end
end

function CTargetMgr:HpMin(oAttack, lTarget)
    if next(lTarget) then
        local iMaxHp, iTarget = 0xffffff, nil
        for _, oTarget in pairs(lTarget) do
            if oTarget:GetHp() <= oTarget:GetMaxHp() and iMaxHp > oTarget:GetHp() then
                iMaxHp = oTarget:GetHp()
                iTarget = oTarget:GetWid()
            end
        end
        return iTarget
    end
end

function CTargetMgr:MagDefenseMin(oAttack, lTarget, ...)
    if next(lTarget) then
        local iMin, iTarget = 0xffffff, nil
        for _, oTarget in pairs(lTarget) do
            local iVal = oTarget:QueryAttr("mag_defense")
            if iMin > iVal then
                iMin, iTarget = iVal, oTarget:GetWid()
            end
        end
        return iTarget
    end
end

function CTargetMgr:HpLess(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        local iRatio = mArgs.ratio or 50
        local iTarget, iHp = nil, nil
        for _, oTarget in pairs(lTarget) do
            if oTarget:GetHp() <= oTarget:GetMaxHp() * iRatio/100 then
                if not iHp or iHp > oTarget:GetHp() then
                    iTarget, iHp = oTarget:GetWid(), oTarget:GetHp()
                end
            end
        end
        return iTarget
    end
end

function CTargetMgr:HpMore(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        local iRatio = mArgs.ratio or 50
        local iTarget, iHp, iTotal = nil, nil, 0
        for _, oTarget in pairs(lTarget) do
            if oTarget:GetHp() >= oTarget:GetMaxHp() * iRatio/100 then
                if not iHp or iHp > oTarget:GetHp() then
                    iTarget, iHp = oTarget:GetWid(), oTarget:GetHp()
                    iTotal = iTotal + 1
                end
            end
        end
        if mArgs.all == true and iTotal == #lTarget then
            return iTarget
        end
        if not mArgs.all then return iTarget end
    end
end

function CTargetMgr:FriendHpMore(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        local iRatio = mArgs.ratio or 50
        local iTotal = 0
        local lFriend = oAttack:GetFriendList(true)
        for _, oFriend in pairs(lFriend) do
            if oFriend:GetHp() < oFriend:GetMaxHp() * iRatio/100 then
                return
            end
        end
        return self:Random(oAttack, lTarget)
    end
end

function CTargetMgr:BeSealed(oAttack, lTarget, ...)
    if next(lTarget) then
        local lResult = {}
        for _, oTarget in pairs(lTarget) do
            if oTarget:IsSealed() then
                table.insert(lResult, oTarget:GetWid())
            end
        end
        if next(lResult) then
            return extend.Random.random_choice(lResult)
        end
    end
end

function CTargetMgr:UnChangeShape(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lResult = {}
        local mArgs = formula_string(sArgs, {})
        local iBuffID = mArgs.changed
        for _, oTarget in pairs(lTarget) do
            if not oTarget.m_oBuffMgr:HasBuff(iBuffID) then
                table.insert(lResult, oTarget:GetWid())
            end
        end

        if next(lResult) then
            return extend.Random.random_choice(lResult)
        end
    end
end

function CTargetMgr:UnExistBuffList(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lResult = {}
        local mArgs = formula_string(sArgs, {})
        local lBuffList = mArgs.buff_list
        for _, oTarget in pairs(lTarget) do
            for _, iBuff in ipairs(lBuffList) do
                if oTarget.m_oBuffMgr:HasBuff(iBuff) then
                    goto continue
                end
            end
            table.insert(lResult, oTarget:GetWid())
            ::continue::
        end

        if next(lResult) then
            return extend.Random.random_choice(lResult)
        end
    end
end

function CTargetMgr:TargetMore(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        if #lTarget >= mArgs.limit then
            local oTarget = extend.Random.random_choice(lTarget)
            return oTarget:GetWid()
        end
    end
end

function CTargetMgr:TargetLess(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        if next(lTarget) and #lTarget <= mArgs.limit then
            local oTarget = extend.Random.random_choice(lTarget)
            return oTarget:GetWid()
        end
    end
end

function CTargetMgr:Target7302(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        if oAttack:GetHp() <= oAttack:GetMaxHp()*mArgs.hp//100 then
            return
        end
        if next(lTarget) and #lTarget <= mArgs.limit then
            local oTarget = extend.Random.random_choice(lTarget)
            return oTarget:GetWid()
        end
    end
end

function CTargetMgr:Target7303(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        if oAttack:GetHp() > oAttack:GetMaxHp()*mArgs.hp//100 then
            return
        end
        if oAttack.m_oBuffMgr:HasBuff(mArgs.buff) then
            return
        end
        if #lTarget < mArgs.limit then
            return
        end
        local lVictim = {}
        for _, oTarget in pairs(lTarget) do
            if oTarget:GetData("school") == mArgs.school then
                table.insert(lVictim, oTarget:GetWid())
            end
        end
        if #lVictim < mArgs.limit then
            return
        end
        return extend.Random.random_choice(lVictim)
    end
end

function CTargetMgr:Target8302(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        if oAttack:GetHp() <= oAttack:GetMaxHp()*mArgs.hp//100 then
            return
        end
        return self:HpLess(oAttack, lTarget, "{ratio=101}", ...)
    end
end

function CTargetMgr:Target7502(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lVictim = {}
        local mArgs = formula_string(sArgs, {})
        local lEnemy = oAttack:GetEnemyList()
        for _, oTarget in pairs(lEnemy) do
            if oTarget:IsSealed() then goto continue end
            if oTarget:HasKey("ghost") then goto continue end

            if oTarget:IsSummonLike() then return end
            if oTarget:IsPlayerLike() or oTarget:IsPartnerLike() then
                local iSchool = oTarget:GetData("school", 0)
                if extend.Array.member(mArgs.school, iSchool) then
                    table.insert(lVictim, oTarget:GetWid())
                else
                    return
                end
            end
            ::continue::
        end
        if next(lVictim) then
            return extend.Random.random_choice(lVictim)
        end
    end
end

function CTargetMgr:Target7503(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        local lPlayer, lSummon, lOther = {}, {}, {}
        for _, oTarget in pairs(lTarget) do
            if oTarget:IsSealed() then goto continue end
            if oTarget:HasKey("ghost") then goto continue end

            if oTarget:IsPlayerLike() or oTarget:IsPartnerLike() then
                local iSchool = oTarget:GetData("school", 0)
                if extend.Array.member(mArgs.school, iSchool) then
                    table.insert(lPlayer, oTarget)
                end
            elseif oTarget:IsSummonLike() then
                table.insert(lSummon, oTarget)
            else
                table.insert(lOther, oTarget)
            end
            ::continue::
        end
        if next(lPlayer) then
            return self:Random(oAttack, lPlayer, ...)
        end
        for _, lWarrior in ipairs({lSummon, lOther}) do
            if next(lWarrior) then
                return self:Random(oAttack, lWarrior, ...)
            end
        end
    end
end

function CTargetMgr:Target7602(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        local lPlayer, lSummon, lOther, lPartner = {}, {}, {}, {}
        for _, oTarget in pairs(lTarget) do
            if oTarget:IsSealed() then goto continue end
            if oTarget:HasKey("ghost") then goto continue end

            if oTarget:IsPlayerLike() then
                table.insert(lPlayer, oTarget)
            elseif oTarget:IsSummonLike() then
                table.insert(lSummon, oTarget)
            elseif oTarget:IsPartnerLike() then
                table.insert(lPartner, oTarget)
            else
                table.insert(lOther, oTarget)
            end
            ::continue::
        end
        local oPerform = oAttack:GetPerform(7606)
        if oPerform then
            for _, lWarrior in pairs({lPlayer, lPartner}) do
                for _, oWarrior in pairs(lWarrior) do
                    if oWarrior:GetData("school") == mArgs.school then
                        return oWarrior:GetWid()
                    end
                end
            end
        end
        for _, lWarrior in pairs({lPlayer, lPartner, lSummon, lOther}) do
            for _, oWarrior in pairs(lWarrior) do
                return oWarrior:GetWid()
            end
        end
    end
end

function CTargetMgr:Target7603(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mArgs = formula_string(sArgs, {})
        local lUnSealed = {}
        for _, oTarget in pairs(lTarget) do
            if not oTarget:IsSealed() and not oTarget:HasKey("ghost") then
                table.insert(lUnSealed, oTarget)
            end
        end
        if next(lUnSealed) and #lUnSealed <= mArgs.limit then
            local oTarget = extend.Random.random_choice(lUnSealed)
            return oTarget:GetWid()
        end
    end
end

function CTargetMgr:Revive(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lPlayer, lCure, lOther = {}, {}, {}
        for _, oTarget in pairs(lTarget) do
            if oAttack.m_iOwner and oAttack.m_iOwner == oTarget.m_iPid then
                return oTarget:GetWid()
            end
            local iHasPerform = oTarget:GetHasPerformType()
            if oTarget:IsPlayerLike() then
                table.insert(lPlayer, oTarget:GetWid())
            elseif iHasPerform & (1<<gamedefines.WAR_ACTION_TYPE.CURE) == (1<<gamedefines.WAR_ACTION_TYPE.CURE) then
                table.insert(lCure, oTarget:GetWid())
            else
                table.insert(lOther, oTarget:GetWid())
            end
            ::continue::
        end
        for _, lWarrior in pairs({lPlayer, lCure, lOther}) do
            if next(lWarrior) then
                return extend.Random.random_choice(lWarrior)
            end
        end
    end
end

function CTargetMgr:Target7902(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lResult = {}
        local mArgs = formula_string(sArgs, {})
        local lBuffList = mArgs.buff_list
        for _, oTarget in pairs(lTarget) do
            for _, iBuff in ipairs(lBuffList) do
                if oTarget.m_oBuffMgr:HasBuff(iBuff) then
                    goto continue
                end
            end
            if oTarget:HasKey("ghost") then
                goto continue
            end
            table.insert(lResult, oTarget)
            ::continue::
        end
        local iWid, iHp = nil, 0
        for _, oTarget in pairs(lResult) do
            if oTarget:GetHp() > iHp then
                iWid = oTarget:GetWid()
                iHp = oTarget:GetHp()
            end
        end
        return iWid
    end
end

function CTargetMgr:Target8003(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lOther, lPlayer = {}, {}
        local mArgs = formula_string(sArgs, {})
        for _, oTarget in pairs(lTarget) do
            if not oTarget:IsSealed() then goto continue end

            if oAttack.m_iOwner and oAttack.m_iOwner == oTarget.m_iPid then
                return oTarget:GetWid()
            end
            if oTarget:IsPlayerLike() then
                table.insert(lPlayer, oTarget)
            else
                table.insert(lOther, oTarget)
            end
            ::continue::
        end

        if next(lPlayer) then
            for _, oWarrior in pairs(lPlayer) do
                if extend.Array.member(mArgs.school, oWarrior:GetData("school")) then
                    return oWarrior:GetWid()
                end
            end
        end
        for _, lWarrior in pairs({lPlayer, lOther}) do
            if next(lWarrior) then
                local oTarget = extend.Random.random_choice(lWarrior)
                return oTarget:GetWid()
            end
        end
    end
end

function CTargetMgr:SchoolSeq(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local mResult = {}
        for _, oTarget in pairs(lTarget) do
            local iSchool = oTarget:GetData("school", 0)
            if not mResult[iSchool] then
                mResult[iSchool] = {}
            end
            table.insert(mResult[iSchool], oTarget:GetWid())
        end
        local mArgs = formula_string(sArgs, {})
        for _, iSchool in ipairs(mArgs.school) do
            if mResult[iSchool] and next(mResult[iSchool]) then
                return extend.Random.random_choice(mResult[iSchool])
            end
        end
        for iSchool, mInfo in pairs(mResult) do
            return extend.Random.random_choice(mInfo)
        end
    end
end

function CTargetMgr:PosFirst(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local oWar = oAttack:GetWar()
        if not oWar then return end

        local mArgs = formula_string(sArgs, {})
        local iCamp = 3 - oAttack:GetCampId()
        local lPosList = self:GetPosPair()
        local mWarrior = {}
        for _, oTarget in pairs(lTarget) do
            mWarrior[oTarget:GetWid()] = 1
        end
        local lResult = {}
        for _, lPos in pairs(lPosList) do
            local iPre, iTail = table.unpack(lPos)
            local oPre = oWar:GetWarriorByPos(iCamp, iPre)
            local oTail = oWar:GetWarriorByPos(iCamp, iTail)
            if oPre and oTail and mWarrior[oPre:GetWid()] and mWarrior[oTail:GetWid()] then
                table.insert(lResult, {oPre:GetWid(), oTail:GetData("school", 0)})
            end
        end
        if next(lResult) then
            for _, iSchool in pairs(mArgs.school) do
                for _, lInfo in pairs(lResult) do
                    local iWid, iSch = table.unpack(lInfo)
                    if iSch == iSchool then
                        return iWid
                    end
                end
            end
            local lInfo = extend.Random.random_choice(lResult)
            return lInfo[1]
        end
    end
end

function CTargetMgr:GetPosPair()
    local lPos = {}
    for i = 6, 10 do
        table.insert(lPos, {i, i-5})
    end
    for i = 1, 3 do
        table.insert(lPos, {i, i+10})
    end
    table.insert(lPos, {11, 14})
    return lPos
end

function CTargetMgr:UnSealed(oAttack, lTarget, ...)
    if next(lTarget) then
        local lResult = {}
        for _, oTarget in pairs(lTarget) do
            if not oTarget:IsSealed() then
                table.insert(lResult, oTarget:GetWid())
            end
        end
        if next(lResult) then
            return extend.Random.random_choice(lResult)
        end
    end
end

function CTargetMgr:NoBuff(oAttack, lTarget, sArgs, ...)
    if next(lTarget) then
        local lResult = {}
        local iMaxHp, iTarget = 0, nil
        local mArgs = formula_string(sArgs, {})
        local iBuffID = mArgs.buff
        local bMaxHp = mArgs.maxhp
        for _, oTarget in pairs(lTarget) do
            if not oTarget.m_oBuffMgr:HasBuff(iBuffID) then
                if bMaxHp then
                    local iHp = oTarget:GetHp()
                    if iMaxHp < iHp then
                        iMaxHp = iHp
                        iTarget = oTarget:GetWid()
                    end
                else
                    table.insert(lResult, oTarget:GetWid())
                end
            end
        end

        if bMaxHp then
            return iTarget
        else
            if next(lResult) then
                return extend.Random.random_choice(lResult)
            end
        end
    end
end

function CTargetMgr:SpeedMax(oAttack, lTarget, ...)
    if next(lTarget) then
        local iMaxSpeed, iTarget = 0, nil
        for _, oTarget in pairs(lTarget) do
            if iMaxSpeed < oTarget:QueryAttr("speed") then
                iMaxSpeed = oTarget:QueryAttr("speed")
                iTarget = oTarget:GetWid()
            end
        end
        return iTarget
    end
end
