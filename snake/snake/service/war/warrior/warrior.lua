local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local extend = require "base.extend"
local res = require "base.res"

local status = import(lualib_path("base.status"))
local gamedefines = import(lualib_path("public.gamedefines"))
local pfload = import(service_path("perform/pfload"))
local buffmgr = import(service_path("buffmgr"))
local pfmgr = import(service_path("pfmgr"))
local loadai = import(service_path("ai.loadai"))
local statusmgr = import(service_path("statusmgr"))


CWarrior = {}
CWarrior.__index = CWarrior
inherit(CWarrior, logic_base_cls())

function CWarrior:New(iWid)
    local o = super(CWarrior).New(self)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.WARRIOR_TYPE
    o.m_iWid = iWid
    o.m_iWarId = nil
    o.m_iCamp = nil
    o.m_iPos = nil

    o.m_bIsDefense = false
    o.m_iProtectVictim = nil
    o.m_mProtectGuard = {}

    o.m_oStatus = status.NewStatus()
    o.m_oStatus:Set(gamedefines.WAR_WARRIOR_STATUS.ALIVE)

    o.m_mFunction = {}
    o.m_mBoutArgs = {}                                                                                  --每回合数据
    o.m_mAttrs = {}                                                                                         --属性数据
    o.m_mExtData = {}
    o.m_iAIType = gamedefines.AI_TYPE.COMMON
    o.m_iHasPerformType = 0
    return o
end

function CWarrior:Release()
    baseobj_safe_release(self.m_oStatus)
    baseobj_safe_release(self.m_oBuffMgr)
    baseobj_safe_release(self.m_oPerformMgr)
    baseobj_safe_release(self.m_oStatusBuffMgr)
    super(CWarrior).Release(self)
end

function CWarrior:Leave()
    local mFunc = self:GetFunction("OnLeave")
    for _,fCallback in pairs(mFunc) do
        safe_call(fCallback, self)
    end
end

function CWarrior:IsObserver()
    return false
end

function CWarrior:Type()
    return self.m_iType
end

function CWarrior:GetAIType()
    return self.m_iAIType
end

function CWarrior:SetAIType(iAIType)
    self.m_iAIType = iAIType
end

function CWarrior:InitAIType()
    local iAIType = self:GetData("aitype")
    if iAIType then
        self:SetAIType(iAIType)
    end
end

function CWarrior:Init(mInit)
    self.m_iWarId = mInit.war_id
    self.m_iCamp = mInit.camp_id
    self.m_mData = mInit.data
    self.m_mTestData = self.m_mData["testdata"] or {}
    self:SetData("hp", self:GetHp())
    self:SetData("mp", self:GetMp())
    self.m_oBuffMgr = buffmgr.NewBuffMgr(self.m_iWarId,self.m_iWid)
    self.m_oPerformMgr = pfmgr.NewPerformMgr(self.m_iWarId,self.m_iWid)
    self.m_oStatusBuffMgr = statusmgr.NewStatusMgr(self.m_iWarId,self.m_iWid)
    local mPerform = self:GetData("perform",{})
    for iPerform, mInfo in pairs(mPerform) do
        self:SetPerform(iPerform, mInfo)
    end
    self:InitAIType()

    local oWar = self:GetWar()
    if oWar then
        local sMsg = string.format("#B%s#n等级:%d,气血:%d,魔法值:%d,物攻:%d,法攻:%d,物防:%d,法防:%d,治疗:%d,封印:%d,抗封:%d,速度:%d,功法修炼:%d,物抗修炼:%d,法抗修炼:%d,封印修炼:%d",
            self:GetName(),
            self:GetGrade(),
            self:GetHp(),
            self:GetMp(),
            self:QueryAttr("phy_attack"),
            self:QueryAttr("mag_attack"),
            self:QueryAttr("phy_defense"),
            self:QueryAttr("mag_defense"),
            self:QueryAttr("cure_power"),
            self:QueryAttr("seal_ratio"),
            self:QueryAttr("res_seal_ratio"),
            self:QueryAttr("speed"),
            self:QueryExpertSkill(1),
            self:QueryExpertSkill(2),
            self:QueryExpertSkill(3),
            self:QueryExpertSkill(4)
        )
        oWar:AddDebugMsg(sMsg, true)
    end
end

function CWarrior:IsDead()
    return self.m_oStatus:Get() == gamedefines.WAR_WARRIOR_STATUS.DEAD
end

function CWarrior:IsAlive()
    return self.m_oStatus:Get() == gamedefines.WAR_WARRIOR_STATUS.ALIVE
end

