--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record" 

local datactrl = import(lualib_path("public.datactrl"))

local INIT_LEVEL = 1

function NewFaBao(iFaBao)
    local mData = global.oFaBaoMgr:GetFaBaoInfo(iFaBao)
    assert(mData,string.format("newfabao error %s",iFaBao))
    local o = CFaBao:New(iFaBao)
    return o
end

CFaBao = {}
CFaBao.__index = CFaBao
inherit(CFaBao, datactrl.CDataCtrl)

function CFaBao:New(iFaBao)
    local o = super(CFaBao).New(self)
    o.m_iFaBao = iFaBao
    o.m_iLevel = INIT_LEVEL
    o.m_iExp = 0
    o.m_iEquipPos = 0
    o.m_iXianling = 0
    o.m_mSkill = {}
    o.m_mApply = {}
    o.m_mPromote = {}
    o:Init()
    return o
end

function CFaBao:Init()
    self.m_ID = global.oFaBaoMgr:DispatchId()
end

function CFaBao:Fid()
    return self.m_iFaBao
end

function CFaBao:ID()
    return self.m_ID
end

function CFaBao:Name()
    local mConfigData = self:GetFaBaoInfo()
    return mConfigData.name
end

function CFaBao:Release()
    local mSkill = self.m_mSkill
    self.m_mSkill = {}
    for _,skobj in pairs(mSkill) do
        baseobj_safe_release(skobj)
    end
    super(CFaBao).Release(self)
end

function CFaBao:Save()
    local mData = {}
    mData.fabao = self.m_iFaBao
    mData.level = self.m_iLevel
    mData.exp = self.m_iExp
    mData.xianling = self.m_iXianling
    mData.equippos = self.m_iEquipPos
    local mSkill = {}
    for iSkill ,skobj in pairs(self.m_mSkill) do
        mSkill[iSkill] = skobj:Save()
    end
    mData.skill = mSkill
    local mPromote = {}
    for sAttr,iPromote in pairs(self.m_mPromote) do
        mPromote[sAttr] = iPromote
    end
    local mXLData = self:GetXinLingData()
    mData.promote = mPromote
    return mData
end

function CFaBao:Load(mData)
    mData = mData or {}
    self.m_iFaBao = mData.fabao
    self.m_iLevel = mData.level or INIT_LEVEL
    self.m_iExp = mData.exp or 0
    self.m_iXianling = mData.xianling or 0
    self.m_iEquipPos = mData.equippos or 0
    local mSkill = mData.skill or {}
    for iSkill,mSkillData in pairs(mSkill) do
        local skobj = global.oFaBaoMgr:LoadSkill(iSkill,mSkillData)
        assert(skobj,string.format("load fabao=%d skill=%d error",self.m_iFaBao,iSkill))
        self.m_mSkill[iSkill] = skobj
    end
    local mXLData = self:GetXinLingData()
    local mConfigData = self:GetFaBaoInfo()
    local mPromote = mData.promote
    for sAttr,iPromote in pairs(mPromote) do
        assert(mXLData[sAttr],string.format("load fabao=%d attr=%s error",self.m_iFaBao,sAttr))
        self.m_mPromote[sAttr] = iPromote
    end
    for sAttr ,iPromote in pairs(self.m_mPromote) do
        self.m_mApply[sAttr] = mConfigData[sAttr] + iPromote*mXLData[sAttr]["value"]
    end
end

function CFaBao:UnDirty()
    for _, skobj in pairs(self.m_mSkill) do
        if skobj:IsDirty() then skobj:UnDirty() end
    end
    super(CFaBao).UnDirty(self)
end

function CFaBao:IsDirty()
    if super(CFaBao).IsDirty(self) then
        return true
    end
    for _, skobj in pairs(self.m_mSkill) do
        if skobj:IsDirty() then return true end
    end
    return false
end


