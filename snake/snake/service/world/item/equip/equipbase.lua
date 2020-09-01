local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local interactive = require "base.interactive"
local record = require "public.record"
local res = require "base.res"

local itembase = import(service_path("item/itembase"))
local itemdefines = import(service_path("item/itemdefines"))
local loadskill = import(service_path("skill/loadskill"))
local gamedefines = import(lualib_path("public.gamedefines"))

local max = math.max
local min = math.min
local floor = math.floor

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "equip"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    -- o.m_mK = {}
    o.m_mApply = {}
    o.m_mRatioApply = {}
    o.m_mAttachAttr = {}
    o.m_mSE = {}
    o.m_mBackSe = {}
    o.m_mSK = {}
    o.m_mShenHun = {}
    o.m_mShenHunExtra = {}
    o.m_mHunShi = {}
    o.m_mFuZhuan = {}
    o:InitData()
    return o
end

function CItem:InitData()
    local mData = self:GetItemData()
    local iMaxLast = mData["last"] or 200
    self:SetData("last",iMaxLast)
end

function CItem:Release()
    for _,oSE in pairs(self.m_mSE) do
        baseobj_safe_release(oSE)
    end
    self.m_mSE = {}
    for _,oSK in pairs(self.m_mSK) do
        baseobj_safe_release(oSK)
    end
    self.m_mSK = {}
    super(CItem).Release(self)
end

function CItem:Load(mData)
    super(CItem).Load(self,mData)
    -- self.m_mK = mData["k"] or self.m_mK
    self.m_mApply = mData["apply"] or self.m_mApply
    self.m_mRatioApply = mData["ratio_apply"] or self.m_mRatioApply
    self.m_mAttachAttr = mData["attach"] or self.m_mAttachAttr
    local mSe = mData["se"] or {}
    for iSe,mSeData in pairs(mSe) do
        iSe = tonumber(iSe)
        local oSE = loadskill.LoadSkill(iSe,mSeData)
        self.m_mSE[iSe] = oSE
    end
    for iSK,mSKData in pairs(mData["sk"] or {}) do
        iSK = tonumber(iSK)
        local oSK = loadskill.LoadSkill(iSK, mSKData)
        self.m_mSK[iSK] = oSK
    end
    self.m_mBackSe = table_to_int_key(mData["back_se"] or {})
    self.m_mShenHun = mData["shenhun"] or self.m_mShenHun
    self.m_mShenHunExtra = mData["shenhun_extra"] or self.m_mShenHunExtra
    self.m_mHunShi = table_to_int_key(mData["hunshi"] or {})
    self.m_mFuZhuan =  mData["fuzhuan"] or {}
    global.oScoreCache:EquipDirty(self:ID())
    -- 尚未装备的神魂也需要填充附加神魂的属性，用以下行
    -- self:FillinShenHunEffect()
end

function CItem:Save()
    local mData = super(CItem).Save(self)
    -- mData["k"] = self.m_mK
    mData["apply"] = self.m_mApply
    mData["ratio_apply"] = self.m_mRatioApply
    mData["attach"] = self.m_mAttachAttr

    local mSe = {}
    for iSe,oSE in pairs(self.m_mSE) do
        mSe[db_key(iSe)] = oSE:Save()
    end
    mData["se"] = mSe

    local mSK = {}
    for iSK,oSK in pairs(self.m_mSK) do
        mSK[db_key(iSK)] = oSK:Save()
    end
    mData["sk"] = mSK

    mData["back_se"] = table_to_db_key(self.m_mBackSe or {})
    mData["shenhun"] = self.m_mShenHun
    mData["shenhun_extra"] = self.m_mShenHunExtra
    mData["hunshi"] = table_to_db_key(self.m_mHunShi or {})
    mData["fuzhuan"] = self.m_mFuZhuan or {}
    return mData
end

function CItem:OnLogin(oPlayer,bReEnter)
    if not bReEnter then
        self:AddFuZhuanTimer()
    end
end

function CItem:SetSE(mSE)
    self:Dirty()
    self.m_mSE = mSE or {}
end

function CItem:GetSE()
    return self.m_mSE or {}
end

function CItem:SetBackSe(mBackSe)
    self:Dirty()
    self.m_mBackSe = mBackSe or {}
end

function CItem:AddBackSe(iSE)
    self:Dirty()
    self.m_mBackSe = self.m_mBackSe or {}
    self.m_mBackSe[iSE] = 1
end

function CItem:GetBackSe()
    return self.m_mBackSe or {}
end

function CItem:EquipPos()
    return self:GetItemData()["equipPos"]
end

function CItem:Equiped()
    local iPos = self:Pos()
    return iPos >= 1 and iPos <= 6
end


function CItem:EquipLevel()
    return self:GetItemData()["equipLevel"]
end

function CItem:Race()
    return self:GetItemData()["race"]
end

function CItem:RoleType()
    return self:GetItemData()["roletype"]
end

function CItem:School()
    return self:GetItemData()["school"]
end

function CItem:Sex()
    return self:GetItemData()["sex"]
end

function CItem:Name()
    local sName = self:GetItemData()["name"]
    if self:IsFuHun() then
        sName = self:GetItemData()["shenhun_name"]
    end
    return sName
end

function CItem:Shape()
    -- if self:IsFuHun() then
    --     return self:GetItemData()["shenhun_icon"]
    -- end
    return self.m_SID