function CWarrior:IsVisible(oAttack, bIncFriend)
    if bIncFriend or not self:IsFriend(oAttack) then
        if self:HasKey("stealth") and not oAttack:HasKey("ignore_stealth") then
            return false
        end

        if self:HasKey("strong_stealth") and not oAttack:HasKey("ignore_stealth") then
            return false
        end

        if self:HasKey("ignore_attacked") then
            return false
        end
    end
    return true
end

function CWarrior:Status()
    return self.m_oStatus:Get()
end

function CWarrior:IsPlayer()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.PLAYER_TYPE
end

function CWarrior:IsRoPlayer()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.ROPLAYER_TYPE
end

function CWarrior:IsNpc()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.NPC_TYPE
end

function CWarrior:IsSummon()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.SUMMON_TYPE
end

function CWarrior:IsRoSummon()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.ROSUMMON_TYPE
end

function CWarrior:IsPartner()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.PARTNER_TYPE
end

function CWarrior:IsRoPartner()
    return self.m_iType == gamedefines.WAR_WARRIOR_TYPE.ROPARTNER_TYPE
end

function CWarrior:IsPlayerLike()
    return self:IsPlayer() or self:IsRoPlayer()
end

function CWarrior:IsSummonLike()
    return self:IsSummon() or self:IsRoSummon()
end

function CWarrior:IsPartnerLike()
    return self:IsPartner() or self:IsRoPartner()
end

function CWarrior:IsNpcLike()
    return self:IsNpc() or self:IsRoPlayer() or self:IsRoSummon() or self:IsRoPartner()
end

function CWarrior:GetWid()
    return self.m_iWid
end

function CWarrior:GetWarId()
    return self.m_iWarId
end

function CWarrior:GetCampId()
    return self.m_iCamp
end

function CWarrior:SetPos(id)
    self.m_iPos = id
end

function CWarrior:GetPos()
    return self.m_iPos
end

function CWarrior:GetData(k, rDefault)
    if not extend.Table.find({"hp", "mp"}, k) then
        if self.m_mTestData[k] then
            return self.m_mTestData[k]
        end
    end
    return self.m_mData[k] or rDefault
end

function CWarrior:GetTypeSid()
    return self:GetData("type")
end

function CWarrior:SetData(k, v)
    self.m_mData[k] = v
end

function CWarrior:GetTestData(k)
    return self.m_mTestData[k]
end

function CWarrior:SetTestData(k, v)
    if k == "hp" or k == "mp" then
        self.m_mData[k] = math.min(v, self:GetData("max_"..k))
        return
    end
    self.m_mTestData[k] = v
    if k == "max_hp" then
        self:SetData("hp", self:GetMaxHp())
        self:StatusChange("hp")
        self:StatusChange("max_hp")
    elseif k == "max_mp" then
        self:SetData("mp", self:GetMaxMp())
        self:StatusChange("mp")
        self:StatusChange("max_mp")
    elseif k == "sp" then
        self.m_iSP = tonumber(v)
        if self.m_iSP > 150 then
            self.m_iTestMaxSP = self.m_iSP
        end
        self:StatusChange("sp")
    end
end

function CWarrior:GetExtData(k,rDefault)
    return self.m_mExtData[k] or rDefault
end

function CWarrior:SetExtData(k,v)
    self.m_mExtData[k] = v
end

function CWarrior:StatusChange(...)
end

function CWarrior:GetMaxHp()
    return self:GetData("max_hp")
end

function CWarrior:GetModelInfo()
    return self:GetData("model_info")
end

function CWarrior:GetMaxMp()
    return self:GetData("max_mp")
end

function CWarrior:GetHp()
    return self:GetData("hp")
end

function CWarrior:GetMp()
    return self:GetData("mp")
end

function CWarrior:GetName()
    return self:GetData("name")
end

function CWarrior:GetAura()
    return 0
end

function CWarrior:GetGrade()
    return self:GetData("grade", 0)
end

function CWarrior:GetTitle()
    return self:GetData("title")
end

