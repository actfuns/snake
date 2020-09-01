local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record" 

local fabaoobj = import(service_path("fabao.fabaoobj"))
local skillobj = import(service_path("fabao.skillbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))


function NewFaBaoMgr(...)
    return CFaBaoMgr:New(...)
end

CFaBaoMgr = {}
CFaBaoMgr.__index = CFaBaoMgr
inherit(CFaBaoMgr, logic_base_cls())

function CFaBaoMgr:New()
    local o = super(CFaBaoMgr).New(self)
    o.m_iFaBaoID = 0
    return o
end

function CFaBaoMgr:DispatchId()
    self.m_iFaBaoID = self.m_iFaBaoID + 1
    return self.m_iFaBaoID
end

function CFaBaoMgr:GetSkillConfig(iSk)
    local mData = res["daobiao"]["skill"][iSk]
    return mData
end

function CFaBaoMgr:GetConfigData()
    local mData = res["daobiao"]["fabao"]["config"][1]
    return mData
end

function CFaBaoMgr:GetFaBaoInfo(iFaBao)
    local mData = res["daobiao"]["fabao"]["info"][iFaBao]
    return mData
end

function CFaBaoMgr:GetAllFaBaoInfo()
    local mData = res["daobiao"]["fabao"]["info"]
    return mData
end

function CFaBaoMgr:GetXinLingData()
    local mData = res["daobiao"]["fabao"]["xianling"]
    return mData
end

function CFaBaoMgr:CreateFaBao(iFaBao)
    local oFaBao = fabaoobj.NewFaBao(iFaBao)
    oFaBao:Create()
    return oFaBao
end

function CFaBaoMgr:LoadFaBao(iFaBao, m)
    local oFaBao = fabaoobj.NewFaBao(iFaBao)
    oFaBao:Load(m)
    return oFaBao
end

function CFaBaoMgr:CreateSkill(iSkill)
    local oSkill = skillobj.NewSkill(iSkill)
    return oSkill
end

function CFaBaoMgr:LoadSkill(iSkill, m)
    local oSkill = skillobj.NewSkill(iSkill)
    oSkill:Load(m)
    return oSkill
end

function CFaBaoMgr:GetText(iText,mReplace)
    local sText = global.oToolMgr:GetTextData(iText,{"fabao"})
    if mReplace then
        sText = global.oToolMgr:FormatColorString(sText,mReplace)
    end
    return sText
end

function CFaBaoMgr:LogData(oPlayer, sSubType, mLog)
    mLog = mLog or {}
    mLog = table_combine(mLog, oPlayer:LogData())
    record.log_db("fabao", sSubType, mLog)
end

function CFaBaoMgr:ComBineFaBao(oPlayer,iOp,iFaBao, bFast)
    local oNotifyMgr = global.oNotifyMgr
    local mRes = res["daobiao"]["fabao"]["combine"]
    local pid = oPlayer:GetPid()
    local mCombine = mRes[iOp]
    assert(mCombine ,string.format("combine fabao error1 %s %s %s",pid,iOp,iFaBao))
    local iAmount = mCombine.amount 
    local itemsid = mCombine.itemsid
    assert(iAmount>0,string.format("combine fabao error2 %s %s %s %s",pid,iOp,iFaBao,iAmount))
    if iOp == 2 then
        assert(self:GetFaBaoInfo(iFaBao),string.format("combine fabao error3 %s %s %s",pid,iOp,iFaBao))
    end
    if oPlayer.m_oFaBaoCtrl:IsFull() then
        oNotifyMgr:Notify(pid,self:GetText(1016))
        return 
    end
    if oPlayer.m_oFaBaoCtrl:IsComplete() then
        oNotifyMgr:Notify(pid,self:GetText(1002))
        return 
    end

    local iHasAmount = oPlayer:GetItemAmount(itemsid)
    if not bFast and iHasAmount<iAmount then
        local itemlist = {}
        itemlist[itemsid] = iAmount
        local mExchange,mCopyExchange = global.oToolMgr:PackExchangeData(nil,0,itemlist)
        mCopyExchange.flag = 1
        global.oCbMgr:SetCallBack(pid, "GS2CExecAfterExchange", mCopyExchange, nil, 
        function (oPlayer,mData)
            if mData.answer ==1 then
                global.oFaBaoMgr:ComBineFaBao(oPlayer,iOp,iFaBao,true)
            end
        end)
        return 
    end
    local mAllFaBaoInfo = self:GetAllFaBaoInfo()
    local sReason = string.format("combine_%s",iOp)
    local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item={[itemsid]=iAmount}}, sReason, {cancel_tip = true})
    if not bSucc then return end

    if iOp == 1 then
        local mRatio = {}
        for iFaBao,mInfo in pairs(mAllFaBaoInfo) do
            mRatio[iFaBao] = mInfo.combine_weight
        end
        iFaBao = extend.Random.choosekey(mRatio)
    end
    local fabaoobj = self:CreateFaBao(iFaBao)
    oPlayer.m_oFaBaoCtrl:AddFaBao(fabaoobj,sReason)
    oNotifyMgr:Notify(pid,self:GetText(1027,{fabao=fabaoobj:Name()}))

    self:LogData(oPlayer, "combine_fabao", {
        fabaoid = iFaBao,
        cost = {sid=itemsid,amount=iAmount}
    })

    analylog.LogSystemInfo(oPlayer, "combine_faobao", iFaBao, {[itemsid]=iAmount})
