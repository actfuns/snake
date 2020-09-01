--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"
local res = require "base.res"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewActionMgr(...)
    local o = CActionMgr:New(...)
    return o
end

CActionMgr = {}
CActionMgr.__index = CActionMgr
inherit(CActionMgr, logic_base_cls())

function CActionMgr:New()
    local o = super(CActionMgr).New(self)
    return o
end

function CActionMgr:WarSkill(oAttack, lVictim, iSkill)
    local oWar = oAttack:GetWar()
    --lxldebug
    if iSkill == 1 then
        self:RemoteSkill(oAttack, lVictim, iSkill)
    elseif iSkill == 2 then
        self:NearSkill(oAttack, lVictim, iSkill)
    elseif iSkill > 100 then
        local oVictim = self:ChoosePerformVictim(oAttack, lVictim, iSkill)
        if not oVictim then
            return
        end
        self:Perform(oAttack, oVictim, iSkill)
    else
        record.error(string.format("lxldebug WarSkill unknown skill %d", iSkill))
    end
end

function CActionMgr:ChoosePerformVictim(oAttack, lVictim, iSkill)
    local oPerform = oAttack:GetPerform(iSkill)
    if not oPerform then
        return
    end
    if not oPerform:CanPerform() then
        return
    end
    lVictim = lVictim or {}
    local oVictim = lVictim[1]
    if not oVictim or not oVictim:IsVisible(oAttack) then
        if oPerform:TargetType() == 1 then
            local lVictim = oAttack:GetFriendList()
            oVictim = lVictim[1]
        elseif oPerform:TargetType() == 2 then
            local lVictim = oAttack:GetEnemyList()
            oVictim = lVictim[1]
        end
    end
    return oVictim
end

function CActionMgr:WarEscape(oAction)
    local oWar = oAction:GetWar()
    if not oWar then
        return
    end

    local iBase = 80
    local iRan = math.random(100)
    local iRatio = iBase + oAction:GetExtData("escape_ratio",0)

    local mFunc = oAction:GetFunction("CheckEscapeRatio")
    for _,fCallback in pairs(mFunc) do
        iRatio = iRatio + fCallback(oAction, iRatio)
    end

    local sMsg = string.format("#B%s#n逃跑,固定概率%d%%,逃跑加成%d%%",oAction:GetName(),iBase,oAction:GetExtData("escape_ratio",0))
    oWar:AddDebugMsg(sMsg, true)
    if iRan < iRatio then

        local mFunc = oAction:GetFunction("OnEscape")
        for _,fCallback in pairs(mFunc) do
            safe_call(fCallback, oAction)
        end

        oAction:SendAll("GS2CWarEscape", {
            war_id = oAction:GetWarId(),
            action_wid = {oAction:GetWid()},
            success = true,
        })
        oWar:AddAnimationTime(1 * 1000)

        if oAction:Type() == gamedefines.WAR_WARRIOR_TYPE.PLAYER_TYPE then
            oWar:LeavePlayer(oAction:GetPid(),true)
        else
            oWar:SendAll("GS2CWarDelWarrior", {
                war_id = oAction:GetWarId(),
                wid = oAction:GetWid(),
            })
            oAction:Leave()
            oWar:Leave(oAction)
        end
    else
        oAction:SendAll("GS2CWarEscape", {
            war_id = oAction:GetWarId(),
            action_wid = {oAction:GetWid()},
            success = false,
        })
        oWar:AddAnimationTime(1 * 1000)
    end
end

function CActionMgr:GetFightSummonCnt(oAction)
    local lConfig = res["daobiao"]["summon"]["config"][1]['fight_count']
    local iCnt = 1
    for _,v in pairs(lConfig) do
        if oAction:GetData("grade") > v.grade then
            iCnt = v.num
        end
    end
    return iCnt
end

function CActionMgr:WarSummon(oAction,mData)
    local oWar = oAction:GetWar()
    if not oWar then
        return
    end
    local mSumData = mData["sumdata"]
    local sum_id = mSumData["sum_id"]
    local mSummon = oAction:Query("summon",{})
    if mSumData["sumdata"]["unablefight"] then
        oAction:Notify(mSumData["sumdata"]["msg"] or "无法参战")
        return
    end
    if mSummon[sum_id] then
        oAction:Notify("该宠物已经参战过，无法再次参战")
        return
    end
    local iFightCnt = self:GetFightSummonCnt(oAction)
    if table_count(mSummon) >= iFightCnt then
        oAction:Notify(string.format("最多可以%s只宠物参战", iFightCnt))
        return
    end
    if mSumData["sumdata"]["grade"] > oAction:GetData("grade") + 10 then
        oAction:Notify(string.format("%s的等级已经超过你10级，无法出战", mSumData["sumdata"]["name"]))
        return
    end
    if (mSumData["sumdata"]["carrygrade"] or 0) > oAction:GetData("grade") then
        oAction:Notify(string.format("%s的携带等级已经超过你等级，无法出战", mSumData["sumdata"]["name"]))
        return
    end

    local iPos = oAction:GetPos()
    local iSumPos = iPos + 5
    local iCamp = oAction:GetCampId()
    local oSummon = oWar:GetWarriorByPos(iCamp,iSumPos)
    if oSummon then
        oWar:SendAll("GS2CWarDelWarrior", {
            war_id = oAction:GetWarId(),
            wid = oSummon:GetWid(),
        })
        oWar:Leave(oSummon)
    end
    oWar:AddSummon(oAction,mSumData,true)
    oAction:Send("GS2CPlayerWarriorEnter",{
        war_id = oWar.m_iWarId,
        wid = oAction:GetWid(),
        sum_list = table_key_list(oAction:Query("summon",{}))
    })

    local iSumWid = oAction:Query("curr_sum")
    if iSumWid then
        local oSummon = oWar:GetWarrior(iSumWid)
        if oSummon then
            oSummon:SetAutoFight(oAction:IsOpenFight())
            oSummon:OnEnterWar()
        end
    end

    -- TODO debug 
    local oCurrSummon = oWar:GetWarrior(iSumWid)
    if not oCurrSummon or oCurrSummon:IsDead() then
        local bDead = oCurrSummon and 0 or 1
        record.error(string.format("liuzla-debug warsummon error %s %s", bDead, oAction:GetName()))
        print("liuzla-debug--warsummon--error-", mSummon, oAction:Query("summon",{}), mSumData)
    end
end

function CActionMgr:WarUseItem(oAction, oVictim, iPid, mItemData)
    local itemid = mItemData.itemid
    local mData = mItemData.data
    local waritemid = mData.waritemid
    local mArgs = mData.args
    local sTips = mData.tips

    local oWar = oAction:GetWar()
    if not oWar then return end

    local oWarItemMgr = global.oWarItemMgr
    local oWarItem = oWarItemMgr:GetWarItem(waritemid)
    if oWarItem:CanUseItem(oAction, mArgs, iPid, itemid)
        and oWarItem:CheckAction(oAction, oVictim, mArgs, iPid) then
        
        oAction:SendAll("GS2CWarUseItem", {
            war_id = oAction:GetWarId(),
            action_wid = oAction:GetWid(),
            select_wid = oVictim:GetWid(),
            item_id = waritemid,
        })

        oWar:AddAnimationTime(1300)

        local iCost = 1
        local iFreeRatio = oAction:QueryAttr("usedrug_free_ratio")
        local lFreeList = oAction:Query("usedrug_free_list", {})
        if extend.Array.member(lFreeList, mArgs.sid) and math.random(100) <= iFreeRatio then
            iCost = 0
        end

        oWarItem:Action(oAction, oVictim, mArgs, iPid)
        oWarItem:DoRecordUseItem(oAction, iPid, itemid)
        interactive.Send(".world", "war", "WarUseItem", {
            warid = oWar:GetWarId(),
            pid = iPid,
            itemid = itemid,
            amount = iCost,
            succ = true,
        })
        oWarItem:DoActionEnd(oAction, oVictim, mArgs, iPid, itemid, sTips)
    else
        interactive.Send(".world", "war", "WarUseItem", {
            warid = oWar:GetWarId(),
            pid = iPid,
            itemid = itemid,
            amount = 0,
        })
    end