function CWarrior:SubHp(i, oAttack, bAddSp)
    bAddSp = (bAddSp==nil) and true or bAddSp

    local oWar = self:GetWar()
    if oWar and oAttack then
        oWar.m_oRecord:AddAttack(oAttack, self, i)
    end

    if self:HasKey("shiled") then
        local iMp = self:GetMp()
        local iSubMp = i /2
        iSubMp = math.min(iMp,iSubMp)
        iSubMp = math.max(iSubMp,0)
        self:SubMp(iSubMp)
        i = i - iSubMp
        local iMp = self:GetMp()
        if iMp <= 0 then
            local oBuff = self.m_oBuffMgr:HasBuff(104)
            if oBuff then
                self.m_oBuffMgr:RemoveBuff(oBuff)
            end
        end
    end
    local iOldHp = self:GetHp("hp")
    local iCurHp = iOldHp - i
    iCurHp = math.max(0, math.min(self:GetMaxHp(), iCurHp))
    self:SetData("hp", iCurHp)

    if self:IsAlive() and self:GetData("hp") <= 0 then
        self:OnBeforeDead(oAttack)
        self.m_oStatus:Set(gamedefines.WAR_WARRIOR_STATUS.DEAD)
        self:StatusChange("status")
    end

    self:StatusChange("hp")
    self:OnSubHp(i, iOldHp, bAddSp, oAttack)

    if self:IsDead() then
        self:OnDead(oAttack)
    end

    self:SetBoutArgs("warrior_sub_hp", 1)
    if not oAttack or not oAttack:HasKey("pf_group_attact") then
        self:DoDeadAfterSubHp(oAttack)    
    end
end

function CWarrior:DoDeadAfterSubHp(oAttack)
    self:SetBoutArgs("warrior_sub_hp", nil)
    local mFunc = self:GetFunction("OnDeadAfterSubHp")
    for _,fCallback in pairs(mFunc) do
        safe_call(fCallback, self, oAttack)
    end
    if not self:IsPlayerLike() and not self:IsPartnerLike() and self:IsDead() and not self:CanKeepInWar(oAttack) then
        self:OnKickOut()
        local oWar = self:GetWar()
        if oWar then
            oWar:KickOutWarrior(self)
        end
    end
end

function CWarrior:CanKeepInWar(oAttack)
    if self:HasKey("keep_in_war") then return true end

    if self:HasKey("ghost") and (not oAttack or not oAttack:HasKey("kick_ghost")) then
        return true
    end
    return false
end

function CWarrior:OnDead(oAttack)
    self:AddCampDeadNum()
    if oAttack then
        oAttack:AddBoutArgs("killEnemy", 1)
        local mFunc = oAttack:GetFunction("OnKill")
        for _,fCallback in pairs(mFunc) do
            safe_call(fCallback, oAttack, self)
        end
    end

    local mFunction = self:GetFunction("OnDead") or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self, oAttack)
    end
end

function CWarrior:OnBeforeDead(oAttack)
    local mFunction = self:GetFunction("OnBeforeDead") or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self, oAttack)
    end
end

function CWarrior:AddCampDeadNum()
    local oWar = self:GetWar()
    oWar:AddCampDeadNum(self.m_iCamp, 1)

    if self:IsNpcLike() then
        local iType = self:GetData("type", 0)
        oWar.m_oRecord:AddMonsterDead(self.m_iCamp, iType)
        oWar.m_oRecord:AddMonsterDeadByWid(self.m_iCamp, self:GetWid())
    end
end

function CWarrior:GetCampDeadNum()
    local oWar = self:GetWar()
    return oWar:GetCampDeadNum(self.m_iCamp)
end

function CWarrior:OnKickOut()
    local mFunction = self:GetFunction("OnKickOut")
    mFunction = mFunction or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end
end

function CWarrior:SubMp(iMp)
    local mFunction = self:GetFunction("OnMpChange") or {}
    for _,fCallback in pairs(mFunction) do
        _, iMp = safe_call(fCallback, self, iMp, false)
    end
    self:SetData("mp",self:GetMp() - iMp)
    self:SetData("mp", math.max(0, math.min(self:GetMaxMp(), self:GetData("mp"))))
    self:StatusChange("mp")
end

function CWarrior:AddMp(iMp)
    local mFunction = self:GetFunction("OnMpChange") or {}
    for _,fCallback in pairs(mFunction) do
        iMp = safe_call(fCallback, self,iMp,true)
    end
    self:SetData("mp",self:GetMp() + iMp)
    self:SetData("mp", math.max(0, math.min(self:GetMaxMp(), self:GetData("mp"))))

    self:StatusChange("mp")   
end

function CWarrior:OnSubHp(iSubHp, iOldHp, bAddSp, oAttack)
    local mFunction = self:GetFunction("OnSubHp") or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self, oAttack)
    end
end

function CWarrior:AddHp(i)
    if self:IsDead() and self:HasKey("revive_disable") then
        return
    end
    self:SetData("hp", self:GetData("hp") + i)
    self:SetData("hp", math.max(0, math.min(self:GetMaxHp(), self:GetData("hp"))))
    -- self:StatusChange("hp")

    if self:IsDead() and self:GetData("hp") > 0 then
        self.m_oStatus:Set(gamedefines.WAR_WARRIOR_STATUS.ALIVE)
        self:StatusChange("status")
        self:OnRevive()
    end
    self:StatusChange("hp") 