end

function CFaBaoMgr:WieldFaBao(oPlayer,iFaBaoID)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj1 = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj1 then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    if fabaoobj1:EquipPos()>0 then
        oNotifyMgr:Notify(pid,self:GetText(1021))
        return 
    end
    local fabaoobj2 = oPlayer.m_oFaBaoCtrl:GetSameTypeFaBao(fabaoobj1:Fid())
    local mNet = {}
    if fabaoobj2 then
        local iEquipPos = fabaoobj2:EquipPos()
        fabaoobj2:UnWield(oPlayer)
        fabaoobj1:Wield(oPlayer,iEquipPos)
    else
        local iEquipPos = oPlayer.m_oFaBaoCtrl:GetEquipPos(oPlayer)
        if not iEquipPos then
            oNotifyMgr:Notify(pid,self:GetText(1003))
            return 
        end
        fabaoobj1:Wield(oPlayer,iEquipPos)
    end
    local mNet = {}
    mNet.wield_id = iFaBaoID
    mNet.equippos = fabaoobj1:EquipPos()
    if fabaoobj2 then
        mNet.unwield_id = fabaoobj2:ID()
    end
    oPlayer:MarkGrow(57)
    oPlayer:Send("GS2CWieldFaBao",mNet)
    oPlayer:RefreshPropAll()
end

function CFaBaoMgr:UnWieldFaBao(oPlayer,iFaBaoID)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    fabaoobj:UnWield(oPlayer)
    local mNet={}
    mNet.unwield_id = iFaBaoID
    oPlayer:Send("GS2CUnWieldFaBao",mNet)
    oPlayer:RefreshPropAll()
end

function CFaBaoMgr:DeComposeFaBao(oPlayer,iFaBaoID)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    if fabaoobj:EquipPos()>0 then
        oNotifyMgr:Notify(pid,self:GetText(1019))
        return 
    end
    local mRes = res["daobiao"]["fabao"]["decompose"]
    local iLevel = fabaoobj:Level()
    local mDeCompose = mRes[iLevel]
    assert(mDeCompose,string.format("decompose fabao %s",iLevel))
    local itemsid = mDeCompose.itemsid 
    local iAmount = mDeCompose.amount 
    local itemlist = {}
    itemlist[itemsid] = iAmount
    local sTips = self:GetText(1018)
    if not oPlayer:ValidGive(itemlist,{tip = sTips}) then
        return 
    end
    local sReason = "法宝分解"
    oPlayer.m_oFaBaoCtrl:RemoveFaBao(iFaBaoID,sReason)
    oPlayer:GiveItem(itemlist,sReason)
    oNotifyMgr:Notify(pid,self:GetText(1020))

    self:LogData(oPlayer, "decombine_fabao", {
        fabaoid = iFaBaoID,
        reward = {sid=itemsid,amount=iAmount}
    })
end

