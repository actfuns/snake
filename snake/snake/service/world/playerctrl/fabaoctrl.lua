--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local net = require "base.net"
local record = require "public.record" 

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local fabaoobj = import(service_path("fabao.fabaoobj"))
local attrmgr = import(service_path("fabao.fabaoattr"))

CFaBaoCtrl = {}
CFaBaoCtrl.__index = CFaBaoCtrl
inherit(CFaBaoCtrl, datactrl.CDataCtrl)

function CFaBaoCtrl:New(pid)
    local o = super(CFaBaoCtrl).New(self, {pid=pid})
    o:Init()
    return o
end

function CFaBaoCtrl:OnLogin(oPlayer,bReEnter)
    self:GS2CAllFaBao()
end

function CFaBaoCtrl:Init()
    self.m_mFaBao = {}
    self.m_mEquipFaBao = {}
    self.m_oAttrMgr = attrmgr.NewAttrMgr(self:GetOwner())
end

function CFaBaoCtrl:Release()
    local mFaBao = self.m_mFaBao
    self.m_mFaBao = {}
    for _, fabaoobj in pairs(mFaBao) do
        baseobj_safe_release(fabaoobj)
    end
    super(CFaBaoCtrl).Release(self)
end

function CFaBaoCtrl:Save()
    local mData = {}
    local mFaBao = {}
    for _,fabaoobj in pairs(self.m_mFaBao) do
        table.insert(mFaBao,fabaoobj:Save())
    end
    mData.fabao = mFaBao
    return mData
end

function CFaBaoCtrl:Load(mData)
    local mData = mData or {}
    local mFaBao = mData.fabao or {}
    for _,mFaBaoData in ipairs(mFaBao) do
        local fabaoobj = global.oFaBaoMgr:LoadFaBao(mFaBaoData.fabao,mFaBaoData)
        assert(fabaoobj,string.format("%d load fabao error %s",self:GetOwner(),mFaBao.fabao))
        local iFaBaoID = fabaoobj:ID()
        self.m_mFaBao[iFaBaoID] = fabaoobj
    end
end

function CFaBaoCtrl:AfterLoadByPlayer(oPlayer)
    for _,fabaoobj in pairs(self.m_mFaBao) do
        local iEquipPos = fabaoobj:EquipPos() 
        if iEquipPos >0 then
            fabaoobj:Wield(oPlayer,iEquipPos)
        end
    end
end

function CFaBaoCtrl:UnDirty()
    for _, fabaoobj in pairs(self.m_mFaBao) do
        if fabaoobj:IsDirty() then fabaoobj:UnDirty() end
    end
    super(CFaBaoCtrl).UnDirty(self)
end

function CFaBaoCtrl:IsDirty()
    if super(CFaBaoCtrl).IsDirty(self) then
        return true
    end
    for _, fabaoobj in pairs(self.m_mFaBao) do
        if fabaoobj:IsDirty() then return true end
    end
    return false
end

function CFaBaoCtrl:GetOwner()
    return self:GetInfo("pid")
end

function CFaBaoCtrl:GetScore()
    local iScore = 0
    for iEquipPos,id in pairs(self.m_mEquipFaBao) do
        local fabaoobj = self.m_mFaBao[id]
        iScore = iScore + fabaoobj:GetScore()
    end
    iScore = math.floor(iScore)
    return iScore
end

function CFaBaoCtrl:GetConfigData()
    local mData = global.oFaBaoMgr:GetConfigData()
    return mData
end

function CFaBaoCtrl:GetFaBao(iFaBaoID)
    return self.m_mFaBao[iFaBaoID]
end

function CFaBaoCtrl:GetSameTypeFaBao(iFaBao)
    for iEquipPos,iID in pairs(self.m_mEquipFaBao) do
        local fobj = self.m_mFaBao[iID]
        if fobj:Fid() == iFaBao then
            return fobj
        end
    end
end

function CFaBaoCtrl:GetEquipPos(oPlayer)
    local iGrade = oPlayer:GetGrade()
    local mRes = res["daobiao"]["fabao"]["equip"]
    local iEquipLimit = 0
    local lKey = table_key_list(mRes)
    table.sort(lKey)
    for _,iKey in ipairs(lKey) do
        if iKey<=iGrade then
            iEquipLimit = mRes[iKey]["amount"]
        end
    end
    for iPos=1,iEquipLimit do
        if not self.m_mEquipFaBao[iPos] then
            return iPos
        end
    end
end

function CFaBaoCtrl:IsFull()
    local mConfigData = self:GetConfigData()
    if table_count(self.m_mFaBao) >= mConfigData.fabao_limit then
        return true
    end
    return false
end

function CFaBaoCtrl:IsComplete()
    local mFaBaoInfo = global.oFaBaoMgr:GetAllFaBaoInfo()
    local mFaBao = {}
    for _,fabaoobj in pairs(self.m_mFaBao) do
        mFaBao[fabaoobj:Fid()] = true
    end
    if table_count(mFaBaoInfo) == table_count(mFaBao) then
        return true 
    end
    return false
