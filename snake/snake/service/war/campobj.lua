--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local fmtobj = import(service_path("fmtobj"))
local util = import(lualib_path("public.util"))

function NewCamp(...)
    local o = CCamp:New(...)
    return o
end

CCamp = {}
CCamp.__index = CCamp
inherit(CCamp, logic_base_cls())

function CCamp:New(id)
    local o = super(CCamp).New(self)
    o.m_iCampId = id
    o.m_mWarriors = {}
    o.m_mPos2Wid = {}
    o.m_iMaxPos = 0
    o.m_oFormation = nil
    o.m_iFmtEffect = 0
    o.m_iDeadNum = 0
    o.m_Appoint = nil
    o.m_bCleanAppoint = false
    o.m_mFunction = {}
    return o
end

function CCamp:Release()
    for _, v in pairs(self.m_mWarriors) do
        baseobj_safe_release(v)
    end
    self.m_mWarriors = {}
    if self.m_oFormation then
        baseobj_safe_release(self.m_oFormation)
    end
    super(CCamp).Release(self)
end

function CCamp:Init(mInit)
    local iBossWarType = mInit.boss_war_type
    if iBossWarType and iBossWarType ~= 0 then
        self.m_iBossWarType = iBossWarType
    end
    local mFmtInfo = mInit.fmtinfo
    if mFmtInfo and mFmtInfo.fmt_id then
        local iFmtId = mFmtInfo.fmt_id
        self.m_oFormation = fmtobj.NewFmtObj(iFmtId, mFmtInfo)
    end
    local lMonsterPos = mInit.monster_pos
    if lMonsterPos then
        self.m_lMonsterPos = lMonsterPos
    end
end

function CCamp:GetCampId()
    return self.m_iCampId
end

function CCamp:GetWarrior(id)
    return self.m_mWarriors[id]
end

function CCamp:GetAliveCount()
    local mFunc = self:GetFunction("GetAliveCount")
    if mFunc then
        for _, func in pairs(mFunc) do
            return func(self, iExclude)
        end
    end

    local i = 0
    for k, v in pairs(self.m_mWarriors) do
        if v:IsAlive() and not v:HasKey("ignore_count") then
            i = i + 1
        end
    end
    return i
end

function CCamp:GetPlayerAliveCout()
    local i = 0
    for k,v in pairs(self.m_mWarriors) do
        if v:IsAlive() and v:IsPlayer() then
            i = i + 1
        end
    end
    return i
end

function CCamp:GetWarriorList()
    local l = {}
    for k,v in pairs(self.m_mWarriors) do
        table.insert(l,v)
    end
    return l
end

function CCamp:GetWarriorByPos(iPos)
    local id = self.m_mPos2Wid[iPos]
    if id then
        return self:GetWarrior(id)
    end
end

function CCamp:DispatchPos(iWid, iPos)
    local iTarget
    if not iPos then
        local iMax = self.m_iMaxPos + 1
        for i = 1, iMax do
            if not self.m_mPos2Wid[i] then
                iTarget = i
                break
            end
        end
    else
        assert(not self.m_mPos2Wid[iPos], string.format("CCamp DispatchPos fail %d %d", iWid, iPos))
        iTarget = iPos
    end
    if iTarget > self.m_iMaxPos then
        self.m_iMaxPos = iTarget
    end
    self.m_mPos2Wid[iTarget] = iWid
    return iTarget
end

function CCamp:GetSummonPos(oPlayer)
    local iPos = oPlayer:GetPos()
    local iTargetPos = nil
    if iPos <= 5 then
        iTargetPos = iPos + 5
    elseif iPos>10 and iPos<14 then
        iTargetPos = iPos - 5
    else
        iTargetPos = 6
    end
    if iTargetPos > self.m_iMaxPos then
        self.m_iMaxPos = iTargetPos
    end
    return iTargetPos
end

function CCamp:HookFormationPosEffect(obj)
    if self.m_oFormation then
        self.m_oFormation:OnEnterFormation(obj)
    end