end

function CItem:FuHunFlag()
    if self:IsFuHun() then return 1 end

    return 0
end

function CItem:Quality()
    local iQuality = self:GetData("equip_level")
    if iQuality then
        return iQuality
    end
    local mItemData = global.oItemLoader:GetItemData(self:SID())
    return mItemData.quality
end

function CItem:IsMake()
    return self:GetData("is_make", 0) == 1
end

function CItem:Create(...)
    global.oItemHandler.m_oEquipMakeMgr:MakeEquip(self,...)
end

function CItem:CreateFixedItem(iFix, ...)
    global.oItemHandler.m_oEquipMakeMgr:MakeFixedEquip(self, iFix, ...)
end

-- function CItem:SetK(mVariK)
--     self:Dirty()
--     self.m_mK = mVariK
-- end

-- function CItem:GetK()
--     return self.m_mK
-- end

function CItem:OnRemove()
    global.oScoreCache:EquipDirty(self:ID())
end

function CItem:AddApply(sAttr,iValue)
    self:Dirty()
    self.m_mApply[sAttr] = iValue
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "equip")
    end
    global.oScoreCache:EquipDirty(self:ID())
end

function CItem:GetApply(sAttr,rDefault)
    return self.m_mApply[sAttr] or rDefault
end

function CItem:AddRatioApply(sAttr,iValue)
    self:Dirty()
    self.m_mRatioApply[sAttr] = iValue
end

function CItem:GetRatioApply(sAttr,rDefault)
    return self.m_mRatioApply[sAttr] or rDefault
end

function CItem:AddAttach(sAttr,iValue)
    self:Dirty()
    self.m_mAttachAttr[sAttr] = iValue
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "equip")
    end
    global.oScoreCache:EquipDirty(self:ID())
end

function CItem:GetAttach(sAttr,rDefault)
    return self.m_mAttachAttr[sAttr] or rDefault
end

function CItem:GetApplySource(sApply)
    return itemdefines.GetApplySource(self:EquipPos(),sApply)
end

function CItem:Use(oPlayer, target, mArgs)
    local sArgs = mArgs.exarg
    if oPlayer:InWar() then
        oPlayer:NotifyMessage("请战斗后再进行操作")
        return
    end

    if self:Equiped() then
        if sArgs == "EQUIP:U" then -- 可以支持以后加多参数
            global.oItemHandler:UnWield(oPlayer,self)
        end
    else
        if sArgs == "EQUIP:W" then
            global.oItemHandler:Wield(oPlayer,self)
        end
    end
    return true
end

local MAX_AUTO_WIELD_SELL_LV = 30

function CItem:UseAmount(oPlayer, iTarget, iAmount, mExtArgs)
    local sArgs = mExtArgs.exarg
    local bSilent = mExtArgs.silent
    if iAmount ~= 1 then
        return false
    end
    -- if oPlayer:InWar() then
    --     oPlayer:NotifyMessage("请战斗后再进行操作")
    --     return
    -- end
    local lArgs = split_string(sArgs or "", ",")
    local mArgs = {}
    for _, sPair in ipairs(lArgs) do
        local k, v = table.unpack(split_string(sPair, ":"))
        mArgs[k] = v
    end
    if mArgs.EQUIP == "W" then
        if self:Equiped() then
            return
        end
        local mRet = global.oItemHandler:Wield(oPlayer, self, {cancel_tip = bSilent})
        if not mRet then
            return
        end
        -- 一键批量穿戴时，此参数控制是否出售卸下的装备
        if mArgs.UNEQUIPED == "SELL" then
            local oOldEquip = mRet.unwielded
            -- 自动出售限制等级
            if oOldEquip then
                local iEquipLv = oOldEquip:EquipLevel()
                if iEquipLv <= MAX_AUTO_WIELD_SELL_LV then
                    global.oItemHandler:RecycleItem(oPlayer, oOldEquip:ID(), 1, true, bSilent)
                end
            end
        end
        return true
    end
end

function CItem:OnBeValid(oPlayer)
    if self:Equiped() then
        self:Wield(oPlayer)
        if self:EquipPos() == itemdefines.EQUIP_WEAPON then
            oPlayer:ChangeWeapon()
        end
        oPlayer:RefreshPropAll()
        local sMsg = global.oToolMgr:FormatColorString(global.oItemHandler:GetTextData(1024), {item = self:TipsName()})
        oPlayer:NotifyMessage(sMsg)
    end
end

function CItem:OnBeInvalid(oPlayer)
    if self:Equiped() then
        self:UnWield(oPlayer)
        if self:EquipPos() == itemdefines.EQUIP_WEAPON then
            oPlayer:ChangeWeapon()
        end
        oPlayer:RefreshPropAll()
        local sMsg = global.oToolMgr:FormatColorString(global.oItemHandler:GetTextData(1023), {item = self:TipsName()})
        oPlayer:NotifyMessage(sMsg)
    end
end

function CItem:IsWield()
    return self:GetData("wield", 0) > 0
end

function CItem:Wield(oPlayer)
    if self:GetData("wield") then
        return
    end
    self:SetData("wield",1)
    self:CalApply(oPlayer)
end