end

function CFaBaoCtrl:AddFaBao(fabaoobj,sReason)
    self:Dirty()
    self.m_mFaBao[fabaoobj:ID()] = fabaoobj
    self:LogData(fabaoobj,"add_fabao",sReason)
    self:GS2CAddFaBao(fabaoobj)
end

function CFaBaoCtrl:RemoveFaBao(iFaBao,sReason)
    self:Dirty()
    local fabaoobj = self.m_mFaBao[iFaBao]
    self.m_mFaBao[iFaBao]  = nil
    local iEquipPos = fabaoobj:EquipPos()
    if iEquipPos>0 then
        self:SetEquipPos(iEquipPos,nil)
    end
    self:LogData(fabaoobj,"remove_fabao",sReason)
    self:GS2CRemoveFaBao(fabaoobj)
end

function CFaBaoCtrl:LogData(fabaoobj,sSubType,sReason)
    local mLogData = fabaoobj:PackLog()
    mLogData.reason = sReason
    mLogData.pid = self:GetOwner()
    record.log_db("fabao",sSubType,mLogData)
end

function CFaBaoCtrl:GetApply(sAttr)
    return self.m_oAttrMgr:GetApply(sAttr)
end

function CFaBaoCtrl:GetRatioApply(sAttr)
    return self.m_oAttrMgr:GetRatioApply(sAttr) 
end

function CFaBaoCtrl:SetEquipPos(iEquipPos,iID)
    self.m_mEquipFaBao[iEquipPos] = iID
end

function CFaBaoCtrl:GetZhenQi()
    local mConfigData = self:GetConfigData()
    local sFormula = mConfigData.zhenqi_init
    local iZhenQi = math.floor(formula_string(sFormula,{}))
    return iZhenQi
end

function CFaBaoCtrl:GetPerformMap()
    local mPerform = {}
    for iEquipPos,iFaBaoID in pairs(self.m_mEquipFaBao) do
        local fabaoobj = self.m_mFaBao[iFaBaoID]
        if fabaoobj then
            local oSk = fabaoobj:GetJXSkill()
            local oTHSk = fabaoobj:GetTHSkill()
            local oDHSk = fabaoobj:GetDHSkill()
            local rhSklist = fabaoobj:GetRHSkill()
            if oSk:IsOpen() and oSk:Level()>0 then
                for iPer, iLv in pairs(oSk:GetPerformList()) do
                    local iLevel = iLv + oTHSk:GetOtherJXLevel(oPlayer) + oDHSk:GetOtherJXLevel() + rhSklist[1]:GetOtherJXLevel() +rhSklist[2]:GetOtherJXLevel()
                    mPerform[iPer] = iLevel
                end
            end
            if oTHSk:IsOpen() then
                for iPer, iLv in pairs(oTHSk:GetPerformList()) do
                    mPerform[iPer] = iLv
                end
            end
            if oDHSk:IsOpen() then
                for iPer, iLv in pairs(oDHSk:GetPerformList()) do
                    mPerform[iPer] = iLv
                end
            end
            if rhSklist[1]:IsOpen() then
                for iPer, iLv in pairs(rhSklist[1]:GetPerformList()) do
                    mPerform[iPer] = iLv
                end
            end
            if rhSklist[2]:IsOpen() then
                for iPer, iLv in pairs(rhSklist[2]:GetPerformList()) do
                    mPerform[iPer] = iLv
                end
            end
        end
    end
    --print("GetPerformMap",mPerform)
    return mPerform
end

function CFaBaoCtrl:OnUpGrade(oPlayer)
    self:RefreshSkillEffect(oPlayer)
end

function CFaBaoCtrl:RefreshSkillEffect(oPlayer)
    for _,iFaBaoID in pairs(self.m_mEquipFaBao) do
        local fabaoobj = self.m_mFaBao[iFaBaoID]
        for _,skobj in pairs(fabaoobj.m_mSkill) do
            skobj:SkillUnEffect(oPlayer)
            skobj:SkillEffect(oPlayer)
        end
    end
end

function CFaBaoCtrl:GS2CAddFaBao(fabaoobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return 
    end
    local mNet = {}
    mNet.fabao = fabaoobj:PackInfo()
    oPlayer:Send("GS2CAddFaBao",mNet)
end

function CFaBaoCtrl:GS2CRemoveFaBao(fabaoobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return 
    end
    local mNet = {}
    mNet.id = fabaoobj:ID()
    oPlayer:Send("GS2CRemoveFaBao",mNet)
end

function CFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return 
    end
    local mNet = {}
    mNet.fabao = fabaoobj:PackInfo()
    oPlayer:Send("GS2CRefreshFaBao",mNet)
end

function CFaBaoCtrl:GS2CAllFaBao()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return 
    end
    local mNet = {}
    local mFaBao = {}
    for _,fabaoobj in pairs(self.m_mFaBao) do
        table.insert(mFaBao,fabaoobj:PackInfo())
    end
    mNet.fabaolist = mFaBao
    oPlayer:Send("GS2CAllFaBao",mNet)
end