--    self:SendAll("GS2CWarWarriorStatus", {
--        war_id = self:GetWarId(),
--        wid = self:GetWid(),
--        type = self:Type(),
--        status = self:GetSimpleStatus(),
--    })
end

function CWarrior:OnRevive()
    local oWar = self:GetWar()
    oWar:AddBoutRevive(self)
end

function CWarrior:GetSimpleWarriorInfo()
end

function CWarrior:GetSimpleStatus()
end

function CWarrior:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self:GetWarId())
end

function CWarrior:GetWarrior(iWid)
    local oWar = self:GetWar()
    return oWar:GetWarrior(iWid)
end

function CWarrior:GetPos()
    return self.m_iPos
end

function CWarrior:GetSpeed()
    local iSpeed = self:QueryAttr("speed")
    if not self:IsNpc() then
        if not self:Query("speed_float") then
            local lFloat = self:GetFloatRange("speed_float")
            local iMin, iMax = table.unpack(lFloat)
            self:Set("speed_float", math.random(iMin, iMax))
        end
        iSpeed = iSpeed * self:Query("speed_float") / 100
    end

    local oWar = self:GetWar()
    local mCmds = oWar:GetBoutCmd(self.m_iWid)
    local cmd = mCmds.cmd
    local mSkillData = mCmds.data
    local iRatio = self:QueryAttr("speed_ratio")
    local iExtSpeed = 0
    oWar:AddDebugMsg(string.format("\n%s波动后速度%s,速度加成%s%%", self:GetName(), iSpeed, iRatio))
    if cmd == "skill" then
        local iSkill = mSkillData.skill_id
        local oPerform = self:GetPerform(iSkill)
        if oPerform then
            iRatio = iRatio + oPerform:SpeedRatio()
            iExtSpeed = oPerform:PerformTempAddSpeed(self)
            oWar:AddDebugMsg(string.format("招式#B%s#n速度加成%s%%, 额外增加%s",
                oPerform:Name(), oPerform:SpeedRatio(), iExtSpeed))
        end
    elseif cmd == "summon" then
        iRatio = iRatio + 20
    elseif cmd == "useitem" then
        iRatio = iRatio + 20
    end
    
    local mFunc = self:GetFunction("OnAddSpeedRatio")
    for _,fCallback in pairs(mFunc) do
        iRatio = iRatio + fCallback(self, iRatio, cmd)
    end
    local oCamp = oWar:GetCampObj(self:GetCampId())
    iRatio = iRatio + (oCamp.m_iSpeedRatio or 0)

    iSpeed = math.floor(iSpeed * (100 + iRatio) / 100)
    iSpeed = iSpeed + iExtSpeed
    oWar:AddDebugMsg(string.format("最终出手速度%s", iSpeed))
    return iSpeed
end

function CWarrior:SetDefense(bFlag)
    self.m_bIsDefense = bFlag
end

function CWarrior:IsDefense()
    return self.m_bIsDefense or self:HasKey("defense")
end

function CWarrior:SetProtect(iVictim)
    if not iVictim then
        if self.m_iProtectVictim then
            local oVictim = self:GetWarrior(self.m_iProtectVictim)
            if oVictim then
                oVictim:SetGuard(self:GetWid(), nil)
            end
            self.m_iProtectVictim = nil
        end
    else
        local oVictim = self:GetWarrior(iVictim)
        if oVictim then
            self.m_iProtectVictim = iVictim
            oVictim:SetGuard(self:GetWid(), 1)
        end
    end
end

function CWarrior:SetGuard(iGuard, iVal)
    self.m_mProtectGuard[iGuard] = iVal
end

function CWarrior:ClearGuard()
    self.m_mProtectGuard = {}
end

function CWarrior:GetProtect()
    local id = self.m_iProtectVictim
    if not id then return end
    return self:GetWarrior(id)
end

function CWarrior:CanProtect()
    if self:IsDead() then return false end

    if self:QueryBoutArgs("protect_cnt", 0) >= 1 then
        return false
    end

    -- 保护没有血量限制
    return true
end

function CWarrior:GetGuard()
    local iSpeed, oResult
    for iGuard, _ in pairs(self.m_mProtectGuard) do
        local oGuard = self:GetWarrior(iGuard)
        if oGuard and oGuard:IsAlive() and oGuard:CanProtect() then
            if not iSpeed then
                oResult = oGuard
                iSpeed = oGuard:GetSpeed()
            else
                if iSpeed < oGuard:GetSpeed() then
                    iSpeed = oGuard:GetSpeed()
                    oResult = oGuard
                end
            end
        end
    end
    return oResult