function CFaBaoMgr:UpGradeFaBao(oPlayer,iFaBaoID,bFast)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    local iPreLevel = fabaoobj:Level()
    local iPreExp = fabaoobj:Exp()
    local iGrade = oPlayer:GetGrade()
    local iLimitLevel = 0
    local mRes = res["daobiao"]["fabao"]["upgrade"]
    local lLevel = table_key_list(mRes)
    table.sort(lLevel)
    for  _ ,iLevel in ipairs(lLevel) do
        if mRes[iLevel]["playergrade"]> iGrade then
            break
        else
            iLimitLevel = iLevel
        end
    end
    if iPreLevel>=iLimitLevel then
        oNotifyMgr:Notify(pid,self:GetText(1006))
        return 
    end
    local iNextLevel = iPreLevel + 1
    local iNextExp = mRes[iNextLevel]["exp"]
    local mCost = {}
    if iPreExp<iNextExp then
        local iNeedExp = iNextExp - iPreExp
        local iSPSid = 10155
        local iJHSid = 10156
        local iSPAmount = oPlayer:GetItemAmount(iSPSid)
        local iJHAmount = oPlayer:GetItemAmount(iJHSid)
        local SPObj = global.oItemLoader:GetItem(iSPSid)
        local JHObj = global.oItemLoader:GetItem(iJHSid)
        local iSPExp = SPObj:CalItemFormula(oPlayer)
        local iJHExp = JHObj:CalItemFormula(oPlayer)

        if not bFast and iSPAmount ==0 and iJHAmount == 0 then
            local iNeedSPAmount  = math.ceil(iNeedExp/iSPExp)
            local itemlist = {}
            itemlist[iSPSid] = iNeedSPAmount
            local mExchange,mCopyExchange = global.oToolMgr:PackExchangeData(nil,0,itemlist)
            mCopyExchange.flag = 1
            global.oCbMgr:SetCallBack(pid, "GS2CExecAfterExchange", mCopyExchange, nil, 
            function (oPlayer,mData)
                if mData.answer ==1 then
                    global.oFaBaoMgr:UpGradeFaBao(oPlayer,iFaBaoID,true)
                end
            end)
            return
        end

        if iSPAmount ==0 and iJHAmount == 0 then
            iSPAmount = math.ceil(iNeedExp/iSPExp)
        end
        local iAllExp = iSPAmount* iSPExp + iJHAmount*iJHExp
        local sReason = "法宝升级"
        if iAllExp<= iNeedExp then
            if iSPAmount > 0 then
                mCost[iSPSid] = iSPAmount
                -- oPlayer:RemoveItemAmount(iSPSid,iSPAmount,"法宝升级")
            end
            if iJHAmount > 0 then
                mCost[iJHSid] = iJHAmount
                -- oPlayer:RemoveItemAmount(iJHSid,iJHAmount,"法宝升级")
            end
            local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCost}, sReason, {cancel_tip = true})
            if not bSucc then return end

            fabaoobj:SetExp(iAllExp+iPreExp)
            oNotifyMgr:Notify(pid,self:GetText(1007,{exp = iAllExp}))
        else
            local iAddExp = 0
            if iSPAmount*iSPExp >= iNeedExp then
                mCost[iSPSid] = math.ceil(iNeedExp/iSPExp)
                iAddExp = mCost[iSPSid] * iSPExp
            else
                local iNeedExp2 = iNeedExp
                if iSPAmount>0 then
                    mCost[iSPSid] = iSPAmount
                    iNeedExp2 =  iNeedExp - iSPAmount*iSPExp
                    iAddExp = iSPAmount*iSPExp
                end
                mCost[iJHSid] = math.ceil(iNeedExp2/iJHExp)
                iAddExp = iAddExp + mCost[iJHSid]*iJHExp
            end
            local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCost}, sReason, {cancel_tip = true})
            if not bSucc then return end

            fabaoobj:SetExp(iPreExp + iAddExp)
        end
    end
    iPreExp = fabaoobj:Exp()
    if iPreExp>=iNextExp then
        fabaoobj:SetLevel(iNextLevel)
        fabaoobj:SetExp(iPreExp-iNextExp)
        fabaoobj:AddXianLing(mRes[iNextLevel]["xianling"])
        oNotifyMgr:Notify(pid,self:GetText(1008,{level= fabaoobj:Level(),fabao=fabaoobj:Name()}))
    end
    oPlayer.m_oFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)
    global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
    oPlayer:PropChange("score")

    self:LogData(oPlayer, "upgrade_fabao", {
        fabaoid = iFaBaoID,
        pre_exp = iPreExp,
        pre_level = iPreLevel,
        now_exp = fabaoobj:Exp(),
        now_level = fabaoobj:Level(),
        cost = mCost
    })

    analylog.LogSystemInfo(oPlayer, "upgrade_faobao", iFaBaoID, mCost)