end

function CActionMgr:GetNormalAttackTime(oAction, idx)
    local mMagicTime = res["magictime"]
    local iShape = oAction:GetShape()
    local mTime = table_get_depth(mMagicTime, {101, iShape, 1})
    if mTime then return mTime end
    local mTime = table_get_depth(mMagicTime, {101, 1, 1})
    if mTime then return mTime end
    return {1000, 1600}
end

function CActionMgr:WarNormalAttack(oAction, oVictim, mArgs)
    mArgs = mArgs or {}
    if oAction:HasKey("attack_disable") and not mArgs.ignore then
        if oAction:IsPlayer() or oAction:IsSummon() then
            oAction:Notify("当前无法行动", 1<<2)
        end
        return
    end
    local oWar = oAction:GetWar()
    if oAction:HasKey("phymock") and not mArgs.hit_back then
        local w = oWar:GetWarrior(oAction:GetKey("phymock"))
        if w then
            oVictim = w
        end
    end
    oAction:SendAll("GS2CWarNormalAttack", {
        war_id = oAction:GetWarId(),
        action_wid = oAction:GetWid(),
        select_wid = oVictim:GetWid(),
    })

    local mTime = self:GetNormalAttackTime(oAction)
    oWar:AddAnimationTime(mArgs.perform_time or mTime[1])

    local iHitRatio = oAction:QueryAttr("phy_hit_ratio") - oVictim:QueryAttr("phy_hit_res_ratio")
    if math.random(100) > iHitRatio then
        oAction:SendAll("GS2CWarDamage", {
            war_id = oVictim:GetWarId(),
            wid = oVictim:GetWid(),
            type = gamedefines.WAR_RECV_DAMAGE_FLAG.MISS,
            damage = 0,
        })
        if not mArgs.perform_time then
            oWar:AddAnimationTime(800)
        end
        oAction:SendAll("GS2CWarGoback", {
            war_id = oAction:GetWarId(),
            action_wid = oAction:GetWid(),
        })
        return
    end

    local oNewVictim, bEngage = oVictim:GetGuard()
    if oNewVictim then
        oAction:SendAll("GS2CWarProtect", {
            war_id = oNewVictim:GetWarId(),
            action_wid = oNewVictim:GetWid(),
            select_wid = oVictim:GetWid(),
        })
        if bEngage then
            oNewVictim:AddBoutArgs("engage_protect_cnt", 1)
        else
            oNewVictim:AddBoutArgs("protect_cnt", 1)    
        end

        oNewVictim:SetProtect(oVictim:GetWid())
        mArgs = mArgs or {}
        mArgs["protect"] = true
        mArgs["normal_hit"] = true
        self:DoNormalAttack(oAction, oNewVictim, mArgs)
        oWar:AddAnimationTime(300)
        oAction:SendAll("GS2CWarGoback", {
            war_id = oNewVictim:GetWarId(),
            action_wid = oNewVictim:GetWid(),
        })
    else
        mArgs = mArgs or {}
        mArgs["normal_hit"] = true
        self:DoNormalAttack(oAction, oVictim, mArgs)
    end

    if not mArgs.perform_time then
        --原位置上反击,不添加返回时间
        oWar:AddAnimationTime(800)
    end
    oAction:SendAll("GS2CWarGoback", {
        war_id = oAction:GetWarId(),
        action_wid = oAction:GetWid(),
    })
end

function CActionMgr:RemoteSkill(oAction, lVictim, iSkill)
    local oWar = oAction:GetWar()
    local lVictim = oWar:ChooseRandomEnemy(oAction)
    oAction:SendAll("GS2CWarSkill", {
        war_id = oAction:GetWarId(),
        action_wlist = {oAction:GetWid(),},
        select_wlist = list_generate(lVictim, function (v)
            return v:GetWid()
        end),
        skill_id = iSkill,
        magic_id = 1,
    })
    oWar:AddAnimationTime(3 * 1000)

    for _, oVictim in ipairs(lVictim) do
        self:DoSkill(oAction, oVictim, iSkill)
    end
end

function CActionMgr:NearSkill(oAction, lVictim, iSkill)
    local oWar = oAction:GetWar()
    local lVictim = oWar:ChooseRandomEnemy(oAction)

    for _, oVictim in ipairs(lVictim) do
        oAction:SendAll("GS2CWarSkill", {
            war_id = oAction:GetWarId(),
            action_wlist = {oAction:GetWid(),},
            select_wlist = {oVictim:GetWid(),},
            skill_id = iSkill,
            magic_id = 1,
        })
        oWar:AddAnimationTime(2 * 1000)
        self:DoSkill(oAction, oVictim, iSkill)
    end

    oAction:SendAll("GS2CWarGoback", {
        war_id = oAction:GetWarId(),
        action_wid = oAction:GetWid(),
    })

end

function CActionMgr:DoSkill(oAction, oVictim, iSkill)
    local iDamage = math.random(-10,-1)
    local iFlag = 0
    if iDamage == 0 then
        iFlag = gamedefines.WAR_RECV_DAMAGE_FLAG.MISS
        oAction:SendAll("GS2CWarDamage", {
            war_id = oVictim:GetWarId(),
            wid = oVictim:GetWid(),
            type = iFlag,
            damage = 0,
        })
        return
    end

    if oVictim:IsDefense() then
        if iDamage < 0 then
            iDamage = math.min(-1, iDamage + 5)
            iFlag = gamedefines.WAR_RECV_DAMAGE_FLAG.DEFENSE
        end
    end
    if iDamage > 0 then
        oVictim:AddHp(iDamage)
    elseif iDamage < 0 then
        oVictim:SubHp(math.abs(iDamage), oAction)
    end
    oAction:SendAll("GS2CWarDamage", {
        war_id = oVictim:GetWarId(),
        wid = oVictim:GetWid(),
        type = iFlag,
        damage = iDamage,
    })
end