function CItem:UnWield(oPlayer)
    -- IMPORTANT! 先计算属性，然后才将装备置为非装备状态，角色属性计算有检查此标记
    -- FIXME 脱装备可能会再穿，值得优化逻辑关系，减少强化属性的计算
    if not self:GetData("wield") then
        return
    end
    self:UnCalApply(oPlayer)
    self:SetData("wield",nil)
end

function CItem:CalApply(oPlayer)
    local iApplySource = self:GetApplySource("apply")
    local iRatioSource = self:GetApplySource("ratio")
    local iAttachSource = self:GetApplySource("attach")
    for sAttr,iValue in pairs(self.m_mApply) do
        oPlayer.m_oEquipMgr:AddApply(sAttr,iApplySource,iValue)
    end
    for sAttr,iValue in pairs(self.m_mRatioApply) do
        oPlayer.m_oEquipMgr:AddRatioApply(sAttr,iRatioSource,iValue)
    end
    for sAttr,iValue in pairs(self.m_mAttachAttr) do
        oPlayer.m_oEquipMgr:AddApply(sAttr,iAttachSource,iValue)
    end
    for _,oSE in pairs(self.m_mSE) do
        oSE:SkillEffect(oPlayer, true, self:SID())
    end
    for _,oSK in pairs(self.m_mSK) do
        oSK:SkillEffect(oPlayer, true, self:SID())
    end
    self:StrengthEffect(oPlayer)
    self:ShenHunEffect(oPlayer)
    self:HunShiEffect(oPlayer)
    self:FuZhuanEffect()
    -- oPlayer:RefreshPropAll()
    -- FIXME 协议统一做优化，与逻辑分离并进行合包
    -- self:Refresh()
end

function CItem:UnCalApply(oPlayer)
    oPlayer.m_oEquipMgr:RemoveSource(self:GetApplySource("apply"))
    oPlayer.m_oEquipMgr:RemoveSource(self:GetApplySource("ratio"))
    oPlayer.m_oEquipMgr:RemoveSource(self:GetApplySource("attach"))
    for _,oSE in pairs(self.m_mSE) do
        oSE:SkillUnEffect(oPlayer, self:SID())
    end
    for _,oSK in pairs(self.m_mSK) do
        oSK:SkillUnEffect(oPlayer, self:SID())
    end
    self:StrengthUnEffect(oPlayer)
    self:ShenHunUnEffect(oPlayer)
    self:HunShiUnEffect(oPlayer)
    self:FuZhuanUnEffect()
    -- oPlayer:RefreshPropAll()
    -- FIXME 协议统一做优化，与逻辑分离并进行合包
    -- self:Refresh()
end

-- TODO 装备已经没有强化逻辑了，要改到EquipMgr里去，但要考虑装备失效情况
function CItem:StrengthEffect(oPlayer)
    local iPos = self:EquipPos()
    local iSource = self:GetApplySource("strength")
    local iPid = oPlayer.m_iPid
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos)
    if not iStrengthenLevel or iStrengthenLevel <= 0 then
        return
    end
    local mAttrs = oPlayer.m_oEquipMgr:GetStrengthenApplyBySource(iPos)
    if not mAttrs or table_count(mAttrs) == 0 then
        return
    end
    for sApply, iValue in pairs(mAttrs) do
        oPlayer.m_oEquipMgr:AddApply(sApply, iSource, iValue)
    end
    oPlayer:RefreshPropAll()
end

function CItem:StrengthUnEffect(oPlayer)
    local iPid = oPlayer.m_iPid
    local iPos = self:EquipPos()
    local iSource = self:GetApplySource("strength")
    local iStrengthenLevel = oPlayer:StrengthenLevel(iPos)
    if not iStrengthenLevel or iStrengthenLevel <= 0 then
        return
    end
    local mAttrs = oPlayer.m_oEquipMgr:GetStrengthenApplyBySource(iPos)
    if not mAttrs or table_count(mAttrs) == 0 then
        return
    end
    oPlayer.m_oEquipMgr:RemoveSource(iSource)
    oPlayer:RefreshPropAll()
end

function CItem:AddSE(oSE)
    self:Dirty()
    self.m_mSE[oSE.m_ID] = oSE
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "equip")
    end
    global.oScoreCache:EquipDirty(self:ID())
end

function CItem:AddSK(oSK)
    self:Dirty()
    self.m_mSK[oSK.m_ID] = oSK
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "equip")
    end
    global.oScoreCache:EquipDirty(self:ID())
end

function CItem:ClearSK()
    self:Dirty()
    local lSkills = table_key_list(self.m_mSK)
    for _,iSK in pairs(lSkills) do
        local oSK = self.m_mSK[iSK]
        self.m_mSK[iSK] = nil
        baseobj_delay_release(oSK)
    end
end

function CItem:HasSE()
    return table_count(self.m_mSE) > 0
end

function CItem:HasSK()
    return table_count(self.m_mSK) > 0
end

function CItem:ApplyInfo()
    local mData = {}
    for sAttr,iValue in pairs(self.m_mApply) do
        table.insert(mData,{key=sAttr,value=iValue})
    end
    for sAttr,iValue in pairs(self.m_mRatioApply) do
        table.insert(mData,{key=sAttr,value=iValue})
    end
    return mData
end

function CItem:Desc()
    -- TODO 此设计预计修改，现已经将装备的属性数据下行且前端已使用之进行信息生成，这部分描述前端拼接更合理，也容易为文本着色，本协议仅提供装备属性之外的额外信息用于前端拼接
    local str = ""
    return str