end

function CFaBaoMgr:XianLingFaBao(oPlayer,iFaBaoID,iOp,sAttr)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    local mRes = res["daobiao"]["fabao"]["xianling"]
    local mXianLing = mRes[sAttr]
    if not mXianLing  then
        return 
    end
    local iCurPromote = fabaoobj:GetPromote(sAttr)
    local mResume = mXianLing.resume
    local iXianLing = fabaoobj:GetXianLing()
    if iOp == 1 then
        local iNextPromoteIndex = iCurPromote + 1
        if iNextPromoteIndex>table_count(mResume) then
            iNextPromoteIndex = table_count(mResume)
        end
        mResume = mResume[iNextPromoteIndex]
        if iXianLing< mResume.xianling then
            oNotifyMgr:Notify(pid,self:GetText(1009))
            return 
        end
        fabaoobj:AddXianLing(-mResume.xianling)
        fabaoobj:AddPromote(sAttr,oPlayer)
        oPlayer.m_oFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)
        global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
        oPlayer:RefreshPropAll()
    elseif iOp ==2 then
        if iCurPromote<=0 then
            return 
        end
        local iPromoteIndex = iCurPromote
        if iPromoteIndex>table_count(mResume) then
            iPromoteIndex = table_count(mResume)
        end
        mResume = mResume[iPromoteIndex]
        local iNeedValue = mResume.gold 
        assert(iNeedValue>0,"fabao xianling reset gold")
        if not oPlayer:ValidSilver(iNeedValue) then
            return 
        end
        oPlayer:ResumeSilver(iNeedValue,"重置法宝属性")
        fabaoobj:AddXianLing(mResume.xianling)
        fabaoobj:RemovePromote(sAttr,oPlayer)
        oPlayer.m_oFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)
        global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
        oPlayer:RefreshPropAll()
        oNotifyMgr:Notify(pid,self:GetText(1028,{silver=iNeedValue}))

        analylog.LogSystemInfo(oPlayer, "reset_attr_faobao", iFaBaoID, {[gamedefines.MONEY_TYPE.SILVER]=iNeedValue})
    end

    self:LogData(oPlayer, "xianling_fabao", {
        fabaoid = iFaBaoID,
        cost = mResume
    })
end

function CFaBaoMgr:JueXingFaBao(oPlayer,iFaBaoID,bFast)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    local jxskill = fabaoobj:GetJXSkill()
    if jxskill:IsOpen() then
        oNotifyMgr:Notify(pid,self:GetText(1022))
        return 
    end
    local mFaBaoInfo = fabaoobj:GetFaBaoInfo()

    local iNeedGrade = mFaBaoInfo["juexing_open"]
    if fabaoobj:Level()<iNeedGrade then
        oNotifyMgr:Notify(pid,self:GetText(1011,{fabao = fabaoobj:Name(),grade = iNeedGrade}))
        return 
    end
    local mResume = mFaBaoInfo["juexing_resume"]
    local iResumeGold = mFaBaoInfo["juexing_resume_gold"]
    local needlist, mCost = {}, {}
    for _,mSubResume in pairs(mResume) do
        local itemsid = mSubResume.itemsid 
        local iNeedAmount = mSubResume.amount
        local iHasAmount = oPlayer:GetItemAmount(itemsid)
        mCost[itemsid] = iNeedAmount
        if iHasAmount<iNeedAmount then
            needlist[itemsid] = iNeedAmount - iHasAmount
        end
    end
    local iHasGold = oPlayer:GetGold()
    local iNeedGold = 0
    if iHasGold<iResumeGold then
        iNeedGold = iResumeGold - iHasGold
    end
    if not bFast and (next(needlist) or iNeedGold>0) then
        local sMoney = gamedefines.MONEY_TYPE.GOLD
        local mExchange,mCopyExchange = global.oToolMgr:PackExchangeData(sMoney,iResumeGold,mCost)
        mCopyExchange.flag = 1
        global.oCbMgr:SetCallBack(pid, "GS2CExecAfterExchange", mCopyExchange, nil, 
        function (oPlayer,mData)
            if mData.answer ==1 then
                global.oFaBaoMgr:JueXingFaBao(oPlayer,iFaBaoID,true)
            end
        end)
        return 
    end
    local sReason = "法宝觉醒开启"
    local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCost,gold=iResumeGold}, sReason, {cancel_tip = true})
    if not bSucc then return end

    jxskill:Open()
    jxskill:SetLevel(1)
    if fabaoobj:EquipPos()>0 then
        jxskill:SkillUnEffect(oPlayer)
        jxskill:SkillEffect(oPlayer)
    end
    global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
    oPlayer:PropChange("score")
    oPlayer.m_oFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)

    self:LogData(oPlayer, "juexing_fabao", {
        fabaoid = iFaBaoID,
        cost = mCost,
    })

    analylog.LogSystemInfo(oPlayer, "juexing_faobao", iFaBaoID, mCost)
