--import module
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local learnskill = import(service_path("skill/skilllearn"))
local loadskill = import(service_path("skill/loadskill"))

local function SortSIDFunc(lItem1, lItem2)
    local sid1, eq1, sort1, lv1 = table.unpack(lItem1)
    local sid2, eq2, sort2, lv2 = table.unpack(lItem2)
    if eq1 and not eq2 then
        return true
    elseif not eq1 and eq2 then
        return false
    else
        if sort1 ~= sort2 then
            return sort1 < sort2
        end
        if eq1 then
            if lv1 ~= lv2 then
                return lv1 > lv2
            end
        end
        if sid1 ~= sid2 then
            return sid1 <sid2
        end
    end
    return false
end

local function SortSameShapeFunc(lItem1, lItem2)
    local id1, eq1, quality1, amount1,bHS = table.unpack(lItem1)
    local id2, eq2, quality2, amount2,bHS = table.unpack(lItem2)

    if bHS then
        if quality1 ~= quality2 then
            return quality1 < quality2
        else
            if amount1 ~= amount2 then
                return amount1 > amount2
            else
                return id1 < id2
            end
        end
    end

    if eq1 then
        if quality1 ~= quality2 then
            return quality1 > quality2
        else
            if amount1 ~= amount2 then
                return amount1 > amount2
            else
                return id1 < id2
            end
        end
    else
        if amount1 ~= amount2 then
            return amount1 > amount2
        else
            if quality1 ~= quality2 then
                return quality1 > quality2
            else
                return id1 < id2
            end
        end
    end
    return false
end


function NewPubMgr()
    local o = CPublicMgr:New()
    return o
end

CPublicMgr = {}
CPublicMgr.__index = CPublicMgr
inherit(CPublicMgr, logic_base_cls())

function CPublicMgr:New()
    local o = super(CPublicMgr).New(self)
    o:InitLearnSkill()
    return o
end

function CPublicMgr:Release()
    baseobj_safe_release(self.m_oLearnActiveSkill)
    baseobj_safe_release(self.m_oLearnPassiveSkill)
    super(CPublicMgr).Release(self)
end

function CPublicMgr:InitLearnSkill()
    self.m_oLearnActiveSkill = learnskill.NewActiveSkillLearn()
    self.m_oLearnPassiveSkill = learnskill.NewPassiveSkillLearn()
end

function CPublicMgr:OnlineExecute(pid,sFunc,mArgs)
    if not pid then
        record.warning(string.format("OnlineExecute no pid %s",sFunc))
        print(debug.traceback())
        return
    end
    -- params sFunc: 待执行方法
    -- params mArgs: 待执行方法参数列表
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadPrivacy(pid, function(oPrivacy)
        if oPrivacy then
            oPrivacy:AddFunc(sFunc, mArgs)
        end
    end)
end


function CPublicMgr:Arrange(pid,oContainer)
    local mOldPos = {}
    local mNewPos = {}
    local iBasePos = 0
    local iStartPos = oContainer:GetStartPos()

    local mShapes = oContainer:GetShapes()
    local lSIDs = {}
    for sid, info in pairs(mShapes) do
        local oItem = oContainer:GetItemObj(sid)
        local bEq = oItem.m_ItemType == "equip"
        local iSort = oItem:SortNo()
        local iEqLv = bEq and oItem:EquipLevel() or 0
        table.insert(lSIDs, {sid, bEq, iSort, iEqLv})
    end
    table.sort(lSIDs, SortSIDFunc)
    for _, info in ipairs(lSIDs) do
        local sid = info[1]
        local mCombine = {}
        local mPerCombineCnt = {}
        local iMaxAmount = 1
        local lSort = {}
        local mAfter = {}
        for iItem, _ in pairs(mShapes[sid] or {}) do
            local oItem = oContainer:HasItem(iItem)
            if oItem then
                local sCombineKey = oItem:CombineKey()
                local lCombine = mCombine[sCombineKey]
                if not lCombine then
                    lCombine = {oItem}
                    mCombine[sCombineKey] = lCombine
                    mPerCombineCnt[sCombineKey] = oItem:GetAmount()
                    iMaxAmount = oItem:GetMaxAmount()
                else
                    table.insert(mCombine[sCombineKey], oItem)
                    mPerCombineCnt[sCombineKey] = mPerCombineCnt[sCombineKey] + oItem:GetAmount()
                end
            end
        end
        for sCombineKey, iTotAmount in pairs(mPerCombineCnt) do
            local iCnt = iTotAmount // iMaxAmount
            if iTotAmount > iCnt * iMaxAmount then
                iCnt = iCnt + 1
            end
            local iLeft = iTotAmount
            local lCombine = mCombine[sCombineKey]
            for i = 1, iCnt do
                local oDestObj = lCombine[i]
                local oSrcObj = lCombine[#lCombine]
                if oDestObj.m_ID == oSrcObj.m_ID then
                    break
                end
                local iAddAmount = math.max(math.min(iLeft, iMaxAmount) - oDestObj:GetAmount(),0)
                while (next(lCombine) and iAddAmount > 0) do
                    local oSrcObj = lCombine[#lCombine]
                    if oDestObj.m_ID == oSrcObj.m_ID then
                        break
                    end
                    local iAdd = math.min(iAddAmount, oSrcObj:GetAmount())
                    if iAdd > 0 then
                        iAddAmount = iAddAmount - iAdd
                        oSrcObj:AddAmount(-iAdd,"arrange",{from_wh=1})
                        oDestObj:AddAmount(iAdd,"arrange",{from_wh=1})
                        oDestObj:AfterCombine(oSrcObj:Save())
                        if oSrcObj:GetAmount() <= 0 then
                            table.remove(lCombine)
                        end
                    end
                end
            end
            for _, oDestObj in ipairs(lCombine) do
                local id = oDestObj.m_ID
                local bEq = oDestObj.m_ItemType == "equip"
                local iQuality = oDestObj:Quality(true)
                local iAmount = oDestObj:GetAmount()
                table.insert(lSort, {id, bEq, iQuality, iAmount,oDestObj:IsHunShi()})
                mAfter[id] = oDestObj
            end
        end
        table.sort(lSort, SortSameShapeFunc)

        for pos, info in ipairs(lSort) do
            local srcobj = mAfter[info[1]]
            local iPos = pos + iBasePos
            if oContainer:ValidArrangeChange(srcobj,iPos) then
                local destobj = oContainer:ArrangeChange(srcobj,iPos)
                mNewPos[srcobj.m_ID] = srcobj.m_Pos
                if destobj then
                    mNewPos[destobj.m_ID] = destobj.m_Pos
                end
            end
        end
        iBasePos = iBasePos + #lSort
    end

    local mChange = {}
    for itemid, iPos in pairs(mNewPos) do
        table.insert(mChange,{itemid = itemid, pos = iPos})
    end
    oContainer:GS2CItemArrange(pid, mChange)
end


function CPublicMgr:GetLearnSkillObj(sType)
    if sType == "active" then
        return self.m_oLearnActiveSkill
    elseif sType == "passive" then
        return self.m_oLearnPassiveSkill
    end
end

--初始化一些配置信息
function CPublicMgr:InitConfig()
    loadskill.InitSkillConfig()
end
