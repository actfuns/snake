local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"

local titledefines = import(service_path("title.titledefines"))
local loadtitle = import(service_path("title.loadtitle"))

function NewTitleMgr(...)
    return CTitleMgr:New(...)
end

CTitleMgr = {}
CTitleMgr.__index = CTitleMgr
inherit(CTitleMgr,logic_base_cls())

function CTitleMgr:New()
    local o = super(CTitleMgr).New(self)
    return o
end

function CTitleMgr:AddTitle(iPid, iTid, name)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:AddTitle(iTid, get_time(), name)
    else
        local oPubMgr = global.oPubMgr
        oPubMgr:OnlineExecute(iPid, "AddTitle", {iTid, get_time(), name})
        local mLogData={
            pid = iPid,
            title = iTid,
        }
        record.log_db("title", "offlineadd",mLogData)
    end
end

function CTitleMgr:RemoveOneTitle(iPid, iTid)
    self:RemoveTitles(iPid, {iTid})
end

function CTitleMgr:RemoveTitles(iPid, lTids)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:RemoveTitles(lTids)
    else
        local oPubMgr = global.oPubMgr
        oPubMgr:OnlineExecute(iPid, "RemoveTitles", {lTids})
    end
end

function CTitleMgr:SyncTitleName(iPid, iTid, name)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:SyncTitleName(iTid, name)
    else
        local oPubMgr = global.oPubMgr
        oPubMgr:OnlineExecute(iPid, "SyncTitleName", {iTid, name})
    end
end

function CTitleMgr:RefreshTitle(iPid, iTid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer.m_oTitleCtrl:RrefreshTitle(oPlayer, iTid)
    end
end

function CTitleMgr:UseTitle(oPlayer, iTid)
    oPlayer.m_oTitleCtrl:UseTitle(oPlayer, iTid)
end

function CTitleMgr:UnUseTitle(oPlayer)
    oPlayer.m_oTitleCtrl:UnUseTitle(oPlayer)
end

function CTitleMgr:GetTitleText(iText, m)
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:GetTextData(iText, {"title"})
    if sText and m then
        sText = oToolMgr:FormatColorString(sText, m)
    end
    return sText
end

function CTitleMgr:GetTitleDataByTid(iTid)
    return loadtitle.GetTitleDataByTid(iTid)
end

-- 如果不在线，在登录的时候处理
function CTitleMgr:CheckOrgPositionTitle(iPid, iPos, sOrgName)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iTid = titledefines.ORG_TITLE[iPos]
    if not iTid then return end

    if oPlayer:GetTitle(iTid) then return end

    local mData = self:GetTitleDataByTid(iTid)
    if not mData then return end 
    
    self:RemoveTitles(iPid, table_value_list(titledefines.ORG_TITLE))
    local sName = string.format(mData.name, sOrgName)
    self:AddTitle(iPid, iTid, sName)
end

function CTitleMgr:ChangeToOrgTitle(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iPos = oOrg:GetPosition(iPid)
    local iTid = titledefines.ORG_TITLE[iPos]
    if not iTid then return end

    self:UseTitle(oPlayer, iTid)
end

function CTitleMgr:GetOrgTitleByPos(iPos)
    return titledefines.ORG_TITLE[iPos]
end

function CTitleMgr:ClearOrgPositionTitle(iPid)
    self:RemoveTitles(iPid, table_value_list(titledefines.ORG_TITLE))
end

-- 活跃称谓　1001
function CTitleMgr:SetHuoYueTitle(iPid, iPointCnt, iAdd)
    if iPointCnt >= 100 and iPointCnt - iAdd < 100 then
        self:AddTitle(iPid, 1001)
    end
end

-- 等级排行榜　第一名(1002)
function CTitleMgr:SetGradeRankTitle(iPid, iRank)
    if iRank == 1 then
        self:AddTitle(iPid, 1002)
    end
end

function CTitleMgr:OnLeaveOrg(iPid)
    local lTitle = titledefines.TITLE_BASE["orgrank"] or {}
    self:RemoveTitles(iPid, lTitle)
end

function CTitleMgr:OnChangeOrgPos(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local lTitle = titledefines.TITLE_BASE["orgrank"] or {}
        for _,iTitle in pairs(lTitle) do
            oPlayer.m_oTitleCtrl:SyncTitleName(oPlayer, iTitle)
        end
    end
end

function CTitleMgr:SyncOrgTitle(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    for _, iTitle in pairs(titledefines.ORG_NAME_TITLE) do
        oPlayer:SyncTitleName(iTitle)
    end
end

function CTitleMgr:GetText(iText, m)
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:GetTextData(iText, {"title"})
    if sText and m then
        sText = oToolMgr:FormatColorString(sText, m)
    end
    return sText
end