end

function CFaBaoMgr:JueXingUpGradeFaBao(oPlayer,iFaBaoID,bFast)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    local jxskill = fabaoobj:GetJXSkill()
    if not jxskill:IsOpen() then
        oNotifyMgr:Notify(pid,self:GetText(1023))
        return 
    end
    local iPreLevel = jxskill:Level()
    local iPreExp = jxskill:Exp()
    local mJXUpgradeData = res["daobiao"]["fabao"]["juexing_upgrade"]
    local mHunData = res["daobiao"]["fabao"]["hun"]
    local lKey = table_key_list(mJXUpgradeData)
    table.sort(lKey)
    if iPreLevel>=lKey[#lKey] then
        oNotifyMgr:Notify(pid,self:GetText(1024))
        return 
    end
    local iNextLevel = iPreLevel +1 
    local mNextLevelData = mJXUpgradeData[iNextLevel]
    local iNextExp = mNextLevelData["exp"]
    local iHun = mJXUpgradeData[iPreLevel] and mJXUpgradeData[iPreLevel].hun
    local mCost = {}
    if iHun and mHunData[iHun] then
        local sFunc = mHunData[iHun]["func"]
        local func = fabaoobj[sFunc]
        local lSkill = func(fabaoobj)
        if iHun == 3 then
            for _, skobj in ipairs(lSkill) do
                if not skobj:IsOpen()  then
                    oNotifyMgr:Notify(pid,self:GetText(1025,{hun = mHunData[iHun]["name"]}))
                    return 
                end
            end
        else
            if not lSkill:IsOpen()  then
                oNotifyMgr:Notify(pid,self:GetText(1025,{hun = mHunData[iHun]["name"]}))
                return 
            end
        end
    end
    if iPreExp<iNextExp then
        local iNeedExp = iNextExp - iPreExp
        local iSPSid = 10155
        local iJHSid = 10156
        local iZLSid = 10157
        -- local iSPAmount = oPlayer:GetItemAmount(iSPSid)
        -- local iJHAmount = oPlayer:GetItemAmount(iJHSid)
        local iZLAmount = oPlayer:GetItemAmount(iZLSid)
        -- local SPObj = global.oItemLoader:GetItem(iSPSid)
        -- local JHObj = global.oItemLoader:GetItem(iJHSid)
        local ZLObj = global.oItemLoader:GetItem(iZLSid)
        -- local iSPExp = SPObj:CalItemFormula(oPlayer)
        -- local iJHExp = JHObj:CalItemFormula(oPlayer)
        local iZLExp =  ZLObj:CalItemFormula(oPlayer)

        --if iSPAmount ==0 and iJHAmount == 0 and iZLAmount == 0 then
        local iNeedSPAmount  = math.ceil(iNeedExp/iZLExp)
        if not bFast and iZLAmount < iNeedSPAmount then
            local itemlist = {}
            itemlist[iZLSid] = iNeedSPAmount
            local mExchange,mCopyExchange = global.oToolMgr:PackExchangeData(nil,0,itemlist)
            mCopyExchange.flag = 1
            global.oCbMgr:SetCallBack(pid, "GS2CExecAfterExchange", mCopyExchange, nil, 
            function (oPlayer,mData)
                if mData.answer ==1 then
                    global.oFaBaoMgr:JueXingUpGradeFaBao(oPlayer,iFaBaoID,true)
                end
            end)
            return
        end

        local iAllExp = iNeedSPAmount*iZLExp
        local sReason = "觉醒升级"
        if iAllExp<= iNeedExp then
            mCost[iZLSid] = iNeedSPAmount
            local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCost}, sReason, {cancel_tip = true})
            if not bSucc then return end

            jxskill:SetExp(iAllExp+iPreExp)
            oNotifyMgr:Notify(pid,self:GetText(1013,{exp = iAllExp}))
        else
            mCost[iZLSid] = iNeedSPAmount
            local iAddExp = iNeedSPAmount * iZLExp
            local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCost}, sReason, {cancel_tip = true})
            if not bSucc then return end

            jxskill:SetExp(iPreExp + iAddExp)
        end
    end
    iPreExp = jxskill:Exp()
    if iPreExp>=iNextExp then
        jxskill:SetLevel(iNextLevel)
        jxskill:SetExp(iPreExp-iNextExp)
        if fabaoobj:EquipPos()>0 then
            jxskill:SkillUnEffect(oPlayer)
            jxskill:SkillEffect(oPlayer)
        end
        oNotifyMgr:Notify(pid,self:GetText(1014,{level= jxskill:Level(),skill=jxskill:Name()}))
    end
    global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
    oPlayer:PropChange("score")
    oPlayer.m_oFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)

    self:LogData(oPlayer, "jx_upgrade_fabao", {
        fabaoid = iFaBaoID,
        pre_exp = iPreExp,
        pre_level = iPreLevel,
        now_exp = fabaoobj:Exp(),
        now_level = fabaoobj:Level(),
        cost = mCost
    })

    analylog.LogSystemInfo(oPlayer, "jx_upgrade_fabao", iFaBaoID, mCost)