function CActionMgr:DoNormalAttack(oAction, oVictim, mArgs)
    local iHitRatio = oAction:QueryAttr("phy_hit_ratio") - oVictim:QueryAttr("phy_hit_res_ratio")
    local bHit = false
    if mArgs.normal_hit or math.random(100) <= iHitRatio then
        bHit =  true
    end
    local oWar = oAction:GetWar()
    oWar:AddDebugMsg(string.format("#B%s#n对#B%s#n使用平砍，命中%d,闪避%d",
        oAction:GetName(),
        oVictim:GetName(),
        oAction:QueryAttr("phy_hit_ratio"),
        oVictim:QueryAttr("phy_hit_res_ratio")
    ), true)
    if not bHit then
        local iFlag = gamedefines.WAR_RECV_DAMAGE_FLAG.MISS
        oAction:SendAll("GS2CWarDamage", {
            war_id = oVictim:GetWarId(),
            wid = oVictim:GetWid(),
            type = iFlag,
            damage = 0,
        })
        return
    end

    local iDamage = 0
    local iFlag = 0
    local iCritFlag
    if oVictim:IsDefense() then
        iFlag = gamedefines.WAR_RECV_DAMAGE_FLAG.DEFENSE
    end

    local oTrueTarget = oVictim
    local oProtect = oVictim:GetProtect()
    if mArgs and mArgs["protect"] and oProtect then
        iDamage = self:CalNormalDamage(oAction,oProtect,mArgs)

        if oAction:QueryBoutArgs("IsPhyCrit") then
            iCritFlag = 1
            oAction:SetBoutArgs("IsPhyCrit",nil)
        end

        local iSubHp = math.max(1, math.floor(iDamage*0.75))
        self:DoSubHp(oVictim, iSubHp, oAction, {crit=iCritFlag})

        oTrueTarget = oProtect
        oVictim:SetProtect()
        local iRealDamage = math.max(1, math.floor(iDamage*0.25))
        -- self:DoSubHp(oProtect, iRealDamage, oAction, {crit=iCritFlag})
        self:DoReceiveDamage(oProtect, iRealDamage, oAction, nil, {crit=iCritFlag, normal_attack=1})
    else
        iDamage = self:CalNormalDamage(oAction,oVictim,mArgs)
        local bImmune, iRealDamage = oVictim:OnImmuneDamage(oAction, nil, iDamage)
        iDamage = iRealDamage
        if bImmune then return end

        if oAction:QueryBoutArgs("IsPhyCrit") then
            iCritFlag = 1
            oAction:SetBoutArgs("IsPhyCrit",nil)
        end

        -- oAction:SendAll("GS2CWarDamage", {
        --     war_id = oVictim:GetWarId(),
        --     wid = oVictim:GetWid(),
        --     type = iFlag,
        --     damage = -iDamage,
        --     iscrit = iCritFlag
        -- })
        -- oVictim:ReceiveDamage(oAction,nil,iDamage)
        self:DoReceiveDamage(oVictim, iDamage, oAction, nil, {crit=iCritFlag, flag=iFlag, normal_attack=1})
    end

    mArgs.is_critical = iCritFlag
    if not oAction:QueryBoutArgs("DoubleAttack") then
        oAction:OnAttack(oTrueTarget, nil, iDamage, mArgs)
        oAction:OnAttack2(oTrueTarget, nil, iDamage, mArgs)
    end
    if oTrueTarget and not oTrueTarget:IsDead() then
        oTrueTarget:OnAttacked(oAction, nil, iDamage, mArgs)
    end
    if not oAction:QueryBoutArgs("DoubleAttack") then
        oAction:OnAttackDelay(oTrueTarget, nil, iDamage, mArgs)
    end
end

function CActionMgr:ValidPerform(oAttack, oVictim, oPerform, bNotify)
    if bNotify == nil then
        bNotify = true
    end
    if oPerform:IsDisabled(oAttack, bNotify) then
        return
    end
    if oPerform:InCD(oAttack) then
        return
    end
    if oPerform:TargetType() == 1 then
        if not oAttack:IsFriend(oVictim) then
            return
        end
    elseif oPerform:TargetType() == 2 then
        if not oAttack:IsEnemy(oVictim) then
            return
        end
    end
    if not oPerform:SelfValidCast(oAttack, oVictim) then
        return
    end
    local oVictim = oPerform:ValidCast(oAttack, oVictim)
    if not oVictim then
        return
    end
    local mResume = oPerform:ValidResume(oAttack, oVictim, bNotify)
    if not mResume then
        return
    end
    return true, mResume
end

function CActionMgr:Perform(oAttack,oVictim,iPerform)
    local oPerform = oAttack:GetPerform(iPerform)
    assert(oPerform, string.format("CActionMgr:Perform err:%d", iPerform))
    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg("", true)
    local bRet, mResume = self:ValidPerform(oAttack, oVictim, oPerform)
    if not bRet then return end

    oPerform:DoResume(oAttack,mResume)
    local mTarget = oPerform:PerformTarget(oAttack,oVictim)
    local lVictim = {}
    for _,iWid in ipairs(mTarget) do
        table.insert(lVictim,oWar:GetWarrior(iWid))
    end
    oPerform:Perform(oAttack,lVictim)
end

--物理多段攻击
function CActionMgr:PerformPhyManyAttack(oAttack, lVictim, oPerform, iDamageRatio)
    local oWar = oAttack:GetWar()

    for i = 1, #lVictim do
        if not oAttack or oAttack:IsDead() then
            break
        end
        local oVictim = lVictim[i]
        if not oVictim or oVictim:IsDead() then
            break
        end
        local iMagicId = 2
        if i == 1 then iMagicId = 1 end

        oAttack:SendAll("GS2CWarSkill", {
            war_id = oAttack:GetWarId(),
            action_wlist = {oAttack:GetWid(),},
            select_wlist = {oVictim:GetWid()},
            skill_id = oPerform:Type(),
            magic_id = iMagicId,
        })
        local mTime = oPerform:PerformMagicTime(oAttack, iMagicId)
        oWar:AddAnimationTime(mTime[1])
        local iAttackedTime = oVictim:GetAttackedTime()
        local iVictimTime = oPerform:GetData("VictimTime", 0)
        if iAttackedTime > iVictimTime then
            oPerform:SetData("VictimTime", iAttackedTime)
        end

        local iAttackCnt = oPerform:GetData("PerformAttackCnt",0)
        iAttackCnt = iAttackCnt + 1
        oPerform:SetData("PerformAttackCnt",iAttackCnt)
        self:TryDoPhyAttack(oAttack, oVictim, oPerform, iDamageRatio)
    end
    oWar:AddAnimationTime(oPerform:GetData("VictimTime", 0))
    oPerform:SetData("PerformAttackCnt",nil)
    oPerform:SetData("VictimTime", nil)
    if oAttack and not oAttack:IsDead() and oPerform:IsNearAction() then
        if oPerform:NeedBackTime() then
            oWar:AddAnimationTime(600)
        end
        oAttack:SendAll("GS2CWarGoback", {
            war_id = oAttack:GetWarId(),
            action_wid = oAttack:GetWid(),
        })
    end
end

--物理攻击一个目标多次
function CActionMgr:PerformPhyAttack(oAttack,oVictim,oPerform,iDamageRatio,iCnt)
    local oWar = oAttack:GetWar()

    for i=1,iCnt do
        if not oAttack or oAttack:IsDead() then
            break
        end
        if not oVictim or oVictim:IsDead() then
            break
        end
        local iMagicId = 2
        if i == iCnt then iMagicId = 3 end
        if i == 1 then iMagicId = 1 end

        oAttack:SendAll("GS2CWarSkill", {
            war_id = oAttack:GetWarId(),
            action_wlist = {oAttack:GetWid(),},
            select_wlist = {oVictim:GetWid()},
            skill_id = oPerform:Type(),
            magic_id = iMagicId,
        })
        local mTime = oPerform:PerformMagicTime(oAttack, iMagicId)
        if i == iCnt then
            oWar:AddAnimationTime(mTime[2])
            local iAttackedTime = oVictim:GetAttackedTime()
            oWar:AddAnimationTime(iAttackedTime)
        else
            oWar:AddAnimationTime(mTime[3])
        end
        local iAttackCnt = oPerform:GetData("PerformAttackCnt",0)
        iAttackCnt = iAttackCnt + 1
        oPerform:SetData("PerformAttackCnt",iAttackCnt)
        self:TryDoPhyAttack(oAttack,oVictim,oPerform,iDamageRatio)
    end

    oPerform:SetData("PerformAttackCnt",nil)
    if oAttack and not oAttack:IsDead() and oPerform:IsNearAction() then
        if oPerform:NeedBackTime() then
            oWar:AddAnimationTime(600)
        end
        oAttack:SendAll("GS2CWarGoback", {
            war_id = oAttack:GetWarId(),
            action_wid = oAttack:GetWid(),
        })
    end
end

