local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:FormulaItemEnv(oPlayer, mEnv)
    local mEnv = super(CItem).FormulaItemEnv(self, oPlayer, mEnv)
    mEnv.SLV = oPlayer:GetServerGrade()
    return mEnv
end

function CItem:CalItemFormula(oPlayer, mEnv)
    local sFormula = self:GetItemData()["item_formula"]
    local mItemEnv = self:FormulaItemEnv(oPlayer, mEnv)
    return formula_string(sFormula, mItemEnv)
end

function CItem:TrueUse(oPlayer, target)
    if self:ValidTrueUse(oPlayer, iTarget) ~= 1 then
        return false
    end
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return false end

    local mRet = self:CalItemFormula(oPlayer)
    local iCostAmount = self:GetUseCostAmount()
    oPlayer:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    oPlayer:RewardCultivateExp(math.floor(mRet.expert), "恭喜发财")

    local mReplace = {role=oPlayer:GetName(), map=oScene:GetName()}
    self:SysAnnounce(1066, mReplace)

    local lPlayer = table_key_list(oScene.m_mPlayers)
    local sKey = "item_" .. self.m_ID
    global.oToolMgr:ExecuteList(lPlayer, 200, 1500, 0, sKey, TryAddBuff)
    return true
end

function CItem:ValidTrueUse(oPlayer, iTarget, bIgnore)
    local mRet = self:CalItemFormula(oPlayer)
    local iExpert = math.floor(mRet.expert)
    local iItem = self.m_ID
    if not oPlayer.m_oSkillCtrl:CanAnyCulSkillAddExp(iExpert) then
        if not bIgnore then
            local mData = {
                sContent = global.oToolMgr:GetTextData(1035, {"itemtext"}),
            }
            mData = global.oCbMgr:PackConfirmData(nil, mData)
            local func = function(oPlayer, mData)
                if mData.answer == 1 then
                    TrueUseForSilver(oPlayer, mData, iItem)
                end
            end
            global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
        end
        return 1001
    end
    if not oPlayer.m_oSkillCtrl:CanAddCurrCulSkillExp(iExpert) then
        if not bIgnore then
            local mData = {
                sContent = global.oToolMgr:GetTextData(1034, {"itemtext"}),
            }
            mData = global.oCbMgr:PackConfirmData(nil, mData)
            local func = function(oPlayer, mData)
                if mData.answer == 1 then
                    TrueUseForExpert(oPlayer, mData, iItem)
                end
            end
            global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
        end
        return 1002
    end
    return 1
end

function CItem:SysAnnounce(iChat, mReplace)
    local mInfo = res["daobiao"]["chuanwen"][iChat]
    if not mInfo then return end

    local sMsg, iHorse = mInfo.content, mInfo.horse_race
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
end

function TrueUseForSilver(oPlayer, mData, iItem)
    local oItem = oPlayer:HasItem(iItem)
    if not oItem or not oItem:ValidUse() then return end

    local iRet = oItem:ValidTrueUse(oPlayer, nil, true)
    if iRet == 1001 then
        local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
        if not oScene then return false end

        local mRet = oItem:CalItemFormula(oPlayer)
        local iCostAmount = oItem:GetUseCostAmount()
        oPlayer:RemoveOneItemAmount(oItem, iCostAmount, "itemuse")
        oPlayer:RewardSilver(math.floor(mRet.silver), "恭喜发财")

        local mReplace = {role=oPlayer:GetName(), map=oScene:GetName()}
        oItem:SysAnnounce(1066, mReplace)

        local lPlayer = table_key_list(oScene.m_mPlayers)
        local sKey = "item_" .. oItem.m_ID
        global.oToolMgr:ExecuteList(lPlayer, 200, 1500, 0, sKey, TryAddBuff)
    else
        oItem:Use(oPlayer)
    end
end

function TrueUseForExpert(oPlayer, mData, iItem)
    local oItem = oPlayer:HasItem(iItem)
    if not oItem then return end

    global.oUIMgr:GS2COpenCultivateUI(oPlayer)
end

function TryAddBuff(iPid)
    if not iPid then return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)

    if not oPlayer or oPlayer:GetGrade() < 20 then
        return
    end

    oPlayer.m_oStateCtrl:AddState(1009, {time=3600})
end