end

function PackApplyInfo(mKeyDatas)
    local mDestData = {}
    for sInfoKey, mSrcData in pairs(mKeyDatas) do
        local mData = {}
        for sAttr,iValue in pairs(mSrcData) do
            table.insert(mData, {key=sAttr,value=iValue})
        end
        if table_count(mData) ~= 0 then
            mDestData[sInfoKey] = mData
        end
    end
    return mDestData
end

function CItem:PackNowWash()
    local mNowApply = {}
    for _, mAttr in pairs(self:GetData("wash_now", {})) do
        for sApply,iValue in pairs(mAttr) do
            table.insert(mNowApply, {key=sApply, value=iValue})
        end
    end
    return mNowApply
end

function CItem:PackBackWash()
    local mBackApply = {}
    for _, mAttr in pairs(self:GetData("wash_back", {})) do
        for sApply,iValue in pairs(mAttr) do
            table.insert(mBackApply, {key=sApply, value=iValue})
        end
    end
    return mBackApply
end

function CItem:PackEquipInfo()
    local mInfo = self:PackEquipValues()
    mInfo.score = math.floor(1000 * self:GetScore())
    return mInfo
end

function CItem:PackEquipValues()
    -- PS:强化是对角色部位进行的，不再属于单个物品
    local mEquipInfo = PackApplyInfo({
        fuhun_attr = self.m_mShenHun,
        fuhun_extra = self.m_mShenHunExtra,
    })
    local mSe = {}
    for iSe, oSE in pairs(self.m_mSE) do
        table.insert(mSe, iSe)
    end
    mEquipInfo.se = mSe
    mEquipInfo.sk = table_key_list(self.m_mSK)
    mEquipInfo.last = self:GetLast()
    mEquipInfo.attach_attr = self:PackNowWash()
    mEquipInfo.is_make = self:GetData("is_make")
    mEquipInfo.hunshi = self:PackHunShi()
    mEquipInfo.fuzhuan = self:PackFuZhuan()
    return mEquipInfo
end

function CItem:PackItemInfo()
    local mNet = super(CItem).PackItemInfo(self)
    mNet.equip_info = self:PackEquipInfo()
    return mNet
end

function CItem:PackShowItemInfo(oPlayer)
    local mNet = self:PackItemInfo()
    if oPlayer and self:IsWield() then
        local iPos = self:EquipPos()
        mNet.equip_info.tmp_strength = oPlayer:StrengthenLevel(iPos)
        mNet.equip_info.tmp_score = math.floor(1000 * oPlayer.m_oEquipMgr:GetStrengthenPosScore(iPos))
    end
    mNet.guild_buy_price = 0
    mNet.stall_buy_price = 0
    return mNet
end

function CItem:PackLogInfo()
    local mInfo = super(CItem).PackLogInfo(self)
    mInfo.equip_info = self:PackEquipValues()
    return mInfo
end

function CItem:GetLast()
    return self:GetData("last",0)
end

function CItem:GetMaxLast()
    if self:IsMake() then
        return 500
    else
        return self:GetItemData()["last"] or 0
    end
end

function CItem:IsValid()
    return self:GetLast() > 0
end

function CItem:SetWarExAttackCnt(iCnt)
    return self:SetData("attach_cnt", iCnt)
end

function CItem:GetWarExAttackCnt()
    return self:GetData("attach_cnt", 0)
end

function CItem:SetWarExAttackedCnt(iCnt)
    return self:SetData("attached_cnt", iCnt)
end

function CItem:GetWarExAttackedCnt()
    return self:GetData("attached_cnt", 0)
end

function CItem:AddLast(iLastModify, bNoCheckSingle)
    if iLastModify == 0 then
        return
    end

    local iOldLast = self:GetData("last",0)
    local bOldNeedFix = self:IsNeedFix()
    -- if iOldLast <= 0 and iLastModify < 0 then
    --     return
    -- end

    local iMaxLast = self:GetMaxLast()
    if iMaxLast <= 0 then return end
    -- if iMaxLast <= iOldLast and iLastModify > 0 then
    --     return
    -- end

    local iNewLast = max(iOldLast + iLastModify, 0)
    iNewLast = min(iNewLast, iMaxLast)
    iNewLast = math.floor(iNewLast)
    if iNewLast == iOldLast then
        return
    end

    self:Dirty()
    self:SetData("last", iNewLast)
    local bNewNeedFix = self:IsNeedFix()

    -- 下行
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    oPlayer:Send("GS2CEquipLast",{
        itemid = self.m_ID,
        last = iNewLast,
    })

    if iOldLast > 0 and iNewLast <= 0 then
        self:OnBeInvalid(oPlayer)
    elseif iOldLast <= 0 and iNewLast > 0 then
        self:OnBeValid(oPlayer)
    end
    -- 强化大师与耐久无关

    if not bNoCheckSingle then
        if self:Equiped() then
            if bOldNeedFix ~= bNewNeedFix then
                oPlayer.m_oItemCtrl:CheckNeedFixEquips(oPlayer)
            end
        end

        if self:Equiped() and self:TouchIsFirstNeedFix() then
            oPlayer.m_oItemCtrl:ToTipsFixEquips(oPlayer)
        end
    end
end

function CItem:TouchIsFirstNeedFix()
    if self:GetData("has_need_fix") then
        return false
    end
    if self:IsNeedFix() then
        self:SetData("has_need_fix", true)
        return true
    end
    return false
