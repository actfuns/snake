local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local itembase = import(service_path("item.other.otherbase"))
local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:Create(mArgs)
    super(CItem).Create(self,mArgs)
    if mArgs and mArgs.grade and mArgs.grade>=1 and mArgs.grade<=10 then
        self:SetGrade(mArgs.grade)
    end
end

function CItem:Setup()
    local iGrade = self:GetGrade()
    if iGrade<1 or iGrade>10 then
        self:SetGrade(1)
    end
    local tAddAttr = self:GetAddAttr()
    local mAttrData = self:GetHunShiAttrData()
    local mBasicData = self:GetHunShiBasicData()
    local bReInit = false
    for _,sAttr in ipairs(tAddAttr) do
        local mAttrInfo = mAttrData[sAttr]
        if not mAttrInfo then
            bReInit = true 
            break
        end
    end
    if #tAddAttr ==0 then
        bReInit = true
    elseif #tAddAttr == 1 then
        if  mBasicData.level ~=1 then
            bReInit = true
        end
    elseif #tAddAttr==2 then
        if mBasicData.level ==2  then
            local mSonAttr = self:GetSonAttrData()
            if not mSonAttr then
                bReInit = true
            elseif table_count(mSonAttr) ~= 2 then
                bReInit = true
            else
                for iSonColor , mAttr in pairs(mSonAttr) do
                    local bNeedInit = true
                    for _,sAddAttr in ipairs(tAddAttr) do
                        if mAttr[sAddAttr] then
                            bNeedInit = false
                        end
                    end
                    if bNeedInit then
                        bReInit = true
                        break
                    end
                end
            end
        else
            bReInit = true
        end
    else
        bReInit = true
    end
    if bReInit then
        self:ReInit()
    end
end

