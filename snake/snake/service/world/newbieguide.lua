local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local serverflag = import(lualib_path("public.serverflag"))
local loadsummon = import(service_path("summon.loadsummon"))
local testdefines = import(service_path("defines/testdefines"))

function NewNewbieGuideMgr(...)
    return CNewbieGuideMgr:New(...)
end

CNewbieGuideMgr = {}
CNewbieGuideMgr.__index = CNewbieGuideMgr
inherit(CNewbieGuideMgr, logic_base_cls())

function CNewbieGuideMgr:New()
    local o = super(CNewbieGuideMgr).New(self)
    return o
end

-- 判断服务器与玩家信息，确定是否不产生强制新手引导
function CNewbieGuideMgr:IsPlayerSkipNewbieGuide(oPlayer)
    if oPlayer.m_oBaseCtrl.m_oTestCtrl:GetTesterKey(testdefines.TESTER_KEY.NO_GUIDE) then
        return true
    end
    return serverflag.is_close_guide()
end

function CNewbieGuideMgr:OnLogin(oPlayer, bReEnter)
    local mNetOpenNotified = self:PackSysOpenNotified(oPlayer)
    oPlayer:Send("GS2CSysOpenNotified", mNetOpenNotified)
    local mNet = {}
    if self:IsPlayerSkipNewbieGuide(oPlayer) then
        mNet.no_guide = 1
    else
        mNet = self:PackNewbieGuideInfo(oPlayer)
        mNet.no_guide = 0
    end
    oPlayer:Send("GS2CNewbieGuideInfo", mNet)
end

function CNewbieGuideMgr:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)
    local mNewbieUpgrades = table_get_depth(res, {"daobiao", "newbieguide", "newbie_upgrade"})
    local lGrades = table_key_list(mNewbieUpgrades)
    table.sort(lGrades)
    local mRewardedUpgrade = oPlayer:Query("newbie_rwd_upgrade") or {}
    local bChanged = false
    for _, iGrade in ipairs(lGrades) do
        if iGrade <= iFromGrade then
            goto continue
        end
        local sKey = db_key(iGrade)
        if mRewardedUpgrade[sKey] then
            goto continue
        end
        if iGrade > iToGrade then
            break
        end
        local iRewardId = table_get_depth(mNewbieUpgrades, {iGrade, "reward_id"})
        if iRewardId then
            -- TODO log
            mRewardedUpgrade[sKey] = 1
            bChanged = true
            global.oRewardMgr:RewardByGroup(oPlayer, "newbie", iRewardId)
        end
        ::continue::
    end
    if bChanged then
        oPlayer:Set("newbie_rwd_upgrade", mRewardedUpgrade)
    end
end

function CNewbieGuideMgr:UpdateNewbieGuideInfo(oPlayer, lLinkInfos, sExData)
    if self:IsPlayerSkipNewbieGuide(oPlayer) then
        return
    end
    local mNewbieInfo = oPlayer:Query("newbie_guide", {})
    if lLinkInfos then
        for _, mLinkInfo in ipairs(lLinkInfos) do
            local sLinkId = mLinkInfo.linkid
            local iStep = mLinkInfo.step
            local sExInfo = mLinkInfo.exdata
            table_set_depth(mNewbieInfo, {"links"}, sLinkId, {
                step = iStep,
                exdata = sExInfo,
            })
        end
    end
    if sExData then
        mNewbieInfo["exdata"] = sExData
    end
    oPlayer:Set("newbie_guide", mNewbieInfo)
end

function CNewbieGuideMgr:PackNewbieGuideInfo(oPlayer)
    local mNewbieInfo = oPlayer:Query("newbie_guide", {})
    local mLinkInfos = mNewbieInfo.links or {}
    local lNetLinkInfos = {}
    for sLinkId, mLinkInfo in pairs(mLinkInfos) do
        table.insert(lNetLinkInfos, {
            linkid = sLinkId,
            step = mLinkInfo.step,
            exdata = mLinkInfo.exdata,
        })
    end
    return {
        guide_links = lNetLinkInfos,
        exdata = mNewbieInfo.exdata,
    }
end

function CNewbieGuideMgr:SetNewSysOpenNotified(oPlayer, lSysIds)
    local mOpenNotified = oPlayer:Query("sys_open_nofitied", {})
    for _, sSysId in ipairs(lSysIds) do
        mOpenNotified[sSysId] = true
    end
    oPlayer:Set("sys_open_nofitied", mOpenNotified)
end

function CNewbieGuideMgr:PackSysOpenNotified(oPlayer)
    local mOpenNotified = oPlayer:Query("sys_open_nofitied", {})
    return {sys_ids = table_key_list(mOpenNotified)}
end

function CNewbieGuideMgr:GetNewbieSummonSid(oPlayer, iSelection)
    return table_get_depth(res, {"daobiao", "newbieguide", "newbie_summon", iSelection, "summon_id"})
end

function CNewbieGuideMgr:GetNewbieSummonPropIdx(oPlayer, iSelection)
    return table_get_depth(res, {"daobiao", "newbieguide", "newbie_summon", iSelection, "fix_prop_idx"})
end

-- TODO 暂且由前端触发，以后改为后端触发吧
function CNewbieGuideMgr:SelectNewbieSummon(oPlayer, iSelection)
    -- 宠物属性等暂时不额外赋值
    local iOldSelection = oPlayer:Query("newbie_summon")
    if iOldSelection then
        oPlayer:Send("GS2CNewibeSummonGot", {
            succ = 0,
            had_selection = iOldSelection,
        })
        return
    end
    local bSucc = false
    local iSid = self:GetNewbieSummonSid(oPlayer, iSelection)
    local iPropIdx = self:GetNewbieSummonPropIdx(oPlayer, iSelection)
    if iSid and iSid > 0 then
        local oSummon
        if iPropIdx and iPropIdx > 0 then
            oSummon = loadsummon.CreateFixedPropSummon(iSid, iPropIdx)
        else
            oSummon = loadsummon.CreateSummon(iSid, 0)
        end
        if oSummon then
            bSucc = oPlayer.m_oSummonCtrl:AddSummon(oSummon, "newbieguide")
            if not bSucc then
                baseobj_delay_release(oSummon)
            end
        end
    end
    if bSucc then
        -- TODO log
        oPlayer:Set("newbie_summon", iSelection)
    end
    oPlayer:Send("GS2CNewibeSummonGot", {
        succ = bSucc and 1 or 0,
    })
end

function CNewbieGuideMgr:GiveNewbieEquip(oPlayer)
    local mEquipFilters = table_get_depth(res, {"daobiao", "newbieguide", "newbie_equip"})
    if not mEquipFilters then
        return
    end
    for iFilterId, mInfo in pairs(mEquipFilters) do
        local iSid, iFix = global.oRewardMgr:FindItemInFilter(oPlayer, iFilterId)
        local iAutoUse = mInfo.auto_use
        local oItem = oPlayer:GiveEquip(iSid, iFix, "newbie_born")
        -- TODO log
        if oItem and iAutoUse == 1 then
            local sItemType = oItem:ItemType()
            if sItemType == "equip" then
                global.oItemHandler:Wield(oPlayer, oItem)
            end
        end
    end
end

function CNewbieGuideMgr:GetNewbieGuildInfo(oPlayer)
    if not oPlayer then return end

    local mNet = {}
    local oOrgMgr = global.oOrgMgr
    mNet["org_cnt"] = table_count(oOrgMgr:GetNormalOrgs())
    oPlayer:Send("GS2CGetNewbieGuildInfo", mNet) 
end