end

function CItem:IsNeedFix()
    local iMaxLast = self:GetMaxLast()
    local iLast = self:GetLast()
    if iLast <= (iMaxLast / 10) then
        return true
    end
    return false
end

function CItem:DeadDelLast()
    local iRatio = self:GetItemData()["deadDelLast"] or 3
    local iLast = self:GetMaxLast() * iRatio / 100
    iLast = max(iLast,1)
    return math.floor(iLast + 0.5)
end

function CItem:GetFixPrice()
    local iPrice = self:GetItemData()["fixPrice"] or 10000
    local iMaxLast = self:GetMaxLast()
    if iMaxLast <= 0 then
        return 0
    end
    iPrice = iPrice * (1 - self:GetLast() / iMaxLast)
    iPrice = math.floor(iPrice + 0.5)
    return iPrice
end

function CItem:FixEquip(oPlayer, bNoCheckSingle)
    local iOldLast = self:GetData("last",0)
    local iMaxLast = math.max(self:GetMaxLast(), 100)
    self:AddLast(iMaxLast - iOldLast, bNoCheckSingle)
end

function CItem:SendNetWash(oPlayer)
    local mSe = {}
    for iSe,oSE in pairs(self.m_mSE) do
        table.insert(mSe,iSe)
    end

    local mBackSe = {}
    local mData = self:GetBackSe()
    for iSe,_ in pairs(mData) do
        table.insert(mBackSe,iSe)
    end

    local mNow = {}
    mNow["apply_info"] = self:PackNowWash()
    mNow["se_list"] = mSe

    local mWash = {}
    mWash["apply_info"] = self:PackBackWash()
    mWash["se_list"] = mBackSe

    oPlayer:Send("GS2CWashEquipInfo",{
        now_info = mNow,
        wash_info = mWash})
end

-- 替换属性
function CItem:Wash(oPlayer)
    local lBackAttach = self:GetData("wash_back",{})
    local mBackSe = self:GetBackSe()
    local bWield = self:GetData("wield")

    local lOldSEs = extend.Table.filter(self.m_mSE, function(o) return o:GetID() end)
    local lNewSEs = table_key_list(mBackSe)
    local mLogData = table_combine(oPlayer:LogData(), {item = self:SID(), old_se = lOldSEs, new_se = lNewSEs, old_attach_attr = self.m_mAttachAttr, new_attach_attr = lBackAttach})
    record.user("equip", "wash", mLogData)

    self:Dirty()
    if bWield then
        oPlayer.m_oEquipMgr:RemoveSource(self:GetApplySource("attach"))
        -- for _,oSE in pairs(self.m_mSE) do
        --     oSE:SkillUnEffect(oPlayer)
        -- end
    end

    -- for _, oSE in pairs(self.m_mSE) do
    --     baseobj_delay_release(oSE)
    -- end
    self.m_mAttachAttr = {}
    -- self.m_mSE = {}
    self:SetData("wash_back",nil)
    -- self:SetBackSe(nil)
    self:SetData("wash_now", lBackAttach)
    global.oScoreCache:Dirty(self:GetOwner(), "equip")
    global.oScoreCache:EquipDirty(self:ID())

    local iSource = self:GetApplySource("attach")
    for _, mAttr in pairs(lBackAttach) do
        for sAttr,iValue in pairs(mAttr) do
            self:AddAttach(sAttr,iValue)
            if bWield then
                oPlayer.m_oEquipMgr:AddApply(sAttr,iSource,iValue)
            end
        end
    end
    -- for iSe,_ in pairs(mBackSe) do
    --     local oSE = loadskill.NewSkill(iSe)
    --     oSE:SetPos(self:EquipPos())
    --     oSE:SetLevel(self:EquipLevel())
    --     self:AddSE(oSE)
    --     if bWield then
    --         oSE:SkillEffect(oPlayer)
    --     end
    -- end
    self:Refresh()
    self:SendNetWash(oPlayer)

    -- 刷新给角色属性
    oPlayer:RefreshPropAll()

    if bWield and oPlayer.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.IN_WAR then
        local sMsg = global.oItemHandler:GetTextData(1088)
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    end
end

function CItem:IsFuHun()
    return self:GetData("fh_sid", 0) > 0 
end

function CItem:RandomRatio(lAttrRatio)
    local mRatio = {}
    for idx, m in pairs(lAttrRatio) do
        mRatio[idx] = m["weight"]
    end
    local iRan = table_choose_key(mRatio)
    local mData = lAttrRatio[iRan]
    return math.random(mData["min"], mData["max"])
end

