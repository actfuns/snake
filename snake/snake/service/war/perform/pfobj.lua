--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local buffmgr = import(service_path("buffmgr"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, logic_base_cls())

function CPerform:New(id)
    local o = super(CPerform).New(self)
    o.m_ID = id
    o.m_iLevel = 0
    o.m_mExtData  = {}
    o.m_mTempData = {}       -- 单次perform数据
    return o
end

function CPerform:GetPerformData()
    local res = require "base.res"
    local mData = res["daobiao"]["perform"][self.m_ID]
    assert(mData,string.format("GetPerformData err %d",self.m_ID))
    return mData
end

function CPerform:GetPerformRatio(oAttack, iMaxCnt)
    if oAttack:HasKey("ignore_group_perform_ratio") then
        return 100
    end

    iMaxCnt = math.max(iMaxCnt,1)
    iMaxCnt = math.min(iMaxCnt,12)
    local res = require "base.res"
    local mData = res["daobiao"]["performratio"][iMaxCnt]
    return mData["damageRatio"]
end

function CPerform:IsActive()
    local mData = self:GetPerformData()
    return mData["is_active"] == 1
end

function CPerform:GetPerformPriority()
    if self:GetData("priority") then
        return self:GetData("priority")
    end
    local mData = self:GetPerformData()
    return mData["priority"] or 100
end

function CPerform:GetAITarget()
    if self:GetData("ai_target") then
        return self:GetData("ai_target")
    end
    local mData = self:GetPerformData()
    return mData["ai_target"] or 2
end

function CPerform:GetAIActionType()
    local mData = self:GetPerformData()
    return mData["ai_action_type"]
end

function CPerform:CanPerform()
    return true
end

--被动技能调用
function CPerform:CalWarrior(oWarrior,oPerformMgr)
    -- body
end

function CPerform:SetLevel(iLevel)
    self.m_iLevel = iLevel
end

function CPerform:Level()
    return self.m_iLevel or 0
end

--法术id
function CPerform:Type()
    return self.m_ID
end

function CPerform:Name( ... )
    local mData = self:GetPerformData()
    return mData["name"]
end

function CPerform:CDBout()
    local mData = self:GetPerformData()
    return mData["cd"] or 0
end

--作用目标类型,1:己方,2:敌方
function CPerform:TargetType()
    local mData = self:GetPerformData()
    local iType = mData["targetType"]
    return iType %10
end

--招式系别(水火土风)
function CPerform:PerformElement()
    local mData = self:GetPerformData()
    local iAttrType = mData["skillElementType"] or 1
    return iAttrType % 10
end

--作用目标状态,死亡和存活
function CPerform:TargetStatus()
    local mData = self:GetPerformData()
    local iStatus = mData["useTargetStatus"]
    iStatus = iStatus %10
    if iStatus == 1 then
        return gamedefines.WAR_WARRIOR_STATUS.ALIVE
    else
        return gamedefines.WAR_WARRIOR_STATUS.DEAD
    end
end

--攻击方式,物理攻击,法术攻击
function CPerform:AttackType()
    local mData = self:GetPerformData()
    local iType = mData["skillAttackType"] or 1
    return iType%10
end

--行动方式,1:攻击,2:封印,3:辅助,4:治疗
function CPerform:ActionType()
    local mData = self:GetPerformData()
    local iType = mData["skillActionType"] or 1
    return iType % 10
end

function CPerform:DoGroupRatio()
    local mData = self:GetPerformData()
    local iType = mData["do_group_ratio"] or 0
    return iType % 10 == 1
end

function CPerform:IsGroupPerform()
    local mData = self:GetPerformData()
    if mData["is_group_perform"] == 1 then
        return true
    end
    return false
end

function CPerform:IsSE()
    return false
end

--是否是近身攻击
function CPerform:IsNearAction()
    local mData = self:GetPerformData()
    local iNearAction = mData["effectAction"]
    if iNearAction == 1 then
        return true
    end
    return false
end

function CPerform:NeedBackTime()
    return self:IsNearAction()
end

function CPerform:NeedVictimTime()
    return self:ActionType() ~= gamedefines.WAR_ACTION_TYPE.CURE
end

--特效编号
function CPerform:PerformMagicID()
    local mData = self:GetPerformData()
    local iEfffectID = mData["effectType"]
    if iEfffectID == 0 then
        return self.m_ID
    end
    return iEfffectID
end


--招式时间
function CPerform:PerformMagicTime(oWarrior, idx)
    idx = idx or 1
    local mMagicTime = res["magictime"]
    local iShape = oWarrior:GetShape()
    local mTime = table_get_depth(mMagicTime, {self.m_ID, iShape, idx})
    if mTime then return mTime end

    local mTime = table_get_depth(mMagicTime, {self.m_ID, 1, idx})
    if mTime then return mTime end

    return {1000, 1600, 1000}
end

--命中率
function CPerform:HitRatio()
    local sFormula
    local mData = self:GetPerformData()
    for _, mInfo in ipairs(mData["hitRate"]) do
        if mInfo["level"] > self:Level() then break end

         sFormula = mInfo["rate"]
    end

    return formula_string(sFormula, {level=self:Level()})
end

-- speed
function CPerform:SpeedRatio()
    local iRatio = 100
    local mInfo = self:GetPerformData()
    for _,mData in ipairs(mInfo["speedRatio"] or {}) do
        if mData["level"] > self:Level() then break end

         iRatio = mData["speed"]
    end
    return iRatio
end

--技能加速度
function CPerform:PerformTempAddSpeed(oAction)
    return 0
end

function CPerform:RangeEnv()
    return {level=self:Level()}
end

--作用人数
function CPerform:Range()
    local mInfo = self:GetPerformData()
    local mRange = mInfo["range"] or {}
    local sRange
    for _,mData in pairs(mRange) do
        local iLevel = mData["level"]
        if self:Level() >= iLevel then
            sRange = mData["range"]
        end
    end
    if not sRange then
        return 1
    end
    local iRange = tonumber(sRange)
    if iRange then
        return iRange
    else
        local mEnv = self:RangeEnv()
        local iRange = math.floor(formula_string(sRange,mEnv))
        return iRange
    end
    return 1
end

function CPerform:DamageRatioEnv(oAttack,oVictim)
    return {level=self:Level()}
end

--效率
function CPerform:DamageRatio(oAttack,oVictim)
    local mInfo = self:GetPerformData()
    local mDamageRatio = mInfo["damageRatio"]
    local sFormula
    for _, mData in ipairs(mDamageRatio) do
        if mData["level"] > self:Level() then break end

        sFormula = mData["ratio"]
    end

    local iRatio = tonumber(sFormula)
    if not iRatio then
        local mEnv = self:DamageRatioEnv(oAttack,oVictim)
        iRatio = formula_string(sFormula, mEnv) 
    end
    return iRatio
end

function CPerform:GetAddVictimBuffRatio()
    return 100
end

function CPerform:GetAddAttackBuffRatio()
    return 100
end

function CPerform:ExtArg()
    local mInfo = self:GetPerformData()
    local sExtArgs = mInfo["extArgs"]
    return sExtArgs
end

function CPerform:IsControl(oVictim)
    if not oVictim or oVictim:IsDead() then
        return false
    end
    local oWar = oVictim:GetWar()
    local mCmds = oWar:GetBoutCmd(oVictim.m_iWid)
    local cmd = mCmds.cmd
    local mSkillData = mCmds.data
    local oPerform
    if cmd == "skill" then
        local iSkill = mSkillData.skill_id
        oPerform = oVictim:GetPerform(iSkill)
    end
    if not oPerform then
        return false
    end
    local iType = self:PerformAttrType()
    local iTargetType = oPerform:PerformAttrType()
    if iType == 1 and iTargetType == 2 then
        return true
    elseif iType == 2 and iTargetType == 3 then
        return true
    elseif iType ==3 and iTargetType == 4 then
        return true
    elseif iType == 4 and iTargetType == 1 then
        return true
    end
    return false
end

--AI检查能否使用招式
function CPerform:AICheckValidPerform(oAttack)
    if self:IsDisabled(oAttack) then
        return false
    end
    if self:InCD(oAttack) then
        return false
    end
    if not self:AICheckResume(oAttack) then
        return false
    end
    if not self:AISelfValidCast(oAttack) then
        return false
    end
    return true
end

function CPerform:AICheckResume(oAttack)
    local iHP = self:ValidResumeHP(oAttack)
    local iMP = self:ValidResumeMP(oAttack)
    local iAura = self:ValidResumeAura(oAttack)
    local iSP = self:ValidResumeSP(oAttack)
    if not iHP or not iMP or not iAura or not iSP then
        return false
    end
    return true
end

function CPerform:AISelfValidCast(oAttack)
    return true
end

--AI选择目标
function CPerform:ChooseAITarget(oAttack)
    local iAITarget = self:GetAITarget()
    if (oAttack:IsPlayer() or oAttack:IsSummon()) and oAttack:IsOpenFight() then
        iAITarget = 2
    end

    local lTarget = self:TargetList(oAttack)
    local oTargetMgr = global.oTargetMgr
    return oTargetMgr:ChooseAITarget(iAITarget, oAttack, lTarget)
end

function CPerform:IsDisabled(oAttack, bNotify)
    if oAttack:HasKey("stealth") then return true end

    local bFlag = false
    if not self.m_bNoDisable then
        if self:AttackType() == gamedefines.WAR_PERFORM_TYPE.PHY then
            if oAttack:HasKey("phy_disable") then
                bFlag = true
            end
        else
            if oAttack:HasKey("mag_disable") then
                bFlag = true
            end
        end
    end
    if bNotify and bFlag == true and (oAttack:IsPlayer() or oAttack:IsSummon()) then
        oAttack:Notify("当前无法行动", 1<<2)
    end
    return bFlag
end

function CPerform:ValidCast(oAttack,oVictim)
    if self:TargetStatus() == gamedefines.WAR_WARRIOR_STATUS.ALIVE then
        if oVictim:IsAlive() and oVictim:IsVisible(oAttack) then
            return oVictim
        end
        if oAttack:HasKey("phymock") then
            if self:ActionType() == gamedefines.WAR_ACTION_TYPE.ATTACK
                and self:AttackType() == gamedefines.WAR_PERFORM_TYPE.PHY then
                local oWar = oAttack:GetWar()
                local w = oWar:GetWarrior(oAttack:GetKey("phymock"))
                if w then
                    return w
                end
            end
        end
        --不可见，随机选
        local m = self:TargetList(oAttack)
        if #m >= 1 then
            return m[math.random(#m)]
        end
    else
        if not oVictim:IsAlive() then
            return oVictim
        end
    end
end

--检查释放条件,主要判断气血等条件
function CPerform:SelfValidCast(oAttack,oVictim)
    local iType = gamedefines.BUFF_TYPE.CLASS_ABNORMAL 
    if self:ActionType() == gamedefines.WAR_ACTION_TYPE.SEAL and oVictim and oVictim.m_oBuffMgr:GetBuffByClass(iType, "封印")  then
        if oAttack:IsPlayer() then
            oAttack:Notify("目标无法被封印")
        end
        return false
    end
    return true
end

function CPerform:ValidResumeHP(oAttack, bNotify)
    local iHP = 0
    local mArgs = {
        level = self:Level(),
        grade = oAttack:GetData("grade",0),
        hp = oAttack:GetHp(),
        maxhp = oAttack:GetMaxHp(),
    }
    local mInfo = self:GetPerformData()
    local sHpResume = mInfo["hpResume"]
    if sHpResume and sHpResume ~= "" then
        if tonumber(sHpResume) then
            iHP = tonumber(sHpResume)
        else
            iHP = math.floor(formula_string(sHpResume,mArgs))
        end
    end
    if not sHpResume then
        print("ERROR weicheng.debug:", mInfo)
    end
    local mFunc = oAttack:GetFunction("CheckResumeHp")
    for _,fCallback in pairs(mFunc) do
        iHP = iHP + fCallback(oAttack, iHP, self)
    end
    if oAttack:GetHp() < iHP then
        if bNotify and oAttack:IsPlayer() then
            oAttack:Notify("气血不足，无法使用")
        end
        return
    end
    return math.floor(iHP)
end

function CPerform:ValidResumeMP(oAttack, bNotify)
    local iMP = 0
    local mArgs = {
        level = self:Level(),
        grade = oAttack:GetData("grade",0),
        mp = oAttack:GetMp(),
        maxmp = oAttack:GetMaxMp(),
    }
    local mInfo = self:GetPerformData()
    local sMpResume = mInfo["mpResume"]
    if sMpResume ~= "" then
        if tonumber(sMpResume) then
            iMP = tonumber(sMpResume)
        else
            iMP = math.floor(formula_string(sMpResume,mArgs))
        end
    end
    if math.random(100) <= oAttack:Query("ignore_resumemp_ratio", 0) then
        iMP = 0
    end

    local mFunc = oAttack:GetFunction("CheckResumeMp")
    for _,fCallback in pairs(mFunc) do
        iMP = iMP + fCallback(oAttack, iMP, self)
    end

    if oAttack:GetMp() < iMP then
        if bNotify and oAttack:IsPlayer() then
            oAttack:Notify("法力不足，无法使用")
        end
        return
    end
    return math.floor(iMP)
end

function CPerform:ValidResumeAura(oAttack, bNotify)
    local iAura = 0
    if oAttack:IsPlayer() then
        local mArgs = {
            level = self:Level(),
            grade = oAttack:GetData("grade",0),
        }
        local mInfo = self:GetPerformData()
        local sAuraResume = mInfo["aura_resume"]
        if sAuraResume ~= "" then
            if tonumber(sAuraResume) then
                iAura = tonumber(sAuraResume)
            else
                iAura = math.floor(formula_string(sAuraResume,mArgs))
            end
        end
    local mFunc = oAttack:GetFunction("CheckResumeAura")
    for _,fCallback in pairs(mFunc) do
        iAura = iAura + fCallback(oAttack, iAura, self)
    end
        if oAttack:GetAura() < iAura then
            if bNotify then
                oAttack:Notify("灵气不足，无法使用")
            end
            return
        end
    end
    return math.floor(iAura)
end

function CPerform:ValidResumeSP(oAttack, bNotify)
    local iSP = 0
    if oAttack:IsPlayerLike() then
        local mEnv = {
            level = self:Level(),
            grade = oAttack:GetData("grade", 0)
        }
        local mInfo = self:GetPerformData()
        local sResumeSP = mInfo["sp_resume"]
        if sResumeSP ~= "" then
            if tonumber(sResumeSP) then
                iSP = tonumber(sResumeSP)
            else
                iSP = math.floor(formula_string(sResumeSP, mEnv))
            end
            iSP = math.floor(iSP + iSP*oAttack:Query("resumesp_add_ratio", 0)/100)
        end
        local mFunc = oAttack:GetFunction("CheckResumeSP")
        for _,fCallback in pairs(mFunc) do
            iSP = iSP + fCallback(oAttack, iSP, self)
        end
        if oAttack:GetSP() < iSP then
            if bNotify and oAttack:IsPlayer() then
                oAttack:Notify("怒气不足，无法使用")
            end
            return
        end
    end
    return math.floor(iSP)
end

--消耗判断
function CPerform:ValidResume(oAttack,oVictim,bNotify)
    local iHP = self:ValidResumeHP(oAttack,bNotify)
    local iMP = self:ValidResumeMP(oAttack,bNotify)
    local iAura = self:ValidResumeAura(oAttack,bNotify)
    local iSP = self:ValidResumeSP(oAttack,bNotify)
    if not iHP or not iMP or not iAura or not iSP then
        return
    end
    return {iHP,iMP,iAura,iSP}
end

function CPerform:DoResume(oAttack,mResume)
    local  iHP,iMP,iAura,iSP = table.unpack(mResume)
    if iHP > 0 then
        oAttack:SubHp(iHP, oAttack)
    end
    if iMP > 0 then
        local iRatio = oAttack:QueryAttr("resume_mp_ratio")
        if math.random(100) > iRatio then
            oAttack:SubMp(iMP)
        else
            if oAttack:GetPerform(5136) then
                oAttack:GS2CTriggerPassiveSkill(5136)
            end
        end
    end
    if iAura > 0 then
        oAttack:AddAura(-iAura)
    end
    if iSP > 0 then
        oAttack:AddSP(-iSP)
    end
end

function CPerform:TargetList(oAttack)
    local mTarget = {}
    if self:TargetType() == 1 then
        mTarget = oAttack:GetFriendList(true)
    elseif self:TargetType() == 2 then
        mTarget = oAttack:GetEnemyList(true)
    elseif self:TargetType() == 3 then
        table.insert(mTarget,oAttack)
    end
    local mRet = {}
    local iStatus = self:TargetStatus()
    for _,oTarget in pairs(mTarget) do
        if iStatus == gamedefines.WAR_WARRIOR_STATUS.ALIVE then
            if oTarget:IsAlive() and oTarget:IsVisible(oAttack) then
                table.insert(mRet,oTarget)
            end
        elseif iStatus == gamedefines.WAR_WARRIOR_STATUS.DEAD then
            if oTarget:IsDead() then
                table.insert(mRet,oTarget)
            end
        else
            table.insert(mRet,oTarget)
        end
    end
    return mRet
end

function CPerform:MaxRange(oAttack, oVictim)
    local iRange = self:Range()

    local mFunc = oAttack:GetFunction("MaxRange")
    for _,fCallback in pairs(mFunc) do
        iRange = iRange + fCallback(oAttack, oVictim, self)
    end
    return iRange
end

function CPerform:SortVictim(lTarget)
    return extend.Random.random_size(lTarget, #lTarget)
end

function CPerform:PerformTarget(oAttack,oVictim)
    local iCnt = self:MaxRange(oAttack,oVictim)
    local mTarget = {oVictim.m_iWid,}
    local m = self:TargetList(oAttack)
    if #m > iCnt then
        m = self:SortVictim(m)
    end

    if not extend.Array.member(m, oVictim) then
        mTarget = {}
    end

    for _,w in pairs(m) do
        if w ~= oVictim and #mTarget < iCnt then
            table.insert(mTarget,w.m_iWid)
        end
        if #mTarget >= iCnt then
            break
        end
    end
    self:SetData("PerformTarget",mTarget)
    return mTarget
end

function CPerform:IsConstantDamage()
    local mInfo = self:GetPerformData()
    local iType = mInfo["is_constant_damage"]
    if iType % 10 == 1 then
        return true
    end
end

function CPerform:SkillFormulaEnv(oAttack,oVictim,mEnv)
    mEnv = mEnv or {}
    mEnv.level = self:Level()
    if oAttack then
        if self:ActionType() == gamedefines.WAR_ACTION_TYPE.CURE then
            mEnv.cure_power = oAttack:QueryAttr("cure_power")
        end
        mEnv.grade = oAttack:GetGrade()
    end
    return mEnv
end

function CPerform:CalSkillFormula(oAttack,oVictim,iRatio,mEnv,bReal)
    local mInfo = self:GetPerformData()
    local sFormula = mInfo["skill_formula"]
    if not sFormula or sFormula == "" then
        return 0
    end
    local mEnv = self:SkillFormulaEnv(oAttack,oVictim,mEnv)
    local iResult = formula_string(sFormula,mEnv)
    if not bReal then
        iResult = iResult * iRatio // 100
    else
        iResult = iResult * iRatio / 100 
    end
    return iResult
end

function CPerform:CalculateHp(oAttack,oVictim,iRatio)
    local mEnv = {
        expert_skill_1 = oAttack:QueryExpertSkill(1),
    }
    local iAdd = self:CalSkillFormula(oAttack,oVictim,iRatio, mEnv)

    local mFunc = oAttack:GetFunction("CalculateHp")
    for _,fCallback in pairs(mFunc) do
        iAdd = iAdd + fCallback(oAttack, oVictim, self)
    end

    return iAdd
end

function CPerform:ConstantDamage(oAttack, oVictim,iRatio,mEnv)
    return self:CalSkillFormula(oAttack,oVictim,iRatio,mEnv)
end

function CPerform:Perform(oAttack,lVictim)
    self:ClearTempData()
    self:PerformOnce(oAttack,lVictim)
    self:EndPerform(oAttack,lVictim)
    self:ClearTempData()
end

function CPerform:PerformOnce(oAttack,lVictim)
    local oWar = oAttack:GetWar()
    local iSkill = self.m_ID
    oAttack:SendAll("GS2CWarSkill", {
        war_id = oAttack:GetWarId(),
        action_wlist = {oAttack:GetWid(),},
        select_wlist = list_generate(lVictim, function (v)
            return v:GetWid()
        end),
        skill_id = iSkill,
        magic_id = 1,
    })

    oAttack:SetBoutArgs("pf_group_attact", 1)
    local mTime = self:PerformMagicTime(oAttack)
    oWar:AddAnimationTime(mTime[1])
    oWar:AddDebugMsg(string.format("#B%s#n使用#B%s#n", oAttack:GetName(), self:Name() ))

    local iRatio = 100
    if self:DoGroupRatio() then
        iRatio = self:GetPerformRatio(oAttack, #lVictim)
    end
    self:SetData("PerformAttackTotal", #lVictim)
    for _, oVictim in ipairs(lVictim) do
        local iAttackCnt = self:GetData("PerformAttackCnt",0)
        self:SetData("PerformAttackCnt",iAttackCnt+1)
        self:TruePerform(oAttack,oVictim,iRatio)
    end

    if self:NeedVictimTime() then
        for _, oVictim in ipairs(lVictim) do
            local iExtTime = oVictim:GetAttackedTime()
            if iExtTime > self:GetData("VictimTime", 0) then
                self:SetData("VictimTime", iExtTime)
            end
        end
        local iVictimTime = self:GetData("VictimTime", 0)
        oWar:AddAnimationTime(iVictimTime)
    end

    self:SetData("VictimTime", nil)
    self:SetData("PerformAttackCnt",nil)
    self:SetData("PerformAttackTotal",nil)
    if oAttack and not oAttack:IsDead() then
        if self:IsNearAction() then
            if self:NeedBackTime() then
                oWar:AddAnimationTime(600)
            end
            oAttack:SendAll("GS2CWarGoback", {
                war_id = oAttack:GetWarId(),
                action_wid = oAttack:GetWid(),
            })
        end
    end

    oAttack:SetBoutArgs("pf_group_attact", nil)
    for _, oVictim in pairs(lVictim) do
        if oVictim:HasKey("warrior_sub_hp") then
            oVictim:DoDeadAfterSubHp(oAttack)
        end
    end
end

function CPerform:EndPerform(oAttack, lVictim)
    local mInfo = res["daobiao"]["warconfig"]
    if oAttack and not oAttack:IsDead() then
        local mFunc = oAttack:GetFunction("OnEndPerform")
        for _,fCallback in pairs(mFunc) do
            safe_call(fCallback, oAttack, self, lVictim)
        end

        self:Effect_Condition_For_Attack(oAttack)
        if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.XINGXIU
            and self:IsGroupPerform() and math.random(100) <= (mInfo.taichu_aura_ratio or 100) then
            oAttack:AddAura(1)
        end
        if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.JINSHAN then
            if oAttack:QueryBoutArgs("recover_self_hp", 0) > 0 then
                local iHp = oAttack:QueryBoutArgs("recover_self_hp")
                local bCritical = oAttack:QueryBoutArgs("recover_self_hp_critical")
                oAttack:SetBoutArgs("recover_self_hp", nil)
                oAttack:SetBoutArgs("recover_self_hp_critical", nil)
                global.oActionMgr:DoAddHp(oAttack, iHp, bCritical)
            end
            if self:ActionType() == gamedefines.WAR_ACTION_TYPE.CURE and math.random(100) <= (mInfo.jinshan_aura_ratio or 100) then
                oAttack:AddAura(1)
            end
        end
        if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.QINGSHAN
            and self:ActionType() == gamedefines.WAR_ACTION_TYPE.SEAL and math.random(100) <= (mInfo.qingshan_aura_ratio or 100) then
            oAttack:AddAura(1)
        end
        if oAttack:IsPlayer() then
            local iAura = self:CalAddAura(oAttack)
            if iAura > 0 then
                oAttack:AddAura(iAura)
            end
        end
    end
    if oAttack then
        oAttack:SetCD(self:Type())
    end
end

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    local oActionMgr = global.oActionMgr
    if self:ActionType() == gamedefines.WAR_ACTION_TYPE.SEAL then
        local iMaxRatio = oAttack:Query("seal_ratio_max", 70)
        oActionMgr:DoSealAction(oAttack,oVictim,self,30, iMaxRatio)
        return
    end
    if self:ActionType() == gamedefines.WAR_ACTION_TYPE.CURE then
        local iHP = self:CalculateHp(oAttack,oVictim,iRatio)
        oActionMgr:DoCureAction(oAttack,oVictim,self,iHP)
        return
    end

    if self:AttackType() == gamedefines.WAR_PERFORM_TYPE.PHY then
        oActionMgr:TryDoPhyAttack(oAttack, oVictim, self, iRatio)
    elseif self:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC then
        oActionMgr:DoMagAttack(oAttack,oVictim,self,iRatio)
    end
end

function CPerform:GetAttackBuffData()
    local lBuffData, iLevel = {}, 0
    local mInfo = self:GetPerformData()
    for _, mData in ipairs(mInfo["attackBuff"] or {}) do
        if mData["level"] <= self:Level() then
            if mData["level"] > iLevel then
                lBuffData = {}
                iLevel = mData["level"]
            end

            local iRatio = self:GetAddAttackBuffRatio()

            if mData["level"] == iLevel and math.random(100) <= iRatio then
                table.insert(lBuffData, mData)
            end
        end 
    end
    return lBuffData
end

function CPerform:Effect_Condition_For_Attack(oAttack, mArgs)
    local mBuff = self:GetAttackBuffData()
    mArgs = mArgs or {}
    mArgs.level = self:Level()
    mArgs.action_wid = oAttack:GetWid()

    local oBuffMgr = oAttack.m_oBuffMgr
    for _,mData in pairs(mBuff) do
        local iBuffID = mData["buffid"]
        local mEnv = self:BoutEnv(oAttack,nil)
        local iBout = math.floor(formula_string(mData["bout"],mEnv))
        oBuffMgr:AddBuff(iBuffID,iBout,mArgs)
    end

    local mInfo = self:GetPerformData()
    mBuff = mInfo["attackDelBuff"] or {}
    for _,iBuffID in pairs(mBuff) do
        local oBuff = oBuffMgr:HasBuff(iBuffID)
        if oBuff then
            oBuffMgr:RemoveBuff(oBuff)
        end
    end
    if oAttack:QueryBoutArgs("element",0) == 3 then
        local oBuff = oBuffMgr:HasBuff(115)
        if oBuff then
            oBuffMgr:RemoveBuff(oBuff)
        end
    end
end

function  CPerform:GetVictimBuffData(oAttack)
    local lBuffData, iLevel = {}, 0
    local mInfo = self:GetPerformData()
    for _, mData in ipairs(mInfo["victimBuff"] or {}) do
        if mData["level"] <= self:Level() then
            if mData["level"] > iLevel then
                lBuffData = {}
                iLevel = mData["level"]
            end

            local iRatio = self:GetAddVictimBuffRatio(oAttack)

            if mData["level"] == iLevel and math.random(100) <= iRatio then
                table.insert(lBuffData, mData)
            end
        end
    end
    return lBuffData
end

function CPerform:Effect_Condition_For_Victim(oVictim,oAttack, mArgs)
    if not oVictim or oVictim:IsDead() then
        return
    end
    mArgs = mArgs or {}
    mArgs.level = self:Level()
    mArgs.action_wid = oAttack:GetWid()

    local oBuffMgr = oVictim.m_oBuffMgr
    local mBuff = self:GetVictimBuffData(oAttack)
    for _,mData in pairs(mBuff) do
        local iBuffID = mData["buffid"]
        local mEnv = self:BoutEnv(oAttack, oVictim)
        local iBout = math.floor(formula_string(mData["bout"],mEnv))

        local mFunc = oAttack:GetFunction("CheckAddBuffBout")
        for _,fCallback in pairs(mFunc) do
            iBout = iBout + fCallback(oVictim, oAttack, iBuffID)
        end
        local mFunc = oVictim:GetFunction("CheckAddBuffBout")
        for _,fCallback in pairs(mFunc) do
            iBout = iBout + fCallback(oVictim, oAttack, iBuffID, iBout)
        end
        if iBout > 0 then
            oBuffMgr:AddBuff(iBuffID,iBout,mArgs)
        end
    end

    local mInfo = self:GetPerformData()
    mBuff = mInfo["victimDelBuff"] or {}
    for _,iBuffID in pairs(mBuff) do
        local oBuff = oBuffMgr:HasBuff(iBuffID)
        if oBuff then
            oBuffMgr:RemoveBuff(oBuff)
        end
    end
end

function CPerform:BoutEnv(oAttack, oVictim)
    local mEnv = {level=self:Level()}
    if oAttack then
        mEnv.ga = oAttack:GetData("grade",0)
    end
    if oVictim then
        mEnv.gv = oVictim:GetData("grade",0)
    end
    return mEnv
end

function CPerform:GetData(key,rDefault)
    return self.m_mExtData[key] or rDefault
end

function CPerform:SetData(key, value)
    self.m_mExtData[key] = value
end

function CPerform:GetTempData(key, rDefault)
    return self.m_mTempData[key] or rDefault
end

function CPerform:SetTempData(key, value)
    self.m_mTempData[key] = value
end

function CPerform:ClearTempData()
    self.m_mTempData = {}
end

function CPerform:SetCD(iEndBout)
    self:SetData("CD", iEndBout) 
end

function CPerform:InCD(oAction)
    local iCDBout = self:GetData("CD")
    if not iCDBout then
        return false
    end
    local oWar = oAction:GetWar()
    if oWar:CurBout() <= iCDBout then
        return true
    end
    return false
end

function CPerform:CalAddAura(oAttack)
    local iAura = 0
    local mArgs = {
        level = self:Level(),
    }
    local mInfo = self:GetPerformData()
    local sAddAura = mInfo["aura_add"]
    if sAddAura and sAddAura ~= "" then
        if tonumber(sAddAura) then
            iAura = tonumber(sAddAura)
        else
            iAura = math.floor(formula_string(sAddAura, mArgs))
        end
    end
    return math.floor(iAura)
end

function CPerform:SetPriority(iPriority)
    self:SetData("priority", iPriority)
end

function CPerform:SetAITarget(iAITarget)
    self:SetData("ai_target", iAITarget)
end


