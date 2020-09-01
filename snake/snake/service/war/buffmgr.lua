--import module

local global = require "global"
local skynet = require "skynet"

local tableop = import(lualib_path("base.tableop"))
local buffload = import(service_path("buff/buffload"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewBuffMgr(...)
    local o = CBuffMgr:New(...)
    return o
end

CBuffMgr = {}
CBuffMgr.__index = CBuffMgr
inherit(CBuffMgr, logic_base_cls())

function CBuffMgr:New(iWarId,iWid)
    local o = super(CBuffMgr).New(self)
    o.m_iWarId = iWarId
    o.m_iWid = iWid
    o.m_mBuffs = {}

    o.m_mAttrRatio = {}
    o.m_mAttrAdd = {}
    o.m_mAttrTempRatio = {}
    o.m_mAttrTempAdd = {}

    o.m_mAttr = {}
    o.m_mFunctor = {}
    return o
end

function CBuffMgr:Release()
    for _, mBuffs in ipairs(self.m_mBuffs) do
        for _,mGroupBuff in pairs(mBuffs) do
            for _,oBuff in pairs(mGroupBuff) do
                baseobj_safe_release(oBuff)
            end
        end
    end
    self.m_mBuffs = {}
    super(CBuffMgr).Release(self)
end

--buff组最大数目
function CBuffMgr:GetBuffGroupMaxCnt(iType)
    local res = require "base.res"
    local mData = res["daobiao"]["bufflimit"][iType]
    return mData["maxcnt"]
end

function CBuffMgr:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self.m_iWarId)
end

function CBuffMgr:GetWarrior()
    local oWar = self:GetWar()
    return oWar:GetWarrior(self.m_iWid)
end

function CBuffMgr:ValidReplaceGroup(oBuff,oNewBuff)
    if oBuff:PerformLevel() ~= oNewBuff:PerformLevel() then
        return oBuff:PerformLevel() < oNewBuff:PerformLevel()
    end
    if oBuff:Bout() ~= oNewBuff:Bout() then
        return oBuff:Bout() < oNewBuff:Bout()
    end
    return true
end

function CBuffMgr:CanAddBuff(iBuffID, mArgs)
    local oBuff =buffload.GetBuff(iBuffID)
    if not oBuff then return end

    local oWarrior = self:GetWarrior()
    if not oWarrior then return false end

    local mFunc = oWarrior:GetFunction("OnBeforeAddBuff")
    for _,fCallback in pairs(mFunc) do
        local bFlag = fCallback(oWarrior, oBuff) 
        if bFlag then return false end
    end

    if oBuff:Type() == gamedefines.BUFF_TYPE.CLASS_ABNORMAL then
        if math.random(100) <= oWarrior:GetAttrAddValue("res_abnormal_buff_ratio", 0) then
            return false
        end
    elseif oBuff:Type() == gamedefines.BUFF_TYPE.CLASS_BENEFIT  then
        if math.random(100) <= oWarrior:GetAttrAddValue("res_benefit_buff_ratio", 0) then
            return false
        end
    end
    if math.random(100) <= oWarrior:GetAttrAddValue("res_all_buff_ratio", 0) then
        return false
    end
    return true
end

function CBuffMgr:AddBuff(iBuffID, iBout, mArgs)
    if not mArgs["bForce"] and not self:CanAddBuff(iBuffID, mArgs) then return end

    local oNewBuff = buffload.NewBuff(iBuffID,iBout,mArgs)
    oNewBuff:Init(iBout,mArgs)
    local iType = oNewBuff:Type()
    local iGroupType = oNewBuff:GroupType()
    local mBuff = self.m_mBuffs[iType] or {}
    local mGroupBuff = mBuff[iGroupType] or {}
    for _,oBuff in pairs(mGroupBuff) do
        if oBuff.m_ID == iBuffID then
            local iBuffType = oBuff:UpdateType()
            if iBuffType == 1 then                           --叠加
                oBuff:AddBout(iBout)
                local oAction = self:GetWarrior()
                if oAction then
                    oAction:SendAll("GS2CWarBuffBout", {
                        war_id = self.m_iWarId,
                        wid = self.m_iWid,
                        buff_id = oBuff.m_ID,
                        bout  = oBuff:Bout(),
                        attrlist = oBuff:PackAttr(oAction),
                    })
                    local oWar = oAction:GetWar()
                    oWar:AddDebugMsg(string.format("#B%s#nbuff#R%s#n增加%d回合", oAction:GetName(),oBuff:Name(),iBout))
                end
                baseobj_delay_release(oNewBuff)

            elseif iBuffType == 2 then                     --替换
                self:RemoveBuff(oBuff)
                self:TrueAddBuff(oNewBuff)
            end
        else
            if self:ValidReplaceGroup(oBuff,oNewBuff) then
                self:RemoveBuff(oBuff)
                self:TrueAddBuff(oNewBuff)
            end
        end
        return
    end
    local iCnt = tableop.table_count(mBuff)
    local iMaxCnt = self:GetBuffGroupMaxCnt(iType)
    if iCnt >= iMaxCnt then
        local mKey = tableop.table_key_list(mBuff)
        local iGroupType = mKey[math.random(#mKey)]
        mGroupBuff = mBuff[iGroupType]
        for _,oBuff in pairs(mGroupBuff) do
            self:RemoveBuff(oBuff)
            self:TrueAddBuff(oNewBuff)
            return
        end
    end
    self:TrueAddBuff(oNewBuff)
end

function CBuffMgr:TrueAddBuff(oBuff)
    local iBuffID = oBuff.m_ID
    local iType = oBuff:Type()
    local iGroupType = oBuff:GroupType()
    local mBuff = self.m_mBuffs[iType] or {}
    local mGroupBuff = mBuff[iGroupType] or {}
    mGroupBuff[oBuff.m_ID] = oBuff
    mBuff[iGroupType]  = mGroupBuff
    self.m_mBuffs[iType] = mBuff

    local mAttrs = oBuff:AttrRatioList()
    for _,str in pairs(mAttrs) do
        local key,value = string.match(str,"(.+)=(.+)")
        value = oBuff:CalAttrValue(value)
        self:SetAttrBaseRatio(key,iBuffID,value)
    end
    mAttrs = oBuff:AttrValueList()
    for _,str in pairs(mAttrs) do
        local key,value = string.match(str,"(.+)=(.+)")
        value = oBuff:CalAttrValue(value)
        self:SetAttrAddValue(key,iBuffID,value)
    end
    mAttrs = oBuff:AttrTempRatio()
    for _,str in pairs(mAttrs) do
        local key,value = string.match(str,"(.+)=(.+)")
        value = oBuff:CalAttrValue(value)
        self:SetAttrTempRatio(key,iBuffID,value)
    end
    mAttrs = oBuff:AttrTempAddValue()
    for _,str in pairs(mAttrs) do
        local key,value = string.match(str,"(.+)=(.+)")
        value = oBuff:CalAttrValue(value)
        self:SetAttrTempValue(key,iBuffID,value)
    end
    mAttrs = oBuff:AttrMask()
    for _,str in pairs(mAttrs) do
        local key,value = string.match(str,"(.+)=(.+)")
        value = oBuff:CalAttrValue(value)
        self:SetAttr(key,value)
        oBuff:SetAttr(key,value)
    end

    local oAction = self:GetWarrior()
    oBuff:CalInit(oAction,self)
    if oAction then
        oAction:SendAll("GS2CWarAddBuff", {
            war_id = self.m_iWarId,
            wid = self.m_iWid,
            buff_id = oBuff.m_ID,
            bout  = oBuff:Bout(),
            attrlist = oBuff:PackAttr(oAction),
        })
        local oWar = oAction:GetWar()
        oWar:AddDebugMsg(string.format("#B%s#n添加buff#R%s#n%d回合", oAction:GetName(),oBuff:Name(),oBuff:Bout()))

        if oBuff:Type() == gamedefines.BUFF_TYPE.CLASS_ABNORMAL and oAction:QueryBoutArgs("buff_sp", 0) == 0 and oAction:IsPlayerLike() then
            oAction:AddSP(5)
            oAction:AddBoutArgs("buff_sp", 1)
        end

        local mFunc = oAction:GetFunction("OnAddBuff")
        for _,fCallback in pairs(mFunc) do
            safe_call(fCallback, oAction, oBuff)
        end
    end
end

function CBuffMgr:RemoveBuff(oBuff, oAction)
    local iType = oBuff:Type()
    local iGroupType = oBuff:GroupType()
    local mBuff = self.m_mBuffs[iType] or {}
    local mGroupBuff = mBuff[iGroupType] or {}
    local iBuffID = oBuff.m_ID
    mGroupBuff[iBuffID] = nil
    if table_count(mGroupBuff) <= 0 then
        mBuff[iGroupType] = nil
    else
        mBuff[iGroupType] = mGroupBuff
    end
    if table_count(mBuff) <= 0 then
        self.m_mBuffs[iType] = nil
    else
        self.m_mBuffs[iType] = mBuff
    end

    oAction = oAction or self:GetWarrior()
    for sAttr,mAttrs in pairs(self.m_mAttrRatio) do
        mAttrs = mAttrs or {}
        mAttrs[iBuffID] = nil
        if tableop.table_count(mAttrs) == 0 then
            self.m_mAttrRatio[sAttr] = nil
        end
    end
    for sAttr,mAttrs in pairs(self.m_mAttrAdd) do
        mAttrs = mAttrs or {}
        mAttrs[iBuffID] = nil
        if tableop.table_count(mAttrs) == 0 then
            self.m_mAttrAdd[sAttr] = nil
        end
    end
    for sAttr,mAttrs in pairs(self.m_mAttrTempRatio) do
        mAttrs = mAttrs or {}
        mAttrs[iBuffID] = nil
        if tableop.table_count(mAttrs) == 0 then
            self.m_mAttrTempRatio[sAttr] = nil
        end
    end
    for sAttr,mAttrs in pairs(self.m_mAttrTempAdd) do
        mAttrs = mAttrs or {}
        mAttrs[iBuffID]  = nil
        if tableop.table_count(mAttrs) == 0 then
            self.m_mAttrTempAdd[sAttr] = nil
        end
    end

    local mSet = oBuff:GetSetAttr()
    for key,value in pairs(mSet) do
        local mBuff = self:GetBuffList()
        local bDelete = true
        for _,oNowBuff in pairs(mBuff) do
            if oNowBuff:GetAttr(key) then
                bDelete = false
                break
            end
        end
        if bDelete then
            self:SetAttr(key,nil)
        end
    end
    if oAction then
        oAction:SendAll("GS2CWarDelBuff", {
            war_id = self.m_iWarId,
            wid = self.m_iWid,
            buff_id = oBuff.m_ID,
        })
        local oWar = oAction:GetWar()
        oWar:AddDebugMsg(string.format("#B%s#n移除buff#R%s#n", oAction:GetName(),oBuff:Name()))
        oBuff:OnRemove(oAction,self)
    end
    baseobj_delay_release(oBuff)
end

function CBuffMgr:RemoveClassBuff(iType, sExclude, iLimit)
    iLimit = iLimit or 99
    local mBuff = self.m_mBuffs[iType] or {}
    for _,mGroupBuff in pairs(mBuff) do
        for _,oBuff in pairs(mGroupBuff) do
            if sExclude and sExclude == oBuff:BuffType() then
                goto continue
            end
            self:RemoveBuff(oBuff)

            iLimit = iLimit - 1
            if iLimit <= 0 then break end
            ::continue::
        end
    end
    return iLimit
end

function CBuffMgr:RemoveClassBuffInclude(iType, mInclude)
    local mBuff = self.m_mBuffs[iType] or {}
    for _,mGroupBuff in pairs(mBuff) do
        for _,oBuff in pairs(mGroupBuff) do
            local sBuffType = oBuff:BuffType()
            if not sBuffType or sBuffType == "" then
                goto continue
            end
            if mInclude[sBuffType] then
                self:RemoveBuff(oBuff)
            end
            ::continue::
        end
    end
end

function CBuffMgr:HasClassBuff(iType)
    local mBuff = self.m_mBuffs[iType] or {}
    local bHas = false
    for _, mGroupBuff in pairs(mBuff) do
        if table_count(mGroupBuff) > 0 then
            bHas = true
            break
        end
    end
    return bHas
end

function CBuffMgr:HasBuff(iBuffID)
    local oBuff = buffload.GetBuff(iBuffID)
    local iType = oBuff:Type()
    local iGroupType = oBuff:GroupType()
    local mBuff = self.m_mBuffs[iType] or {}
    local mGroupBuff = mBuff[iGroupType] or {}
    for _,oBuff in pairs(mGroupBuff) do
        if oBuff.m_ID == iBuffID then
            return oBuff
        end
    end
end

function CBuffMgr:GetBuffByClass(iType, sClass)
    local mBuff = self.m_mBuffs[iType] or {}
    for _, mGroupBuff in pairs(mBuff) do
        for _, oBuff in pairs(mGroupBuff) do
            local sClassType = oBuff:BuffType()
            if sClassType and sClassType == sClass then
                return oBuff
            end
        end
    end
end

function CBuffMgr:GetAttrBaseRatio(sAttr,rDefault)
    rDefault = rDefault or 0
    local iBaseRatio = 0
    local mRatio = self.m_mAttrRatio[sAttr] or {}
    for _,iRatio in pairs(mRatio) do
        iBaseRatio = iBaseRatio + iRatio
    end
    return iBaseRatio
end

function CBuffMgr:SetAttrBaseRatio(sAttr,iBuffID,iValue)
    local mAttrRatio = self.m_mAttrRatio[sAttr] or {}
    mAttrRatio[iBuffID] = iValue
    self.m_mAttrRatio[sAttr] = mAttrRatio
end

function CBuffMgr:GetAttrBaseRatioByBuff(sAttr, iBuffID)
    local mAttrRatio = self.m_mAttrRatio[sAttr] or {}
    return mAttrRatio[iBuffID] or 0
end

function CBuffMgr:AddAttrBaseRatioByBuff(sAttr, iBuffID, iVal)
    local mAttrRatio = self.m_mAttrRatio[sAttr] or {}
    mAttrRatio[iBuffID] = mAttrRatio[iBuffID] + iVal
    self.m_mAttrRatio[sAttr] = mAttrRatio
end

function CBuffMgr:GetAttrAddValue(sAttr,rDefault)
    rDefault = rDefault or 0
    local mAddValue = self.m_mAttrAdd[sAttr] or {}
    local iAddValue = 0
    for _,iValue in pairs(mAddValue) do
        iAddValue = iAddValue + iValue
    end
    return iAddValue
end

function CBuffMgr:SetAttrAddValue(sAttr,iBuffID,iValue)
    local mAttrAdd = self.m_mAttrAdd[sAttr] or {}
    mAttrAdd[iBuffID] = iValue
    self.m_mAttrAdd[sAttr] = mAttrAdd
end

function CBuffMgr:AddAttrAddValue(sAttr, iBuffID, iValue)
    local mAttrAdd = self.m_mAttrAdd[sAttr] or {}
    if not mAttrAdd[iBuffID] then
        mAttrAdd[iBuffID] = 0
    end
    mAttrAdd[iBuffID] = mAttrAdd[iBuffID] + iValue
    self.m_mAttrAdd[sAttr] = mAttrAdd
end

function CBuffMgr:GetAttrAddValueByBuff(sAttr, iBuffID)
    local mAttrAdd = self.m_mAttrAdd[sAttr] or {}
    return mAttrAdd[iBuffID] or 0
end

function CBuffMgr:GetAttrTempRatio(sAttr,rDefault)
    local iTempRatio = 0
    local mTempRatio = self.m_mAttrTempRatio[sAttr] or {}
    for _,iRatio in pairs(mTempRatio) do
        iTempRatio = iTempRatio + iRatio
    end
    return iTempRatio
end

function CBuffMgr:SetAttrTempRatio(sAttr,iBuffID,iRatio)
    local mTempRatio = self.m_mAttrTempRatio[sAttr] or {}
    mTempRatio[iBuffID] = iRatio
    self.m_mAttrTempRatio[sAttr] = mTempRatio
end

function CBuffMgr:GetAttrTempAddValue(sAttr,rDefault)
    rDefault = rDefault or 0
    local mTempAdd = self.m_mAttrTempAdd[sAttr] or {}
    local iTempAdd = 0
    for _,iValue in pairs(mTempAdd) do
        iTempAdd = iTempAdd + iValue 
    end
    return iTempAdd
end

function CBuffMgr:SetAttrTempValue(sAttr,iBuffID,iValue)
    local mAttrTemp = self.m_mAttrTempAdd[sAttr] or {}
    mAttrTemp[iBuffID] = iValue
    self.m_mAttrTempAdd[sAttr] = mAttrTemp
end

function CBuffMgr:SetAttr(sAttr,iValue)
    self.m_mAttr[sAttr] = iValue
end

function CBuffMgr:GetAttr(sAttr)
    return self.m_mAttr[sAttr]
end

function CBuffMgr:GetBuffList()
    local mBuffList = {}
    for _,mBuff in pairs(self.m_mBuffs) do
        for _,mGroupBuff in pairs(mBuff) do
            for _,oBuff in pairs(mGroupBuff) do
                table.insert(mBuffList,oBuff)
            end
        end
    end
    return mBuffList
end

function CBuffMgr:GetBuffListByType(iType)
    local lBuffList = {}
    for iGroup, mGroup in pairs(self.m_mBuffs[iType] or {}) do
        for iBuff, oBuff in pairs(mGroup) do
            table.insert(lBuffList, oBuff)
        end
    end
    return lBuffList
end

function CBuffMgr:OnNewBout(oAction)
    for _,mBuff in pairs(self.m_mBuffs) do
        for _,mGroupBuff in pairs(mBuff) do
            for _,oBuff in pairs(mGroupBuff) do
                oBuff:OnNewBout(oAction)
            end
        end
    end
end

function CBuffMgr:OnBoutEnd(oAction)
    for iType,mBuff in pairs(self.m_mBuffs) do
        for iGroupType,mGroupBuff in pairs(mBuff) do
            for _,oBuff in pairs(mGroupBuff) do
                oBuff:SubBout()
                if oBuff:Bout() < 1 then
                    oBuff:OnBoutEnd(oAction,self)
                    self:RemoveBuff(oBuff,oAction)
                else
                    oBuff:OnBoutEnd(oAction,self)
                end
            end
        end
    end
end

function CBuffMgr:HasKey(sKey)
    if self.m_mAttr[sKey] then
        return true
    end
    return false
end

function CBuffMgr:AddFunction(sKey,iNo,fCallback)
    local mFunctor = self.m_mFunctor[sKey] or {}
    mFunctor[iNo] = fCallback
    self.m_mFunctor[sKey] = mFunctor
end

function CBuffMgr:GetFunction(sKey)
    return self.m_mFunctor[sKey] or {}
end

function CBuffMgr:RemoveFunction(sKey,iNo)
    local mFunctor = self.m_mFunctor[sKey] or {}
    mFunctor[iNo] = nil
    self.m_mFunctor[sKey] = mFunctor
end