function CItem:CalFuHunExtra(lAttrRatio)
    local mRatio = {}
    for idx, m in pairs(lAttrRatio) do
        mRatio[idx] = m["weight"]
    end
    local iRan = table_choose_key(mRatio)
    local mData = lAttrRatio[iRan]
    local sValue = mData["ratio"]
    
    local iValue = 0
    if string.match(sValue, "rf") then
        local lValue = split_string(string.sub(sValue, 4, -2), ",", tonumber) 
        iValue = lValue[math.random(#lValue)]
    else
        iValue = formula_string(sValue, {ilv=self:EquipLevel()}) 
    end
    return iValue
end

function CItem:EquipFH(oPlayer, iShenHun)
    local mShenHunRatio = res["daobiao"]["shenhuneffect"]
    local mRatio = mShenHunRatio[self:EquipLevel()]
    assert(mRatio, string.format("not find funhun shenhuneffect level:%d", self:EquipLevel()))
    local mFunHunExtra = res["daobiao"]["fuhunextra"]
    local lExtraRatio = mFunHunExtra[self:EquipPos()]

    local mNewAttr = {}
    for sAttr, iValue in pairs(self.m_mApply) do
        local iRatio = self:RandomRatio(mRatio["attr_ratio"])
        mNewAttr[sAttr] = math.floor(iValue * iRatio / 100)
    end

    local oNewExtraAttr = {}
    local iRatio = self:CalFuHunExtraRatio()
    if #lExtraRatio > 0 and math.random(1, 100) <= iRatio then
        local mAttrRatio = lExtraRatio[math.random(#lExtraRatio)]
        oNewExtraAttr[mAttrRatio["attr"]] = self:CalFuHunExtra(mAttrRatio["attr_ratio"])
    end

    local oOldAttr = self.m_mShenHun
    self:ShenHunUnEffect(oPlayer)
    self:Dirty()
    self.m_mShenHun = mNewAttr
    self.m_mShenHunExtra = oNewExtraAttr
    self:SetData("fh_sid", iShenHun)
    global.oScoreCache:Dirty(oPlayer:GetPid(), "equip")
    global.oScoreCache:EquipDirty(self:ID())
    self:ShenHunEffect(oPlayer)
    self:Refresh()

    local mLogData = table_combine(oPlayer:LogData(), {item = self:SID(), old_shenhun = oOldAttr, new_shenhun = mNewAttr})
    record.user("equip", "fuhun", mLogData)
end

--神魂效果
function CItem:ShenHunEffect(oPlayer)
    if self:IsWield() then
        local iShenhunSource = self:GetApplySource("shenhun")
        for sApply,iValue in pairs(self.m_mShenHun) do
            oPlayer.m_oEquipMgr:AddApply(sApply, iShenhunSource, iValue)
        end
        local iShenhunSourceExt = self:GetApplySource("shenhunext")
        for sApply,iValue in pairs(self.m_mShenHunExtra) do
            oPlayer.m_oEquipMgr:AddApply(sApply, iShenhunSourceExt, iValue)
        end
    end
end

--神魂效果移除
function CItem:ShenHunUnEffect(oPlayer)
    if self:IsWield() then
        oPlayer.m_oEquipMgr:RemoveSource(self:GetApplySource("shenhun"))
        oPlayer.m_oEquipMgr:RemoveSource(self:GetApplySource("shenhunext"))
    end
end

--评分--
function CItem:CountAllScoreByAttrs(mAttrs)
    return global.oEquipMgr:CountAllScoreByAttrs(mAttrs)
end

function CItem:GetScore(bForce)
    local iScore = 0
    if not bForce then
        iScore =  global.oScoreCache:GetEquipScore(self)
    else
        iScore =  self:CalScore()
    end
    iScore = math.floor(iScore)
    return iScore
end

function CItem:CalScore()
    local rScore = 0
    rScore = rScore + self:GetScoreBySK()
    rScore = rScore + self:GetScoreBySE()
    rScore = rScore + self:GetScoreByBasic()
    rScore = rScore + self:GetScoreBySH()
    rScore = rScore + self:GetScoreByAttach()
    rScore = rScore + self:GetScoreByHunShi()
    return rScore
end

function CItem:GetScoreBySK()
    local iLevel = self:EquipLevel()
    local rScore = 0
    for _,oSK in pairs(self.m_mSK) do
        rScore = rScore + oSK:GetScore(iLevel)
    end
    return rScore
end

function CItem:GetScoreBySE()
    local iLevel = self:EquipLevel()
    local rScore = 0
    for _,oSE in pairs(self.m_mSE) do
        rScore = rScore + oSE:GetScore(iLevel)
    end
    return rScore
end

function CItem:GetScoreByBasic()
    local rScore = 0
    local mBasicAttrs = self:GetBaseAttrs()
    if table_count(mBasicAttrs)<=0 then
        return rScore
    end
    local sBasicAttrScore = self:GetItemData()["basic_score"]
    for sAttr,iValue in pairs(mBasicAttrs) do
        local iBasicValue = self:GetBasicScoreByAttr(sAttr)
        rScore = rScore + formula_string(sBasicAttrScore,{attr = iBasicValue,value = iValue})
    end
    return rScore
end

function CItem:GetScoreBySH()
    local rScore = 0
    local mShenhunAttrs = self:GetShenHunAttrs()
    if table_count(mShenhunAttrs)<=0 then
        return rScore
    end
    local sShenHunAttrScore = self:GetItemData()["shenhun_attr_score"]
    for sAttr,iValue in pairs(mShenhunAttrs) do
        local iBasicValue = self:GetBasicScoreByAttr(sAttr)
        rScore = rScore + formula_string(sShenHunAttrScore,{attr = iBasicValue,value = iValue})
    end
    local sShenHunBasicScore = self:GetItemData()["shenhun_basic_score"]
     rScore = rScore + formula_string(sShenHunBasicScore,{})
    return rScore
end

function CItem:GetScoreByAttach()
    local rScore = 0
    local mAttachAttrs = self:GetAttachAttrs()
    if table_count(mAttachAttrs)<=0 then
        return rScore
    end
    local sAttachAttrs = self:GetItemData()["attach_attr_score"]
    for sAttr,iValue in pairs(mAttachAttrs) do
        local iBasicValue = self:GetBasicScoreByAttr(sAttr)
        rScore = rScore + formula_string(sAttachAttrs,{attr = iBasicValue,value = iValue})
    end
    return rScore
end

function CItem:GetBasicScoreByAttr(sAttr)
    return  res["daobiao"]["equipscore"][sAttr]["score"]
end
--评分--

function CItem:GetBaseAttrs()
    return self.m_mApply
end

function CItem:GetBaseRatioAttrs()
    return self.m_mRatioApply
end

function CItem:GetAttachAttrs()
    return self.m_mAttachAttr
end

function CItem:GetSEs()
    return self.m_mSE
end

function CItem:GetShenHunAttrs()
    return self.m_mShenHun
end

function CItem:ValidDeCompose()
    if self:Equiped() then return false end
    
    return super(CItem).ValidDeCompose(self)
end

function CItem:DeComposeItems()
    local mData = res["daobiao"]["equipfenjie"]
    local mFenjieData = table_get_depth(mData, {self:EquipLevel(), self:EquipPos(), self:Quality()})
    if not mFenjieData then return end

    local lFenJieIdx = {}
    if self:IsFuHun() then
        lFenJieIdx = mFenjieData["hunfenjie_list"]
    else
        local iFenjieIdx = mFenjieData["fenjie_id"]
        table.insert(lFenJieIdx, iFenjieIdx)    
    end
    
    local mGiveItem = {}
    local mFenjieKu = res["daobiao"]["fenjieku"]
    for _, idx in pairs(lFenJieIdx) do
        local mItemData = mFenjieKu[idx]
        for _, mData in pairs(mItemData) do
            local iSid = mData["sid"]
            local iAmount = math.random(mData["minAmount"], mData["maxAmount"])
            assert(iAmount > 0, string.format("equipbase feijie error %s", idx))
            mGiveItem[iSid] = iAmount
        end
    end
    return mGiveItem
end

function CItem:CalFuHunExtraRatio()
    local sFormula = self:GetEquipGlobal()["fh_extra_attr_ratio"]
    local iValue = formula_string(sFormula, {ilv = self:EquipLevel()})
    return math.floor(iValue)
end

function CItem:GetEquipGlobal()
    return res["daobiao"]["equipglobal"][1] 
end

function CItem:CanLevelUp()
    return false
end

function CItem:CanWield(oPlayer)
    if self:EquipLevel() > oPlayer:GetGrade() then
        return false, global.oItemHandler:GetTextData(1004, {grade=self:EquipLevel()})
    end
    return true
end

--魂石相关
function CItem:AddHunShi(mInfo)
    self:Dirty()
    self.m_mHunShi[mInfo.pos] = mInfo
    global.oScoreCache:EquipDirty(self:ID())
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "equip")
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        self:HunShiEffect(oPlayer,{mInfo})
    end
    self:Refresh()
end

function CItem:DelHunShi(iPos)
    self:Dirty()
    local mInfo = self.m_mHunShi[iPos]
    self.m_mHunShi[iPos] = nil
    global.oScoreCache:EquipDirty(self:ID())
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "equip")
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        self:HunShiUnEffect(oPlayer,iPos)
    end
    self:Refresh()
end

function CItem:GetHunShi()
    return self.m_mHunShi
end

function CItem:PackHunShi()
    local mNet = {}
    local mHunShi = self:GetHunShi()
    for _,mInfo in pairs(mHunShi) do
        table.insert(mNet,mInfo)
    end
    return mNet
end

function CItem:GetHunShiSource(iPos)
    local iSource = self:GetApplySource("hunshi")
    return iSource + iPos * 1000
end

function CItem:HunShiEffect(oPlayer,mHS)
    if self:IsWield() then
        local mHunShi = self:GetHunShi()
        if mHS then
            mHunShi = mHS
        end
        for _, mInfo in pairs(mHunShi) do
            local iColor = mInfo.color 
            local iGrade = mInfo.grade 
            local iSource = self:GetHunShiSource(mInfo.pos)
            local mAttrRes = res["daobiao"]["hunshi"]["attr"][iColor]
            if mAttrRes then
                for _,sApply in pairs(mInfo.addattr) do 
                    if mAttrRes[sApply] then
                        local sValue = mAttrRes[sApply]["attr_skill"]
                        local iValue = formula_string(sValue,{lv = iGrade})
                        if iValue>0 then
                            sApply = tostring(sApply)
                            oPlayer.m_oEquipMgr:AddApply(sApply, iSource, iValue)
                        end
                    end
                end
            end
        end
    end
end

function CItem:HunShiUnEffect(oPlayer,iPos)
    if self:IsWield() then
        if iPos then
            local iSource = self:GetHunShiSource(iPos)
            oPlayer.m_oEquipMgr:RemoveSource(iSource)
        else
            local mHunShi = self:GetHunShi()
            for iPos, mInfo in pairs(mHunShi) do
                local iSource = self:GetHunShiSource(iPos)
                oPlayer.m_oEquipMgr:RemoveSource(iSource)
            end
        end
    end
end

function CItem:GetScoreByHunShi()
    local iScore = 0
    local mHunShi = self:GetHunShi()
    for _, mInfo in pairs(mHunShi) do
        local iColor = mInfo.color
        local iGrade = mInfo.grade 
        local mRes = res["daobiao"]["hunshi"]["color"][iColor]
        if not mRes then
            goto continue
        end
        local sScore = mRes["score"]
        iScore =  iScore +  math.floor(formula_string(sScore,{lv = iGrade}))
        ::continue::
    end
    return iScore
end

--魂石相关

--符篆相关
function CItem:SetFuZhuanAttr(mAttr)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    local iSource = self:GetApplySource("fuzhuan")
    for sAttr,iValue in pairs(mAttr) do
        self:FuZhuanUnEffect(sAttr)
        self.m_mFuZhuan[sAttr] = {}
        self.m_mFuZhuan[sAttr]["value"] = iValue
        self.m_mFuZhuan[sAttr]["time"] = get_time()
        self:FuZhuanEffect(sAttr)
        self:AddFuZhuanTimer(sAttr)
    end
    self:Dirty()
    
    self:Refresh()
end

function CItem:AddFuZhuanTimer(sAttr)
    if not next(self.m_mFuZhuan) then
        return
    end
    local mAttrName = res["daobiao"]["attrname"]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    local lAttr =  table_key_list(self.m_mFuZhuan)
    if sAttr then
        lAttr = {sAttr}
    end
    local iCurTime = get_time()
    for _,sApply in ipairs(lAttr) do
        local mInfo = self.m_mFuZhuan[sApply]
        if not mInfo then
            goto continue
        end
        local iTime = mInfo.time or 0
        local iValue = mInfo.value or 0
        local iEndTime = iTime + self:GetFuZhuanTime()
        if iEndTime<=iCurTime then
            self:Dirty()
            self:FuZhuanUnEffect(sApply)
            self.m_mFuZhuan[sApply] = nil 
            goto continue
        end
        local iLeftTime = iEndTime - iCurTime
        local itemid =self:ID()
        local pid =self:GetOwner()
        local sTimer = string.format("FuZhuanCheck_%s",sApply)
        self:DelTimeCb(sTimer)
        self:AddTimeCb(sTimer,iLeftTime*1000,function ()
            _FuZhuanCheck(pid,itemid,sApply)
        end)
        if sAttr and oPlayer then
            local sText = global.oToolMgr:GetTextData(1015,{"skill"})
            local sAttrName = "神秘属性" 
            if mAttrName[sAttr] and mAttrName[sAttr]["name"] then
                sAttrName = mAttrName[sAttr]["name"]
            end
            sText = global.oToolMgr:FormatColorString(sText,{attr=sAttrName,amount = iValue})
            global.oNotifyMgr:Notify(pid,sText)
        end
        ::continue::
    end
end

function _FuZhuanCheck(pid,itemid,sAttr)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid,true)
    if not itemobj then
        return
    end
    itemobj:FuZhuanCheckEnd(oPlayer,sAttr)
end

function CItem:FuZhuanCheckEnd(oPlayer,sAttr)
    local iSource = self:GetApplySource("fuzhuan")
    local sTimer = string.format("FuZhuanCheck_%s",sAttr)
    self:DelTimeCb(sTimer)
    self:FuZhuanUnEffect(sAttr)
    self:Dirty()
    self.m_mFuZhuan[sAttr] = nil 
    self:Refresh()
    oPlayer:RefreshPropAll()
end

function CItem:FuZhuanEffect(sAttr)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    if self:IsWield() then
        if not next(self.m_mFuZhuan) then
            return 
        end
        if not sAttr then
            for sApply,mInfo in pairs(self.m_mFuZhuan) do
                local iSource = self:GetApplySource("fuzhuan")
                local iValue = mInfo.value or 0
                oPlayer.m_oEquipMgr:AddApply(sApply, iSource, iValue)
            end
        else
            local mInfo = self.m_mFuZhuan[sAttr] 
            if not mInfo then
                return
            end
                local iSource = self:GetApplySource("fuzhuan")
                local iValue = mInfo.value or 0
                oPlayer.m_oEquipMgr:AddApply(sAttr, iSource, iValue)
        end
    end
end

function CItem:FuZhuanUnEffect(sAttr)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    if self:IsWield() then
        if not sAttr then
            local iSource = self:GetApplySource("fuzhuan")
            oPlayer.m_oEquipMgr:RemoveSource(iSource)
        else
            local mInfo = self.m_mFuZhuan[sAttr] 
            if not mInfo then
                return
            end
                local iSource = self:GetApplySource("fuzhuan")
                local iValue = mInfo.value or 0
                oPlayer.m_oEquipMgr:AddApply(sAttr, iSource, -iValue)
        end
    end
end

function CItem:GetFuZhuanSource(iPos)
    local iSource = self:GetApplySource("fuzhuan")
    return iSource + iPos * 1000
end

function CItem:GetFuZhuanTime()
    local mConfig = res["daobiao"]["skill"]["config"][1]
    local iTime = mConfig.fuzhuan_time
    return iTime
end

function CItem:PackFuZhuan()
    local mNet = {}
    for sAttr,mInfo in pairs(self.m_mFuZhuan) do
        local mData = {}
        mData.attr = sAttr
        mData.time = mInfo.time + self:GetFuZhuanTime()
        mData.value = mInfo.value 
        table.insert(mNet,mData)
    end
    return mNet
end

--符篆相关

