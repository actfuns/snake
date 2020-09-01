--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function C2GSWarSkill(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarSkill", oPlayer:GetPid(), mData)
    end
end

function C2GSWarNormalAttack(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarNormalAttack", oPlayer:GetPid(), mData)
    end
end

function C2GSWarProtect(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarProtect", oPlayer:GetPid(), mData)
    end
end

function C2GSWarEscape(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarEscape", oPlayer:GetPid(), mData)
    end
end

function C2GSWarDefense(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarDefense", oPlayer:GetPid(), mData)
    end
end

function C2GSWarSummon(oPlayer,mData)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        local iSumId = mData["sum_id"]
        local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSumId)
        if not oSummon then
            oNotifyMgr:Notify(pid,"没有这只宠物")
            return
        end
        if not oPlayer.m_oSummonCtrl:GetFightSummon() then
            global.oSummonMgr:SetFight(oPlayer, oSummon, 1)
        end

        local mWarInfo = oSummon:PackWarInfo(oPlayer)
        local bCanFight, sMsg = oSummon:CanFight(oPlayer)
        if not bCanFight then
            mWarInfo = {unablefight=true, msg=sMsg}
        end
        local mSumData = {
            sumdata = mWarInfo,
        }
        mData.sumdata = mSumData
        oNowWar:Forward("C2GSWarSummon",oPlayer:GetPid(),mData)
    end
end

function C2GSWarUseItem(oPlayer, mData)
    local oNotifyMgr = global.oNotifyMgr
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        local iItemID = mData["item_id"]
        local iPid = oPlayer:GetPid()
        local oItem = oPlayer.m_oItemCtrl:HasItem(iItemID)
        if not oItem then
            oNotifyMgr:Notify(iPid,"没有这个物品")
            return
        end
        if not oItem:ValidUseInWar() then
            oNotifyMgr:Notify(iPid,"战斗中不能使用该物品")
            return
        end
        local iMask = oPlayer:GenItemLockMask()
        oItem:SetWarLock(iMask)
        global.oWarMgr:RecordUseItem(iPid, iItemID)
        local mWarUseInfo = oItem:PackWarUseInfo()
        local mItemData = {
            itemid = iItemID,
            data = mWarUseInfo,
        }
        mData.itemdata = mItemData
        oNowWar:Forward("C2GSWarUseItem",iPid,mData)
    end
end

function C2GSWarAutoFight(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarAutoFight", oPlayer:GetPid(), mData)
    end
end

function C2GSChangeAutoPerform(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSChangeAutoPerform", oPlayer:GetPid(), mData)
    end
end

function C2GSWarCommand(oPlayer,mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        local mNet = {}
        mNet.data = mData
        mNet.type = 1
        oNowWar:Forward("C2GSWarCommand", oPlayer:GetPid(), mNet)
    end
end

function C2GSWarCommandOP(oPlayer,mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarCommandOP", oPlayer:GetPid(), mData)
    end
end

function C2GSWarAnimationEnd(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == mData.war_id then
        oNowWar:Forward("C2GSWarAnimationEnd", oPlayer:GetPid(), mData)
    end
end

function C2GSReEnterWar(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        oNowWar:ReEnterPlayer(oPlayer)
    end
end