end

function CCamp:CalFormationEffect(oOtherCamp)
    local oOtherFmt = oOtherCamp.m_oFormation
    if not oOtherFmt or not self.m_oFormation then
        return
    end
    local iVal = self.m_oFormation:CalFormationEffect(oOtherFmt)
    self.m_iFmtEffect =  iVal
    oOtherCamp.m_iFmtEffect = -iVal
    self:NotifyFormation(oOtherCamp)
    oOtherCamp:NotifyFormation(self)
end

function CCamp:DispatchBossPosition(oWarrior)
    if oWarrior:IsBoss() then
        local lPos = res["daobiao"]["bosswar_pos"][self.m_iBossWarType]["boss_pos"]
        if not self.m_iBossWarBoss then
            self.m_iBossWarBoss = 0
        end
        self.m_iBossWarBoss = self.m_iBossWarBoss + 1
        return lPos[self.m_iBossWarBoss]
    else
        local lPos = res["daobiao"]["bosswar_pos"][self.m_iBossWarType]["normal_pos"]
        if not self.m_iBossWarNormal then
            self.m_iBossWarNormal = 0
        end
        self.m_iBossWarNormal = self.m_iBossWarNormal + 1
        return lPos[self.m_iBossWarNormal]
    end
end

function CCamp:GetWarPos(obj)
    if self.m_iBossWarType and obj:IsNpc() then
        return self:DispatchBossPosition(obj)
    end
    if self.m_lMonsterPos and obj:IsNpc() then
        return table.remove(self.m_lMonsterPos, 1)
    end
    if obj:IsNpc() and self.m_iCampId == gamedefines.WAR_WARRIOR_SIDE.FRIEND then
        local lPos = {13, 12, 11, 14}
        for _, iPos in ipairs(lPos) do
            if not self.m_mPos2Wid[iPos] then
                return iPos
            end
        end
    end
    if self.m_oFormation then
        return self.m_oFormation:GetWarPos(obj)
    end
end

function CCamp:Enter(obj)
    if not obj:GetPos() then
        local iPos = self:GetWarPos(obj)
        local iTargetPos = self:DispatchPos(obj:GetWid(), iPos)
        obj:SetPos(iTargetPos)
    end
    self.m_mWarriors[obj:GetWid()] = obj
    self.m_mPos2Wid[obj:GetPos()] = obj:GetWid()
    self:HookFormationPosEffect(obj)
end

function CCamp:GetLeftPosCnt()
    return math.max(0,14-table_count(self.m_mPos2Wid))
end

function CCamp:EnterSummon(obj,iTargetPos)
    obj:SetPos(iTargetPos)
    self.m_mWarriors[obj:GetWid()] = obj
    self.m_mPos2Wid[iTargetPos] = obj:GetWid()
    self:HookFormationPosEffect(obj)
end

function CCamp:Leave(obj)
    self.m_mPos2Wid[obj:GetPos()] = nil
    self.m_mWarriors[obj:GetWid()] = nil
end

function CCamp:WarriorCount()
    return table_count(self.m_mWarriors)
end

function CCamp:OnWarStart()
    local mWarrior  = extend.Table.clone(self.m_mWarriors)
    for k,v in pairs(mWarrior) do
        if self.m_mWarriors[k] then
            v:OnWarStart()
        end
    end
end

function CCamp:OnBoutStart()
    if self.m_bCleanAppoint then
        self:CleanAppoint()
    end
    local mWarrior  = extend.Table.clone(self.m_mWarriors)
    for k, v in pairs(mWarrior) do
        if self.m_mWarriors[k] then
            v:OnBoutStart()
        end
    end
end

function CCamp:NewBout()
    local mWarrior  = extend.Table.clone(self.m_mWarriors)
    for k,v in pairs(mWarrior) do
        if self.m_mWarriors[k] then
            v:NewBout()
        end
    end
end

