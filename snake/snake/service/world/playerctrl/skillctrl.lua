--import module
local skynet = require "skynet"
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"

local tableop = import(lualib_path("base.tableop"))
local datactrl = import(lualib_path("public.datactrl"))
local loadskill = import(service_path("skill/loadskill"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

local max = math.max
local min = math.min

CSkillCtrl = {}
CSkillCtrl.__index = CSkillCtrl
inherit(CSkillCtrl, datactrl.CDataCtrl)

function CSkillCtrl:New(pid)
    local o = super(CSkillCtrl).New(self, {pid = pid})
    o.m_List = {}
    o.m_mOrgSkill = {}
    o.m_mItemSkill = {}
    o.m_mFuZhuanSkill = {}
    o.m_mMarrySkill = {}
    return o
end

function CSkillCtrl:Release()
    for _,oSkill in pairs(self.m_List) do
        baseobj_safe_release(oSkill)
    end
    for _, oSk in pairs(self.m_mOrgSkill) do
        baseobj_safe_release(oSk)
    end
    for _, mSkill in pairs(self.m_mItemSkill) do
        for iSkill, oSkill in pairs(mSkill) do
            baseobj_safe_release(oSkill)
        end
    end
    for _, oSk in pairs(self.m_mFuZhuanSkill) do
        baseobj_safe_release(oSk)
    end
    for _,oSk in pairs(self.m_mMarrySkill) do
        baseobj_safe_release(oSk)        
    end
    self.m_List = {}
    self.m_mOrgSkill = {}
    self.m_mItemSkill = {}
    self.m_mFuZhuanSkill = {}
    self.m_mMarrySkill = {}
    super(CSkillCtrl).Release(self)
end

function CSkillCtrl:Load(mData)
    mData = mData or {}
    local mSkData = mData["skdata"] or {}
    for iSk,data in pairs(mSkData) do
        iSk = tonumber(iSk)
        local oSk = loadskill.LoadSkill(iSk,data)
        self.m_List[iSk] = oSk
    end

    for iSk, mSk in pairs(mData["org_skill"] or {}) do
        iSk = tonumber(iSk)
        local oSk = loadskill.LoadSkill(iSk, mSk)
        self.m_mOrgSkill[iSk] = oSk
    end

    for iSk, mSk in pairs(mData["fuzhuan_skill"] or {}) do
        iSk = tonumber(iSk)
        local oSk = loadskill.LoadSkill(iSk, mSk)
        self.m_mFuZhuanSkill[iSk] = oSk
    end

    for iSk, mSk in pairs(mData["marry_skill"] or {}) do
        iSk = tonumber(iSk)
        local oSk = loadskill.LoadSkill(iSk, mSk)
        self.m_mMarrySkill[iSk] = oSk
    end

    self:SetData("role_sk", mData["role_sk"])
    -- self:SetData("partner_sk", mData["partner_sk"])
end

function CSkillCtrl:Save()
    local mData = {}
    local mSkData = {}
    for iSk,oSk in pairs(self.m_List) do
        mSkData[db_key(iSk)] = oSk:Save()
    end
    mData["skdata"] = mSkData

    local mOrgSkill = {}
    for iSk, oSk in pairs(self.m_mOrgSkill) do
        mOrgSkill[db_key(iSk)] = oSk:Save()
    end
    mData["org_skill"] = mOrgSkill
    local mFuZhuanSkill = {}
    for iSk, oSk in pairs(self.m_mFuZhuanSkill) do
        mFuZhuanSkill[db_key(iSk)] = oSk:Save()
    end
    mData["fuzhuan_skill"] = mFuZhuanSkill

    local mMarrySkill = {}
    for iSk, oSk in pairs(self.m_mMarrySkill) do
        mMarrySkill[db_key(iSk)] = oSk:Save()
    end
    mData["marry_skill"] = mMarrySkill
    
    mData["role_sk"] = self:GetData("role_sk")
    -- mData["partner_sk"] = self:GetData("partner_sk")
    return mData
end

function CSkillCtrl:GetSkill(iSk)
    return self.m_List[iSk]
end

function CSkillCtrl:SkillList()
    return self.m_List
end

function CSkillCtrl:GetOrgSkillById(iSk)
    return self.m_mOrgSkill[iSk]
end

function CSkillCtrl:GetOrgSkills()
    return self.m_mOrgSkill
end

function CSkillCtrl:GetFuZhuanSkills()
    return self.m_mFuZhuanSkill
end

function CSkillCtrl:GetFuZhuanSkillById(iSk)
    return self.m_mFuZhuanSkill[iSk]
end

function CSkillCtrl:SetLevel(iSk,iLevel,bRefresh)
    self:Dirty()
    local oSk = self.m_List[iSk]
    if not oSk then
        oSk =  loadskill.NewSkill(iSk)
        self.m_List[iSk] = oSk
    end
    oSk:SetLevel(iLevel)
    global.oScoreCache:Dirty(self:GetInfo("pid"), "skill")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oSk:SkillEffect(oPlayer)
        oPlayer:PropChange("score")
    end
    if bRefresh then
        self:GS2CRefreshSkill(oSk)
    end
end

function CSkillCtrl:OnUpGrade(oPlayer)
    self:CheckOpenSkill(oPlayer,true)

    local oToolMgr = global.oToolMgr
    if oPlayer:GetGrade() >= oToolMgr:GetSysOpenPlayerGrade("XIU_LIAN_SYS") and not self:GetData("role_sk") then
        self:UnlockCultivateSkill()
    end

    if oPlayer:GetGrade() >= oToolMgr:GetSysOpenPlayerGrade("ORG_SKILL") and table_count(self.m_mOrgSkill) <= 0 then
        self:SetupOrgSkill()
        self:GS2COrgSkills(oPlayer)
    end
    self:TriggerLockFuZhuanSkill(oPlayer)
end

function CSkillCtrl:TriggerLockFuZhuanSkill(oPlayer)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("FUZHUAN",oPlayer,true) then
        return
    end
    if oPlayer:GetGrade() >= oToolMgr:GetSysOpenPlayerGrade("FUZHUAN") and table_count(self.m_mFuZhuanSkill) <= 0  then
        self:UnlockFuZhuanSkill()
    end
end

function CSkillCtrl:CheckOpenSkill(oPlayer,bRefresh)
    local iSchool = oPlayer:GetSchool()
    local iGrade = oPlayer:GetGrade()
    local lAllSkills = {}
    extend.Array.append(lAllSkills, loadskill.GetActiveSkill(iSchool) or {})
    extend.Array.append(lAllSkills, loadskill.GetPassiveSkill(iSchool) or {})
    for _,iSk in ipairs(lAllSkills) do
        local oSk = self.m_List[iSk]
        if not oSk then
            self:Dirty()
            oSk = loadskill.NewSkill(iSk)
            self.m_List[iSk] = oSk
            global.oScoreCache:Dirty(self:GetInfo("pid"), "skill")
            oPlayer:PropChange("score")
        end
        if oSk and oSk:OpenLevel() <= iGrade then
            local iInitLevel = oSk:GetInitLevel() or 1
            if oSk:Level() < iInitLevel then
                oSk:SetLevel(iInitLevel)
                oSk:SkillEffect(oPlayer)
            end
            if bRefresh then
                self:GS2CRefreshSkill(oSk)
            end
        end
    end
end

function CSkillCtrl:OnLogin(oPlayer,bReEnter)
    if not bReEnter then
        self:TriggerLockFuZhuanSkill(oPlayer)
    end
    self:CheckOpenSkill(oPlayer)
    self:GS2CLoginSkill(oPlayer)
    self:GS2COrgSkills(oPlayer)
    self:GS2CMarrySkill(oPlayer)
    self:GS2CAllFuZhuanSkill(oPlayer)
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("XIU_LIAN_SYS")
    if oPlayer:GetGrade() >= iOpenGrade then
        if self:GetData("role_sk") then
            self:GS2CAllCultivateSkill()
        else
            self:UnlockCultivateSkill()
        end
    end
end

function CSkillCtrl:CalApply(oPlayer,bReEnter)
    if not bReEnter then
        local mSchoolSkill = loadskill.GetSchoolSkill(oPlayer:GetSchool()) or {}
        for _,iSk in ipairs(mSchoolSkill) do
            local oSk = self.m_List[iSk]
            if not oSk then
                self:Dirty()
                oSk = loadskill.NewSkill(iSk)
                self.m_List[iSk] = oSk
                global.oScoreCache:Dirty(self:GetInfo("pid"), "skill")
            end
            if oSk then
                oSk:SkillEffect(oPlayer)
            end
        end
        for _, oSk in pairs(self.m_mOrgSkill) do
            oSk:SkillEffect(oPlayer)  
        end
    end
end

function CSkillCtrl:UnlockCultivateSkill()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local mCultivateSkill = loadskill.GetCultivateSkill()
    local lCultivateSkill = {}
    for iSk, _ in pairs(mCultivateSkill) do
        assert(not self.m_List[iSk], string.format("cultivate skill:%d unlock need 40 level", iSk))
        local oSk = loadskill.NewSkill(iSk)
        self.m_List[iSk] = oSk
        table.insert(lCultivateSkill, iSk)
    end
    if next(lCultivateSkill) then
        self:SetData("role_sk", 4000) --default
        -- self:SetData("partner_sk", 4004)
        self:GS2CAllCultivateSkill(lCultivateSkill)
        global.oScoreCache:Dirty(self:GetInfo("pid"), "skill")
        if oPlayer then
            oPlayer:PropChange("score")
        end
    end
end

-- 更新修炼技能的最大等级上限（客户端做了特殊处理只需要发一个技能数据）
function CSkillCtrl:RefreshCulSkillUpperLevel(oPlayer)
    local mCultivateSkill = loadskill.GetCultivateSkill()
    for iSk, _ in pairs(mCultivateSkill) do
        local oSk = self:GetSkill(iSk)
        if oSk then
            oSk:GS2CRefreshSkillMaxLevel(oPlayer)
            break
        end  
    end    
end

function CSkillCtrl:GetRoleCultivateSkill()
    local iSk = self:GetData("role_sk")
    return self.m_List[iSk]
end

function CSkillCtrl:GetPartnerCulitivateSkill()
    local iSk = self:GetData("partner_sk")
    return self.m_List[iSk]  
end

function CSkillCtrl:SetCultivateSkillID(iSk)
    local mCultivateSkill = loadskill.GetCultivateSkill()
    local oWorldMgr = global.oWorldMgr
    if mCultivateSkill[iSk] then
        local oSk = self.m_List[iSk]
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        if oSk and oPlayer then
            self:SetData("role_sk", iSk)
            -- if iSk > 4003 then
            --     self:SetData("partner_sk", iSk)
            -- else
            --     self:SetData("role_sk", iSk)
            -- end
            oPlayer:Send("GS2CSetCultivateSkill", {sk = iSk})
        end
    end
end

function CSkillCtrl:PackExpertSkill()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local mSkill = {4000,4001,4002,4003}
    local mLevel = {}
    for _,iSk in pairs(mSkill) do
        local oSk = self:GetSkill(iSk)
        local iLevel = 0
        if oSk then
            iLevel = oSk:Level()
            iLevel = iLevel + oPlayer.m_oTouxianCtrl:GetCultivateLevel(iSk)
        end
        table.insert(mLevel,iLevel)
    end
    return mLevel
end

function CSkillCtrl:PackPartnerExpertSkill()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local mSkill = {4004,4005,4006,4007}
    local mLevel = {}
    for _,iSk in pairs(mSkill) do
        local oSk = self:GetSkill(iSk)
        local iLevel = 0
        if oSk then
            iLevel = oSk:Level()
            iLevel = iLevel + oPlayer.m_oTouxianCtrl:GetCultivateLevel(iSk)
        end
        table.insert(mLevel,iLevel)
    end
    return mLevel
end

function CSkillCtrl:GS2CLoginSkill(oPlayer)
    local iGrade = oPlayer:GetGrade()
    local iSchool = oPlayer:GetSchool()
    local mActiveSkill = loadskill.GetActiveSkill(iSchool) or {}
    local mActiveData = {}
    local mPassiveData = {}
    for _,iSk in ipairs(mActiveSkill) do
        local oSk = self:GetSkill(iSk)
        if oSk and oSk:OpenLevel() <= iGrade then
            table.insert(mActiveData,oSk:PackNetInfo())
        end
    end
    local mPassiveSkill = loadskill.GetPassiveSkill(iSchool)
    for _,iSk in ipairs(mPassiveSkill) do
        local oSk = self:GetSkill(iSk)
        if oSk then
            table.insert(mPassiveData,oSk:PackNetInfo())
        end
    end
    local mNet = {}
    mNet["active_skill"]  = mActiveData
    mNet["passive_skill"] = mPassiveData
    if oPlayer then
        oPlayer:Send("GS2CLoginSkill",mNet)
    end
end

function CSkillCtrl:GS2CRefreshSkill(oSk)
    local mNet = {}
    mNet["skill_info"] = oSk:PackNetInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CRefreshSkill",mNet)
    end
end


function CSkillCtrl:GS2CAllCultivateSkill(lSkill)
    local mData = {}
    if not lSkill then
        local mCultivateSkill = loadskill.GetCultivateSkill()
        lSkill = tableop.table_key_list(mCultivateSkill)
    end
    for _, iSk in ipairs(lSkill) do
        local oSk = self.m_List[iSk]
        if oSk then
            local m = oSk:PackNetInfo()
            table.insert(mData, m)
        end
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local oSk = self.m_List[lSkill[1]]
    local mItemSid = {10007, 10008}
    local mItemUseInfo = {}
    for _, sid in pairs(mItemSid) do
        local oItem = global.oItemLoader:GetItem(sid)
        if oItem then
            local iLimit, iCountLimit = oItem:DayUseLimit(oPlayer)
            table.insert(mItemUseInfo, { itemsid = sid, count_limit = iCountLimit, flag_limit = iLimit })
        end
    end
    local mNet = {}
    mNet["role_sk"] = self:GetData("role_sk")
    -- mNet["partner_sk"] = self:GetData("partner_sk")
    local iMaxLv, iLimit = oSk:MaxLevel(oPlayer)
    mNet["upperlevel"] = iMaxLv
    mNet["limit"] = iLimit
    mNet["skill_info"] = mData
    mNet["item_useinfo"] = mItemUseInfo
    if oPlayer then
        oPlayer:Send("GS2CAllCultivateSkill", mNet)
    end
end

function CSkillCtrl:SetupOrgSkill()
    self:Dirty()
    local mOrgSkill = self.m_mOrgSkill
    self.m_mOrgSkill = {}
    for iSk,_ in pairs(loadskill.GetOrgSkillData()) do
        if iSk == 4120 or iSk == 4121 then
            goto continue
        end
        local oSkill = mOrgSkill[iSk]
        if not oSkill then
            oSkill = loadskill.NewSkill(iSk)
        end
        self.m_mOrgSkill[iSk] = oSkill
        
        ::continue::
    end
    global.oScoreCache:Dirty(self:GetInfo("pid"), "skill")
end

function CSkillCtrl:GS2COrgSkills(oPlayer)
    local mNet = {}
    for _, oSkill in pairs(self.m_mOrgSkill) do
        table.insert(mNet, oSkill:PackNetInfo())
    end

    if #mNet > 0 then
        oPlayer:Send("GS2COrgSkills", {org_skill=mNet})
    end
end

function CSkillCtrl:UnDirty()
    super(CSkillCtrl).UnDirty(self)
    for _,oSk in pairs(self.m_List) do
        if oSk:IsDirty() then
            oSk:UnDirty()
        end
    end
    for _,oSk in pairs(self.m_mOrgSkill) do
        if oSk:IsDirty() then
            oSk:UnDirty()
        end
    end
    for _,oSk in pairs(self.m_mFuZhuanSkill) do
        if oSk:IsDirty() then
            oSk:UnDirty()
        end
    end
end

function CSkillCtrl:IsDirty()
    local bDirty = super(CSkillCtrl).IsDirty(self)
   if bDirty then
        return true
    end
    for _,oSk in pairs(self.m_List) do
        if oSk:IsDirty() then
            return true
        end
    end
    for _,oSk in pairs(self.m_mOrgSkill) do
        if oSk:IsDirty() then
            return true
        end
    end
    for _,oSk in pairs(self.m_mFuZhuanSkill) do
        if oSk:IsDirty() then
            return true
        end
    end
    return false
end

function CSkillCtrl:GetCurrCulSKill()
    return self:GetSkill(self:GetData("role_sk"))    
end

function CSkillCtrl:CanAddCurrCulSkillExp(iExp)
    if iExp <= 0 then return false end

    local oSk = self:GetCurrCulSKill()
    if not oSk then return false end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer or oSk:Level() >= oSk:MaxLevel(oPlayer) then return false end

    return true
end

function CSkillCtrl:CanAnyCulSkillAddExp(iExp)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then
        return false
    end
    local mCultivateSkill = loadskill.GetCultivateSkill()
    local lSkill = table_key_list(mCultivateSkill)
    for _, iSk in ipairs(lSkill) do
        local oSk = self.m_List[iSk]
        if oSk then
            if oSk:Level() < oSk:MaxLevel(oPlayer) then
                return true
            end
        end
    end
    return false
end

function CSkillCtrl:AddCurrCulSkillExp(iExp)
    if iExp <= 0 then return end

    local oSk = self:GetCurrCulSKill()
    if not oSk then return end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oSk:AddExp(oPlayer, iExp)
    end
end

function CSkillCtrl:GetScore()
    local iScore = 0
    for _,oSk in pairs(self.m_List) do
        iScore = iScore +oSk:GetScore()
    end
    for _,oSk in pairs(self.m_mOrgSkill) do
        iScore = iScore +oSk:GetScore()
    end
    return iScore
end

function CSkillCtrl:GetScoreDebug()
    local sMsg = "招式技能=%s\n心法技能=%s\n修炼技能=%s\n帮派技能=%s\n"
    local iScore1 = 0
    local iScore2 = 0
    local iScore3 = 0
    local iScore4 = 0
    for _,oSk in pairs(self.m_List) do
        if oSk:Type() == "active" then
            iScore1 = iScore1 + oSk:GetScore()
        elseif oSk:Type() == "passive" then
            iScore2 = iScore2 +oSk:GetScore()
        elseif oSk:Type() == "cultivate" then
            iScore3 = iScore3 + oSk:GetScore()
        end
    end
    for _,oSk in pairs(self.m_mOrgSkill) do
        iScore4 = iScore4 +oSk:GetScore()
    end
    return string.format(sMsg,iScore1,iScore2,iScore3,iScore4)
end


function CSkillCtrl:GetScore2()
    local iScore1 = 0
    local iScore2 = 0
    local iScore3 = 0
    local iScore4 = 0
    for _,oSk in pairs(self.m_List) do
        if oSk:Type() == "active" then
            iScore1 = iScore1 + oSk:GetScore()
        elseif oSk:Type() == "passive" then
            iScore2 = iScore2 +oSk:GetScore()
        elseif oSk:Type() == "cultivate" then
            iScore3 = iScore3 + oSk:GetScore()
        end
    end
    for _,oSk in pairs(self.m_mOrgSkill) do
        iScore4 = iScore4 +oSk:GetScore()
    end
    return {{iScore1,"school"},{iScore2,"passive"},{iScore3,"cultivate"},{iScore4,"org_skill"}}
end

function CSkillCtrl:AddItemSkill(iSkill, mSkill, iSource)
    local oSkill = loadskill.LoadSkill(iSkill, mSkill)
    local mKeep = self.m_mItemSkill[iSource] or {}
    mKeep[iSkill] = oSkill
    self.m_mItemSkill[iSource] = mKeep
end

function CSkillCtrl:DelItemSkill(iSkill, iSource)
    local mKeep = self.m_mItemSkill[iSource]
    if mKeep then
        baseobj_delay_release(mKeep[iSkill])
        mKeep[iSkill] = nil
        if table_count(mKeep) then
            self.m_mItemSkill[iSource] = nil
        end
    end
end

function CSkillCtrl:GetItemSkill()
    local mResult = {}
    for iSource, mSkill in pairs(self.m_mItemSkill) do
        for iSkill, oSkill in pairs(mSkill) do
            if not mResult[iSkill] or mResult[iSkill]:Level()<oSkill:Level() then
                mResult[iSkill] = oSkill
            end
        end
    end
    return mResult
end

function CSkillCtrl:UnlockFuZhuanSkill()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local mSkill = loadskill.GetFuZhuanSkill()
    for iSk, _ in pairs(mSkill) do
        assert(not self.m_mFuZhuanSkill[iSk], string.format("fuzhuan skill:%d unlock", iSk))
        local oSk = loadskill.NewSkill(iSk)
        self.m_mFuZhuanSkill[iSk] = oSk
    end
    
    global.oScoreCache:Dirty(self:GetInfo("pid"), "skill")
    if oPlayer then
        oPlayer:PropChange("score")
        self:GS2CAllFuZhuanSkill(oPlayer)
    end
end

function CSkillCtrl:GS2CAllFuZhuanSkill(oPlayer)
    local mNet = {}
    local skill_list = {}
    for iSk,oSK in pairs(self.m_mFuZhuanSkill) do
        table.insert(skill_list, oSK:PackNetInfo())
    end
    if next(skill_list) then
        mNet.skill_list = skill_list
        oPlayer:Send("GS2CAllFuZhuanSkill",mNet)
    end
end

function CSkillCtrl:FireLearnActiveSkill(oSk, iNewLv, iOldLv)
    self:TriggerEvent(gamedefines.EVENT.PLAYER_LEARN_ACTIVE_SKILL, {skill = oSk, newlv = iNewLv, oldlv = iOldLv})
end

function CSkillCtrl:FireLearnPassiveSkill(oSk, iNewLv, iOldLv)
    self:TriggerEvent(gamedefines.EVENT.PLAYER_LEARN_PASSIVE_SKILL, {skill = oSk, newlv = iNewLv, oldlv = iOldLv})
end

function CSkillCtrl:FireLearnOrgSkill(oSk, iNewLv, iOldLv)
    self:TriggerEvent(gamedefines.EVENT.PLAYER_LEARN_ORG_SKILL, {skill = oSk, newlv = iNewLv, oldlv = iOldLv})
end

function CSkillCtrl:FireLearnCultivateSkill(oSk)
    self:TriggerEvent(gamedefines.EVENT.PLAYER_LEARN_CULTIVATE_SKILL, {skill = oSk})
end

function CSkillCtrl:C2GSLearnCultivateSkill(iType,iSkill)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("XIU_LIAN_SYS", oPlayer) then return end

    local mCultivateSkill = loadskill.GetCultivateSkill()
    if not mCultivateSkill[iSkill] then return end
         
    local oSk = self:GetSkill(iSkill)
    if not oSk then return end

    local iCurLv = oSk:Level()
    if iCurLv >= oSk:MaxLevel(oPlayer) then
        oPlayer:NotifyMessage("修炼等级已达到当前人物等级能学习的上限")
        return 
    end

    local mLog = oPlayer:LogData()
    mLog["level_old"] = iCurLv
    mLog["exp_old"] = oSk:Exp()

    local itemsid = 0
    local iSilver = 0
    local sSubType, mCost = "", {} 
    local mLearnTimeConf = res["daobiao"]["cultivatelearntime"]
    if iType == 1 then
        itemsid = 10007
        if oSk:EffectType() == 2 then
            itemsid = 10008
        end
        local oItem= oPlayer.m_oItemCtrl:GetItemObj(itemsid)
        if oItem then
            oItem:Use(oPlayer, iSkill)
        else
            oPlayer:NotifyMessage("丹药不足")
            return
        end
        sSubType = "item_learn_cultivate"
        mCost[itemsid] = 1
    elseif iType == 2 then
        iSilver = mLearnTimeConf[1]["silvercost"]
        if oPlayer:ValidSilver(iSilver) then
            oPlayer:ResumeSilver(iSilver, "修炼技能")
            oSk:AddExp(oPlayer, mLearnTimeConf[1]["exp"])
            self:FireLearnCultivateSkill(oSk)
        end
        sSubType = "sliver_learn_cultivate"
        mCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
    elseif iType == 3 then
        local iPlayerGrade = oPlayer:GetGrade()
        local iLearn = #mLearnTimeConf
        for iOrder, mLearnTime in ipairs(mLearnTimeConf) do
            if iPlayerGrade <= mLearnTime["playerlevel"] then
                iLearn = iOrder
                break
            end
        end
        iSilver = mLearnTimeConf[iLearn]["silvercost"]
        if oPlayer:ValidSilver(iSilver) then
            oPlayer:ResumeSilver(iSilver, "修炼技能")
            oSk:AddExp(oPlayer,  mLearnTimeConf[iLearn]["exp"])
            self:FireLearnCultivateSkill(oSk)
        end
        sSubType = "sliver_learn_cultivate"
        mCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
    end
    mLog["skid"] = iSkill
    mLog["level_now"] = oSk:Level()
    mLog["exp_now"] = oSk:Exp()
    mLog["silver_cost"] = iSilver
    mLog["item_cost"] = itemsid
    record.log_db("playerskill", "learn_cultivate_skill", mLog)
    analylog.LogSystemInfo(oPlayer,"learn_cultivate_skill", iSkill, mCost)
end

function CSkillCtrl:AddMarsySkill(iSkill)
    local oSkill =  loadskill.NewSkill(iSkill)
    self.m_mMarrySkill[iSkill] = oSkill
    self:Dirty()
end

function CSkillCtrl:RemoveMarrySkill(iSkill)
    local oSkill = self.m_mMarrySkill[iSkill]
    if oSkill then
        self.m_mMarrySkill[iSkill] = nil
        baseobj_delay_release(oSkill)
    end
end

function CSkillCtrl:GetMarrySkills()
    return self.m_mMarrySkill
end

function CSkillCtrl:GS2CMarrySkill(oPlayer)
    local mNet = {}
    for _, oSkill in pairs(self.m_mMarrySkill) do
        table.insert(mNet, oSkill:PackNetInfo())
    end

    oPlayer:Send("GS2CMarrySkill", {skill_list=mNet})
end

function CSkillCtrl:C2GSExChangeDanceBook(oPlayer)
    if not oPlayer.m_oItemCtrl:ValidGive({[11142] = 1}) then
        oPlayer:NotifyMessage("包裹空间不足，请先整理包裹")
        return
    end

    local res = require "base.res"
    local mSkill = res["daobiao"]["orgskill"]["skill"][4120]
    if not mSkill then return end

    local iEnergy = tonumber(mSkill["cost_energy"])
    if iEnergy <= 0 then return end

    if oPlayer:GetEnergy() < iEnergy then
        oPlayer:NotifyMessage("活力不足")
        return
    end
    oPlayer:AddEnergy(-iEnergy, "兑换跳舞卷")
    oPlayer:RewardItems(11142, 1, "活力兑换")
end

function CSkillCtrl:C2GSEnergyExchangeSilver(oPlayer)
    local res = require "base.res"
    local mSkill = res["daobiao"]["orgskill"]["skill"][4121]
    if not mSkill then return end

    local iEnergy = tonumber(mSkill["cost_energy"])
    if iEnergy <= 0 then return end

    local iServerGrade = oPlayer:GetServerGrade()
    local iSilver = formula_string(mSkill["exchange_silver"], {SLV = iServerGrade})
    if iSilver <= 0 then return end
    if oPlayer:GetEnergy() < iEnergy then
        oPlayer:NotifyMessage("活动不足")
        return
    end
    oPlayer:AddEnergy(-iEnergy, "兑换银币")
    oPlayer:RewardSilver(iSilver, "活力兑换")
end