function CFaBao:Create()
    local mConfigData = self:GetFaBaoInfo()
    local iJXSkill = mConfigData.juexing_skill
    self.m_mSkill[iJXSkill] = global.oFaBaoMgr:CreateSkill(iJXSkill)
    local iTHSkill = mConfigData.tianhun_skill
    self.m_mSkill[iTHSkill] = global.oFaBaoMgr:CreateSkill(iTHSkill)
    local iDHSkill = mConfigData.dihun_skill
    self.m_mSkill[iDHSkill] = global.oFaBaoMgr:CreateSkill(iDHSkill)
    local lRHSkill = mConfigData.renhun_skill
    for _,iSkill in ipairs(lRHSkill) do
        self.m_mSkill[iSkill] = global.oFaBaoMgr:CreateSkill(iSkill)
    end
    local mXLData = self:GetXinLingData()
    for sAttr,_ in pairs(mXLData) do
        self.m_mPromote[sAttr] = 0
    end
    
    for sAttr ,iPromote in pairs(self.m_mPromote) do
        self.m_mApply[sAttr] = mConfigData[sAttr] + iPromote*mXLData[sAttr]["value"]
    end
end

function CFaBao:GetFaBaoInfo()
    local mData = global.oFaBaoMgr:GetFaBaoInfo(self:Fid())
    return mData
end

function CFaBao:GetXinLingData()
    local mData = global.oFaBaoMgr:GetXinLingData()
    return mData
end

function CFaBao:Level()
    return self.m_iLevel
end

function CFaBao:Exp()
    return self.m_iExp
end

function CFaBao:SetLevel(iLevel)
    self:Dirty()
    self.m_iLevel = iLevel 
end

function CFaBao:SetExp(iExp)
    self:Dirty()
    self.m_iExp = iExp 
end

function CFaBao:GetScore()
    local mFaBaoInfo = self:GetFaBaoInfo()
    local iScore = 0
    local sFormula = mFaBaoInfo.score
    local  jxSkobj = self:GetJXSkill()
    local thSkobj = self:GetTHSkill()
    local dhSkobj = self:GetDHSkill()
    local rhSklist = self:GetRHSkill()

    local iJXLevel = 0
    local hun_cnt = 0
    if jxSkobj then
        iJXLevel = jxSkobj:Level()
    end
    if thSkobj:IsOpen() then hun_cnt = hun_cnt + 1 end 
    if dhSkobj:IsOpen() then hun_cnt = hun_cnt + 1 end 
    if rhSklist[1]:IsOpen() then hun_cnt = hun_cnt + 1 end 

    iScore = formula_string(sFormula, {level=self.m_iLevel,jx_level = iJXLevel,hun_cnt = hun_cnt})
    iScore = math.floor(iScore)
    return iScore
end

function CFaBao:GetJXSkill()
    local mFaBaoInfo = self:GetFaBaoInfo()
    local skobj = self.m_mSkill[mFaBaoInfo.juexing_skill]
    return skobj
end

function CFaBao:GetTHSkill()
    local mFaBaoInfo = self:GetFaBaoInfo()
    local skobj = self.m_mSkill[mFaBaoInfo.tianhun_skill]
    return skobj
end

function CFaBao:GetDHSkill()
    local mFaBaoInfo = self:GetFaBaoInfo()
    local skobj = self.m_mSkill[mFaBaoInfo.dihun_skill]
    return skobj
end

function CFaBao:GetRHSkill()
    local mFaBaoInfo = self:GetFaBaoInfo()
    local sklist = {}
    for _,iSkill in pairs(mFaBaoInfo.renhun_skill) do
        local skobj = self.m_mSkill[iSkill]
        table.insert(sklist,skobj)
    end
    return sklist
end

function CFaBao:PackInfo()
    local mNet = {}
    mNet.id = self:ID()
    mNet.fabao = self:Fid()
    mNet.equippos = self.m_iEquipPos
    mNet.level = self.m_iLevel
    mNet.exp = self.m_iExp
    mNet.xianling = self.m_iXianling
    mNet.score = self:GetScore()
    local mSkill = {}
    for iSkill,skobj in pairs(self.m_mSkill) do
        if skobj:IsOpen() then
            table.insert(mSkill,skobj:PackInfo())
        end
    end
    mNet.skilllist = mSkill
    local mPromote = {}
    for sAttr,iPromote in pairs(self.m_mPromote) do
        table.insert(mPromote,{attr=sAttr,promote = iPromote})
    end
    mNet.promotelist = mPromote
    return mNet
