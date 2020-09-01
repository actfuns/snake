
local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))
local wardefines = import(service_path("fight/wardefines"))

function NewWarItem(...)
    local o = CWarItem:New(...)
    return o
end


CWarItem = {}
CWarItem.__index = CWarItem
inherit(CWarItem, logic_base_cls())

function CWarItem:New(id)
    local o = super(CWarItem).New(self)
    o.m_iID = id
    return o
end

function CWarItem:CheckAction(oAction, oVictim, mArgs, iPid)
    return true
end

function CWarItem:Action(oAction, oVictim, mArgs, iPid)
    return true
end

function CWarItem:DoResDrug(oAction, iLv)
    if iLv <= 1 then return end
    local oWar = oAction:GetWar()
    if oWar and oWar:GetWarType() ~= gamedefines.WAR_TYPE.PVP_TYPE then
        return
    end

    local oBuffMgr = oAction.m_oBuffMgr
    local oBuff = oBuffMgr:HasBuff(139)
    if not oBuff then
        oBuffMgr:AddBuff(139, 99, {bForce=true})
        oBuff = oBuffMgr:HasBuff(139)
    end
    iLv = iLv + iLv * oAction:Query("res_drug_add_ratio", 0)
    oBuff:AddDrugPoint(math.floor(iLv), oAction)
end

function CWarItem:MaxUseItemCnt(iType)
    if iType == 1 then
        return 10
    elseif iType == 2 then
        return 20
    end
    return 0
end

function CWarItem:CanUseItem(oAction, mArgs, iPid, iItemId)
    local iItem = mArgs["sid"] or 0
    local iAmount = mArgs["amount"] or 0
    local iCalType = mArgs["cal_type"] or 0

    local oWar = oAction:GetWar()
    if not oWar then return false end

    local oPlayer = oWar:GetPlayerWarrior(iPid)
    if not oPlayer then return false end

    local mUseItem = oPlayer:QueryBoutArgs("use_item", {})
    local iUseCnt = mUseItem[iItemId] or 0
    if iUseCnt + 1 > iAmount then
        oPlayer:Notify("物品已被使用")
        return false
    end

    local bUse = true
    if iCalType > 0 and oPlayer:GetUseDrugCnt(iCalType) >= self:MaxUseItemCnt(iCalType) then
        oPlayer:Notify("物品使用已达上限")
        bUse = false
    end
    return bUse
end

function CWarItem:DoRecordUseItem(oAction, iPid, iItemId)
    local oWar = oAction:GetWar()
    if not oWar then return end
    local oPlayer = oWar:GetPlayerWarrior(iPid)
    if not oPlayer then return end

    local mUseItem = oPlayer:QueryBoutArgs("use_item", {})
    local iUseCnt = mUseItem[iItemId] or 0
    mUseItem[iItemId] = iUseCnt + 1
    oPlayer:SetBoutArgs("use_item", mUseItem)
end

function CWarItem:DoActionEnd(oAction, oVictim, mArgs, iPid, iItemId, sTips)
    local iLv = mArgs["level"] or 0
    self:DoResDrug(oVictim, iLv)

    local oWar = oAction:GetWar()
    if not oWar then return end
    local oPlayer = oWar:GetPlayerWarrior(iPid)
    if not oPlayer then return end
    self:AddUseDrugCnt(oAction, mArgs, oPlayer)

    local mFunc = oAction:GetFunction("DoActionEnd")
    for _,fCallback in pairs(mFunc) do
        safe_call(fCallback, oAction, oVictim, self.m_iID, mArgs)
    end

    oWar:AddDebugMsg(string.format("#B%s#n对#B%s#n使用了道具#B%s#n,当前抗药性%d%%",
        oAction:GetName(),
        oVictim:GetName(),
        mArgs.sid or "",
        oVictim:QueryAttr("res_drug")
    ), true)

    oPlayer:Notify(string.format("使用了物品%s", sTips), 3)
end

function CWarItem:AddUseDrugCnt(oAction, mArgs, oPlayer)
    local iItem = mArgs["sid"] or 0
    if not oPlayer then return end

    local iCalType = mArgs["cal_type"] or 0
    if iCalType > 0 then
        oPlayer:AddUseDrugCnt(iCalType, 1)
    end
end