end

function CFaBaoMgr:JueXingHunFaBao(oPlayer,iFaBaoID,iHun,bFast)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local fabaoobj = oPlayer.m_oFaBaoCtrl:GetFaBao(iFaBaoID)
    if not fabaoobj then
        oNotifyMgr:Notify(pid,self:GetText(1017))
        return 
    end
    local mHunData = res["daobiao"]["fabao"]["hun"]
    if not mHunData[iHun] then
        return 
    end
    local mResume = mHunData[iHun]["resume"]
    local sFunc = mHunData[iHun]["func"]
    local func = fabaoobj[sFunc]
    local lSkill = func(fabaoobj)
    if iHun == 1 or iHun == 2 then
        if lSkill:IsOpen() then
            oNotifyMgr:Notify(pid,self:GetText(1026,{hun = mHunData[iHun]["name"]}))
            return 
        end
    else
        for _, skobj in ipairs(lSkill) do
            if skobj:IsOpen() then
                oNotifyMgr:Notify(pid,self:GetText(1026,{hun = mHunData[iHun]["name"]}))
                return 
            end
        end
    end
    local itemsid = mResume[1]["itemsid"]
    local iNeedAmount = mResume[1]["amount"]
    local iHasAmount = oPlayer:GetItemAmount(itemsid)
    if not bFast and iHasAmount<iNeedAmount then
        local itemlist = {}
        itemlist[itemsid] = iNeedAmount
        local mExchange,mCopyExchange = global.oToolMgr:PackExchangeData(nil,0,itemlist)
        mCopyExchange.flag = 1
        global.oCbMgr:SetCallBack(pid, "GS2CExecAfterExchange", mCopyExchange, nil, 
        function (oPlayer,mData)
            if mData.answer ==1 then
                global.oFaBaoMgr:JueXingHunFaBao(oPlayer,iFaBaoID,iHun,true)
            end
        end)
        return 
    end
    local sReason = "法宝魂开启"
    local mCost = {}
    mCost[itemsid] = iNeedAmount
    local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCost}, sReason, {cancel_tip = true})
    if not bSucc then return end

    if iHun == 1 or iHun == 2 then
        lSkill:Open()

        if fabaoobj:EquipPos()>0 then
            lSkill:SkillUnEffect(oPlayer)
            lSkill:SkillEffect(oPlayer)
        end
    else
        for _, skobj in ipairs(lSkill) do
            skobj:Open()
            if fabaoobj:EquipPos()>0 then
                skobj:SkillUnEffect(oPlayer)
                skobj:SkillEffect(oPlayer)
            end
        end
    end
    global.oScoreCache:Dirty(oPlayer:GetPid(), "fabaoctrl")
    oPlayer:PropChange("score")
    oPlayer.m_oFaBaoCtrl:GS2CRefreshFaBao(fabaoobj)

    self:LogData(oPlayer, "jx_hun_fabao", {
        fabaoid = iFaBaoID,
        cost = mCost
    })

    analylog.LogSystemInfo(oPlayer, "jx_hun_fabao", iFaBaoID, mCost)
end