--法术攻击一个目标多次
function CActionMgr:PerformMagAttack(oAttack,oVictim,oPerform,iDamageRatio,iCnt)
    local oWar = oAttack:GetWar()
    for i=1,iCnt do
        if not oAttack or oAttack:IsDead() then
            break
        end
        if not oVictim or oVictim:IsDead() then
            break
        end
        oAttack:SendAll("GS2CWarSkill", {
            war_id = oAttack:GetWarId(),
            action_wlist = {oAttack:GetWid(),},
            select_wlist = {oVictim:GetWid()},
            skill_id = oPerform.m_ID,
            magic_id = i,
        })
        local mTime = oPerform:PerformMagicTime(oAttack, i)
        if oWar then
            oWar:AddAnimationTime(mTime[1])
        end

        local iAttackCnt = oPerform:GetData("PerformAttackCnt",0)
        iAttackCnt = iAttackCnt + 1
        oPerform:SetData("PerformAttackCnt",iAttackCnt)
        self:DoMagAttack(oAttack,oVictim,oPerform,iDamageRatio)
    end
    oPerform:SetData("PerformAttackCnt",nil)
    if oAttack and not oAttack:IsDead() then
        if oPerform:IsNearAction() then
            if oPerform:NeedBackTime() then
                oWar:AddAnimationTime(600)
            end
            oAttack:SendAll("GS2CWarGoback", {
                war_id = oAttack:GetWarId(),
                action_wid = oAttack:GetWid(),
            })
        end
    end
end

function CActionMgr:TryDoPhyAttack(oAttack, oVictim, oPerform, iDamageRatio)
    local bHit = self:CalActionHit(oAttack,oVictim,oPerform,1)
    if not bHit then
        oAttack:SendAll("GS2CWarDamage", {
            war_id = oVictim:GetWarId(),
            wid = oVictim:GetWid(),
            type = gamedefines.WAR_RECV_DAMAGE_FLAG.MISS,
            damage = 0,
        })
        return
    end
    local oWar = oVictim:GetWar()
    local oGuarder, bEngage = oVictim:GetGuard()
    if oGuarder and (oPerform and not oPerform:IsGroupPerform()) then
        local mNet = {
            war_id = oGuarder:GetWarId(),
            action_wid = oGuarder:GetWid(),
            select_wid = oVictim:GetWid(),
        }
        oAttack:SendAll("GS2CWarProtect", mNet)
        if bEngage then
            oGuarder:AddBoutArgs("engage_protect_cnt", 1)
        else
            oGuarder:AddBoutArgs("protect_cnt", 1)    
        end
        local mArgs = {protect = true}
        self:DoPhyAttack(oAttack, oGuarder, oPerform, iDamageRatio, mArgs)

        local mNet = {
            war_id = oGuarder:GetWarId(),
            action_wid = oGuarder:GetWid(),
        }
        oWar:AddAnimationTime(300)
        oAttack:SendAll("GS2CWarGoback", mNet)
    else
        local mArgs = {}
        self:DoPhyAttack(oAttack, oVictim, oPerform, iDamageRatio, mArgs)
    end
end

function CActionMgr:DoPhyAttack(oAttack,oVictim,oPerform,iDamageRatio, mArgs)
    local iCritFlag
    local iDamage, iRealDamage, bImmune = 0, 0, false
    local oTrueTarget = oVictim
    mArgs = mArgs or {}

    local oProtecter = oVictim:GetProtect()
    if mArgs.protect and oProtecter then
        iDamage = self:CalPhyDamage(oAttack,oProtecter,oPerform,iDamageRatio)

        if oAttack:QueryBoutArgs("IsPhyCrit") then
            iCritFlag = 1
            oAttack:SetBoutArgs("IsPhyCrit",nil)
        end
        local iSubHp = math.max(1, math.floor(iDamage*0.75))
        self:DoSubHp(oVictim, iSubHp, oAttack, {crit=iCritFlag})

        oTrueTarget = oProtecter
        oVictim:SetProtect()
        local iRealDamage = math.max(1, math.floor(iDamage*0.25))
        -- self:DoSubHp(oProtecter, iRealDamage, oAttack, {crit=iCritFlag})
        self:DoReceiveDamage(oProtecter, iRealDamage, oAttack, oPerform, {crit=iCritFlag})
        self:CalPerformTotDamage(oPerform, iDamage)
    else
        iDamage = self:CalPhyDamage(oAttack,oVictim,oPerform,iDamageRatio)
        bImmune, iRealDamage = oVictim:OnImmuneDamage(oAttack, oPerform, iDamage)
        iDamage = iRealDamage
        if bImmune then return end

        if oAttack:QueryBoutArgs("IsPhyCrit") then
            iCritFlag = 1
            oAttack:SetBoutArgs("IsPhyCrit",nil)
        end

        local iFlag = gamedefines.WAR_RECV_DAMAGE_FLAG.DEFENSE
        if not oVictim:IsDefense() then
            iFlag = 0
        end
        -- local mNet = {
        --     war_id = oVictim:GetWarId(),
        --     wid = oVictim:GetWid(),
        --     type = iFlag,
        --     damage = -iRealDamage,
        --     iscrit = iCritFlag,
        -- }
        -- oAttack:SendAll("GS2CWarDamage", mNet)
        -- oVictim:ReceiveDamage(oAttack,oPerform,iDamage)
        self:DoReceiveDamage(oVictim, iRealDamage, oAttack, oPerform, {crit=iCritFlag, flag=iFlag})
        self:CalPerformTotDamage(oPerform, iDamage)
    end

    mArgs.is_critical = iCritFlag
    if not oAttack:QueryBoutArgs("DoubleAttack") then
        oAttack:OnAttack(oTrueTarget,oPerform,iDamage,mArgs)
        oAttack:OnAttack2(oTrueTarget,oPerform,iDamage,mArgs)
    end
    if oTrueTarget and not oTrueTarget:IsDead() then
        oTrueTarget:OnAttacked(oAttack,oPerform,iDamage,mArgs)
        oPerform:Effect_Condition_For_Victim(oTrueTarget,oAttack,{damage=iRealDamage})
    end
    if not oAttack:QueryBoutArgs("DoubleAttack") then
        oAttack:OnAttackDelay(oTrueTarget, oPerform, iDamage, mArgs)
    end
end

function CActionMgr:DoMagAttack(oAttack,oVictim,oPerform,iDamageRatio)
    local bHit = self:CalActionHit(oAttack,oVictim,oPerform,2)
    if not bHit then
        oAttack:SendAll("GS2CWarDamage", {
            war_id = oVictim:GetWarId(),
            wid = oVictim:GetWid(),
            type = gamedefines.WAR_RECV_DAMAGE_FLAG.MISS,
            damage = 0,
        })
        return
    end

    local iFlag = 0
    local iCritFlag
    if oVictim:IsDefense() then
        iFlag = gamedefines.WAR_RECV_DAMAGE_FLAG.DEFENSE
    end

    local iMagDamage = self:CalMagDamage(oAttack,oVictim,oPerform,iDamageRatio)
    local bImmune, iRealDamage = oVictim:OnImmuneDamage(oAttack, oPerform, iMagDamage)
    iMagDamage = iRealDamage
    if bImmune then return end

    if oAttack:QueryBoutArgs("IsMagCrit") then
        iCritFlag = 1
        oAttack:SetBoutArgs("IsMagCrit",nil)
    end

    -- oAttack:SendAll("GS2CWarDamage", {
    --     war_id = oVictim:GetWarId(),
    --     wid = oVictim:GetWid(),
    --     type = iFlag,
    --     damage = -iMagDamage,
    --     iscrit = iCritFlag,
    -- })
    -- local mArgs = {is_critical=iCritFlag}
    -- oVictim:ReceiveDamage(oAttack,oPerform,iMagDamage)
    self:DoReceiveDamage(oVictim, iMagDamage, oAttack, oPerform, {crit=iCritFlag, flag=iFlag})

    self:CalPerformTotDamage(oPerform, iMagDamage)
    if not oAttack:QueryBoutArgs("DoubleAttack") then
        oAttack:OnAttack(oVictim,oPerform,iMagDamage, mArgs)
        oAttack:OnAttack2(oVictim,oPerform,iMagDamage, mArgs)
    end
    if oVictim and not oVictim:IsDead() then
        oVictim:OnAttacked(oAttack,oPerform,iMagDamage, mArgs)
        oPerform:Effect_Condition_For_Victim(oVictim,oAttack, {damage=iMagDamage})
    end
    if not oAttack:QueryBoutArgs("DoubleAttack") then
        oAttack:OnAttackDelay(oVictim, oPerform, iMagDamage, mArgs)
    end
