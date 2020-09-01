local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))


Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.clone = true
Helpers.clone = {
    "克隆道具",
    "clone 物品类型 物品数量 [额外参数mapping]",
    "clone 1001 200 {lv=4,se_ratio=100}",
}
function Commands.clone(oMaster,sid,iAmount, mArgs)
    if mArgs then
        if type(mArgs) ~= "table" then
            oMaster:NotifyMessage("额外参数为mapping")
            return
        end
    else
        mArgs = {}
    end
    local oNotifyMgr = global.oNotifyMgr
    while(iAmount>0) do
        local iLv = mArgs.lv
        if iLv and global.oItemLoader:GetItemDir(sid) == "equip" then
            if iLv <= 0 or iLv > 4 then
                oMaster:NotifyMessage("lv须在1~4之间")
                return
            end
            mArgs.school = oMaster:GetSchool()
            mArgs.equip_level = iLv
            -- mArgs.quality = iLv
            mArgs.equip_make = true
        end
        local itemobj = global.oItemLoader:Create(sid, mArgs)
        if sid <= 10000 and sid > 1000 then
            itemobj:SetData("Value", iAmount)
            iAmount = 1
        end
        local iMaxAmount = itemobj:GetMaxAmount()
        local iAddAmount = math.min(iAmount,iMaxAmount)
        iAmount = iAmount - iAddAmount
        itemobj:SetAmount(iAddAmount)

        local lItem = {10057, 10051, 10052, 10053, 10054, 10055, 10056}
        if itemobj:ItemType() == "pellet" and not table_in_list(lItem, sid) then
            if not mArgs.quality then
                itemobj:SetQuality(math.random(1, 100))
            end
        end
        oMaster:RewardItem(itemobj, "gm_clone", {from_wh="gm"})
    end
end

Opens.modifyitemlast = false
Helpers.modifyitemlast={
    "更改物品耐久",
    "modifyitemlast 物品pos 变化量",
    "modifyitemlast 1 -10"
}
function Commands.modifyitemlast(oMaster, iPos, iModi)
    local oNotifyMgr = global.oNotifyMgr
    if (iModi == 0) then
        oNotifyMgr:Notify(oMaster.m_iPid,"耐久变化值输入为0")
        return
    end
    local itemobj = oMaster.m_oItemCtrl:GetItem(iPos)
    if not itemobj then
        oNotifyMgr:Notify(oMaster.m_iPid,"物品不存在")
        return
    end

    if not itemobj.AddLast then
        oNotifyMgr:Notify(oMaster.m_iPid,"此物品没有耐久属性")
        return
    end

    itemobj:AddLast(iModi)
    local iCurLast = itemobj:GetLast()
    oNotifyMgr:Notify(oMaster.m_iPid,"物品耐久修改完成，当前为:" .. iCurLast)
end

Opens.clearall = true
Helpers.clearall = {
    "清空背包",
    "clearall",
    "clearall",
}
function Commands.clearall(oMaster)
    for iPos,itemobj in pairs(oMaster.m_oItemCtrl.m_Item) do
        if iPos >= 101 and itemobj then
            local iAmount = itemobj:GetAmount()
            itemobj:AddAmount(-iAmount,"gm")
        end
    end
end

Opens.listallitems = true
Helpers.listallitems = {
    "列出所有道具",
    "listallitems",
    "listallitems",
}
function Commands.listallitems(oMaster)
    local sText = ""
    for iPos,itemobj in pairs(oMaster.m_oItemCtrl.m_Item) do
        if iPos >= 101 then
            sText = sText .. string.format("%d: %d [%d](%d)%s\n", iPos, itemobj.m_ID, itemobj:SID(), itemobj.m_iAmount, itemobj:Name())
        end
    end
    global.oNotifyMgr:Notify(oMaster:GetPid(), "所有物品: " .. sText)
end

Opens.AddExtend2MaxSize = false
Helpers.AddExtend2MaxSize = {
    "解锁所有背包",
    "AddExtend2MaxSize"
}
function Commands.AddExtend2MaxSize(oMaster)
    local iMaxSize = oMaster.m_oItemCtrl:MaxSize()
    local iCurSize = oMaster.m_oItemCtrl:GetSize()
    local iSize = math.min(iMaxSize, iMaxSize - iCurSize)
    if iSize > 0 then
        oMaster.m_oItemCtrl:AddExtendSize(iSize)
    end
end

Opens.itemop = true
function Commands.itemop(oMaster,iFlag,mArgs)
    local itemtest = import(service_path("item/test"))
    itemtest.TestOP(oMaster,iFlag,mArgs)    
end

Opens.copyotheritem = true
function Commands.copyotheritem(oMaster, iTarget, iBind)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        global.oNotifyMgr:Notify(oMaster.m_iPid, "对方没在线") 
        return
    end
    
    Commands.AddExtend2MaxSize(oMaster)

    iBind = iBind or 0 -- 0 不继承绑定 1 继承绑定
    for iPos, itemobj in pairs(oTarget.m_oItemCtrl.m_Item) do
        if iPos >= 101 and itemobj then
            if iBind == 1 then
                local cloneitem = global.oItemLoader:CloneItem(itemobj, oMaster:GetPid())
                oMaster:RewardItem(cloneitem, "gm_clone", {from_wh="gm"})
            else
                local iSid = itemobj:SID()
                local iAmount = itemobj:GetAmount()
                Commands.clone(oMaster, iSid, iAmount, mArgs)
            end
        end
    end

    local m_oActiveCtrl = oTarget.m_oActiveCtrl
    local iSilver = m_oActiveCtrl:GetData("silver", 0)
    local iOweSilver =  m_oActiveCtrl:GetData("silver_owe", 0)
    local iGold = m_oActiveCtrl:GetData("gold", 0)
    local iOweGold = m_oActiveCtrl:GetData("gold_owe", 0)

    oMaster.m_oActiveCtrl:SetData("silver", iSilver)
    oMaster.m_oActiveCtrl:SetData("silver_owe", iOweSilver)
    oMaster:PropChange("silver")

    oMaster.m_oActiveCtrl:SetData("gold", iGold)
    oMaster.m_oActiveCtrl:SetData("gold_owe", iOweGold)
    oMaster:PropChange("gold")

    local iGoldCoin = oTarget:GetProfile().m_iGoldCoin
    local iRplGoldCoin = oTarget:GetProfile().m_iRplGoldCoin
    oMaster:GetProfile().m_iGoldCoin = iGoldCoin
    oMaster:GetProfile().m_iRplGoldCoin = iRplGoldCoin
    oMaster:PropChange("goldcoin", "rplgoldcoin")
end