end

function CWarrior:OnWarStart()
    local mFunction = self:GetFunction("OnWarStart")
    mFunction = mFunction or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end
end

function CWarrior:OnEnterWar()
    local mFunction = self:GetFunction("OnEnterWar")
    mFunction = mFunction or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end
end

function CWarrior:OnBoutStart()
    self:SetDefense(false)
    self:SetProtect()
    self:ClearGuard()
    self.m_mBoutArgs = {}
    local mFunction = self:GetFunction("OnBoutStart")
    for iNo,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end
    if self:IsPlayer() or self:IsSummon() then
        self:StatusChange("cmd")
    end
end

function CWarrior:CurBout()
    local oWar = self:GetWar()
    return oWar:CurBout()
end

function CWarrior:NewBout()
    local oWar = self:GetWar()
    local mCmds = oWar:GetBoutCmd(self.m_iWid)
    if mCmds then 
        local cmd = mCmds.cmd
        local mSkillData = mCmds.data
        self:SetBoutArgs("element",0)
        if cmd == "skill" then
            local iSkill = mSkillData.skill_id
            local oPerform = self:GetPerform(iSkill)
            if oPerform then
                self:SetBoutArgs("element",oPerform:PerformElement())
            end
        end
        if self:IsSummon() then
            self:SetBoutArgs("element",self:GetData("element",0))
        end
    end 

    self.m_oBuffMgr:OnNewBout(self)
    local mFunction = self:GetFunction("OnNewBout")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end
end

function CWarrior:OnBoutEnd()
    self.m_oBuffMgr:OnBoutEnd(self)

    local mFunction = self:GetFunction("OnBoutEnd")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end

    if self:IsPlayer() then
        local oWar = self:GetWar()
        oWar:AddDebugMsg(string.format("#B%s#n回合结束灵气:%d", self:GetName(), self:GetAura()))
    end
end

function CWarrior:CheckChangeCmd(mCmd,sType)
    local cmd
    local mFunction = self:GetFunction("ChangeCmd")
    for _,fCallback in pairs(mFunction) do
        local bRet , mRet = safe_call(fCallback, self, mCmd, sType)
        if bRet and mRet then
            cmd = mRet
            break
        end
    end
    return cmd
end

function CWarrior:PerformFunc(lSelect,iSkill)
    local mFunction = self:GetFunction("PerformFunc")
    for _,fCallback in pairs(mFunction) do
        if fCallback(self,lSelect,iSkill) then
            return true
        end
    end
    return false
end

function CWarrior:DoBeforeAct()
    local mFunction = self:GetFunction("OnBeforeAct")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self)
    end
end

function CWarrior:Send(sMessage, mData)
    -- 基类不能发送，player才能发
end

function CWarrior:SendRaw(sData)
end

function CWarrior:SendAll(sMessage, mData, mExclude)
    local oWar = self:GetWar()
    oWar:SendAll(sMessage, mData, mExclude)
end

function CWarrior:QueryAttr(sAttr)
    local iBase = self:GetBaseAttr(sAttr) * ( 100 + self:GetAttrBaseRatio(sAttr)) /100 + self:GetAttrAddValue(sAttr)
    iBase = iBase * ( 100 + self:GetAttrTempRatio(sAttr) ) /100 + self:GetAttrTempAddValue(sAttr)
    iBase  = iBase + self:QueryBoutArgs(sAttr,0) + self:Query(sAttr,0)
    iBase = math.floor(iBase)
    return iBase
end

function CWarrior:GetBaseAttr(sAttr)
    return self:GetData(sAttr,0)
end

function CWarrior:GetAttrBaseRatio(sAttr)
    local iRatio = self.m_oBuffMgr:GetAttrBaseRatio(sAttr) + self.m_oPerformMgr:GetAttrBaseRatio(sAttr)
    return iRatio
end

function CWarrior:GetAttrAddValue(sAttr)
    local iValue = self.m_oBuffMgr:GetAttrAddValue(sAttr) + self.m_oPerformMgr:GetAttrAddValue(sAttr)
    return iValue
end

function CWarrior:GetAttrTempRatio(sAttr)
    local iRatio = self.m_oBuffMgr:GetAttrTempRatio(sAttr)
    return iRatio
end

function CWarrior:GetAttrTempAddValue(sAttr)
    local iValue = self.m_oBuffMgr:GetAttrTempAddValue(sAttr)
    return iValue