end

function CActionMgr:DoCureAction(oAttack,oVictim,oPerform,iPerformHP)
    if oVictim:IsDead() and (oVictim:HasKey("revive_disable") or oVictim:HasKey("ghost")) then 
        return
    end
    if oVictim:IsAlive() and oVictim:HasKey("disable_cure") then
        return
    end

--    local iCure_Power = oAttack:QueryAttr("cure_power")
--    local iHP = math.floor(iPerformHP + iCure_Power)
    local iHP = math.floor(iPerformHP)
    local iRatio = 100 + oAttack:QueryAttr("cure_ratio") + oVictim:QueryAttr("cured_ratio")

    local mFunc = oAttack:GetFunction("AddCureRatio")
    for _,fCallback in pairs(mFunc) do
        iRatio = iRatio + fCallback(oAttack, oVictim, oPerform)
    end

    local bRecoverSelf = false
    if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.JINSHAN then
        iRatio = iRatio + oAttack:GetAura() * self:GetWarConfig("aura_jinshan")
        if oAttack:GetAura() > 0 and math.random(100) <= self:GetWarConfig("aura_jinshan_cure") * oAttack:GetAura() then
            bRecoverSelf = true
        end
    end

    iHP = math.floor(iHP * iRatio / 100)

    local mFunc = oAttack:GetFunction("AddExtCurePower")
    for _,fCallback in pairs(mFunc) do
        iHP = iHP + fCallback(oAttack, oVictim, oPerform, iHP)
    end
    local bCritical = math.random(100) <= oAttack:QueryAttr("cure_critical_ratio")
    if bCritical then
        iHP = iHP * 2
    end
    if iHP > 0 then
        self:DoAddHp(oVictim, iHP, bCritical)
        if bRecoverSelf then
            oAttack:AddBoutArgs("recover_self_hp", iHP)
            oAttack:SetBoutArgs("recover_self_hp_critical", bCritical)
        end
    end

    if oVictim and not oVictim:IsDead() then
        oPerform:Effect_Condition_For_Victim(oVictim,oAttack)
    end

    local mFunc = oAttack:GetFunction("OnDoCureAction")
    for _,fCallback in pairs(mFunc) do
        safe_call(fCallback, oAttack, oVictim, oPerform, iHP)
    end

    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg(string.format("招式治疗%s,自己治疗加成%d%%,目标治疗加成%d%%,治疗结果加成%d%%,最终治疗量%d",
        iPerformHP,
        oAttack:QueryAttr("cure_ratio"),
        oVictim:QueryAttr("cured_ratio"),
        0,
        iHP
    ))
end

function CActionMgr:DoSealAction(oAttack,oVictim,oPerform,iMinRatio,iMaxRatio)
    local iRatio = self:CalSealRatio(oAttack,oVictim,oPerform,iMinRatio,iMaxRatio)
    if math.random(100) <= iRatio then
        if oVictim and not oVictim:IsDead() then
            oPerform:Effect_Condition_For_Victim(oVictim,oAttack)

            local mFunc = oVictim:GetFunction("OnSealed")
            for _,fCallback in pairs(mFunc) do
                safe_call(fCallback, oAttack, oVictim, oPerform)
            end

            local mFunc = oAttack:GetFunction("OnSeal")
            for _,fCallback in pairs(mFunc) do
                safe_call(fCallback, oAttack, oVictim, oPerform)
            end
        end
    end
    self:DoSealActionEnd(oAttack,oVictim,oPerform)
end

function CActionMgr:DoSealActionEnd(oAttack,oVictim,oPerform)
    if not oAttack:IsPlayer() or oAttack:GetAura() <= 0 then return end
    if not oAttack:GetData("school") ~= gamedefines.PLAYER_SCHOOL.QINGSHAN then return end