end

function CFaBao:PackLog()
    local mLogData = {}
    mLogData.fabao = self:Fid()
    mLogData.level = self.m_iLevel
    mLogData.exp = self.m_iExp
    return mLogData
end

function CFaBao:LogData(sSubType, mLog)
    mLog = mLog or {}
    mLog = table_combine(mLog, self:PackLog())
    record.log_db("fabao", sSubType, mLog)
end

function CFaBao:Wield(oPlayer,iEquipPos)
    oPlayer.m_oFaBaoCtrl:SetEquipPos(iEquipPos,self:ID())
    self:SetEquipPos(iEquipPos)
    local mXianlingData = res["daobiao"]["fabao"]["xianling"]
    for sAttr,_ in pairs(mXianlingData) do
        local iValue = self:GetApply(sAttr)
        oPlayer.m_oFaBaoCtrl.m_oAttrMgr:AddApply(sAttr,iEquipPos,iValue)
    end
    for _,skobj in pairs(self.m_mSkill) do
        skobj:SkillEffect(oPlayer)
    end
    global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
    self:LogData("wield_fabao", {
        pid = oPlayer:GetPid(),
        pos = iEquipPos,
    })
end

function CFaBao:UnWield(oPlayer)
    local iEquipPos = self.m_iEquipPos
    oPlayer.m_oFaBaoCtrl:SetEquipPos(iEquipPos,nil)
    oPlayer.m_oFaBaoCtrl.m_oAttrMgr:RemoveSource(iEquipPos)
    for _,skobj in pairs(self.m_mSkill) do
        skobj:SkillUnEffect(oPlayer)
    end
    self:SetEquipPos(0)
    global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
    self:LogData("unwield_fabao", {
        pid = oPlayer:GetPid(),
        pos = iEquipPos,
    })
end

function CFaBao:GetApply(sAttr)
    local iValue = 0
    local mXianlingData = res["daobiao"]["fabao"]["xianling"]
    if not mXianlingData[sAttr] then
        return iValue
    end
    local mFaBaoInfo = self:GetFaBaoInfo()
    iValue = mFaBaoInfo[sAttr] + self.m_mPromote[sAttr]*mXianlingData[sAttr]["value"]
    return iValue
end

function CFaBao:SetEquipPos(iEquipPos)
    self:Dirty()
    self.m_iEquipPos = iEquipPos
end

function CFaBao:EquipPos()
    return self.m_iEquipPos
end

function CFaBao:AddXianLing(iValue)
    self:Dirty()
    self.m_iXianling = self.m_iXianling  + iValue
end

function CFaBao:GetXianLing()
    return self.m_iXianling
end

function CFaBao:AddPromote(sAttr,oPlayer)
    assert(self.m_mPromote[sAttr],"fabao promote attr error")
    self:Dirty()
    self.m_mPromote[sAttr] = self.m_mPromote[sAttr] + 1
    if self.m_iEquipPos>0 then
        local mXianlingData = res["daobiao"]["fabao"]["xianling"]
        oPlayer.m_oFaBaoCtrl.m_oAttrMgr:AddApply(sAttr,self.m_iEquipPos,mXianlingData[sAttr]["value"])
    end
end

function CFaBao:RemovePromote(sAttr,oPlayer)
    assert(self.m_mPromote[sAttr],"fabao promote attr error")
    assert(self.m_mPromote[sAttr] >0 ,"fabao removepromote attr error")
    self:Dirty()
    self.m_mPromote[sAttr] = self.m_mPromote[sAttr] - 1
    if self.m_iEquipPos>0 then
        local mXianlingData = res["daobiao"]["fabao"]["xianling"]
        oPlayer.m_oFaBaoCtrl.m_oAttrMgr:AddApply(sAttr,self.m_iEquipPos,-mXianlingData[sAttr]["value"])
    end
end

function CFaBao:GetPromote(sAttr)
    assert(self.m_mPromote[sAttr],"fabao promote attr error")
    return self.m_mPromote[sAttr]
end