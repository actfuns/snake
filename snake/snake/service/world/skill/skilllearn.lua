--import module

local global = require "global"
local record = require "public.record"

local loadskill = import(service_path("skill/loadskill"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

ERR_FASTLEARN_LIMITLV = 1
ERR_FASTLEARN_GRADE = 2
ERR_FASTLEARN_SILVER = 3
ERR_FASTLEARN_UNOPEN = 4

CSkillLearn = {}
CSkillLearn.__index = CSkillLearn
inherit(CSkillLearn,logic_base_cls())

function CSkillLearn:New()
    local o = super(CSkillLearn).New(self)
    return o
end

function CSkillLearn:ValidLearn(oPlayer)
end

function CSkillLearn:Learn(oPlayer)
end

function CSkillLearn:FastLearn(oPlayer)
end

function CSkillLearn:GetTextData(iText, mReplace)
    return global.oToolMgr:GetSystemText({"text"}, iText, mReplace)
end

function CSkillLearn:RecordLearnSkillLog(oPlayer, sLogType, iSk, sType, iOldLv, iNowLv, iAddLv, iSilver, iPoint, iGoldCoin)
    local mLog = oPlayer:LogData()
    mLog["skid"] = iSk
    mLog["sktype"] = sType
    mLog["level_old"] = iOldLv
    mLog["level_now"] = iNowLv
    mLog["add_level"] = iAddLv
    mLog["silver_cost"] = iSilver
    mLog["point_cost"] = iPoint
    mLog["goldcoin"] = iGoldCoin
    record.log_db("playerskill", sLogType, mLog)
end


CPassiveSkillLearn = {}
CPassiveSkillLearn.__index = CPassiveSkillLearn
inherit(CPassiveSkillLearn,CSkillLearn)

function CPassiveSkillLearn:New()
    local o = super(CPassiveSkillLearn).New(self)
    return o
end

function CPassiveSkillLearn:ValidLearn(oPlayer,iSk,bNotify)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return false
    end
    local iOpenLevel = oSk:OpenLevel()
    if iOpenLevel > oPlayer:GetGrade() then
        oNotifyMgr:Notify(pid, self:GetTextData(2020, {level=iOpenLevel}))
        return false
    end
    local iLevel = oSk:Level()
    if iLevel >= oPlayer:GetGrade()  then
        oNotifyMgr:Notify(pid, self:GetTextData(2021))
        return false
    end
    if iLevel >= oSk:LimitLevel(oPlayer) then
        oNotifyMgr:Notify(pid, self:GetTextData(2022))
        return
    end
    local iSilver = oSk:LearnNeedCost()
    if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then
        return false
    end
    return true
end

function CPassiveSkillLearn:Learn(oPlayer,iSk)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    if not self:ValidLearn(oPlayer,iSk) then
        return
    end
    local mSchoolSkill = loadskill.GetSchoolSkill(oPlayer:GetSchool())
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return
    end
    local iSilver = oSk:LearnNeedCost()
    if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then
        return
    end
    oPlayer.m_oActiveCtrl:ResumeSilver(iSilver,"学习门派技能")
    local iLevel = oSk:Level()
    local iNewLevel = iLevel + 1
    oPlayer.m_oSkillCtrl:SetLevel(iSk,iNewLevel,true)
    local sMsg = self:GetTextData(2023, {name = oSk:Name(),level = oSk:Level()})
    oNotifyMgr:Notify(pid,sMsg)
    oPlayer:MarkGrow(3)
    oPlayer.m_oSkillCtrl:FireLearnPassiveSkill(oSk, iNewLevel, iLevel)

    analylog.LogSystemInfo(oPlayer, "learn_school_passive", iSk, {[gamedefines.MONEY_TYPE.SILVER]=iSilver})
    self:RecordLearnSkillLog(oPlayer, "learn_skill", iSk, "passive", iLevel, iNewLevel, 1, iSilver, 0, 0)
end

function CPassiveSkillLearn:GetValidSkill(oPlayer)
    local iSchool = oPlayer:GetSchool()
    local mPassiveSkill = loadskill.GetPassiveSkill(iSchool)
    local oSkillCtrl = oPlayer.m_oSkillCtrl
    local iPlayerGrade = oPlayer:GetGrade()
    local lRetValidSkill = {}
    for _, iSk in pairs(mPassiveSkill) do
        local oSk = oSkillCtrl:GetSkill(iSk)
        if oSk and oSk:OpenLevel() <= iPlayerGrade and oSk:Level() < iPlayerGrade then
            table.insert(lRetValidSkill, oSk)
        end
    end
    return lRetValidSkill
end

function CPassiveSkillLearn:SortValidSkillByLevel(lValidSkill)
    local function Comp(oSkill1, oSkill2)
        return oSkill1:Level() < oSkill2:Level()
    end
    table.sort(lValidSkill, Comp)
    return lValidSkill
end

function CPassiveSkillLearn:SortLearnSkillByOpenLevel(lLearnSkill)
    local function Comp(oSkill1, oSkill2)
        return oSkill1:OpenLevel() < oSkill2:OpenLevel()
    end
    table.sort(lLearnSkill,Comp)
    return lLearnSkill
end

function CPassiveSkillLearn:_ValidLearnLevel(oPlayer,mLearnArgs)
    local oSk = mLearnArgs.skill
    local iCount = mLearnArgs.count
    local iMaxCount = 0
    local iLevelCost = 0
    local iTotalCost = mLearnArgs.total_cost
    local iMaxLearnLevel = mLearnArgs.start_level
    local iAllMaxLearnLevel = iMaxLearnLevel - 1
    local iErr = nil
    for iLevel = mLearnArgs.start_level, mLearnArgs.end_level do
         iLevelCost = oSk:LearnNeedCost(iLevel)
         iTotalCost = iTotalCost + iLevelCost * iCount
         if not oPlayer.m_oActiveCtrl:ValidSilver(iTotalCost, {cancel_tip = true}) then
            local iValidTotalCost = iTotalCost - iLevelCost * iCount
            for iMax = 1, iCount do
                if oPlayer.m_oActiveCtrl:ValidSilver(iValidTotalCost + iLevelCost * iMax, {cancel_tip = true}) then
                    iMaxCount = iMax
                    iMaxLearnLevel = iLevel
                else
                    break
                end
            end
            iErr = ERR_FASTLEARN_SILVER
            break
        end
        iMaxLearnLevel = iLevel
        iAllMaxLearnLevel = iMaxLearnLevel
    end
    local mRet = {}
    mRet.max_learnlevel = iMaxLearnLevel
    mRet.all_max_learnlevel = iAllMaxLearnLevel
    mRet.error = iErr
    mRet.max_learncount = iMaxCount
    mRet.total_cost = iTotalCost
    return mRet
end

function CPassiveSkillLearn:LearnSkillInTurn(oPlayer, lSortSkill)
    if #lSortSkill  <= 0 then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(2021))
        return
    end
    local iHigher = 1     --次低等级的哨兵
    local iHigherLevel = lSortSkill[iHigher]:Level()
    local iMaxLearnLevel = iHigherLevel
    local iLearnCount = 0
    local iAllMaxLearnLevel = iHigherLevel
    local iMaxLearnCount = 0
    local iPerTotalCost = 0
    local iErr = nil
    local bSuccess
    local iLength = #lSortSkill

    for  iNextTurn = 1, iLength do
        local iOldHigher = iHigher
        for index = iHigher + 1, iLength do
            if lSortSkill[index]:Level() > iHigherLevel then
                iHigherLevel = lSortSkill[index]:Level()
                iHigher = index
                iLearnCount = iHigher - 1
                break
            end
        end
        local  mLearnArgs = {
                start_level = lSortSkill[iOldHigher]:Level() + 1,        -- 获得上一次升级到的等级
                skill = lSortSkill[1],
                total_cost = iPerTotalCost,             -- 前几次计算升级的花费
            }
        if iOldHigher == iHigher then
            -- 所有技能等级可达到最高等级技能的等级，可能学习到的最高等级为玩家等级
            mLearnArgs.end_level = oPlayer:GetGrade()
            mLearnArgs.count = iLength
            iLearnCount = iLength
        else
            mLearnArgs.end_level = lSortSkill[iHigher]:Level()
            mLearnArgs.count = iLearnCount
        end
        local mRet = self:_ValidLearnLevel(oPlayer, mLearnArgs)
        iPerTotalCost = mRet.total_cost
        iMaxLearnLevel = mRet.max_learnlevel
        iAllMaxLearnLevel = mRet.all_max_learnlevel
        iMaxLearnCount = mRet.max_learncount
        iErr = mRet.error
        if iOldHigher == iHigher then
            break
        end
        if iErr and iErr == ERR_FASTLEARN_SILVER then
            break
        end
        -- 计算下一轮是否可以学到更高等级
        iNextTurn = iHigher
    end
    -- 拷贝可以学习的技能
    local lLearnSkill = {}
    for index = 1, iLearnCount do
        table.insert(lLearnSkill, lSortSkill[index])
    end
    -- 按开放等级排序
    lSortSkill = nil
    self:SortLearnSkillByOpenLevel(lLearnSkill)
    for index = 1, iMaxLearnCount do
        local iSk = lLearnSkill[index]:ID()
        local iLevel = lLearnSkill[index]:Level()
        if iLevel < iMaxLearnLevel then
            local rRet = self:FastLearnSkill(oPlayer, iSk, iMaxLearnLevel)
            if not rRet then
                bSuccess = true
            elseif not iErr or iErr < rRet then
                iErr = rRet
            end
        end
    end

-- 当时把FastLearnSkill 相当于写入 这里（减少计算钱的循环，最后节约时间不到1ms秒）
    for index  =  iMaxLearnCount + 1, iLearnCount do
        local iSk = lLearnSkill[index]:ID()
        local iLevel = lLearnSkill[index]:Level()
        if iLevel  < iAllMaxLearnLevel then
            local rRet = self:FastLearnSkill(oPlayer,iSk, iAllMaxLearnLevel)
            if not rRet then
                bSuccess = true
            elseif not iErr or iErr < rRet then
                iErr = rRet
            end
        end
    end

    if not bSuccess then
        local oNotifyMgr = global.oNotifyMgr
        local pid = oPlayer:GetPid()
        if iErr == ERR_FASTLEARN_GRADE then
            oNotifyMgr:Notify(pid, self:GetTextData(2021))
        elseif iErr == ERR_FASTLEARN_LIMITLV then
            oNotifyMgr:Notify(pid, self:GetTextData(2022))
        elseif iErr == ERR_FASTLEARN_SILVER then
            oNotifyMgr:Notify(pid, self:GetTextData(2024))
        elseif iErr == ERR_FASTLEARN_UNOPEN then
            oNotifyMgr:Notify(pid, self:GetTextData(2025))
        end
    else
        oPlayer:MarkGrow(3)
    end
end

function CPassiveSkillLearn:FastLearn(oPlayer)
    local lRetValidSkill = self:GetValidSkill(oPlayer)
    self:SortValidSkillByLevel(lRetValidSkill)
    self:LearnSkillInTurn(oPlayer,lRetValidSkill)
end

function CPassiveSkillLearn:ValidFastLearn(oPlayer,oSk,iLevel)
    local pid = oPlayer.m_iPid
    if iLevel > oPlayer:GetGrade()  then
        return ERR_FASTLEARN_GRADE
    end
    if iLevel > oSk:LimitLevel(oPlayer) then
        return ERR_FASTLEARN_LIMITLV
    end
    if oSk:OpenLevel() > oPlayer:GetGrade() then
        return ERR_FASTLEARN_UNOPEN
    end
    return
end

function CPassiveSkillLearn:FastLearnSkill(oPlayer,iSk,iMaxLevel)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return
    end
    local iNowLevel = oSk:Level()
    if iNowLevel >= iMaxLevel then
        return ERR_FASTLEARN_LIMITLV
    end
    local mArgs = {
        cancel_tip = 1
    }
    local iLearnLevel
    local iTotal = 0
    local iErr
    for iLevel=iNowLevel+1,iMaxLevel do
        iErr = self:ValidFastLearn(oPlayer,oSk,iLevel)
        if iErr then
            break
        end
        local iSilver = oSk:LearnNeedCost(iLevel)
        if not oPlayer.m_oActiveCtrl:ValidSilver(iTotal + iSilver,mArgs) then
            iErr = ERR_FASTLEARN_SILVER
            break
        end
        iTotal = iTotal + iSilver
        iLearnLevel = iLevel
    end

    if not iLearnLevel then
        return iErr
    end
    if not oPlayer.m_oActiveCtrl:ValidSilver(iTotal) then
        return ERR_FASTLEARN_SILVER
    end
    oPlayer.m_oActiveCtrl:ResumeSilver(iTotal,"快速学习门派技能")
    oPlayer.m_oSkillCtrl:SetLevel(iSk,iLearnLevel)
    oSk:SkillUnEffect(oPlayer)
    oPlayer.m_oSkillCtrl:GS2CRefreshSkill(oSk)
    oSk:SkillEffect(oPlayer)
    local sMsg = self:GetTextData(2023, {name = oSk:Name(),level = oSk:Level()})
    oNotifyMgr:Notify(pid,sMsg)

    analylog.LogSystemInfo(oPlayer, "fast_school_passive", iSk, {[gamedefines.MONEY_TYPE.SILVER]=iTotal})
    local iAddLevel = iLearnLevel - iNowLevel 
    self:RecordLearnSkillLog(oPlayer, "fast_learn_skill", iSk, "passive", iNowLevel, iLearnLevel, iAddLevel, iTotal, 0, 0)

    oPlayer.m_oSkillCtrl:FireLearnPassiveSkill(oSk, iLearnLevel, iNowLevel)
end


CActiveSkillLearn = {}
CActiveSkillLearn.__index = CActiveSkillLearn
inherit(CActiveSkillLearn,CSkillLearn)

function CActiveSkillLearn:New()
    local o = super(CActiveSkillLearn).New(self)
    return o
end

function CActiveSkillLearn:ValidLearn(oPlayer,iSk)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return false
    end

    local iLevel = oSk:Level()
    if iLevel >= oPlayer:GetGrade() then
        oNotifyMgr:Notify(pid, self:GetTextData(2026))
        return false
    end
    local iTopLevel = oSk:LimitLevel(oPlayer)
    if iLevel >= iTopLevel then
        oNotifyMgr:Notify(pid, self:GetTextData(2027))
        return false
    end
    local iGradeLimit = oSk:GetGradeLimit()
    if not iGradeLimit then return false end

    if oPlayer:GetGrade() < iGradeLimit then
        oNotifyMgr:Notify(pid, self:GetTextData(2028, {level=iGradeLimit}))
        return false
    end
    -- 添加快捷购买银币判断和道具判断移到 Learn 函数
    return true
end

function CActiveSkillLearn:Learn(oPlayer,iSk,iFlag)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local pid = oPlayer.m_iPid
    if not self:ValidLearn(oPlayer,iSk) then
        return
    end
    local mActiveSkill = loadskill.GetActiveSkill(oPlayer:GetSchool())
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return
    end
    local iSilver = oSk:LearnCostSilver()
    local iSid = 10167
    local iPoint = oSk:LearnCostSkillPoint()
    local sReason
    local iGoldCoin = 0
    if iFlag and iFlag > 0 then
        sReason = "快捷学习门派主动技能"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        mNeedCost["item"][iSid] = iPoint
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        -- 用于记录日志
        iGoldCoin = mTrueCost["goldcoin"] or 0
        iSilver = mTrueCost["silver"] or 0
        iPoint = mTrueCost["item"][iSid] or 0
    else
        sReason = "学习门派主动技能"
        if iSilver > 0  then
            if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then return end
        end
        if iPoint > 0 then
            if  oPlayer:GetItemAmount(iSid) < iPoint then
                global.oNotifyMgr:Notify(pid, self:GetTextData(2029))
                return
            end
        end

        if iSilver > 0 then
            oPlayer.m_oActiveCtrl:ResumeSilver(iSilver, sReason)
        end
        if iPoint > 0 then
            oPlayer:RemoveItemAmount(iSid, iPoint, sReason)
        end
    end
    local iLevel = oSk:Level()
    local iNewLevel = iLevel + 1
    oPlayer.m_oSkillCtrl:SetLevel(iSk,iNewLevel,true)
    local sMsg = self:GetTextData(2031, {name = oSk:Name(),level = oSk:Level()})
    oNotifyMgr:Notify(pid,sMsg)

    local mAnaly = {
        [gamedefines.MONEY_TYPE.SILVER]=iSilver,
        [1020]=iPoint,
        [gamedefines.MONEY_TYPE.GOLDCOIN] = iGoldCoin
    }
    analylog.LogSystemInfo(oPlayer, "learn_school_active", iSk, mAnaly)
    self:RecordLearnSkillLog(oPlayer, "learn_skill", iSk, "acitve", iLevel, iNewLevel, 1, iSilver, iPoint, iGoldCoin)

    oPlayer.m_oSkillCtrl:FireLearnActiveSkill(oSk, iNewLevel, iLevel)
    if iNewLevel==2 then
        oPlayer:MarkGrow(9)
    end
end

function CActiveSkillLearn:FastLearn(oPlayer)
    local iMaxLevel = oPlayer:GetGrade()
    local iSchool = oPlayer:GetSchool()
    local mActiveSkill = loadskill.GetActiveSkill(iSchool)
    if not mActiveSkill or #mActiveSkill <= 0 then
        return
    end
    for _,iSk in pairs(mActiveSkill) do
        local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
        if oSk then
            self:FastLearnSkill(oPlayer,iSk,iMaxLevel)
        end
    end
end

function CActiveSkillLearn:ValidFastLearn(oPlayer,oSk,iLevel)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    if iLevel >= oPlayer:GetGrade() then
        return false
    end
    local iTopLevel = oSk:LimitLevel(oPlayer)
    if iLevel >= iTopLevel then
        return false
    end
    return true
end

function CActiveSkillLearn:FastLearnSkill(oPlayer,iSk,iMaxLevel)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk then
        return
    end
    local iNowLevel = oSk:Level()

    if iNowLevel >= iMaxLevel then
        return
    end
    local iLearnLevel
    local iTotal = 0
    local iTotalPoint = 0
    local iSid = 10167
    local mArgs = {
        cancel_tip = true,
    }
    for iLevel=iNowLevel+1,iMaxLevel do
        if not self:ValidFastLearn(oPlayer,oSk,iLevel) then
            break
        end
        local iSilverResume = iTotal + oSk:LearnCostSilver(iLevel)
        if iSilverResume > 0 and not oPlayer.m_oActiveCtrl:ValidSilver(iSilverResume ,mArgs) then
            break
        end
        local iPointResume = iTotalPoint + oSk:LearnCostSkillPoint(iLevel)
        if iPointResume > 0 and oPlayer:GetItemAmount(iSid) < iPointResume then
            break
        end
        iTotal = iSilverResume
        iTotalPoint = iPointResume
        iLearnLevel = iLevel
    end
    if not iLearnLevel then
        return
    end
    if iTotal > 0 then
        oPlayer.m_oActiveCtrl:ResumeSilver(iTotal,"快速学习门派技能")
    end
    if iTotalPoint > 0 then
        oPlayer:RemoveItemAmount(iSid, iTotalPoint, "快速学习门派技能")
    end
    oPlayer.m_oSkillCtrl:SetLevel(iSk,iLearnLevel)
    if iLearnLevel >=2 then
        oPlayer:MarkGrow(9)
    end
    oPlayer.m_oSkillCtrl:GS2CRefreshSkill(oSk)
    local sMsg = self:GetTextData(2031, {name = oSk:Name(),level = oSk:Level()})
    oNotifyMgr:Notify(pid,sMsg)

    local iAddLevel = iLearnLevel - iNowLevel
    self:RecordLearnSkillLog(oPlayer, "fast_learn_skill", iSk, "active", iNowLevel, iLearnLevel, iAddLevel, iTotal, iTotalPoint)
    oPlayer.m_oSkillCtrl:FireLearnActiveSkill(oSk, iLearnLevel, iNowLevel)
end

function CActiveSkillLearn:CalResetReturn(oSk,iStartLevel,iEndLevel)
    if iStartLevel > iEndLevel then
        return 0
    end
    local iTotalPoint = 0
    for iLevel = iStartLevel,iEndLevel do
        iTotalPoint = iTotalPoint + oSk:LearnCostSkillPoint(iLevel)
    end
    return iTotalPoint
end

--重置技能
function CActiveSkillLearn:ResetSkill(oPlayer,iSk)
    local oNotifyMgr = global.oNotifyMgr
    local iSchool = oPlayer:GetSchool()
    local pid = oPlayer:GetPid()
    local mPassiveSkill = loadskill.GetActiveSkill(iSchool)
    if not mPassiveSkill then
        return
    end
    if not table_in_list(mPassiveSkill,iSk) then
        return
    end
    local oSk = oPlayer.m_oSkillCtrl:GetSkill(iSk)
    if not oSk or oSk:Level() <= 1 then
        return
    end
    local mResume = oSk:ResetResume()
    local iGold = 0
    local mRelResume = {}
    for sid, mData in pairs(mResume) do
        local iHasAmount = oPlayer:GetItemAmount(sid)
        local iNeedAmount = mData["amount"]
        if iHasAmount < iNeedAmount then
            local iLack = iNeedAmount - iHasAmount
            iGold = iGold + iLack * mData["gold"]
            if iHasAmount > 0 then
                mRelResume[sid] = iHasAmount
            end
        else
            mRelResume[sid] = iNeedAmount
        end
    end
    if iGold > 0 then
        if not oPlayer:ValidGold(iGold) then
            return
        end
        oPlayer:ResumeGold(iGold, "重置门派主动技能")
    end

    local lItemCost = {}
    for sid, iAmount in pairs(mRelResume) do
        oPlayer:RemoveItemAmount(sid, iAmount, "重置门派主动技能")
        table.insert(lItemCost, {itemid=sid, amount=iAmount})
    end
    local iCurLevel = oSk:Level()
    local iTotalPoint = self:CalResetReturn(oSk,2,iCurLevel)
    oPlayer.m_oSkillCtrl:SetLevel(iSk,1,true)
    if iTotalPoint > 0 then
        oPlayer.m_oActiveCtrl:AddSkillPoint(iTotalPoint,"重置门派主动技能")
        oNotifyMgr:Notify(oPlayer:GetPid(), self:GetTextData(2032, {amount=iTotalPoint}))
    end

    local mLog = oPlayer:LogData()
    mLog["skid"] = iSk
    mLog["level_old"] = iCurLevel
    mLog["gold_cost"] = iGold
    mLog["add_point"] = iTotalPoint
    mLog["item_cost"] = lItemCost
    record.log_db("playerskill", "reset_active_skill", mLog)

    mRelResume[gamedefines.MONEY_TYPE.GOLD] = iGold
    analylog.LogSystemInfo(oPlayer, "reset_school_active", iSk, mRelResume)
end

function NewPassiveSkillLearn( ... )
    local o = CPassiveSkillLearn:New()
    return o
end

function NewActiveSkillLearn()
    local o = CActiveSkillLearn:New()
    return o
end