--    if math.random(100) < 5 then
--        local lEnemy = oAttack:GetEnemyList()
--        local oEnemy
--        if #lEnemy > 0 then
--            oEnemy = lEnemy[math.random(#lEnemy)]
--        end
--        if oEnemy and oEnemy:GetWid() ~= oVictim:GetWid() then
--            oPerform:Effect_Condition_For_Victim(oEnemy,oAttack)
--        end
--    end
end

--计算封印概率
function CActionMgr:CalSealRatio(oAttack,oVictim,oPerform,iMinRatio,iMaxRatio)
    local iSeal_Ratio = oAttack:QueryAttr("seal_ratio")
    local iRes_Seal_Ratio = oVictim:QueryAttr("res_seal_ratio")
    local iExpertSkillLevel = oAttack:QueryExpertSkill(1) - oVictim:QueryExpertSkill(4)
    local iPerformRatio = oPerform:HitRatio(oAttack,oVictim)
    local iRatio = iPerformRatio + iSeal_Ratio - iRes_Seal_Ratio
    iRatio = iRatio + iExpertSkillLevel * 2
    if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.QINGSHAN then
        iRatio = iRatio + oAttack:GetAura() * self:GetWarConfig("aura_qingshan")
    end

    iRatio = math.min(iRatio,iMaxRatio)
    iRatio = math.max(iRatio,iMinRatio)

    local mFunc = oAttack:GetFunction("OnSealRatio")
    for _,fCallback in pairs(mFunc) do
        iRatio = iRatio + fCallback(oAttack, oVictim, oPerform, iRatio)
    end

    local iCalSealRatio = iRatio
    local mFunc = oVictim:GetFunction("OnSealedRatio")
    for _,fCallback in pairs(mFunc) do
        iRatio = iRatio + fCallback(oAttack, oVictim, oPerform, iCalSealRatio)
    end

    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg(string.format("封印概率%d%%,敌方抗封%d%%,我方封印修炼%d,敌方抗封修炼%d,招式封印概率%d%%,最终概率%d%%",
        oAttack:QueryAttr("seal_ratio"),
        oVictim:QueryAttr("res_seal_ratio"),
        oAttack:QueryExpertSkill(1),
        oVictim:QueryExpertSkill(4),
        iPerformRatio,
        iRatio
    ))
    return iRatio
end

function CActionMgr:DoAddHp(oAction, iHp, bCritical)
    if not oAction or iHp <= 0 then return end

    if oAction:Query("disable_add_hp", 0) == 1 then
        return
    end

    if oAction:GetHp() <= 0 then
        oAction:SetBoutArgs("rebirth", 1)
    end
    oAction:AddHp(iHp)
    oAction:SendAll("GS2CWarDamage", {
        war_id = oAction:GetWarId(),
        wid = oAction:GetWid(),
        type = 0,
        damage = iHp,
        iscrit = bCritical and 1 or 0,
    })
    local oWar = oAction:GetWar()
    oWar:AddDebugMsg(string.format("%s(%d) 加血 %d", oAction:GetName(), oAction:GetWid(), iHp), true)
end

function CActionMgr:DoSubHp(oAction, iHp, oAttack, mArgs)
    if not oAction or oAction:IsDead() then return end
    if iHp <= 0 then return end

    mArgs = mArgs or {}
    oAction:SendAll("GS2CWarDamage", {
        war_id = oAction:GetWarId(),
        wid = oAction:GetWid(),
        type = 0,
        damage = -iHp,
        iscrit = mArgs.crit and 1 or 0,
        hited_effect = mArgs.hited_effect,
    })

    oAction:ReceiveDamage(oAttack, nil, iHp)
end

function CActionMgr:DoAddMp(oAction, iMp)
    if iMp == 0 then return end
    
    if not oAction or oAction:IsDead() then
        return
    end

    oAction:SendAll("GS2CWarAddMp", {
        war_id = oAction:GetWarId(),
        wid = oAction:GetWid(),
        add_mp = iMp,
    })
    oAction:AddMp(iMp)
end

function CActionMgr:DoReceiveDamage(oAction, iDamage, oAttack, oPerform, mArgs)
    if not oAction or oAction:IsDead() then return end
    if iDamage <= 0 then return end

    local iShare = 0
    local mFunc = oAction:GetFunction("OnShareDamage")
    for _,fCallback in pairs(mFunc) do
        iShare = iShare + fCallback(oAction, oAttack, iDamage)
    end

    mArgs = mArgs or {}
    iDamage = iDamage - iShare
    oAction:SendAll("GS2CWarDamage", {
        war_id = oAction:GetWarId(),
        wid = oAction:GetWid(),
        type = mArgs.flag or 0,
        damage = -iDamage,
        iscrit = mArgs.crit and 1 or 0,
        hited_effect = mArgs.hited_effect,
    })

    oAction:ReceiveDamage(oAttack, oPerform, iDamage, mArgs)
end

function CActionMgr:CalNormalDamage(oAttack,oVictim,mArgs)
    local iPhyAttack = self:CalPhyAttack(oAttack,oVictim) + 40
    local iDefense = self:CalPhyDefense(oAttack,oVictim)
    local lFloat = self:GetFloatRange("normal_float")
    local iMin, iMax = table.unpack(lFloat)
    local iDamage = (iPhyAttack - iDefense) * math.random(iMin,iMax) / 100

    local iCritRatio = oAttack:QueryAttr("phy_critical_ratio") - oVictim:QueryAttr("res_phy_critical_ratio")
    if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.SHUSHAN then
        iCritRatio = iCritRatio + oAttack:GetAura() * self:GetWarConfig("aura_shushan")
    end
    local iRatioA = 100
    if math.random(100) <= iCritRatio then
        iRatioA = iRatioA * 2
        oAttack:SetBoutArgs("IsPhyCrit",1)
    end

    mArgs = mArgs or {}
    local iExtRatio = mArgs["damage_addratio"] or 0
    local iAddRatioA = oAttack:QueryAttr("phy_damage_addratio") + oAttack:QueryAttr("damage_addratio") + iExtRatio
    local iSubRatioA = oVictim:QueryAttr("phy_damaged_addratio") + oVictim:QueryAttr("damaged_addratio")
    local mFunc = oAttack:GetFunction("OnCalDamageResultRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioA = iAddRatioA + fCallback(oAttack,oVictim,nil)
    end
    local mFunc = oVictim:GetFunction("OnCalDamagedResultRatio")
    for _,fCallback in pairs(mFunc) do
        iSubRatioA = iSubRatioA + fCallback(oAttack,oVictim,nil)
    end

    iRatioA = iRatioA + iAddRatioA + iSubRatioA
    if oVictim:IsDefense() and not oAttack:HasKey("ignore_defense") then
        iRatioA = iRatioA * oVictim:GetDefenseFactor()
    end

    local iAddRatioB = oAttack:QueryAttr("phy_damage_ratio") + oAttack:QueryAttr("damage_ratio")
    local iSubRatioB = oVictim:QueryAttr("phy_damaged_ratio") + oVictim:QueryAttr("damaged_ratio")
    local iRatioB = (100 + iAddRatioB + iSubRatioB) / 100

    local iExpertSkillLevel = oAttack:QueryExpertSkill(1) - oVictim:QueryExpertSkill(2)
    local iExpertRatio = (100 + iExpertSkillLevel * 2) /100

    local iAttackedDegree = oAttack:GetAttackedDegree() + oVictim:GetAttackedDegree()
    iAttackedDegree = math.min(iAttackedDegree,10)
    local iAttackedDegreeRatio = (100 - iAttackedDegree) / 100

    iDamage = math.floor(iDamage * iExpertRatio * iAttackedDegreeRatio * iRatioB)
    iDamage = iDamage + iExpertSkillLevel * 5 + oAttack:QueryAttr("FixDamage")

    iDamage = math.floor(iDamage * iRatioA / 100)
    local mFunc = oAttack:GetFunction("OnCalDamage")
    for _,fCallback in pairs(mFunc) do
        iDamage = iDamage + fCallback(oAttack, oVictim, nil)
    end
    local mFunc = oVictim:GetFunction("OnCalDamaged")
    for _,fCallback in pairs(mFunc) do
        iDamage = iDamage + fCallback(oAttack, oVictim, nil)
    end

    local iBaseDamage = math.max(iPhyAttack // 10, 1)
    if iDamage < iBaseDamage then
        iDamage = iBaseDamage
    end

    iDamage = math.floor(iDamage)

    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg(string.format("物攻%d,防御%d,暴击几率%d%%,敌方抗暴击%d%%,是否暴击%d,最终暴击概率%s,伤害结果加成%d%%,敌方伤害结果加成%d%%,敌方是否防御%s,伤害加成%d%%,伤害减少%d%%,最终伤害%d",
        iPhyAttack,
        iDefense,
        oAttack:QueryAttr("phy_critical_ratio"),
        oVictim:QueryAttr("res_phy_critical_ratio"),
        oAttack:QueryBoutArgs("IsPhyCrit",0),
        iCritRatio,
        iAddRatioA,
        iSubRatioA,
        oVictim:IsDefense(),
        iAddRatioB,
        iSubRatioB,
        iDamage
    ))
    return iDamage
end

function CActionMgr:CalMagDamage(oAttack,oVictim,oPerform,iDamageRatio)
    local iMagAttack = self:CalMagAttack(oAttack,oVictim,oPerform)
    local iMagDefense = self:CalMagDefense(oAttack,oVictim,oPerform)
    local iBaseDamage, iAttack = 0, 0
    local lFloat = self:GetFloatRange("mag_float")
    local iMin, iMax = table.unpack(lFloat)
    iBaseDamage = (iMagAttack - iMagDefense) * math.random(iMin,iMax) / 100

    if oPerform:IsConstantDamage() then
        local mEnv = {
            level = oPerform:Level(),
            grade = oAttack:GetGrade(),
            mag_attack = iMagAttack,
            mag_defense = iMagDefense,
        }
        iBaseDamage = oPerform:ConstantDamage(oAttack,oVictim,100, mEnv)
    end

    local iPfDamageRatio = oPerform:DamageRatio(oAttack,oVictim) / 100

    local iAttackedDegree = oAttack:GetAttackedDegree() + oVictim:GetAttackedDegree()
    iAttackedDegree = math.min(iAttackedDegree,10)
    local iControlDegree = oAttack:GetControlAttackedDegree() + oVictim:GetControlAttackedDegree()
    iControlDegree = math.min(iControlDegree,30)
    local iAttackedDegreeRatio = (100 - iAttackedDegree - iControlDegree) /100

    local iExpertSkillLevel = oAttack:QueryExpertSkill(1) - oVictim:QueryExpertSkill(3)
    local iExpertRatio = (100 + iExpertSkillLevel * 2) /100

    local iAddRatioB = oAttack:QueryAttr("mag_damage_ratio") + oAttack:QueryAttr("damage_ratio")
    iAddRatioB = iAddRatioB + oAttack:QueryAttr(string.format("elem%d_damage_ratio", oAttack:QueryBoutArgs("element",0)))
    local iSubRatioB = oVictim:QueryAttr("mag_damaged_ratio")  + oVictim:QueryAttr("damaged_ratio")

    local mFunc = oAttack:GetFunction("OnCalDamageRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioB = iAddRatioB + fCallback(oAttack,oVictim,oPerform)
    end
    local mFunc = oVictim:GetFunction("OnCalDamagedRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioB = iAddRatioB + fCallback(oAttack,oVictim,oPerform)
    end

    local iRatioB = 100 + iAddRatioB + iSubRatioB
    if oAttack:IsControl(oVictim) then
        iRatioB = iRatioB + 30
    end
    if oVictim:IsControl(oAttack) then
        iRatioB = iRatioB - 30
    end

    iRatioB = iRatioB / 100
    iDamageRatio = iDamageRatio / 100
    local iDamage = math.floor(iBaseDamage * iDamageRatio * iPfDamageRatio * iAttackedDegreeRatio * iExpertRatio * iRatioB)
    iDamage = iDamage + iExpertSkillLevel * 5 +  oAttack:QueryAttr("mag_damage_add")

    local iCritRatio = oAttack:QueryAttr("mag_critical_ratio") - oVictim:QueryAttr("res_mag_critical_ratio")
    local iRatioA = 100
    if math.random(100) <= iCritRatio then
        iRatioA = iRatioA * 2
        oAttack:SetBoutArgs("IsMagCrit",1)
    end

    local iAddRatioA = oAttack:QueryAttr("mag_damage_addratio") + oAttack:QueryAttr("damage_addratio")
    if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.XINGXIU then
        iAddRatioA = iAddRatioA + oAttack:GetAura() * self:GetWarConfig("aura_xingxiu")
    end

    local iSubRatioA = oVictim:QueryAttr("mag_damaged_addratio") + oVictim:QueryAttr("damaged_addratio")
    local mFunc = oAttack:GetFunction("OnCalDamageResultRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioA = iAddRatioA + fCallback(oAttack,oVictim,oPerform)
    end
    local mFunc = oVictim:GetFunction("OnCalDamagedResultRatio")
    for _,fCallback in pairs(mFunc) do
        iSubRatioA = iSubRatioA + fCallback(oAttack,oVictim,oPerform)
    end

    iRatioA = iRatioA + iAddRatioA + iSubRatioA
    -- if oVictim:IsDefense() and not oAttack:HasKey("ignore_defense") then
    --     iRatioA = iRatioA / 2
    -- end
    iDamage = iDamage * iRatioA / 100
    iDamage = iDamage + oAttack:QueryAttr("FixDamage")
    local mFunc = oAttack:GetFunction("OnCalDamage")
    for _,fCallback in pairs(mFunc) do
        iDamage = iDamage + fCallback(oAttack, oVictim, oPerform)
    end
    local mFunc = oVictim:GetFunction("OnCalDamaged")
    for _,fCallback in pairs(mFunc) do
        iDamage = iDamage + fCallback(oAttack, oVictim, oPerform)
    end

    local iMinDamage = math.max(1, iMagAttack // 10)
    if iDamage < iMinDamage then
        iDamage = iMinDamage
    end
    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg(string.format("法攻%d,魔法防御%d,招式效率%s%%,受击度%d,敌方受击度%d,受击度克制%d,敌方受击度克制%d,修炼%d,敌方修炼%d,是否克制对方%s,是否被对方克制%s,暴击几率%d%%,敌方抗暴击%d%%,是否暴击%s,伤害加成%d%%,伤害减少%d%%,伤害结果加成%d%%,伤害结果减少%d%%",
        iMagAttack,
        iMagDefense,
        iPfDamageRatio * 100,
        oAttack:GetAttackedDegree(),
        oVictim:GetAttackedDegree(),
        oAttack:GetControlAttackedDegree(),
        oVictim:GetControlAttackedDegree(),
        oAttack:QueryExpertSkill(1),
        oVictim:QueryExpertSkill(3),
        oAttack:IsControl(oVictim),
        oVictim:IsControl(oAttack),
        oAttack:QueryAttr("mag_critical_ratio"),
        oVictim:QueryAttr("res_mag_critical_ratio"),
        oAttack:QueryBoutArgs("IsMagCrit",0),
        iAddRatioB,
        iSubRatioB,
        iAddRatioA,
        iSubRatioA
    ))
    return math.floor(iDamage)
end

function CActionMgr:CalPhyDamage(oAttack,oVictim,oPerform,iDamageRatio)
     --固定伤害
    local iPhyAttack = self:CalPhyAttack(oAttack,oVictim,oPerform)
    local iPhyDefense = self:CalPhyDefense(oAttack,oVictim,oPerform)
    local lFloat = self:GetFloatRange("phy_float")
    local iMin, iMax = table.unpack(lFloat)
    local iBaseDamage = (iPhyAttack - iPhyDefense) * math.random(iMin, iMax) / 100
    if oPerform:IsConstantDamage() then
        iBaseDamage = oPerform:ConstantDamage(oAttack,oVictim,100)
    end

    local iPfDamageRatio = oPerform:DamageRatio(oAttack,oVictim) / 100

    local iAttackedDegree = oAttack:GetAttackedDegree() + oVictim:GetAttackedDegree()
    local iControlDegree = oAttack:GetControlAttackedDegree() + oVictim:GetControlAttackedDegree()
    iControlDegree = math.min(iControlDegree,30)
    local iAttackedDegreeRatio = (100 - iAttackedDegree - iControlDegree) /100

    local iExpertSkillLevel = oAttack:QueryExpertSkill(1) - oVictim:QueryExpertSkill(2)
    local iExpertRatio = (100 + iExpertSkillLevel * 2) /100

    local iAddRatioB = oAttack:QueryAttr("phy_damage_ratio") + oAttack:QueryAttr("damage_ratio")
    iAddRatioB = iAddRatioB + oAttack:QueryAttr(string.format("elem%d_damage_ratio", oAttack:QueryBoutArgs("element",0)))
    local iSubRatioB = oVictim:QueryAttr("phy_damaged_ratio") + oVictim:QueryAttr("damaged_ratio")

    local mFunc = oAttack:GetFunction("OnCalDamageRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioB = iAddRatioB + fCallback(oAttack,oVictim,oPerform)
    end
    local mFunc = oVictim:GetFunction("OnCalDamagedRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioB = iAddRatioB + fCallback(oAttack,oVictim,oPerform)
    end

    local iRatioB = 100 + iAddRatioB + iSubRatioB
    iRatioB = iRatioB / 100
    iDamageRatio = iDamageRatio / 100
    local iDamage = math.floor(iBaseDamage * iDamageRatio * iPfDamageRatio * iAttackedDegreeRatio * iExpertRatio * iRatioB)
    iDamage = iDamage + iExpertSkillLevel * 5 +  oAttack:QueryAttr("phy_damage_add")

    local iCritRatio = oAttack:QueryAttr("phy_critical_ratio") - oVictim:QueryAttr("res_phy_critical_ratio")
    if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.SHUSHAN then
        iCritRatio = iCritRatio + oAttack:GetAura() * self:GetWarConfig("aura_shushan")
    end
    local iRatioA = 100
    if math.random(100) <= iCritRatio then
        iRatioA = iRatioA * 2
        oAttack:SetBoutArgs("IsPhyCrit",1)
    end

    local iAddRatioA = oAttack:QueryAttr("phy_damage_addratio") + oAttack:QueryAttr("damage_addratio")
    local iSubRatioA = oVictim:QueryAttr("phy_damaged_addratio") + oVictim:QueryAttr("damaged_addratio")
    local mFunc = oAttack:GetFunction("OnCalDamageResultRatio")
    for _,fCallback in pairs(mFunc) do
        iAddRatioA = iAddRatioA + fCallback(oAttack,oVictim,oPerform)
    end
    local mFunc = oVictim:GetFunction("OnCalDamagedResultRatio")
    for _,fCallback in pairs(mFunc) do
        iSubRatioA = iSubRatioA + fCallback(oAttack,oVictim,oPerform)
    end

    iRatioA = iRatioA + iSubRatioA + iAddRatioA
    if oVictim:IsDefense() and not oAttack:HasKey("ignore_defense") then
        iRatioA = iRatioA * oVictim:GetDefenseFactor()
    end
    iDamage = iDamage * iRatioA / 100
    iDamage = iDamage + oAttack:QueryAttr("FixDamage")
    local mFunc = oAttack:GetFunction("OnCalDamage")
    for _,fCallback in pairs(mFunc) do
        iDamage = iDamage + fCallback(oAttack, oVictim, oPerform)
    end
    local mFunc = oVictim:GetFunction("OnCalDamaged")
    for _,fCallback in pairs(mFunc) do
        iDamage = iDamage + fCallback(oAttack, oVictim, oPerform)
    end

    local iMinDamage = math.max(1, iPhyAttack // 10)
    if iDamage < iMinDamage then
        iDamage = iMinDamage
    end
    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg(string.format("物攻%d,物理防御%d,招式效率%s%%,受击度%d,敌方受击度%d,受击度克制%d,敌方受击度克制%d,修炼%d,敌方修炼%d,暴击几率%d%%,敌方抗暴击%d%%,是否暴击%s,最终暴击概率%s,伤害加成%d%%,伤害减少%d%%,伤害结果加成%d%%,伤害结果减少%d%%,元素伤害加成%d%%",
        iPhyAttack,
        iPhyDefense,
        iPfDamageRatio * 100,
        oAttack:GetAttackedDegree(),
        oVictim:GetAttackedDegree(),
        oAttack:GetControlAttackedDegree(),
        oVictim:GetControlAttackedDegree(),
        oAttack:QueryExpertSkill(1),
        oVictim:QueryExpertSkill(2),
        oAttack:QueryAttr("phy_critical_ratio"),
        oVictim:QueryAttr("res_phy_critical_ratio"),
        oAttack:QueryBoutArgs("IsPhyCrit",0),
        iCritRatio,
        iAddRatioB,
        iSubRatioB,
        iAddRatioA,
        iSubRatioA,
        oAttack:QueryAttr(string.format("elem%d_damage_ratio", oAttack:QueryBoutArgs("element",0)))
    ))
    return math.floor(iDamage)
end

function CActionMgr:CalPhyAttack(oAttack, oVictim, oPerform)
    local iAttack = oAttack:QueryAttr("phy_attack") * (100 - oVictim:QueryAttr("res_phy_attack_ratio")) / 100
    local mFunc = oAttack:GetFunction("CalPhyAttack")
    for _,fCallback in pairs(mFunc) do
        iAttack = iAttack + fCallback(oAttack,oVictim,oPerform)
    end
    return math.floor(iAttack)
end

function CActionMgr:CalMagAttack(oAttack, oVictim, oPerform)
    local iAttack = oAttack:QueryAttr("mag_attack") * (100 - oVictim:QueryAttr("res_mag_attack_ratio")) / 100
    local mFunc = oAttack:GetFunction("CalMagAttack")
    for _,fCallback in pairs(mFunc) do
        iAttack = iAttack + fCallback(oAttack,oVictim,oPerform)
    end
    return math.floor(iAttack)
end

function CActionMgr:CalPhyDefense(oAttack, oVictim, oPerform)
    local iDefense = oVictim:QueryAttr("phy_defense") * (100 - oAttack:QueryAttr("res_phy_defense_ratio")) / 100
    local mFunc = oVictim:GetFunction("CalPhyDefense")
    for _,fCallback in pairs(mFunc) do
        iDefense = iDefense + fCallback(oAttack,oVictim,oPerform)
    end
    return math.floor(iDefense)
end

function CActionMgr:CalMagDefense(oAttack, oVictim, oPerform)
    local iDefense = oVictim:QueryAttr("mag_defense") * (100 - oAttack:QueryAttr("res_mag_defense_ratio")) / 100
    local mFunc = oVictim:GetFunction("CalMagDefensed")
    for _,fCallback in pairs(mFunc) do
        iDefense = iDefense + fCallback(oAttack,oVictim,oPerform)
    end

    local mFunc = oAttack:GetFunction("CalMagDefense")
    for _,fCallback in pairs(mFunc) do
        iDefense = iDefense + fCallback(oAttack,oVictim,oPerform)
    end
    return math.floor(iDefense)
end

function CActionMgr:CalActionHit(oAttack, oVictim, oPerform, iType)
    local iHitRatio = 0
    if iType == gamedefines.WAR_PERFORM_TYPE.PHY then
        iHitRatio = oAttack:QueryAttr("phy_hit_ratio") - oVictim:QueryAttr("phy_hit_res_ratio") + (oPerform:HitRatio(oAttack, oVictim)  - 100)
    else
        iHitRatio = oAttack:QueryAttr("mag_hit_ratio") - oVictim:QueryAttr("mag_hit_res_ratio") + (oPerform:HitRatio(oAttack, oVictim)  - 100)
    end

    local iExtHitRatio = 0
    local mFunc = oAttack:GetFunction("CalActionHit")
    for _,fCallback in pairs(mFunc) do
        iExtHitRatio = iExtHitRatio + fCallback(oAttack,oVictim,oPerform)
    end

    local iExtHitedRatio = 0
    local mFunc = oVictim:GetFunction("CalActionHited")
    for _,fCallback in pairs(mFunc) do
        iExtHitedRatio = iExtHitedRatio + fCallback(oAttack,oVictim,oPerform)
    end

    local oWar = oAttack:GetWar()
    oWar:AddDebugMsg(string.format("攻击#B%s#n,招式命中%s,物理命中%s,物理闪避%s,法术命中%s,法术闪避%s,其他加成%s,招式衰减%s",
        oVictim:GetName(),
        oPerform:HitRatio(oAttack, oVictim),
        oAttack:QueryAttr("phy_hit_ratio"),
        oVictim:QueryAttr("phy_hit_res_ratio"),
        oAttack:QueryAttr("mag_hit_ratio"),
        oVictim:QueryAttr("mag_hit_res_ratio"),
        iExtHitRatio,
        iExtHitedRatio
    ))

    if math.random(100) <= (iHitRatio+iExtHitRatio-iExtHitedRatio) then return true end

    return false
end

function CActionMgr:CalPerformTotDamage(oPerform, iDamage)
    if not oPerform then return end

    local iTotal = oPerform:GetTempData("total_damage", 0) + iDamage
    oPerform:SetTempData("total_damage", iTotal)
end


function CActionMgr:GetFloatRange(sKey)
    return res["daobiao"]["warconfig"][sKey]["float_range"]
end

function CActionMgr:GetWarConfig(sKey)
    return res["daobiao"]["warconfig"][sKey]
end