end

function CWarrior:SetPerform(iPerform, mInfo)
    self.m_oPerformMgr:SetPerform(self, iPerform, mInfo)
end

function CWarrior:GetPerform(pfid)
    return self.m_oPerformMgr:GetPerform(pfid)
end

function CWarrior:GetPerformList()
    local mPerform = self.m_oPerformMgr:GetPerformList()
    mPerform = mPerform or {}
    return mPerform
end

function CWarrior:GetActivePerformList()
    local lPerform = {}
    local mPerform = self.m_oPerformMgr:GetPerformTable()
    for iPerform, oPerform in pairs(mPerform) do
        if oPerform:IsActive() then
            table.insert(lPerform, iPerform)
        end
    end
    return lPerform
end

function CWarrior:PackActivePerform()
    local lPerform = {}
    local mPerform = self.m_oPerformMgr:GetPerformTable()
    for iPerform, oPerform in pairs(mPerform) do
        if oPerform:IsActive() then
            local mUnit = {
                pf_id = iPerform,
                cd = oPerform:GetData("CD"),
            }
            table.insert(lPerform, mUnit)
        end
    end
    return lPerform
end

function CWarrior:SetCD(iPerform)
    local oWar = self:GetWar()
    if not oWar then return end

    local oPerform = self:GetPerform(iPerform)
    if not oPerform or not oPerform:IsActive() then
        return
    end

    local iCDBout = oPerform:CDBout()
    if iCDBout > 0 then
        local iCurrBout = oWar:CurBout()
        oPerform:SetCD(iCurrBout + iCDBout)
        self:RefreshPerformCD(iPerform)
    end
end

function CWarrior:RefreshPerformCD(iPerform)
end

function CWarrior:AddBoutArgs(key,value)
    local iValue = self.m_mBoutArgs[key] or 0
    self.m_mBoutArgs[key] = iValue + value
end

function CWarrior:SetBoutArgs(key,value)
    self.m_mBoutArgs[key] = value
end

function CWarrior:QueryBoutArgs(key,rDefault)
    return self.m_mBoutArgs[key] or rDefault
end

function CWarrior:Add(key,value)
    local iValue = self.m_mAttrs[key] or 0
    self.m_mAttrs[key] = iValue + value
end

function CWarrior:Set(key,value)
    self.m_mAttrs[key] = value
end

function CWarrior:Query(key,rDefault)
    return self.m_mAttrs[key] or rDefault
end

function CWarrior:HasKey(sKey)
    local oBuffMgr = self.m_oBuffMgr
    if oBuffMgr:HasKey(sKey) then
        return true
    end
    if self:QueryBoutArgs(sKey) then
        return true
    end
    if self:Query(sKey) then
        return true
    end
    return false
end

function CWarrior:GetKey(sKey, rDefault)
    local iVal = self:QueryBoutArgs(sKey)
    if iVal then
        return iVal
    end
    local oBuffMgr = self.m_oBuffMgr
    iVal = oBuffMgr:HasKey(sKey)
    if iVal then
        return oBuffMgr:GetAttr(sKey)
    end
    iVal = self:Query(sKey)
    if iVal then
        return iVal
    end
    return rDefault
end

function CWarrior:GetFriendList(bAll)
    local oWar = self:GetWar()
    local iCamp = self.m_iCamp
    local mFriendList = oWar:GetWarriorList(iCamp)
    if bAll then
        return mFriendList
    else
        local l = {}
        for _,oVictim in pairs(mFriendList) do
            if oVictim:IsAlive() and oVictim:IsVisible(self) then
                table.insert(l,oVictim)
            end
        end
        return l
    end
end

function CWarrior:GetEnemyList(bAll)
    local oWar = self:GetWar()
    local iCamp = 3 - self.m_iCamp
    local mEnemy = oWar:GetWarriorList(iCamp)
    if bAll then
        return mEnemy
    else
        local l = {}
        for _,oVictim in pairs(mEnemy) do
            if oVictim:IsAlive() and oVictim:IsVisible(self) then
                table.insert(l,oVictim)
            end
        end
        return l
    end
end

function CWarrior:IsFriend(oVictim)
    if not oVictim then
        return
    end
    if self.m_iCamp == oVictim.m_iCamp then
        return true
    end
    return false
end

function CWarrior:IsEnemy(oVictim)
    if not oVictim then
        return
    end
    if self.m_iCamp ~= oVictim.m_iCamp then
        return true
    end
    return false
end