function CItem:ReInit()
    local mBasicData = self:GetHunShiBasicData()
    local mAttrData = self:GetHunShiAttrData()
    local tAddAttr = {}
    if mBasicData.level == 1 then
        local lAttr = table_key_list(mAttrData)
        local sAttr = extend.Random.random_choice(lAttr)
        table.insert(tAddAttr,sAttr)
        assert(#tAddAttr==1,string.format("%s reinit",self:SID()))
    elseif mBasicData.level == 2 then
        local mSonAttr = self:GetSonAttrData()
        assert(mSonAttr,string.format("%s reinit",self:SID()))
        for iColor,mSonAttrData in pairs(mSonAttr) do
            local lAttr = table_key_list(mSonAttrData)
            local sAttr = extend.Random.random_choice(lAttr)
            table.insert(tAddAttr,sAttr)
        end
        assert(#tAddAttr==2,string.format("%s reinit",self:SID()))
        for _,sAttr in pairs(tAddAttr) do
            assert(mAttrData[sAttr],string.format("%s %s reinit ",self:SID(),sAttr))
        end
    end
    self:SetAddAttr(tAddAttr)
end

function CItem:GetGrade()
    return self:GetData("grade",1)
end

function CItem:SetGrade(iGrade)
    assert(iGrade>=1 and iGrade<=10,string.format("%s error grade %s",self:SID(),iGrade))
    self:SetData("grade",iGrade)
end

function CItem:GetAddAttr()
    local tAddAttr = self:GetData("addattr",{})
    if type(tAddAttr) == "string" then
        tAddAttr = string.sub(tAddAttr,2,#tAddAttr-1)
        tAddAttr = split_string(tAddAttr,"+")
        for i,sAttr in ipairs(tAddAttr) do
            tAddAttr[i] = trim(sAttr)
        end
        self:SetAddAttr(tAddAttr)
    end
    return tAddAttr
end

function CItem:SetAddAttr(tAddAttr)
    self:SetData("addattr",tAddAttr)
end

function CItem:GetColor()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    return iColor
end

function CItem:GetHunShiBasicData()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    assert(iColor,string.format("hunshi icolorindex error %s",self:SID()))
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    assert(mRes,string.format("hunshi basicdata error %s %s",self:SID(),iColor))
    return mRes
end

function CItem:GetHunShiAttrData()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    assert(iColor,string.format("hunshi icolorindex error %s",self:SID()))
    local mRes = res["daobiao"]["hunshi"]["attr"][iColor]
    assert(mRes,string.format("hunshi attrdata error %s %s",self:SID(),iColor))
    return mRes
end

function CItem:GetSonAttrData()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    assert(iColor,string.format("hunshi icolorindex error %s",self:SID()))
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    if #mRes.son<0 then
        return 
    end
    local mSonAttr = {}
    for _,iSonColor in pairs(mRes.son)  do
        mSonAttr[iSonColor] = res["daobiao"]["hunshi"]["attr"][iSonColor]
    end
    return mSonAttr
end

function CItem:GetFatherAttrData()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    assert(iColor,string.format("hunshi icolorindex error %s",self:SID()))
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    if #mRes.father<0 then
        return 
    end
    local mFatherAttr = {}
    for _,iFatherColor in pairs(mRes.father)  do
        mFatherAttr[iFatherColor] = res["daobiao"]["hunshi"]["attr"][iFatherColor]
    end
    return mFatherAttr
end

function CItem:GetSonBasicData()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    assert(iColor,string.format("hunshi icolorindex error %s",self:SID()))
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    if #mRes.son<0 then
        return 
    end
    local mSonBasic = {}
    for _,iSonColor in pairs(mRes.son)  do
        mSonBasic[iSonColor] = res["daobiao"]["hunshi"]["color"][iSonColor]
    end
    return mSonBasic
end

function CItem:GetFatherBasicData()
    local iColor = res["daobiao"]["hunshi"]["sid2color"][self:SID()]
    assert(iColor,string.format("hunshi icolorindex error %s",self:SID()))
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    if #mRes.father<0 then
        return 
    end
    local mFatherBasic = {}
    for _,iFatherColor in pairs(mRes.father)  do
        mFatherBasic[iFatherColor] = res["daobiao"]["hunshi"]["color"][iFatherColor]
    end
    return mFatherBasic
end

function CItem:GetComposeRadio()
    local mRes = res["daobiao"]["hunshi"]["ratio"]
    return mRes
end

function CItem:PackItemInfo()
    local mNet = super(CItem).PackItemInfo(self)
    mNet.hunshi_info = self:PackHunShi()
    return mNet
end

function CItem:PackHunShi()
    local mNet = {}
    mNet.grade = self:GetGrade()
    mNet.addattr = self:GetAddAttr()
    return mNet
end

function CItem:IsHunShi()
    return true
end

function CItem:CustomCombineKey()
    local mAddAttr = self:GetAddAttr()
    local mAttrData = self:GetHunShiAttrData()
    local iKey = 0
    for _,sAttr in pairs(mAddAttr) do
        iKey = iKey + mAttrData[sAttr]["attr_key"]
    end
    local iGrade = self:GetGrade()
    iKey = iKey + iGrade*1000
    return iKey
end

function CItem:ValidCombine(oSrcItem)
    if oSrcItem:GetGrade() ~= self:GetGrade() then
        return false
    end
    local tAddAttr1 = self:GetAddAttr()
    local tAddAttr2 = oSrcItem:GetAddAttr()
    if #tAddAttr2 ~=#tAddAttr1 then
        return false
    else
        for _,sAttr in pairs(tAddAttr1) do
            if not extend.Table.find(tAddAttr2,sAttr) then
                return false
            end
        end
    end
    local bResult =  super(CItem).ValidCombine(self,oSrcItem)
    return bResult
end

function CItem:TipsName()
    local res = require "base.res"
    local iColor = self:ItemColor()
    local mItemColor = res["daobiao"]["itemcolor"][iColor]
    assert(iColor, mItemColor, string.format("item color config not exist! id:", iColor))
    local iGrade = self:GetGrade()
    local sName = string.format("%s级%s",iGrade,self:Name())
    return string.format(mItemColor.color, sName)
end

function CItem:Quality(bArrange)
    if not bArrange then
        return super(CItem).Quality(self,bArrange)
    end
    local iGrade = self:GetGrade()
    iGrade = iGrade*10
    if self:IsBind() then
        iGrade = iGrade - 1
    end
    return iGrade
end