function CCamp:OnBoutEnd()
    local mWarrior  = extend.Table.clone(self.m_mWarriors)
    for k, v in pairs(mWarrior) do
        if self.m_mWarriors[k] then
            v:OnBoutEnd()
        end
    end
end

function CCamp:AddDeadNum(iCnt)
    self.m_iDeadNum = self.m_iDeadNum + iCnt
end

function CCamp:GetDeadNum()
    return self.m_iDeadNum
end

function CCamp:UpdateAppoint(oWar,iAppoint)
    self.m_Appoint = iAppoint
    self.m_bCleanAppoint = false
    local mExclude = oWar:GetWarCommandExclude(self.m_iCampId)
    local mNet = {}
    mNet.war_id = oWar.m_iWarId
    mNet.appoint =self.m_Appoint
    mNet.appointop = self:GetAppointOP(self.m_Appoint)
    oWar:SendAll("GS2CUpdateWarCommand",mNet,mExclude)
end

function CCamp:GetWar()
    for k,v in pairs(self.m_mWarriors) do
        return v:GetWar()
    end
end

function CCamp:CleanAppoint()
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    if oWar.m_Appoint and oWar.m_Appoint[self.m_iCampId] and #oWar.m_Appoint[self.m_iCampId]>0 then
        local mExclude = oWar:GetWarCommandExclude(self.m_iCampId)
        local mNet = {war_id = oWar.m_iWarId,op = 0}
        oWar:SendAll("GS2CWarCommand",mNet,mExclude)
    end
end

function CCamp:ChangeAppointOP(pid,iOP)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    if self.m_Appoint ~= pid then
        return
    end
    if iOP == 1 then
        self.m_bCleanAppoint = true
    else
        self.m_bCleanAppoint = false
    end
    local mExclude = oWar:GetWarCommandExclude(self.m_iCampId)
    local mNet = {}
    mNet.war_id = oWar.m_iWarId
    mNet.appoint =self.m_Appoint
    mNet.appointop = self:GetAppointOP(self.m_Appoint)
    oWar:SendAll("GS2CUpdateWarCommand",mNet,mExclude)
end

function CCamp:GetAppointOP(pid)
    if self.m_bCleanAppoint  and self.m_Appoint == pid then
        return 1
    else
        return 0
    end
end

function CCamp:GetFunction(sFunction)
    return self.m_mFunction[sFunction]
end

function CCamp:AddFunction(sFunction,iNo,fCallback)
    local mFunction = self.m_mFunction[sFunction] or {}
    mFunction[iNo] = fCallback
    self.m_mFunction[sFunction] = mFunction
end

function CCamp:RemoveFunction(sFunction,iNo)
    local mFunction = self.m_mFunction[sFunction] or {}
    mFunction[iNo] = nil
    self.m_mFunction[sFunction] = mFunction
end

function CCamp:GetFmtId()
    if self.m_oFormation then
        return self.m_oFormation:GetFmtId()
    end
    return 1
end

function CCamp:GetFmtGrade()
    if self.m_oFormation then
        return self.m_oFormation:GetGrade()
    end
    return 1
end

function CCamp:NotifyFormation(oOtherCamp)
    local oWar = self:GetWar()
    if not oWar then return end

    if not self.m_iFmtEffect or self.m_iFmtEffect == 0 then
        return
    end

    if oWar:GetWarType() ~= gamedefines.WAR_TYPE.PVP_TYPE then
        local iFmtId = self:GetCampId() == 2 and self:GetFmtId() or oOtherCamp:GetFmtId()
        if iFmtId == 1 or self:GetCampId() == 2 then return end
    end

    local iChat = self.m_iFmtEffect > 0 and 1008 or 1007
    local sText = res["daobiao"]["formation"]["text"][iChat]["content"]
    local mReplace = {damage_ratio = math.abs(self.m_iFmtEffect)}
    local sMsg = util.FormatColorString(sText, mReplace)
    for k, v in pairs(self.m_mWarriors) do
        if v and v:IsPlayer() then
            v:Notify(sMsg)
        end
    end
end