function CWarrior:GetFunction(sFunction)
    local mFunction = self.m_mFunction[sFunction] or {}
    local mBuffFunction = self.m_oBuffMgr:GetFunction(sFunction)
    local mPfFunction = self.m_oPerformMgr:GetFunction(sFunction)
    local mCallback = {}
    for iNo,fCallback in pairs(mFunction) do
        mCallback[iNo] = fCallback
    end
    for iNo,fCallback in pairs(mBuffFunction) do
        mCallback[iNo] = fCallback
    end
    for iNo,fCallback in pairs(mPfFunction) do
        mCallback[iNo] = fCallback
    end
    return mCallback
end

function CWarrior:AddFunction(sFunction,iNo,fCallback)
    local mFunction = self.m_mFunction[sFunction] or {}
    mFunction[iNo] = fCallback
    self.m_mFunction[sFunction] = mFunction
end

function CWarrior:RemoveFunction(sFunction,iNo)
    local mFunction = self.m_mFunction[sFunction] or {}
    mFunction[iNo] = nil
    self.m_mFunction[sFunction] = mFunction
end

function CWarrior:OnAttackDelay(oVictim,oPerform,iDamage,mArgs)
    local mFunction = self:GetFunction("OnAttackDelay")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self,oVictim,oPerform,iDamage,mArgs)
    end
end

function CWarrior:OnAttack(oVictim,oPerform,iDamage,mArgs)
    local mFunction = self:GetFunction("OnAttack")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self,oVictim,oPerform,iDamage,mArgs)
    end

    if not mArgs or mArgs.is_critical ~= 1 then
        return
    end
    if not self:IsPlayerLike() or self:GetData("school") ~= gamedefines.PLAYER_SCHOOL.SHUSHAN then
        return
    end
    if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return
    end

    self:AddAura(1)
end

function CWarrior:OnAttack2(oVictim,oPerform,iDamage,mArgs)
    local mFunction = self:GetFunction("OnAttack2")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self,oVictim,oPerform,iDamage,mArgs)
    end    
end

function CWarrior:OnAttacked(oAttack,oPerform,iDamage,mArgs)
    local mFunction = self:GetFunction("OnAttacked")
    for _,fCallback in pairs(mFunction) do
        fCallback(self,oAttack,oPerform,iDamage,mArgs)
    end
    self:AddBoutArgs("attacked_cnt",1)
    if oAttack:IsControl(self) then
        self:AddBoutArgs("control_attacked_cnt",1)
    end
end

function CWarrior:QueryExpertSkill(iNo)
    local mData = self:GetData("expertskill",{})
    local iValue = mData[iNo] or 0
    return iValue
end

--是否克制
function CWarrior:IsControl(oVictim)
    local iElement = self:QueryBoutArgs("element",0)
    local iTargetElement = oVictim:QueryBoutArgs("element",0)
    if self:GetData("element",0) then
        iElement = self:GetData("element")
    end
    --无属性
    if iTargetElement == 0 then
        return false
    end
    --全属性
    if iElement == 5 then
        return true
    end
    if iElement == 1 and iTargetElement == 2 then
        return true
    elseif iElement == 2 and iTargetElement == 3 then
        return true
    elseif iElement ==3 and iTargetElement == 4 then
        return true
    elseif iElement == 4 and iTargetElement == 1 then
        return true
    end
    return false
end

--受击度
function CWarrior:GetAttackedDegree()
    local iAttackedCnt = self:QueryBoutArgs("attacked_cnt",0)
    local iDegree = iAttackedCnt * 5
    iDegree = math.min(iDegree,10)
    return iDegree
end

--克制受击度
function CWarrior:GetControlAttackedDegree()
    local iAttackedCnt = self:QueryBoutArgs("control_attacked_cnt",0)
    local iDegree = iAttackedCnt * 5
    return iDegree
end

function CWarrior:ReceiveDamage(oAttack,pfobj,iDamage,mArgs)
    iDamage = math.floor(math.abs(iDamage))
    local oWar = self:GetWar()
    oWar:AddDebugMsg(string.format("#B%s#n受到伤害%d",self:GetName(),iDamage))
    self:SubHp(iDamage, oAttack)
    if self:IsDead() then
        if oAttack and oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.SHUSHAN then
            oAttack:AddAura(1)
        end
        oWar:AddDebugMsg(string.format("#B%s#n死亡",self:GetName()))
    end
    self:OnReceiveDamage(oAttack, pfobj, iDamage, mArgs)
end

function CWarrior:OnReceiveDamage(oAttack, oPerform, iDamage, mArgs)
    local mFunction = self:GetFunction("OnReceiveDamage")
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self, oAttack, oPerform, iDamage, mArgs)
    end
end

function CWarrior:IsGhost()
    if self:HasKey("ghost") then
        return true
    end
    return false
end

function CWarrior:AISetNormalAttack(iTarget)
    local oWar = self:GetWar()
    if not iTarget then
        local mTarget = self:GetEnemyList()
        if mTarget and #mTarget > 0 then
            local oTarget = mTarget[math.random(#mTarget)]
            iTarget = oTarget.m_iWid
        end
    end

    local mCmd = {
        cmd = "normal_attack",
        data = {
            action_wid = self.m_iWid,
            select_wid = iTarget,
        }
    }
    oWar:AddBoutCmd(self.m_iWid,mCmd)
end

function CWarrior:OnImmuneDamage(oAttack, oPerform, iDamage)
    local mFunction = self:GetFunction("OnImmuneDamage") or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, self, oAttack, oPerform, iDamage)
    end

    local iRatio = 100 + self:QueryBoutArgs("immune_damage_ratio", 0)
    self:SetBoutArgs("immune_damage_ratio", nil)
    if self:HasKey("immune_damage") then
        self:SetBoutArgs("immune_damage", nil)
        return true, iDamage
    end
    return false, math.floor(iDamage * iRatio / 100)
end

function CWarrior:AICommand()
    local oWar = self:GetWar()
    if oWar and oWar:GetBoutCmd(self:GetWid()) then
        return
    end
    local iAIType = self:GetAIType()
    local oAIObj = loadai.GetAI(iAIType)
    if oAIObj then
        oAIObj:Command(self)
    end
end

function CWarrior:IsSealed()
    return self:HasKey("phy_disable") or self:HasKey("mag_disable") or self:HasKey("attack_disable")
end

function CWarrior:GetFloatRange(sKey)
    return res["daobiao"]["warconfig"][sKey]["float_range"]
end

function CWarrior:GS2CTriggerPassiveSkill(iPerform, lArgs)
    local oWar = self:GetWar()
    if not oWar then return end

    local mNet = {
        war_id = self:GetWarId(),
        pfid = iPerform,
        wid = self:GetWid(),
        key_list = lArgs,
    }
    self:SendAll("GS2CTriggerPassiveSkill", mNet)
end

function CWarrior:GetDefenseFactor()
    local iFactor = 50

    local mFunc = self:GetFunction("GetDefenseFactor")
    for _,fCallback in pairs(mFunc) do
        iFactor = iFactor - fCallback(self)
    end

    return iFactor/100
end

function CWarrior:IsUseMagFormula()
    local iSchool = self:GetData("school")
    if iSchool == gamedefines.PLAYER_SCHOOL.JINSHAN then
        return true
    end
    if iSchool == gamedefines.PLAYER_SCHOOL.QINGSHAN then
        return true
    end
    if iSchool == gamedefines.PLAYER_SCHOOL.YAOCHI then
        return true
    end
    return false
end

function CWarrior:GetHasPerformType()
    return self.m_iHasPerformType
end

function CWarrior:GetShape()
    local mModel = self:GetData("model_info", {})
    local iShape
    if mModel.shape then
        iShape = mModel.shape
    elseif mModel.figure then
        iShape = mModel.figure
    else
        iShape = 1
    end
    return iShape
end

function CWarrior:GetAttackedTime()
    local iShape = self:GetShape()
    local mInfo = res["attackedtime"]
    local mTime = table_get_depth(mInfo, {iShape})
    if mTime then
        return mTime.hit1 + mTime.hit2
    else
        return 600
    end
end

function CWarrior:PackBuffList()
    local oWar = self:GetWar()
    if not oWar then return end

    local iExtBout = 0
    local iStatus, iStatusTime = oWar.m_oBoutStatus:Get()
    if iStatus ~= gamedefines.WAR_BOUT_STATUS.NULL then
        iExtBout = 1
    end

    local lBuff = self.m_oBuffMgr:GetBuffList()
    local lResult = {}
    for idx, oBuff in ipairs(lBuff or {}) do
        local mBuff = {}
        mBuff.buff_id = oBuff.m_ID
        mBuff.bout  = oBuff:Bout() + iExtBout
        mBuff.attrlist = oBuff:PackAttr(self)
        table.insert(lResult, mBuff)
    end
    return lResult
end

function CWarrior:PackStatusList()
    local lNet = {}
    for _, oStatus in ipairs(self.m_oStatusBuffMgr:GetAllStatus() or {}) do
        table.insert(lNet, oStatus:PackUnit())
    end
    return lNet
end

function CWarrior:GetSP()
end

function CWarrior:AddSP(iSP)
end

